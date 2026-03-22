# giveaway_app Cleanup Plan

## Purpose

This document is the bridge between:

- inventorying the current codebase;
- and making actual cleanup changes later.

It does not perform refactoring.
It defines what should be cleaned up, in what order, with what risks, and with what checks before touching code.

Related documents:

- [handbook/CODEBASE_NOTES.md](/Users/starlord/giveaway_app/handbook/CODEBASE_NOTES.md)
- [handbook/ARCHITECTURE.md](/Users/starlord/giveaway_app/handbook/ARCHITECTURE.md)
- [docs/DEFINITION_OF_DONE.md](/Users/starlord/giveaway_app/docs/DEFINITION_OF_DONE.md)
- [docs/DEV_SETUP.md](/Users/starlord/giveaway_app/docs/DEV_SETUP.md)

## Cleanup Strategy

The cleanup strategy for this repository should be:

1. decide canonical paths first
2. document legacy status second
3. verify active flows third
4. remove or consolidate code only after that

This avoids the main failure mode:

- deleting a duplicate that is still silently used somewhere.

## Cleanup Scope

The current cleanup scope is limited to structural clarity.

It is not intended to:

- redesign product behavior;
- rewrite major architecture;
- replace both login systems;
- migrate the full app in one step.

The goal is smaller:

- reduce confusion;
- identify the canonical implementation for each area;
- isolate legacy files;
- make later cleanup safe and incremental.

## Priority Order

This is the recommended order of cleanup work.

### Priority 1. Clarify Canonical Auth Path

Files:

- [lib/services/auth_service.dart](/Users/starlord/giveaway_app/lib/services/auth_service.dart)
- [lib/services/appapi/app_auth_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_auth_service.dart)

Why first:

- auth touches startup, routing, session checks, and login entry;
- cleanup here affects the whole app.

Current status:

- both are active;
- current usage is split across startup logic and newer app flows.

Decision needed before code changes:

- which auth service becomes canonical for future work;
- whether startup auth state should keep using the older service or move to the `appapi` layer.

### Priority 2. Clarify Canonical Participants Path

Files:

- [lib/services/participants_service.dart](/Users/starlord/giveaway_app/lib/services/participants_service.dart)
- [lib/services/appapi/app_participants_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_participants_service.dart)

Why second:

- participant loading is one of the two core product flows;
- the newer implementation already understands account-aware jobs.

Current status:

- current screen flow appears to use the `appapi` service;
- the older service still exists and is easy to use by mistake.

Decision needed before code changes:

- whether account-aware fetching is now the standard behavior;
- whether the old service can be deprecated.

### Priority 3. Mark And Consolidate Legacy Screens

Files:

- [lib/screens/login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login_screen.dart)
- [lib/screens/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/participants_screen.dart)
- [lib/screens/home_screen.dart](/Users/starlord/giveaway_app/lib/screens/home_screen.dart)
- [lib/screens/login/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/login/instagram_login_webview.dart)
- [lib/screens/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/instagram_login_webview.dart)

Why third:

- screen duplication confuses onboarding and future edits;
- but deleting screens too early can remove fallback behavior or hidden references.

Decision needed before code changes:

- which screens are formally active;
- which screens should be labeled legacy;
- whether legacy screens should stay for reference or be removed.

### Priority 4. Remove Or Archive Unused Backend Entry Files

Files:

- [api/app.py](/Users/starlord/giveaway_app/api/app.py)

Why fourth:

- it appears legacy and duplicated;
- but backend entry files are operationally sensitive.

Decision needed before code changes:

- confirm it is not used by any deployment, local script, or external process;
- decide whether to delete it or move it into an archive/legacy location.

### Priority 5. Clean Localization Duplicates

Files:

- [lib/l10n/app_uk.arb](/Users/starlord/giveaway_app/lib/l10n/app_uk.arb)

Why fifth:

- this cleanup is lower risk than auth or backend entry cleanup;
- but localization output may still be fragile if not regenerated carefully.

Decision needed before code changes:

- confirm which duplicate values are intended final values;
- confirm localization generation remains valid after cleanup.

## Cleanup Items

Each cleanup item below describes:

- what to clean;
- why it matters;
- risk level;
- required checks before making code changes.

## Item 1. Auth Service Consolidation

### What To Clean

- duplicate auth service layer

### Why It Matters

- same conceptual responsibility exists in two places;
- both expose `AuthService`;
- future edits can easily go to the wrong file.

### Risk Level

- high

### Risks

- breaking startup auth restore
- breaking login/password flow
- breaking sessionid flow
- breaking logout/session cleanup

### Checks Required Before Changes

- list which screens import each auth service
- list which routes rely on each auth behavior
- verify current startup behavior from [lib/main.dart](/Users/starlord/giveaway_app/lib/main.dart)
- define which service is canonical

### Verification Required After Changes

- app startup reaches correct screen
- Instagram login/password still works
- sessionid fallback still works if touched
- logout still clears state correctly

## Item 2. Participants Service Consolidation

### What To Clean

- duplicate participants service layer

### Why It Matters

