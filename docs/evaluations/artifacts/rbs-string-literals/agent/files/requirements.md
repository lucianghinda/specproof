# Delivery options requirement

For the supported country values `"ro"` and `"de"`,
`DeliveryOptions#build(country:, expedited:)` preserves the supplied country
string in its result. It selects `"express"` when `expedited` is true and
`"standard"` when it is false. The country and expedited choice are independent
options, so every combination is allowed.

This requirement is the expected-result source for the example's assertions.
The RBS signature describes accepted input values only; its return type is not
used as a behavior oracle.
