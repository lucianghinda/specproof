# Delivery option requirements

These are the normative requirements for `DeliveryOptions#build`:

1. Speed is `:express` exactly when `expedited` is true; otherwise it is
   `:standard`.
2. The notification flag equals `notify`, independent of the speed selection.

Both inputs are booleans. Every combination is valid for this example. The
faulty and corrected implementations are judged against these rules, not used
to derive them.
