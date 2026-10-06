# Agent Note: automatic merge, deploy and migrations for drive plans

Status: proposed

## Problem

The [plan-driven slice loop](../../implemented/process/2026-10-05-plan-driven-slice-loop.md)
leaves merge, deploy and the production check of every slice to the user. For
internal, non-customer-facing services in core_v2 (`admin_web`, `spider`,
`release_dashboard`), those steps were mechanical in the support and spider
work. The user merged within minutes of a merge-ready report, deployed, and
told the next agent it was deployed. "Merged means deployed" was wrong at least
once (`ce/2026-09-23T18-51-19` in that note's sources). The step that worries
the user is running database migrations unattended.

The release machinery in core_v2 already covers most of the safety:

- Spider and the release dashboard are CI-deployed on every master push
  (`release_dashboard/lib/release_dashboard/deployments/ci_deployed_services.ex`).
- Release targets such as `admin_web` deploy through a deploy request. The
  dashboard verifies the revision live and healthy in Argo, and runs a revert
  deploy on an explicit rollout failure.
- A Migration Run (`release_dashboard/CONTEXT.md`) runs staging first and moves
  to production only after every database verifies. It holds a migration lock,
  runs a read-only preflight, and requires the stored version to read back with
  `dirty = false`. Migrations never roll back automatically.

Two prerequisites live in other repositories:

- A db-schemas CI classifier labels each migration PR `migration:auto` or
  `migration:manual`.
- A local release CLI in core_v2 performs the dashboard's operations with the
  developer's own `aws`, `kubectl` and `git`, without calling the dashboard.

## Proposal

Add `autonomy: deploy` with a service list to a drive plan's `plan.md`. The
setting is the durable authorization; services outside the list fall back to
the user.

A migration counts as `auto` only when every one of these holds:

- every statement is additive: `CREATE TABLE`, an index on a table created in
  the same migration, a nullable or constant-default `ADD COLUMN`, or a foreign
  key from a new table;
- every object it touches is owned by the feature (a declared prefix such as
  `metadata.support_*`) or created in the same migration;
- there is no DML and no `-- migrator:allow` lint escape (an agent used one to
  get #719 through lint);
- `down` drops only what `up` created;
- the PR only adds new files and never edits an applied migration (the support
  migrations were squashed and changed during development, `0a85559` and
  `8ec344b`).

MySQL `core`, ClickHouse `events`, and anything touching shared tables are
always `manual`.

For a merge-ready slice whose services are all listed and whose migrations are
all `auto`, the driver works in this order:

1. Merge the db-schemas PR with `gh pr merge --match-head-commit`.
2. Run the staging → production Migration Run through the release CLI, and wait
   for a verified migration in both environments.
3. Merge the ce PR.
4. Deploy. For spider, CI deploys it. For release targets, the release CLI
   creates a deploy request and waits for a verified deploy.
5. Check production: error rates for N minutes, read-only production queries
   for the acceptance gate, and a browser check for UI slices.
6. Write the `deployed/NN` marker, or let `deploy_check` see the commit.

A deploy that is "successful but unverified" stops the loop, like a failure.
On failure the driver reverts the code through the CLI and stops. It never runs
a migration `down`: an additive migration left in place is harmless to the old
code.

These always go back to the user:

- a dirty database;
- an interrupted run;
- a `manual` migration;
- ClickHouse migrations;
- recovery runs.

New behavior ships switched off where possible, and the production check turns
it on.

Two more db-schemas CI jobs would strengthen the `auto` evidence:

- an up/down/up run on a fresh database;
- a rehearsal on a production-shaped dump with the migrator's lock timeout.

## Alternatives considered

- **Keep merge and deploy manual.** This is the current state. It is safe, but
  each slice waits on the user for steps that need no judgment for internal
  services.
- **Drive the release dashboard through its browser UI.** That is fragile, and
  it needs the user's session. The local CLI uses credentials every developer
  already has.
- **Automate all migrations, with rollback by `down`.** A failed or dirty
  migration needs manual cleanup and a `force` recovery. `down` can destroy
  data, so it stays with the user.

## Acceptance criteria

- A plan with `autonomy: deploy` merges, migrates, deploys and verifies at least
  three slices with `auto` migrations, with no user action between the slices.
- A slice with a `manual` migration or an unlisted service stops at merge-ready
  and notifies the user.
- An injected rollout failure produces a revert, and the loop stops.
- No migration `down` runs without the user.

## Risks

- **Autonomy creep.** Authority is per plan and per service, and limited to
  internal services.
- **Races with the dashboard.** The CLI bypasses the dashboard's in-process
  deploy lock, so it must honor an equivalent lock.
- **Classifier gaps.** A statement the parser misreads as additive could take
  locks on a shared table. Parse failures must classify as `manual`.

## Open questions

1. Which services may be listed under `autonomy: deploy`? The proposal covers
   internal ones only: `admin_web`, `spider`, `release_dashboard`.
2. Does the metadata Postgres have point-in-time recovery? That decides whether
   any `manual` class could later become automatic.
3. Is losing a feature's own tables acceptable if an `auto` migration later has
   to be dropped by hand?
4. What is the deploy check for ce release targets: the image tag in the
   k8s-config overlay contains the merge commit, or a status command in the
   release CLI?
