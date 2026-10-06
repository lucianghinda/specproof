# Independent requirements

These rules define the example's expected behavior independently of its Ruby
implementation:

- An instance delivery build accepts quantities from `0` through `100`; a
  zero quantity selects the `:empty` package and every positive quantity
  selects `:parcel` in its result.
- The class-level delivery builder supports `:scheduled` and `:immediate`;
  scheduling at checkout is enabled only for `:scheduled`.
- The module-level default builder supports `:local` and `:remote`; local
  delivery selects the `:nearby` carrier and remote delivery selects
  `:national`.

The two specification files encode the same input domains and canonical target
names. `specification_strings.rb` can be planned without loading these methods.
`specification_objects.rb` loads the file and demonstrates equivalent
`UnboundMethod`/`Method` selections. The runtime methods exist to make those
objects available; the requirements above remain the source of expected
behavior.
