# Roadmap: 14 Days

## Purpose

This roadmap exists so the project can move in a controlled way instead of jumping between unrelated improvements.

The goal is not "perfect architecture in two weeks". The goal is:

- stable project context
- current documentation
- minimum quality gates
- predictable staging workflow
- a short list of next actions with visible status

Canonical context file:

- [`PROJECT_SUMMARY_FOR_CHAT.md`](C:/dev/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)

Documentation maintenance rules:

- [`docs/DOCS_POLICY.md`](C:/dev/giveaway_app/docs/DOCS_POLICY.md)

## Status Legend

- `Done`: finished and already present in the repository
- `In Progress`: started and useful, but still not complete enough to treat as settled
- `Not Started`: still missing
- `Blocked`: work exists, but a major blocker prevents completion

## Current Snapshot

Overall state:

- documentation foundation: mostly done
- staging and account-affinity foundation: done
- minimum API smoke tests: done
- end-to-end Instagram server-side fetch: blocked by challenge behavior
- process/quality discipline: mostly done

## Week 1: Stabilize The Base

### Day 1. Freeze the current project state

Status:

- [`PROJECT_SUMMARY_FOR_CHAT.md`](C:/dev/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md): `Done`
- [`README.md`](C:/dev/giveaway_app/README.md): `Done`

Definition:

- summary reflects actual repo and staging reality
- README explains:
  - what the product does
  - the two main flows
  - how to run Flutter
  - how to run API
  - required env vars
  - where tests live

### Day 2. Describe the architecture

Status:

- [`docs/ARCHITECTURE.md`](C:/dev/giveaway_app/docs/ARCHITECTURE.md): `Done`

Definition:

- describe:
  - Flutter layer
  - Flask API
  - Redis/RQ
  - Graph API flow
  - instagrapi flow
  - account-affinity flow
  - duplicates and technical debt

### Day 3. Describe dev setup

Status:

- [`docs/DEV_SETUP.md`](C:/dev/giveaway_app/docs/DEV_SETUP.md): `Done`

### Day 4. Define minimum Definition of Done

Status:

- [`docs/DEFINITION_OF_DONE.md`](C:/dev/giveaway_app/docs/DEFINITION_OF_DONE.md): `Done`

### Day 5. Record codebase structure and duplication

Status:

- [`docs/CODEBASE_NOTES.md`](C:/dev/giveaway_app/docs/CODEBASE_NOTES.md): `Done`

Definition:

- list:
  - active files
  - legacy files
  - suspicious duplication

Known items to capture:

- `lib/services/auth_service.dart` vs `lib/services/appapi/app_auth_service.dart`
- `lib/services/participants_service.dart` vs `lib/services/appapi/app_participants_service.dart`
- `api/app.py`
- duplicates in `lib/l10n/app_uk.arb`

### Days 6-7. Close the highest-value small debt

Status:

- `In Progress`

Done already:

- docs baseline is much better than before
- staging setup exists
- account-affinity job path exists

Remaining candidates:

- remove or document dead code in [`api/tasks.py`](C:/dev/giveaway_app/api/tasks.py)
- explicitly document the real Docker/Railway deploy path

## Week 2: Quality Gates And AI Routines

### Day 8. Define testing strategy

Status:

- [`docs/TESTING.md`](C:/dev/giveaway_app/docs/TESTING.md): `Done`

### Day 9. Add minimum checks

Status:

- `In Progress`

Done already:

- Playwright smoke tests exist in [`tests/playwright/admin-api.spec.ts`](C:/dev/giveaway_app/tests/playwright/admin-api.spec.ts)

Remaining work:

- add 1-2 more checks for the riskiest flow
- run and document `flutter analyze`
- add at least one focused unit or widget test if practical

Progress since the initial plan:

- focused widget tests now cover blocked account-state UX on the participants screen
- the new tests verify both disabled draw action and banner-driven navigation back to login

### Day 10. Add release checklist

Status:

- [`docs/RELEASE_CHECKLIST.md`](C:/dev/giveaway_app/docs/RELEASE_CHECKLIST.md): `Done`

### Day 11. First useful skill

Status:

- `Not Started`

Target:

- `project-summary-maintainer`

Definition:

- reads git diff
- reviews key files
- updates [`PROJECT_SUMMARY_FOR_CHAT.md`](C:/dev/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)
- avoids unnecessary structural changes

### Day 12. Second useful skill

Status:

- `Not Started`

Target:

- `feature-checklist`

Definition:

- before work starts, prepares:
  - what changes
  - affected files
  - risk
  - tests
  - required docs updates

### Day 13. Keep MCP limited

Status:

- `In Progress`

Current direction:

- keep MCP usage minimal and practical
- prefer Git/GitHub and browser/docs style workflows when needed
- do not expand into unrelated MCP surfaces without a concrete problem

### Day 14. Retrospective

Status:

- [`docs/PROCESS_RETRO.md`](C:/dev/giveaway_app/docs/PROCESS_RETRO.md): `Done`

## Main Blocker Right Now

The main blocker is not documentation or queue wiring anymore.

Current blocker:

- server-side Instagram media/comment fetch still hits challenge/checkpoint behavior during worker execution

This affects:

- choosing a post
- fetching participants reliably
- completing the account-based giveaway flow end to end

So the current roadmap should not drift into new big features until this is handled clearly through the chosen network path:

- keep product/API challenge handling honest
- and now actively invest in sticky proxy/account-bound network strategy

## Recommended Execution Order From Here

1. Roll out the first sticky proxy slice for account onboarding and verification.
2. Re-test staging `sessionid -> verify -> participants` with a bound proxy.
3. Only after that, build the first skill.

Follow-up execution plan:

- once the UX and focused tests are in place, use [`docs/DELIVERY_PLAN_FINISH_FLOW.md`](C:/dev/giveaway_app/docs/DELIVERY_PLAN_FINISH_FLOW.md) as the concrete plan for finishing the account-based giveaway flow
- that plan replaces vague next steps with a narrower finish target centered on account verification, challenge handling, and the final decision on server-side Instagram fetch viability

Progress before the proxy slice:

- participants screen now shows backend-driven account-state banners for `challenge`, `cooldown`, and `unverified`
- retry/draw action is blocked in the UI when the active account is already in a blocked state
- onboarding now performs an explicit account verification step after `from_sessionid`
- the banner recovery action can now trigger a fresh account verification attempt
- the staging diagnosis path is now documented in [`docs/ACCOUNT_RECOVERY_RUNBOOK.md`](C:/dev/giveaway_app/docs/ACCOUNT_RECOVERY_RUNBOOK.md)
- next related step is to validate whether sticky account-bound proxy assignment changes the repeated `verify_session_challenge` behavior on staging

## Definition Of Success For This Roadmap

This roadmap is considered complete when:

- README is trustworthy
- architecture and codebase notes exist
- testing and release docs stay current
- account-affinity flow is documented and understandable
- challenge failures are surfaced explicitly instead of looking like generic server errors
- a new chat can understand the repo from docs without rebuilding context from memory
