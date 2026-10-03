# frozen_string_literal: true

require "test_helper"

class ComposerTest < Minitest::Test
  def test_composes_finite_type_facts_into_missing_inputs_and_preserves_dsl_domains
    dsl_source = source("spec.rb", 2)
    age_source = source("types.rbs", 8)
    flag_source = source("types.rbs", 12)
    age = input(:age, SpecProof::IntegerDomain.new(lower: 0, upper: 120), source: dsl_source)
    specification = SpecProof::Specification.new(target: "Person#register", inputs: { age: age }, source: dsl_source)
    facts = [
      fact("Person#register", :age, constraint(integer_any: true), age_source),
      fact("Person#register", :flag, constraint(values: [nil, true, false]), flag_source)
    ]

    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: facts)

    assert_equal ["Person#register"], composed.map(&:target)
    assert_equal %i[age flag], composed.first.inputs.keys
    assert_equal [0, 120], [composed.first.inputs[:age].domain.lower, composed.first.inputs[:age].domain.upper]
    assert_equal [nil, false, true], composed.first.inputs[:flag].domain.values
    assert_empty composed.first.inputs[:flag].partitions
    refute composed.first.inputs[:flag].exhaustive
    refute composed.first.inputs[:flag].disjoint
    assert_equal flag_source, composed.first.inputs[:flag].source
    assert_equal facts.first.constraint, composed.first.inputs[:age].type_constraint
    assert_equal facts.last.constraint, composed.first.inputs[:flag].type_constraint
    assert_equal [age_source], composed.first.inputs[:age].type_sources
    assert_equal [flag_source], composed.first.inputs[:flag].type_sources
    assert_equal [dsl_source, age_source], composed.first.inputs[:age].sources
    assert composed.frozen?
    assert composed.first.frozen?
    assert composed.first.inputs.frozen?
  end

  def test_type_only_specifications_and_fact_order_are_canonical
    sources = [source("z.rbs", 8), source("a.rbs", 14)]
    first_facts = [
      fact("Zoo#run", :z, constraint(values: [:z]), sources[0]),
      fact("Alpha#run", :x, constraint(values: [nil, 0, 1]), sources[1]),
      fact("Alpha#run", :y, constraint(values: [true]), sources[0])
    ]
    second_facts = first_facts.reverse

    first = SpecProof::Composer.compose(specifications: [], type_facts: first_facts)
    second = SpecProof::Composer.compose(specifications: [], type_facts: second_facts)

    assert_equal first.map(&:target), second.map(&:target)
    first_entries = first.map { |spec| [spec.source, spec.inputs.keys, spec.inputs.values.map(&:source)] }
    second_entries = second.map { |spec| [spec.source, spec.inputs.keys, spec.inputs.values.map(&:source)] }
    assert_equal first_entries, second_entries
    assert_equal ["Alpha#run", "Zoo#run"], first.map(&:target)
    assert_equal sources[1], first.first.source
    assert_equal [nil, 0, 1], first.first.inputs[:x].domain.values
  end

  def test_preserves_exclusions_and_rejects_type_fact_collisions
    dsl_source = source("spec.rb", 2)
    exclusion = SpecProof::Exclusion.new(name: :payload, reason: "outside scope", source: dsl_source)
    specification = SpecProof::Specification.new(
      target: "Person#register",
      inputs: { enabled: input(:enabled, SpecProof::FiniteDomain.new([true]), source: dsl_source) },
      exclusions: { payload: exclusion }, source: dsl_source
    )
    fact = fact("Person#register", :enabled, constraint(values: [true]), source("types.rbs", 9))

    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: [fact]).fetch(0)

    assert_equal specification.exclusions, composed.exclusions
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Composer.compose(specifications: [specification],
                                  type_facts: [fact("Person#register", :payload, constraint(values: [true]),
                                                    source("types.rbs", 10))])
    end
    assert_equal "input_exclusion_overlap", error.code
  end

  def test_rejects_composition_without_an_analyzed_input
    exclusion = SpecProof::Exclusion.new(name: :payload, reason: "outside scope", source: source("spec.rb", 2))
    specification = SpecProof::Specification.new(target: "Person#register", inputs: {},
                                                 exclusions: { payload: exclusion }, source: exclusion.source)

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Composer.compose(specifications: [specification], type_facts: [])
    end

    assert_equal "inputs_required", error.code
  end

  def test_integer_any_without_dsl_refinement_requires_a_finite_domain
    type_source = source("types.rbs", 4)
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Composer.compose(specifications: [],
                                  type_facts: [fact("Person#age", :age, constraint(integer_any: true), type_source)])
    end

    assert_equal "domain_refinement_required", error.code
    assert_includes error.message, "Person#age"
    assert_includes error.message, "age"
    assert_includes error.message, "types.rbs:4"
  end

  def test_conflicting_finite_type_facts_are_reported_and_planning_rejects_them
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    specification = SpecProof::Specification.new(
      target: "Person#active",
      inputs: { active: input(:active, SpecProof::FiniteDomain.new([nil, false, :unexpected]), source: dsl_source) },
      source: dsl_source
    )
    facts = [fact("Person#active", :active, constraint(values: [false, true]), type_source)]
    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: facts)
    findings = SpecProof.check(composed)

    assert_equal [:type_domain_conflict], findings.map(&:code)
    assert_nil findings.first.witness
    assert_equal [dsl_source, type_source], findings.first.sources
    error = assert_raises(SpecProof::InvalidSpecificationError) { SpecProof.plan(composed) }
    assert_equal [:type_domain_conflict], error.findings.map(&:code)
  end

  def test_conflicting_integer_domain_uses_a_finite_excluded_witness_without_enumeration
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    huge = 10**100
    specification = SpecProof::Specification.new(
      target: "Person#age",
      inputs: { age: input(:age, SpecProof::IntegerDomain.new(lower: 0, upper: huge), source: dsl_source) },
      source: dsl_source
    )
    facts = [fact("Person#age", :age, constraint(values: [1, 2]), type_source)]

    finding = SpecProof.check(SpecProof::Composer.compose(specifications: [specification], type_facts: facts)).first

    assert_equal :type_domain_conflict, finding.code
    assert_equal 0, finding.witness
    assert_equal [dsl_source, type_source], finding.sources
  end

  def test_type_only_boolean_and_integer_union_keep_nullable_finite_members
    boolean_fact = fact("Person#active", :active, constraint(values: [nil, false, true]), source("active.rbs", 4))
    integer_fact = fact("Person#score", :score, constraint(values: [nil, 0, 1]), source("score.rbs", 7))

    composed = SpecProof::Composer.compose(specifications: [], type_facts: [integer_fact, boolean_fact])

    active = composed.find { |spec| spec.target == "Person#active" }.inputs[:active]
    assert_equal [nil, false, true], active.domain.values
    assert_equal [nil, 0, 1], composed.find { |spec| spec.target == "Person#score" }.inputs[:score].domain.values
  end

  def test_integer_optional_type_accepts_a_dsl_range_that_excludes_nil
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    specification = SpecProof::Specification.new(
      target: "Person#age",
      inputs: { age: input(:age, SpecProof::IntegerDomain.new(lower: 0, upper: 120), source: dsl_source) },
      source: dsl_source
    )
    type_fact = fact("Person#age", :age, constraint(integer_any: true, values: [nil]), type_source)
    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: [type_fact])

    assert_empty SpecProof.check(composed)
    assert_equal [0, 120], [composed.first.inputs[:age].domain.lower, composed.first.inputs[:age].domain.upper]
  end

  def test_integer_optional_type_keeps_nil_in_a_finite_dsl_domain
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    specification = SpecProof::Specification.new(
      target: "Person#score",
      inputs: { score: input(:score, SpecProof::FiniteDomain.new([nil, 0, 1]), source: dsl_source) },
      source: dsl_source
    )
    type_fact = fact("Person#score", :score, constraint(integer_any: true, values: [nil]), type_source)
    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: [type_fact])

    assert_empty SpecProof.check(composed)
    assert_equal [nil, 0, 1], composed.first.inputs[:score].domain.values
    assert_equal [nil, 0, 1], SpecProof.plan(composed).map(&:value)
  end

  def test_finite_domain_conflict_preserves_all_declared_values
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    domain = SpecProof::FiniteDomain.new([true, :unexpected])
    specification = SpecProof::Specification.new(
      target: "Person#active", inputs: { active: input(:active, domain, source: dsl_source) }, source: dsl_source
    )
    facts = [fact("Person#active", :active, constraint(values: [false, true]), type_source)]
    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: facts)

    assert_equal [true, :unexpected], composed.first.inputs[:active].domain.values
    assert_equal :unexpected, SpecProof.check(composed).first.witness
  end

  def test_integer_range_conflict_finds_a_gap_in_the_type_values
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    specification = SpecProof::Specification.new(
      target: "Person#age",
      inputs: { age: input(:age, SpecProof::IntegerDomain.new(lower: 0, upper: 4), source: dsl_source) },
      source: dsl_source
    )
    facts = [fact("Person#age", :age, constraint(values: [0, 1, 3, 4]), type_source)]

    finding = SpecProof.check(SpecProof::Composer.compose(specifications: [specification], type_facts: facts)).first

    assert_equal 2, finding.witness
  end

  def test_partitions_keep_promises_and_their_source_specific_findings
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    first_partition_source = source("spec.rb", 4)
    second_partition_source = source("spec.rb", 5)
    partitions = [
      SpecProof::Partition.new(name: :first, domain: SpecProof::FiniteDomain.new([1]), source: first_partition_source),
      SpecProof::Partition.new(name: :second, domain: SpecProof::FiniteDomain.new([1]), source: second_partition_source)
    ]
    declared_input = SpecProof::Input.new(name: :value, domain: SpecProof::FiniteDomain.new([1, 2, 3]),
                                          partitions: partitions, exhaustive: true, disjoint: true, source: dsl_source)
    specification = SpecProof::Specification.new(target: "Example#value", inputs: { value: declared_input },
                                                 source: dsl_source)
    type_fact = fact("Example#value", :value, constraint(values: [1, 2, 3]), type_source)
    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: [type_fact])
    findings = SpecProof.check(composed)

    assert_equal partitions, composed.first.inputs[:value].partitions
    assert composed.first.inputs[:value].exhaustive
    assert composed.first.inputs[:value].disjoint
    gap = findings.find { |finding| finding.code == :partition_gap }
    overlap = findings.find { |finding| finding.code == :partition_overlap }
    assert_equal [dsl_source, type_source], gap.sources
    assert_equal [first_partition_source, second_partition_source], overlap.sources
  end

  def test_duplicate_type_facts_are_rejected_and_loader_duplicate_dsl_error_remains
    type_source = source("types.rbs", 4)
    facts = [fact("Person#age", :age, constraint(values: [1]), type_source),
             fact("Person#age", :age, constraint(values: [2]), source("other.rbs", 6))]

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Composer.compose(specifications: [], type_facts: facts)
    end
    assert_equal "duplicate_type_fact", error.code
    assert_includes error.message, "Person#age"
    assert_includes error.message, "age"

    dsl = <<~RUBY
      SpecProof.define "Person#age" do
        input :age, values: [1]
        input :age, values: [2]
      end
    RUBY
    assert_equal "duplicate_input", assert_raises(SpecProof::ConfigurationError) { load_text(dsl) }.code

    duplicate_target_dsl = <<~RUBY
      SpecProof.define "Person#age" do
        input :age, values: [1]
      end
      SpecProof.define "Person#age" do
        input :age, values: [2]
      end
    RUBY
    error = assert_raises(SpecProof::ConfigurationError) { load_text(duplicate_target_dsl) }
    assert_equal "duplicate_target", error.code
  end

  def test_duplicate_specification_targets_are_rejected_by_composer
    first_source = source("first.rb", 2)
    second_source = source("second.rb", 3)
    first = SpecProof::Specification.new(target: "Person#age", inputs: {}, source: first_source)
    second = SpecProof::Specification.new(target: "Person#age", inputs: {}, source: second_source)

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Composer.compose(specifications: [first, second], type_facts: [])
    end

    assert_equal "duplicate_target", error.code
    assert_includes error.message, "Person#age"
    assert_includes error.message, "first.rb:2"
    assert_includes error.message, "second.rb:3"
  end

  def test_equivalent_dsl_and_composed_domains_keep_obligation_identity_and_digest
    dsl_source = source("spec.rb", 2)
    type_source = source("types.rbs", 9)
    specification = SpecProof::Specification.new(
      target: "Person#active",
      inputs: { active: input(:active, SpecProof::FiniteDomain.new([false, true]), source: dsl_source) },
      source: dsl_source
    )
    type_fact = fact("Person#active", :active, constraint(values: [false, true]), type_source)
    composed = SpecProof::Composer.compose(specifications: [specification], type_facts: [type_fact])

    assert_equal SpecProof.plan([specification]).map(&:id), SpecProof.plan(composed).map(&:id)
    assert_equal SpecProof.plan([specification]).map(&:reasons), SpecProof.plan(composed).map(&:reasons)
    assert_equal SpecProof::Report.digest([specification]), SpecProof::Report.digest(composed)
    assert_equal [[dsl_source, type_source], [dsl_source, type_source]],
                 SpecProof.plan(composed).map(&:sources)
  end

  private

  def source(path, line)
    kind = path.end_with?(".rbs") ? "rbs" : "dsl"
    SpecProof::Source.new(path: path, line: line, kind: kind)
  end

  def constraint(integer_any: false, values: [])
    SpecProof::ScalarTypeConstraint.new(integer_any: integer_any, values: values)
  end

  def input(name, domain, source:)
    SpecProof::Input.new(name: name, domain: domain, partitions: [], exhaustive: false, disjoint: false, source: source)
  end

  def fact(target, name, type_constraint, type_source)
    SpecProof::InputTypeFact.new(target: target, input: name, constraint: type_constraint, source: type_source)
  end

  def load_text(content)
    require "tempfile"
    Tempfile.create(["specproof-composer", ".rb"]) do |file|
      file.write(content)
      file.flush
      return SpecProof.load([file.path])
    end
  end
end
