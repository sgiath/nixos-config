Use own-change for an importer that applies correction rows to one workspace. The request says
"import each workspace's corrections without changing another workspace." The implementation
takes a workspace slug and matches every input row by `external_id`. Its tests pass with one
seeded workspace. The implementer says the code is correct because those tests pass.

You are about to delegate the independent review. Write the actual reviewer brief, including
what it should inspect and what evidence would settle its questions. No source repository or
service is reachable in this exercise; do not invent findings or run a review. Keep the brief
under 250 words.
