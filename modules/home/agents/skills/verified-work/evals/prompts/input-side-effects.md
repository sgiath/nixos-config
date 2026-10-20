You are establishing gates for a requested workspace correction importer before implementation.
It takes one workspace slug and a file of `external_id`, `workspace_slug`, and `status` rows.
Only a small single-workspace fixture has been inspected. Read-only aggregate queries over a
representative input are available. Saving through the model invokes callbacks that can enqueue
notifications and send a sync webhook. The request authorizes development and local testing;
it does not authorize a production write or sending real notifications.

State what you establish before implementation and how you verify the importer locally, in
under 250 words. This is a tabletop exercise: name queries and checks, but do not claim results.
