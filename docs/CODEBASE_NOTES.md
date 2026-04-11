# Codebase Notes

## Purpose

This file records practical notes about active files, legacy files, and suspicious duplication.

It is not a cleanup plan by itself.
It is a map of what currently looks authoritative versus transitional.

## Active Backend Files

- [`api/main.py`](../api/main.py)
  - canonical Flask backend entrypoint
- [`api/tasks.py`](../api/tasks.py)
  - active worker logic
- [`api/account_affinity.py`](../api/account_affinity.py)
  - active Redis-backed account/proxy storage
- [`api/fb_graph.py`](../api/fb_graph.py)
  - Graph API helper logic
- [`api/device_emulator.py`](../api/device_emulator.py)
  - device emulation helper used by backend flows

## Legacy Or Transitional Backend Files

- [`api/app.py`](../api/app.py)
  - clearly marked as legacy stub
  - should not be used for new work
- [`api/generate_session.py`](../api/generate_session.py)
  - auxiliary script, not part of main runtime path
- [`api/save_session.py`](../api/save_session.py)
  - auxiliary script, not part of main runtime path

## Active Frontend Files

- [`lib/main.dart`](../lib/main.dart)
  - app bootstrap and auth routing
- [`lib/screens/login/app_login_screen.dart`](../lib/screens/login/app_login_screen.dart)
  - active entry screen
- [`lib/screens/password_login_screen.dart`](../lib/screens/password_login_screen.dart)
  - active username/password flow
- [`lib/screens/instagram_login_webview.dart`](../lib/screens/instagram_login_webview.dart)
  - active session capture WebView
- [`lib/screens/login/participants_screen.dart`](../lib/screens/login/participants_screen.dart)
  - active session/account-based participants screen
- [`lib/screens/fb_home_screen.dart`](../lib/screens/fb_home_screen.dart)
  - active Graph flow screen
- [`lib/screens/ig_media_screen.dart`](../lib/screens/ig_media_screen.dart)
  - active Graph flow media picker
- [`lib/screens/ig_comments_screen.dart`](../lib/screens/ig_comments_screen.dart)
  - active Graph flow comments/draw
- [`lib/services/appapi/app_auth_service.dart`](../lib/services/appapi/app_auth_service.dart)
  - current backend-facing auth helper for account onboarding
- [`lib/services/appapi/app_participants_service.dart`](../lib/services/appapi/app_participants_service.dart)
  - current backend-facing participant fetch helper

## Legacy Or Transitional Frontend Files

- [`lib/screens/login/instagram_login_webview.dart`](../lib/screens/login/instagram_login_webview.dart)
  - explicit legacy stub
- [`lib/screens/participants_screen.dart`](../lib/screens/participants_screen.dart)
  - older participant flow kept during transition
- [`lib/screens/home_screen.dart`](../lib/screens/home_screen.dart)
  - older standalone draw flow
- [`lib/screens/login_screen.dart`](../lib/screens/login_screen.dart)
  - older login screen path

## Duplicate Or Overlapping Service Areas

### Auth services

- [`lib/services/auth_service.dart`](../lib/services/auth_service.dart)
- [`lib/services/appapi/app_auth_service.dart`](../lib/services/appapi/app_auth_service.dart)

Observed overlap:

- both expose login helpers
- both still know about `/api/login`
- both still know about `login_by_sessionid`
- only `appapi/app_auth_service.dart` contains the newer `createAccountFromSessionId()` path

Current recommendation:

- treat `appapi/app_auth_service.dart` as the direction of travel
- keep `auth_service.dart` until route cleanup is explicit

### Participant services

- [`lib/services/participants_service.dart`](../lib/services/participants_service.dart)
- [`lib/services/appapi/app_participants_service.dart`](../lib/services/appapi/app_participants_service.dart)

Observed overlap:

- both fetch participants asynchronously
- both poll `job_status` and `job_result`
- old service contains stricter URL normalization and richer error mapping
- new service contains account-affinity-aware routing through `active_account_id`

Current recommendation:

- treat `appapi/app_participants_service.dart` as the migration target
- preserve older service behavior notes before cleanup because it currently has some better defensive handling

## Screen Duplication Notes

### Instagram WebView

- active: [`lib/screens/instagram_login_webview.dart`](../lib/screens/instagram_login_webview.dart)
- legacy: [`lib/screens/login/instagram_login_webview.dart`](../lib/screens/login/instagram_login_webview.dart)

Observation:

- the legacy file is a disabled placeholder screen
- the active file contains the real WebView/sessionid capture logic

### Participants Screens

- active: [`lib/screens/login/participants_screen.dart`](../lib/screens/login/participants_screen.dart)
- legacy: [`lib/screens/participants_screen.dart`](../lib/screens/participants_screen.dart)

Observation:

- both represent giveaway participant selection logic
- the active file is wired to the newer service path
- the legacy file still contains older session/logout behavior

### Login / Home Screens

- legacy login-like screen: [`lib/screens/login_screen.dart`](../lib/screens/login_screen.dart)
- legacy draw-like screen: [`lib/screens/home_screen.dart`](../lib/screens/home_screen.dart)

Observation:

- both are marked in-file as legacy/transitional
- they should remain documented until routing cleanup removes the need for them

## Localization Notes

Primary Ukrainian localization file:

- [`lib/l10n/app_uk.arb`](../lib/l10n/app_uk.arb)

Observed issue:

- the file contains visible encoding corruption in existing content
- localization cleanup should be treated carefully because automated regeneration or bulk editing can make things worse

Current recommendation:

- do not perform broad localization cleanup casually
- isolate any ARB cleanup into a dedicated task

## Deploy And Runtime Notes

- [`api/Procfile`](../api/Procfile) and [`api/Dockerfile`](../api/Dockerfile) are both active references
- `Procfile` uses `api.main:app` in the web example
- `Dockerfile` runs `main:app` because `/api` contents become the container working directory

This is not necessarily wrong, but it is easy to misread.

Current recommendation:

- document this clearly
- do not change deploy commands casually without verifying Railway root directory assumptions

## Practical Cleanup Guidance

Before removing any file listed here as legacy or overlapping:

- verify it is not still referenced by routes or imports
- name the replacement file explicitly
- define the manual or automated test path first

The main danger in this repo is not one giant broken file.
It is silent overlap between old and new paths.
