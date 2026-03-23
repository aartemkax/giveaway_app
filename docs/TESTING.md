# giveaway_app Testing Strategy

## Purpose

This document defines the current testing strategy for `giveaway_app`.

It is not an aspirational “perfect test pyramid”.
It is a practical strategy based on the codebase as it exists today.

The goals are:

- be honest about current coverage;
- define what should be tested first;
- protect the two main product flows;
- give a stable baseline before cleanup or refactoring.

## Current Reality

The project currently has:

- one real Flutter widget smoke test for startup/loading state;
- one Playwright API smoke suite focused on staging admin/account-affinity endpoints.

In practice this means:

- backend admin API has some smoke coverage;
- app startup has minimal automated sanity coverage;
- the main Flutter user flows are still largely not protected by tests yet;
- the main login and draw product flows still rely heavily on manual verification.

## Testing Priorities

The test strategy should protect the system in this order:

1. core runtime health
2. main login flows
3. main draw flows
4. cleanup-sensitive duplication areas
5. lower-risk UI details

## Main Flows That Must Be Protected

### 1. Facebook / Graph API Flow

Critical path:

- Facebook login starts correctly
- IG accounts can be loaded
- media list loads
- comments load
- draw returns winners

Primary risk:

- Graph API or routing changes silently break the official flow.

### 2. Instagram Session / instagrapi Flow

Critical path:

- device fingerprint path works
- login/password reaches backend
- backend session is stored
- async participant fetch job is created
- job reaches terminal state
- participant screen can choose winners

Primary risk:

- session handling, Redis, or worker changes silently break the less official flow.

## Test Layers

The project should use three practical layers.

## Layer 1. Smoke Tests

Purpose:

- verify that critical services and endpoints still respond;
- catch major regressions quickly.

Best current fit:

- Playwright API smoke tests
- basic Flutter app-boot smoke test
- manual app boot check

Current repo status:

- [tests/playwright/admin-api.spec.ts](/Users/starlord/giveaway_app/tests/playwright/admin-api.spec.ts) exists and is useful
- it currently focuses mostly on admin/account-affinity endpoints
- [test/widget_test.dart](/Users/starlord/giveaway_app/test/widget_test.dart) provides a minimal app-startup smoke check

Current recommended smoke coverage:

- `/api/runtime_info`
- `/api/admin/accounts`
- `/api/admin/proxies`
- `/api/admin/accounts/<id>/fetch_participants_async`
- `/api/job_status/<job_id>`
- `/api/job_result/<job_id>`
- app boots to login screen

Run with:

```bash
cd /Users/starlord/giveaway_app
npm run test:api
```

## Layer 2. Integration Tests

Purpose:

- verify that multi-step flows still work together.

This is the most important missing layer right now.

Highest-value integration scenarios for this project:

- Instagram login/password -> backend session -> participants flow
- account-scoped participant fetch -> job status -> job result
- Facebook login -> IG account list -> media/comments retrieval
- draw request -> winners returned

Current repo status:

- partial backend integration exists through Playwright API smoke
- there is no strong automated integration coverage for the main client flows yet

Recommendation:

- add integration coverage incrementally around the two core flows before large cleanup work

## Layer 3. UI Sanity Checks

Purpose:

- verify that main screens still open and render correctly enough for basic use.

These do not need full visual regression at this stage.
They should mainly answer:

- does the screen open?
- is the main CTA present?
- does the screen fail immediately?

Priority UI sanity targets:

- app startup/login entry
- password login screen
- participants screen
- FB home screen
- IG media screen
- IG comments screen

Current repo status:

- current Flutter widget test protects startup/loading-shell behavior only

File:

- [test/widget_test.dart](/Users/starlord/giveaway_app/test/widget_test.dart)

Important note:

- this is no longer the default counter scaffold;
- it should be treated as minimal startup sanity coverage, not as broad UI protection.

## What Counts As “Good Enough” Right Now

Before any cleanup or non-trivial feature work, the minimum acceptable verification should be:

### For backend-facing change

- `npm run test:api`
- plus one targeted manual check if login or draw is affected

### For Flutter UI change

- `flutter analyze`
- plus one manual screen sanity check

### For auth/session change

- at least one login path checked manually
- plus one backend or smoke verification

### For participant/draw change

- at least one draw path checked manually
- plus one backend or smoke verification

## Recommended Test Matrix

Use this as the project-level checklist.

| Area | Minimum Test Type | Current State |
| --- | --- | --- |
| App boot | Flutter widget smoke + manual sanity | Partial |
| Facebook login start | Manual sanity | Needed |
| Instagram login/password | Manual sanity | Needed |
| Session-based async fetch | API smoke + manual | Partial |
| Account-affinity backend | Playwright smoke | Present |
| Draw via Graph API | Manual sanity | Needed |
| Localization rendering | Manual sanity | Needed |
| Widget-level UI behavior | Flutter widget tests | Minimal |

## Existing Test Assets

### Flutter

- [test/widget_test.dart](/Users/starlord/giveaway_app/test/widget_test.dart)

Current assessment:

- useful as a startup smoke test;
- currently verifies app boot, loading shell, and env badge rendering;
- still too narrow to count as full UI coverage.

### Playwright

- [tests/playwright/admin-api.spec.ts](/Users/starlord/giveaway_app/tests/playwright/admin-api.spec.ts)
- [playwright.config.ts](/Users/starlord/giveaway_app/playwright.config.ts)
- [tests/playwright/README.md](/Users/starlord/giveaway_app/tests/playwright/README.md)

Current assessment:

- useful and real;
- strongest current automated coverage in the repo;
- still narrower than the actual product surface.

## Default Commands

### Flutter Analysis

```bash
cd /Users/starlord/giveaway_app
flutter analyze
```

### Flutter Tests

```bash
cd /Users/starlord/giveaway_app
flutter test
```

### Playwright Smoke

```bash
cd /Users/starlord/giveaway_app
npm run test:api
```

## Manual Test Checklist

Use this before and after risky cleanup work.

### Login Sanity

- app starts
- login entry screen renders
- password login screen opens
- Facebook login screen opens

### Session Flow Sanity

- backend is reachable
- Redis is running
- worker is running
- async participant job can start
- job reaches terminal state

### Draw Sanity

- participants can be loaded for at least one known scenario
- winners can be selected
- Graph draw endpoint returns winners when used

## Cleanup Protection Rules

Before any cleanup in these areas, test coverage must be chosen explicitly:

- auth service cleanup
- participants service cleanup
- screen cleanup
- `api/app.py` cleanup
- localization cleanup

Minimum rule:

- no cleanup PR without naming the verification path in advance

## Recommended Next Test Improvements

These are ordered by value, not by difficulty.

### 1. Expand the current Flutter startup smoke test

Target:

- app boot plus login entry sanity

Why:

- startup coverage exists now, but it is still too narrow for the main auth flow

### 2. Add one real auth sanity test path

Target:

- login screen renders and primary CTA exists

Why:

- auth is currently the highest-risk shared dependency

### 3. Expand Playwright smoke around job-based participant flow

Target:

- validate end-to-end job lifecycle more explicitly

Why:

- async participant loading is a core product behavior

### 4. Add one Graph flow sanity test

Target:

- at least a lightweight check around Graph-backed endpoint behavior

Why:

- official flow is a core product mode and currently underprotected

## Definition Of Done Link

This testing strategy works together with:

- [docs/DEFINITION_OF_DONE.md](/Users/starlord/giveaway_app/docs/DEFINITION_OF_DONE.md)

Simple rule:

- if a task changes login, draw, env, sessions, Redis, or routing, testing must be part of completion.
