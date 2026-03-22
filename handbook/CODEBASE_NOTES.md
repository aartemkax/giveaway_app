# giveaway_app Codebase Notes

## Purpose

This document maps the current codebase without trying to refactor it.

It exists to answer a practical question:

- which files are active;
- which files look legacy;
- which files are duplicated or suspicious;
- which areas should not be touched casually without first deciding the intended direction.

This is an inventory document, not a rewrite plan.

## How To Read This File

Use these labels:

- `Active`: clearly used by the current app entrypoint or current runtime flow
- `Likely Active`: not proven by direct route import only, but clearly part of the current path
- `Legacy / Inactive`: present in repo but not part of the current main app flow
- `Suspicious Duplicate`: overlaps another file and can confuse ownership

## Canonical Entry Points

These files currently define the main runtime shape of the app.

### Active

- [lib/main.dart](/Users/starlord/giveaway_app/lib/main.dart)
  Main Flutter entrypoint. This is the canonical client bootstrap.

- [api/main.py](/Users/starlord/giveaway_app/api/main.py)
  Main Flask backend entrypoint. This is the canonical backend API.

- [api/tasks.py](/Users/starlord/giveaway_app/api/tasks.py)
  Main worker entry logic for async participant jobs.

- [api/account_affinity.py](/Users/starlord/giveaway_app/api/account_affinity.py)
  Current account/proxy state model for backend operations.

## Active Client Files

These are the files that currently look like the main supported app path.

### Active Screens

- [lib/screens/login/app_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/app_login_screen.dart)
  Current entry login selector. Imported in `main.dart`.

- [lib/screens/password_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/password_login_screen.dart)
  Current Instagram login/password path. Imported in `main.dart`.

- [lib/screens/login/fb_oauth_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/fb_oauth_screen.dart)
  Current Facebook OAuth webview path. Imported in `main.dart`.

- [lib/screens/fb_home_screen.dart](/Users/starlord/giveaway_app/lib/screens/fb_home_screen.dart)
  Current Facebook flow landing screen. Imported in `main.dart`.

- [lib/screens/ig_media_screen.dart](/Users/starlord/giveaway_app/lib/screens/ig_media_screen.dart)
  Current Graph media browser. Imported in `main.dart`.

- [lib/screens/ig_comments_screen.dart](/Users/starlord/giveaway_app/lib/screens/ig_comments_screen.dart)
  Current Graph comments/draw screen. Imported in `main.dart`.

- [lib/screens/login/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/participants_screen.dart)
  Current session-based participants/draw screen. Imported in `main.dart`.

- [lib/screens/debug_env_screen.dart](/Users/starlord/giveaway_app/lib/screens/debug_env_screen.dart)
  Current debug utility screen. Imported in `main.dart`.

### Active Or Likely Active Services

- [lib/services/api_client.dart](/Users/starlord/giveaway_app/lib/services/api_client.dart)
  Canonical HTTP client.

- [lib/services/graph_service.dart](/Users/starlord/giveaway_app/lib/services/graph_service.dart)
  Canonical Graph-related client service for the current screens.

- [lib/services/device_service.dart](/Users/starlord/giveaway_app/lib/services/device_service.dart)
  Canonical device fingerprint + backend emulation bridge.

- [lib/services/auth_service.dart](/Users/starlord/giveaway_app/lib/services/auth_service.dart)
  Still active through `main.dart` startup auth checks.

- [lib/services/appapi/app_auth_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_auth_service.dart)
  Also active in current password login and webview-based session flows.

- [lib/services/appapi/app_participants_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_participants_service.dart)
  Used by the current `lib/screens/login/participants_screen.dart`.

## Files That Look Legacy Or Inactive

These are not necessarily wrong, but they do not appear to be the current canonical path.

### Legacy / Inactive Screens

- [lib/screens/login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login_screen.dart)
  Old login flow based on Instagram webview. Not imported in `main.dart`.

- [lib/screens/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/participants_screen.dart)
  Older participants screen using older services. Not imported in `main.dart`.

- [lib/screens/home_screen.dart](/Users/starlord/giveaway_app/lib/screens/home_screen.dart)
  Standalone draw screen style, not imported in `main.dart`.

- [lib/screens/login/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/login/instagram_login_webview.dart)
  Disabled stub screen with text saying the scenario is disabled. Not part of the current route wiring.

### Legacy / Inactive Backend File

- [api/app.py](/Users/starlord/giveaway_app/api/app.py)
  Looks like an older minimal Flask app containing simplified versions of routes now present in `api/main.py`.
  This should be treated as legacy until proven otherwise.

### Likely Inactive Support Files

- [lib/services/fb/fb_auth_service.dart](/Users/starlord/giveaway_app/lib/services/fb/fb_auth_service.dart)
  Present, but the current screens use `GraphService` and direct `ApiClient` calls instead.

- [lib/services/fb/fb_participants_service.dart](/Users/starlord/giveaway_app/lib/services/fb/fb_participants_service.dart)
  Present, but not visibly wired into current screens.

- [lib/providers.dart](/Users/starlord/giveaway_app/lib/providers.dart)
  Defines Riverpod providers for `appapi` services, but is not visibly imported by current screen flow.

- [lib/models/profile_participant.dart](/Users/starlord/giveaway_app/lib/models/profile_participant.dart)
  Looks redundant with `Participant`, with no clear current usage.

## Suspicious Duplicates

These are the most important overlap points in the repository.

## 1. Auth Services

- [lib/services/auth_service.dart](/Users/starlord/giveaway_app/lib/services/auth_service.dart)
- [lib/services/appapi/app_auth_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_auth_service.dart)

Why this is suspicious:

- both expose `AuthService`;
- both talk to similar auth endpoints;
- both are currently used in different parts of the app;
- one is tied to startup/session checks, the other to newer app/admin flows.

