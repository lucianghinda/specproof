# Constrained delivery requirement

For this separate target, expedited delivery requires notification. Therefore
the full tuple `expedited: true, notify: false` is invalid. The other three
boolean tuples are allowed. This requirement justifies the explicit forbidden
assignment in `constrained_specification.rb`.
