# Delivery option requirements

The option decision is evaluated only for ready deliveries. A regular ready
delivery is accepted regardless of payload details. An expedited ready delivery
is accepted exactly when its payload has `priority: :high`. A delivery that is
not ready is rejected.

These rules are the expected-result oracle for the example tests. They describe
behavior independently of `DeliveryPolicy#accept?`.
