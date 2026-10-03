# Independent requirements

Provenance: fictional task brief supplied for the SpecProof skill application exercise (not repository product requirements).

- `FileLabel#label(payload, file_id: nil)` returns `"automatic"` when `file_id` is `nil`.
- It returns `"1.pstore"` when `file_id` is integer `1`.
- It returns `"user_123.pstore"` when `file_id` is the string `"user_123"`.
- `payload` behavior is outside this label scenario; it is deliberately excluded from input analysis.

These three examples are the entire finite exercise contract. They do not establish behavior for all integers or all strings.