Current practical interpretation:

- `auth_service.dart` is still part of the active startup/auth-state logic;
- `appapi/app_auth_service.dart` is the newer flow used by password login and sessionid/account flows.

Do not casually merge or delete one without first deciding:

- which auth model is canonical;
- whether startup state should also move to the `appapi` layer.

## 2. Participants Services

- [lib/services/participants_service.dart](/Users/starlord/giveaway_app/lib/services/participants_service.dart)
- [lib/services/appapi/app_participants_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_participants_service.dart)

Why this is suspicious:

- both expose `ParticipantsService`;
- both fetch participants asynchronously;
- one is older session-based logic;
- the `appapi` version understands `active_account_id` and admin account-scoped jobs.

Current practical interpretation:

- `appapi/app_participants_service.dart` is the current participants service for the active session-based participants screen;
- `participants_service.dart` is older but still present and easy to accidentally use.

Do not rename, delete, or refactor one without first choosing:

- whether account-aware fetch is now the only supported implementation;
- whether the older service should be formally deprecated.

## 3. Login And Participant Screens

- [lib/screens/login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login_screen.dart)
- [lib/screens/login/app_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/app_login_screen.dart)
- [lib/screens/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/participants_screen.dart)
- [lib/screens/login/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/participants_screen.dart)

Why this is suspicious:

- there are both old and new versions of login and participants screens;
- the active versions live under `lib/screens/login/` for some cases, while other active screens still live directly under `lib/screens/`;
- the directory naming no longer cleanly reflects feature ownership.

Current practical interpretation:

- `lib/screens/login/app_login_screen.dart` and `lib/screens/login/participants_screen.dart` are the active pair for the newer path;
- `lib/screens/login_screen.dart` and `lib/screens/participants_screen.dart` look legacy.

## 4. Instagram Webview Screens

- [lib/screens/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/instagram_login_webview.dart)
- [lib/screens/login/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/login/instagram_login_webview.dart)

Why this is suspicious:

- two files share almost the same conceptual name;
- one is actively imported by current flows;
- the other is a disabled stub.

Current practical interpretation:

- `lib/screens/instagram_login_webview.dart` is the active one;
- `lib/screens/login/instagram_login_webview.dart` is legacy or placeholder.

This is a high-confusion pair and should be handled carefully in future cleanup.

## 5. Localization Cleanup Note

Files:

- [lib/l10n/app_uk.arb](/Users/starlord/giveaway_app/lib/l10n/app_uk.arb)
- [lib/l10n/app_fr.arb](/Users/starlord/giveaway_app/lib/l10n/app_fr.arb)

Status:

- duplicate keys that previously existed in these files were cleaned up;
- they should now be treated as active and normalized, not as current cleanup targets.

## Active vs Legacy Summary

### Safe To Treat As Current Canonical Path

- [lib/main.dart](/Users/starlord/giveaway_app/lib/main.dart)
- [lib/screens/login/app_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/app_login_screen.dart)
- [lib/screens/password_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/password_login_screen.dart)
- [lib/screens/login/fb_oauth_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/fb_oauth_screen.dart)
- [lib/screens/fb_home_screen.dart](/Users/starlord/giveaway_app/lib/screens/fb_home_screen.dart)
- [lib/screens/ig_media_screen.dart](/Users/starlord/giveaway_app/lib/screens/ig_media_screen.dart)
- [lib/screens/ig_comments_screen.dart](/Users/starlord/giveaway_app/lib/screens/ig_comments_screen.dart)
- [lib/screens/login/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/participants_screen.dart)
- [lib/services/api_client.dart](/Users/starlord/giveaway_app/lib/services/api_client.dart)
- [lib/services/graph_service.dart](/Users/starlord/giveaway_app/lib/services/graph_service.dart)
- [api/main.py](/Users/starlord/giveaway_app/api/main.py)
- [api/tasks.py](/Users/starlord/giveaway_app/api/tasks.py)
- [api/account_affinity.py](/Users/starlord/giveaway_app/api/account_affinity.py)

### Safe To Treat As Legacy Until Proven Otherwise

- [lib/screens/login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login_screen.dart)
- [lib/screens/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/participants_screen.dart)
- [lib/screens/home_screen.dart](/Users/starlord/giveaway_app/lib/screens/home_screen.dart)
- [lib/screens/login/instagram_login_webview.dart](/Users/starlord/giveaway_app/lib/screens/login/instagram_login_webview.dart)
- [api/app.py](/Users/starlord/giveaway_app/api/app.py)

### Active But Needs Cleanup Attention

- [lib/services/auth_service.dart](/Users/starlord/giveaway_app/lib/services/auth_service.dart)
- [lib/services/appapi/app_auth_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_auth_service.dart)
- [lib/services/participants_service.dart](/Users/starlord/giveaway_app/lib/services/participants_service.dart)
- [lib/services/appapi/app_participants_service.dart](/Users/starlord/giveaway_app/lib/services/appapi/app_participants_service.dart)

## Do-Not-Touch-Casually List

These areas should not be “cleaned up quickly” without deciding the target architecture first:

- auth service duplication
- participants service duplication
- old vs new login/participants screens
- `api/app.py` removal

## Practical Next Cleanup Steps

This is the smallest sensible order for future cleanup.

1. Decide which auth service is canonical.
2. Decide which participants service is canonical.
3. Mark legacy screens clearly or remove them in a dedicated cleanup task.
4. Remove or archive `api/app.py` once confirmed unused.
5. Rename or regroup screens so directory structure matches actual ownership.

## Update Rule

Update this document when:

- a legacy file is reactivated;
- a duplicate file is removed;
- a canonical service changes;
- the app routing is simplified;
- screen ownership is reorganized.
