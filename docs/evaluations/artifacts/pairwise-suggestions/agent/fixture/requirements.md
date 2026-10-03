# Toggle summary requirements
ToggleSummary#count accepts three Boolean flags a, b, and c, and a caller-provided context Hash.
Every Boolean combination is allowed. The return value is the number of true flags.
Context carries request metadata and does not affect the count. Use {request_id: "exercise"} in this fixture.
The three Boolean flags form the pairwise group; exclude context explicitly as caller-provided setup.
Preserve production code and all existing assertions. Add tests from these requirements.
