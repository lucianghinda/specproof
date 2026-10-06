# String and method-object targets

Support `SpecProof.define "DeliveryOptions#build"`,
`SpecProof.define DeliveryOptions.instance_method(:build)`,
`SpecProof.define "DeliveryOptions.build"`, and
`SpecProof.define DeliveryOptions.method(:build)`.

Strings stay unresolved during offline checking/planning. Method objects
require loaded code and normalize to the same string identity, giving identical
digests and obligation IDs for equivalent declarations. Reports retain string
targets. Editor navigation depends on the language server; no navigation
guarantee is implied.

Support directly defined public Ruby instance methods on named classes and
singleton methods on named classes/modules. Reject aliases as declarations,
inherited singleton methods, anonymous owners and bound methods on arbitrary
instances. Unbound instance methods identify their defining class. Validate
that method objects still represent the current directly defined method when
declared. Collection resolves canonical names afresh when started and retains
method-redefinition, constant-binding and duplicate-binding guards.

Shared interface: `TargetName.normalize(target, source: nil)` produces a
validated string. `TargetName.parse(string)` returns `[owner_path, method_name,
kind]`, where owner_path is a String, method_name a Symbol, and kind is
`:instance` or `:singleton`. Legacy valid string identities stay unchanged.

Implementation lanes: target normalization/DSL/signatures; singleton runtime
collection; RBS singleton projection; documentation and agent guidance.
RBS selection remains explicit and supports `def self.build` in named classes
and modules, with existing restrictions on overloads, unsupported inputs,
aliases and instance module methods.

Acceptance: equivalent string/object plans and reports; independent `#build`
and `.build` identities; positional/keyword/default/excluded inputs; real
Minitest collection; no invocation during normalization; clear unsupported
target errors; no autoload from strings; aliases called through the selected
definition retain current collection semantics; redefinition/binding changes
cannot produce complete evidence; RBS and DSL compose consistently.

Use Luna implementation and independent review, run core/RBS suites, signatures,
lint and packaging, then commit the feature branch without merging.
