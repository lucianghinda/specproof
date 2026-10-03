# Boolean batch requirements

`SuggestedBooleanBatch#build` returns the supplied three boolean values in
`[first, second, third]` order. Every triple is permitted. `context` is an
application value outside this finite pairwise scenario; callers must supply a
value appropriate for their application. The pairwise suggestions specify
neither that value nor an expected return value.