- two similarly named services fetch participants differently;
- one supports account-aware jobs and one does not.

### Risk Level

- high

### Risks

- breaking async job polling
- breaking account-aware participant fetch
- breaking error mapping in the participants screen
- breaking draw input data

### Checks Required Before Changes

- confirm which screen uses which participants service
- confirm whether `active_account_id` support is required in the canonical path
- confirm whether the old service is still referenced anywhere meaningful

### Verification Required After Changes

- session-based participant flow still loads participants
- job status/result still reaches terminal state
- participant list still renders
- draw still produces winners

## Item 3. Screen Consolidation

### What To Clean

- duplicate or legacy login and participant screens

### Why It Matters

- screen ownership is currently mixed between `lib/screens/` and `lib/screens/login/`;
- this creates false signals about which flow is current.

### Risk Level

- medium to high

### Risks

- deleting a screen that is still referenced
- losing a fallback screen unexpectedly
- breaking navigation routes

### Checks Required Before Changes

- confirm which screens are imported by `main.dart`
- confirm which screens are not imported anywhere
- verify whether any legacy screen still serves as a manual fallback

### Verification Required After Changes

- app startup route still works
- login entry still opens expected screens
- participants route still opens expected screen
- Facebook flow route still works

## Item 4. Legacy Backend Entry Cleanup

### What To Clean

- remove or archive [api/app.py](/Users/starlord/giveaway_app/api/app.py)

### Why It Matters

- it duplicates a subset of `api/main.py`;
- it increases uncertainty about the true backend entrypoint.

### Risk Level

- medium

### Risks

- hidden operational dependency
- local script or deployment still pointing at `api/app.py`

### Checks Required Before Changes

- search repo for references to `api/app.py`
- verify local startup docs point only to `api/main.py`
- verify deployment docs or configs do not depend on `api/app.py`

### Verification Required After Changes

- backend still starts normally
- health check works
- active API endpoints still respond

## Item 5. Localization Duplicate Cleanup

### What To Clean

- duplicate keys in [lib/l10n/app_uk.arb](/Users/starlord/giveaway_app/lib/l10n/app_uk.arb)

### Why It Matters

- duplicate keys hide intended source of truth;
- future localization edits become error-prone.

### Risk Level

- low to medium

### Risks

- keeping the wrong final text
- breaking localization generation if formatting is changed carelessly

### Checks Required Before Changes

- identify the intended final text for each duplicate key
- confirm there are no duplicate-key equivalents in other locale files

### Verification Required After Changes

- localization generation still works
- affected screens still render correct text

## Decision Table

This is the current recommended decision state before code cleanup.

| Area | Current Recommendation | Confidence |
| --- | --- | --- |
| Auth service | Keep both for now, decide canonical first | Medium |
| Participants service | Treat `appapi` version as likely canonical | Medium |
| Legacy screens | Keep, but mark as legacy in docs until dedicated cleanup | High |
| `api/app.py` | Treat as legacy candidate, do not use for new work | High |
| `app_uk.arb` duplicates | Clean in dedicated low-risk task | High |

## Current Cleanup Decisions

These are the current working decisions for future cleanup.

They are documentation decisions only.
They do not change runtime behavior by themselves.

## Decision 1. Canonical Auth Service

### Decision

For future work, treat:

- [lib/services/appapi/app_auth_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_auth_service.dart)

as the `canonical auth service`.

Treat:

- [lib/services/auth_service.dart](/Users/starlord/giveaway_app/lib/services/auth_service.dart)

as a `transitional runtime dependency`, not the long-term canonical layer.

### Why This Decision

Current evidence suggests:

- newer login flows already use `appapi/app_auth_service.dart`;
- `appapi` auth already includes account-aware behavior such as `createAccountFromSessionId`;
- this direction matches the newer participants flow and admin/account-affinity model.

At the same time:

- `lib/main.dart` still imports the older `auth_service.dart` for startup auth-state checks;
- removing or replacing it immediately would be risky without a focused auth cleanup task.

### Practical Rule

Until code cleanup happens:

- new auth-related work should prefer `appapi/app_auth_service.dart`;
- old `auth_service.dart` should only be touched when the task is specifically about startup/session migration or compatibility.

### Follow-Up Implication

Before deleting or merging the older auth service, a later cleanup task must:

- migrate startup auth checks in [lib/main.dart](/Users/starlord/giveaway_app/lib/main.dart);
- verify login/password flow;
- verify session restore behavior;
- verify logout behavior.

## Decision 2. Canonical Participants Service

### Decision

For future work, treat:

- [lib/services/appapi/app_participants_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_participants_service.dart)

as the `canonical participants service`.

Treat:

- [lib/services/participants_service.dart](/Users/starlord/giveaway_app/lib/services/participants_service.dart)

as a `legacy candidate`.

### Why This Decision

Current evidence suggests:

- the active participants screen uses the `appapi` implementation;
- the `appapi` service supports `active_account_id` and account-scoped backend jobs;
- this aligns better with the current account-affinity direction of the backend.

The older participants service still exists, but:

