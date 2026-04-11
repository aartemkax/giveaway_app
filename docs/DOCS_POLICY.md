# Documentation Policy

## Canonical Handoff Document

The canonical project handoff and context document is:

- [PROJECT_SUMMARY_FOR_CHAT.md](C:/dev/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)

Rule:

- `PROJECT_SUMMARY_FOR_CHAT.md` is the single source of truth for compact project state and handoff context.
- `project_init/` is only a lightweight entrypoint and navigation layer.
- `README.md` is not the authoritative handoff document.

## Update Rule

`PROJECT_SUMMARY_FOR_CHAT.md` must be reviewed after every meaningful engineering change.

If the summary is no longer accurate, it must be updated in the same work cycle as the code change.

If nothing material changed, no summary edit is required.

## What Counts As A Meaningful Change

Update the summary when changes affect any of the following:

- application architecture
- authentication or session flow
- account-affinity behavior
- worker or queue behavior
- API contract or important endpoints
- deploy/runtime behavior
- staging/production operating model
- key risks, caveats, or known blockers
- the list of key files a new engineer should read first

## What Usually Does Not Require A Summary Update

A summary update is usually not needed for:

- formatting-only changes
- cosmetic UI adjustments
- local refactors that do not change behavior
- renames that do not affect system understanding
- small test-only changes that do not change current conclusions

## Required Check After Important Work

After important changes, check:

1. Did current project behavior change?
2. Did an important flow change?
3. Did deploy/runtime assumptions change?
4. Did a key risk appear or disappear?
5. Did any statement in `PROJECT_SUMMARY_FOR_CHAT.md` become false?

If any answer is yes, update the summary.

## Documentation Layers

Use the documentation layers like this:

- `PROJECT_SUMMARY_FOR_CHAT.md`
  - compact current-state handoff
  - should stay current
- `README.md`
  - broad onboarding and project introduction
  - can remain higher level
- `docs/*.md`
  - focused policies, procedures, or subsystem notes

## Maintenance Principle

Documentation maintenance is part of finishing meaningful work, not a separate optional follow-up.
