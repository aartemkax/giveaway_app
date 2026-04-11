# giveaway_app Definition Of Done

## Purpose

This document defines the minimum bar for considering a task finished in `giveaway_app`.

It is intentionally practical.

The goal is not perfect process.
The goal is to stop shipping undocumented, unverified, fragile changes.

If a task does not meet this checklist, it is not done yet.

## Core Rule

A task is done only when:

- the code change is complete;
- the affected flow still works;
- the change is documented if behavior changed;
- at least one verification step was performed;
- any env impact is written down.

## Minimum Definition Of Done

For any task, all of the following must be true.

### 1. Documentation Is Updated If The Flow Changed

If the task changes behavior, routing, setup, env requirements, user flow, or architecture assumptions, the related docs must be updated in the same task.

Typical files to update:

- [README.md](/Users/starlord/giveaway_app/README.md)
- [PROJECT_SUMMARY_FOR_CHAT.md](/Users/starlord/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)
- [docs/ARCHITECTURE.md](/Users/starlord/giveaway_app/docs/ARCHITECTURE.md)
- [docs/CODEBASE_NOTES.md](/Users/starlord/giveaway_app/docs/CODEBASE_NOTES.md)
- [docs/DEV_SETUP.md](/Users/starlord/giveaway_app/docs/DEV_SETUP.md)

Simple rule:

- behavior changed -> docs changed

### 2. At Least One Verification Was Run

Every task must include at least one real verification step.

Examples:

- `flutter analyze`
- `flutter test`
- `npm run test:api`
- manual verification of one affected screen
- manual verification of one affected API endpoint

Simple rule:

- no verification -> not done

### 3. Env Changes Are Recorded

If the task introduces, removes, or changes environment variables, that impact must be captured immediately.

What must be updated when env changes:

- [.env.example](/Users/starlord/giveaway_app/.env.example) if Flutter env changed
- [api/.env.example](/Users/starlord/giveaway_app/api/.env.example) if backend env changed
- [README.md](/Users/starlord/giveaway_app/README.md) if setup changed
- [docs/DEV_SETUP.md](/Users/starlord/giveaway_app/docs/DEV_SETUP.md) if startup instructions changed

Simple rule:

- env changed -> example file and setup docs changed

### 4. The Main Login Flow Is Not Broken

At least one relevant login scenario must still be confirmed after changes that may affect auth, sessions, navigation, backend config, cookies, or API routing.

Main login scenarios in this project:

- Facebook / Graph API login path
- Instagram login/password path
- Instagram `sessionid` fallback path when relevant

Minimum expectation:

- if auth-related code changed, verify the affected login path;
- if shared infra changed, verify at least one main login path still works.

### 5. The Main Draw Flow Is Not Broken

At least one winner-selection flow must still be confirmed after changes that may affect comments, participants, jobs, filtering, or draw logic.

Main draw scenarios in this project:

- session-based participants flow via `/api/fetch_participants_async`
- Graph API draw flow via `/api/ig/comments`, `/api/ig/run_draw`

Minimum expectation:

- if participant fetching or draw logic changed, verify the affected flow;
- if shared infra changed, verify at least one main draw path still works.

## Task Categories

Different tasks need different depth, but they all must satisfy the minimum bar.

### A. Small UI Or Copy Change

Examples:

- label text
- spacing or layout change
- non-critical visual adjustment

Done means:

- changed screen reviewed manually;
- docs updated only if user-facing flow or setup changed;
- at least one verification performed.

### B. Feature Change

Examples:

- new screen behavior
- changed login step
- changed draw/filter logic
- changed API request/response shape

Done means:

- affected docs updated;
- at least one verification run;
- impacted login or draw flow checked;
- env updates recorded if needed.

### C. Infrastructure Or Config Change

Examples:

- Redis setup
- session handling
- Procfile / deployment assumptions
- `.env` changes

Done means:

- setup docs updated;
- env examples updated;
- at least one runtime verification done;
- login and draw sanity checked if the change could affect them.

## Required Verification Matrix

Use this table as the minimum expected check.

| Change Type | Minimum Verification |
| --- | --- |
| Flutter UI only | Manual screen check or `flutter analyze` |
| Flutter navigation/auth | Manual login path check |
| Backend endpoint change | Endpoint smoke test or manual API check |
| Async job change | Worker path check or Playwright/API verification |
| Draw logic change | Verify one draw scenario end-to-end |
| Env/config change | Startup check + affected flow sanity check |

## Required Sanity Checks

Before calling a task done, ask these questions:

1. Did I change user behavior or setup?
   If yes, update docs.

2. Did I run at least one real verification?
   If no, task is not done.

3. Did I touch env, routing, auth, sessions, Redis, jobs, or API shape?
   If yes, update env/setup docs and verify flow impact.

4. Could this break login?
   If yes, check login.

5. Could this break draw or participant loading?
   If yes, check draw.

## Preferred Verification Commands

These are the default checks to reach for first.

### Flutter

```bash
cd /Users/starlord/giveaway_app
flutter analyze
flutter test
```

### Backend / API Smoke

```bash
cd /Users/starlord/giveaway_app
npm run test:api
```

### Manual Runtime Checks

Examples:

- app boots and reaches login screen
- Facebook flow opens correctly
- Instagram login leads to participants screen
- participant fetch job reaches terminal state
- Graph API media/comments screen loads
- draw returns winners

## Done Statement Template

When finishing a task, the result should be expressible in this form:

```text
Done when:
- code change is in place
- related docs are updated
- verification was run
- env changes were recorded if any
- affected login flow still works
- affected draw flow still works
```

## Explicit Exceptions

There are only a few valid exceptions.

### Exception 1. Pure Internal Refactor

If behavior truly did not change:

- docs may not need updates;
- but at least one verification is still required.

### Exception 2. Documentation-Only Task

If the task changes only docs:

- runtime verification is optional;
- but the document itself must clearly improve accuracy.

### Exception 3. Blocked Verification

If a verification cannot be run:

- state explicitly what was not verified;
- state why;
- do not claim the task is fully done without noting the gap.

## Non-Negotiable Rules

- No hidden env changes.
- No behavior changes without docs.
- No auth-impacting change without login sanity.
- No draw-impacting change without draw sanity.
- No “done” without at least one verification.

## Short Version

Use this as the compact checklist:

- docs updated if flow changed
- at least one verification run
- env changes recorded
- login still works
- draw still works