- it appears tied to the older screen flow;
- it is easier to misuse than to justify keeping as the default.

### Practical Rule

Until code cleanup happens:

- new participant-fetch work should use `appapi/app_participants_service.dart`;
- the older participants service should not be used for new screens or new flow logic.

### Follow-Up Implication

Before deleting or deprecating the older participants service, a later cleanup task must:

- confirm no active screen still relies on it;
- verify async job polling still works;
- verify participants render correctly;
- verify draw still works after fetch completion.

## Decision Confidence Notes

These decisions are intentionally pragmatic, not final architecture law.

Confidence is not absolute because:

- runtime still mixes old and newer service layers;
- startup logic has not yet been migrated;
- some legacy screens remain in the repository.

So the correct interpretation is:

- `canonical for future work`
- not yet `safe to delete the older version`

## Decision 3. Status Of `api/app.py`

### Decision

Treat:

- [api/app.py](/Users/starlord/giveaway_app/api/app.py)

as:

- `legacy`
- `not for new work`
- `archive later if no external dependency is found`

### Why This Decision

Current evidence suggests:

- [api/main.py](/Users/starlord/giveaway_app/api/main.py) is the real backend entrypoint;
- [api/app.py](/Users/starlord/giveaway_app/api/app.py) duplicates a small subset of backend behavior;
- current docs and current architecture already point to `api/main.py` as canonical.

At the same time:

- backend entry files are operationally sensitive;
- deleting it without checking deployment or external scripts would be careless.

### Practical Rule

Until a dedicated cleanup task happens:

- do not add new endpoints or new logic to `api/app.py`;
- treat `api/main.py` as the only backend entrypoint for active development;
- if any script or environment still references `api/app.py`, document that dependency before touching the file.

### Follow-Up Implication

Before archiving or deleting `api/app.py`, a later cleanup task must:

- search for references in repo and deployment configs;
- verify local startup path uses only `api/main.py`;
- verify health check and main API endpoints still work after cleanup.

## Decision 4. Status Of Legacy Screen Duplicates

### Decision

Treat the following files as:

- `legacy`
- `not for new work`
- `remove or archive only in a dedicated screen cleanup task`

Files:

- [lib/screens/login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login_screen.dart)
- [lib/screens/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/participants_screen.dart)
- [lib/screens/home_screen.dart](/Users/starlord/giveaway_app/lib/screens/home_screen.dart)
- [lib/screens/login/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/login/instagram_login_webview.dart)

### Why This Decision

Current evidence suggests:

- current runtime routes come from [lib/main.dart](/Users/starlord/giveaway_app/lib/main.dart);
- the active login and participants flow already uses newer screens;
- at least one duplicated webview screen is clearly just a disabled stub.

These files still stay in the repository for now because:

- removing screens is more dangerous than merely avoiding them;
- old screens may still contain behavior worth comparing during later cleanup.

### Practical Rule

Until a dedicated cleanup task happens:

- do not use these legacy screens for new features;
- do not wire new routes to them;
- do not treat them as the source of truth when reading the codebase.

For active work, prefer:

- [lib/screens/login/app_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/app_login_screen.dart)
- [lib/screens/password_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/password_login_screen.dart)
- [lib/screens/login/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/participants_screen.dart)
- [lib/screens/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/instagram_login_webview.dart)

### Follow-Up Implication

Before removing or archiving legacy screens, a later cleanup task must:

- confirm they are not imported by active routing;
- confirm no manual fallback still depends on them;
- verify startup navigation still works;
- verify login and participants routes still open the intended screens.

## Readiness Checklist Before Any Cleanup PR

Before making a cleanup change, confirm all of the following:

- the targeted file is classified in [handbook/CODEBASE_NOTES.md](/Users/starlord/giveaway_app/handbook/CODEBASE_NOTES.md)
- the intended canonical replacement is named explicitly
- the affected login or draw flow is known
- the verification method is chosen in advance
- the expected docs updates are identified

## Recommended Cleanup Sequence

When actual code cleanup starts, use this sequence:

1. auth decision
2. participants decision
3. screen cleanup
4. legacy backend file cleanup
5. localization cleanup

This order minimizes the chance of deleting something before its replacement is stable.

## What Not To Do

Do not:

- delete both versions of a duplicated service in one pass
- rename files before deciding the canonical path
- mix auth cleanup with participants cleanup in the same task
- remove `api/app.py` before confirming it is operationally unused
- combine localization cleanup with major flow refactors

## Suggested Future Tasks

These are the next sensible cleanup tasks, one per PR or one per focused session.

### Task A

- decide canonical auth service
- document decision
- update code references in a separate task later

### Task B

- decide canonical participants service
- document decision
- remove accidental imports later

### Task C

- label legacy screens clearly
- remove inactive screen duplicates in a dedicated pass

### Task D

- verify `api/app.py` unused
- archive or delete it

### Task E

- remove duplicate keys from `app_uk.arb`
- regenerate localization outputs if required

## Update Rule

Update this plan when:

- one cleanup decision becomes final
- a legacy file is removed
- a canonical path changes
- a cleanup task is completed
