# String and method-object targets

The requirements in [requirements.md](requirements.md) define independent
input and behavior rules for an instance method, a class method, and a module
method. The two declarations below select those same methods in equivalent
ways and produce the same canonical target identities, contract digest, and
obligation IDs.

Run from the `gems/specproof` directory with the checkout's Ruby and bundle:

```sh
bundle exec ruby -Ilib exe/specproof plan examples/method_targets/specification_strings.rb --format json > tmp/method-targets-strings.json
bundle exec ruby -Ilib exe/specproof plan examples/method_targets/specification_objects.rb --format json > tmp/method-targets-objects.json
```

The first command uses strings and does not load or autoload the application
owners. The second loads the definitions so Ruby can provide one
`UnboundMethod` and two `Method` objects; SpecProof inspects those objects
without invoking the methods. Compare `contract_digest` and the typed
obligation `id`/`target` pairs in the reports. The target fields remain
canonical strings, such as `DeliveryOptions#build` and
`DeliveryDefaults.build`.

String declarations are a good fit for offline checking or planning when
application loading is unavailable or could trigger autoload. Method objects
are useful in runtime declarations after code has loaded. They must refer to
directly defined public methods on named classes/modules and remain current at
declaration time. Aliases, inherited singleton methods, anonymous owners, and
bound methods on arbitrary instances are unsupported. Editor navigation from
target names depends on language-server support.
