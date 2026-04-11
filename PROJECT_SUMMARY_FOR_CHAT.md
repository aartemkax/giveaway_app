# PROJECT_SUMMARY_FOR_CHAT

## Overview

`giveaway_app` is a Flutter client plus Flask backend for Instagram/Facebook giveaway workflows.

The repository currently contains:

- a Flutter mobile app in [`lib/`](C:/dev/giveaway_app/lib)
- a Flask API in [`api/main.py`](C:/dev/giveaway_app/api/main.py)
- Redis-backed background jobs in [`api/tasks.py`](C:/dev/giveaway_app/api/tasks.py)
- an account-affinity store in [`api/account_affinity.py`](C:/dev/giveaway_app/api/account_affinity.py)
- Railway deploy configuration in [`railway.json`](C:/dev/giveaway_app/railway.json) and [`api/Dockerfile`](C:/dev/giveaway_app/api/Dockerfile)
- Playwright API smoke tests in [`tests/playwright/admin-api.spec.ts`](C:/dev/giveaway_app/tests/playwright/admin-api.spec.ts)

The long-term direction is moving from direct session-based Instagram server login toward account-scoped async jobs backed by persisted session/device context.

## Repository State

Verified from repository state:

- `README.md` is still the default Flutter template and is not an authoritative project description.
- There is no separate `handbook/` directory in this repo.
- `docs/` currently contains built Flutter web artifacts and is not only handwritten engineering documentation.
- `project_init/` is now a lightweight entrypoint and should not duplicate the canonical summary.
- `PROJECT_SUMMARY_FOR_CHAT.md` is intended to be the single compact handoff document.

## Frontend

The Flutter app boots from [`lib/main.dart`](C:/dev/giveaway_app/lib/main.dart).

Current frontend behavior:

- startup auth state is routed through `auth_method`
- supported auth modes are:
  - `fb`
  - `ig`
  - `ig_account`
- environment visibility is built into the UI through an environment badge and debug screen
- the debug screen route is `/debug_env`

Important frontend service flows:

- [`lib/services/auth_service.dart`](C:/dev/giveaway_app/lib/services/auth_service.dart)
  - legacy auth/session checks
  - `hasActiveAccount()` for account-affinity mode
- [`lib/services/appapi/app_auth_service.dart`](C:/dev/giveaway_app/lib/services/appapi/app_auth_service.dart)
  - new API-facing auth helper
  - `createAccountFromSessionId()` stores:
    - `auth_method = ig_account`
    - `active_account_id`
- [`lib/services/appapi/app_participants_service.dart`](C:/dev/giveaway_app/lib/services/appapi/app_participants_service.dart)
  - starts async participant fetch
  - prefers `/api/admin/accounts/<account_id>/fetch_participants_async` when `active_account_id` exists
  - otherwise falls back to the legacy `/api/fetch_participants_async`
- [`lib/screens/instagram_login_webview.dart`](C:/dev/giveaway_app/lib/screens/instagram_login_webview.dart)
  - extracts `sessionid` from Instagram WebView cookies
  - sends it to `/api/admin/accounts/from_sessionid`
  - does not treat `sessionid` onboarding as a server-side Instagram login anymore

## Backend

The backend entrypoint is [`api/main.py`](C:/dev/giveaway_app/api/main.py).

Core backend pieces:

- Flask app with `Flask-Session`
- Redis for both session storage and job queue backing
- RQ queue via `Queue(connection=redis_conn)`
- CORS configured for local dev and optional Railway origin
- `ProxyFix` enabled for forwarded host/ip handling

Backend still contains both old and new Instagram paths:

- legacy login/session validation endpoints remain in place
- new account-affinity endpoints exist for account registration and account-scoped work

Important new endpoints:

- `POST /api/admin/accounts`
- `GET /api/admin/accounts`
- `GET /api/admin/accounts/<account_id>`
- `POST /api/admin/accounts/from_current_session`
- `POST /api/admin/accounts/from_sessionid`
- `POST /api/admin/accounts/<account_id>/bind_proxy`
- `POST /api/admin/accounts/<account_id>/sync_session`
- `POST /api/admin/accounts/<account_id>/fetch_participants_async`
- `GET /api/job_status/<job_id>`
- `GET /api/job_result/<job_id>`

## Account-Affinity Model

The account-affinity layer is implemented in [`api/account_affinity.py`](C:/dev/giveaway_app/api/account_affinity.py).

Current persisted entities:

- `AccountRecord`
  - `account_id`
  - `instagram_username`
  - `status`
  - `proxy_id`
  - `session_settings`
  - `device_profile`
  - `last_login_at`
  - `last_success_at`
  - `cooldown_until`
  - `challenge_reason`
  - `notes`
- `ProxyRecord`
  - `proxy_id`
  - `proxy_url`
  - `region`
  - `proxy_type`
  - `status`
  - `assigned_account_id`

Current guarantees from this layer:

- account-scoped Redis records
- proxy binding support
- account lock support to prevent concurrent worker execution
- account context restoration for background jobs

What `from_sessionid` actually does:

- accepts raw `sessionid` plus `deviceInfo.settings`
- stores those cookies/settings as account session state
- marks the record as coming from `sessionid` source
- does **not** validate the session with Instagram at onboarding time

## Background Jobs

Background job logic lives in [`api/tasks.py`](C:/dev/giveaway_app/api/tasks.py).

Two main job paths exist:

- `fetch_participants_task(...)`
  - legacy path using encoded settings payload
- `fetch_account_participants_task(account_id, post_url)`
  - new account-affinity path

`fetch_account_participants_task(...)`:

- acquires an account lock
- loads persisted `session_settings` and optional proxy from `AccountAffinityStore`
- restores an `instagrapi.Client`
- attempts to fetch media comments from Instagram
- marks account state based on result

Important current implementation detail:

- jobs are considered technically successful by RQ even when they return an error dict like `{"error": "internal_error"}`; API then converts that to an HTTP error in `/api/job_result/<job_id>`

## Deploy / Runtime

Railway deploy is configured in [`railway.json`](C:/dev/giveaway_app/railway.json) and [`api/Dockerfile`](C:/dev/giveaway_app/api/Dockerfile).

Runtime facts from repository config:

- build uses Dockerfile
- deploy runtime is Railway V2
- web container default command is Gunicorn from `api/Dockerfile`
- worker process convention is defined in [`api/Procfile`](C:/dev/giveaway_app/api/Procfile):
  - `web: gunicorn ...`
  - `worker: python -m rq worker --with-scheduler -u $REDIS_URL -P .`

Operational caveat:

- API and worker must be redeployed together when queue/job signatures change
- if API is updated but worker is still on an older image, queue jobs may enqueue successfully while failing at worker import/runtime

## Testing

Playwright smoke coverage exists in [`tests/playwright/admin-api.spec.ts`](C:/dev/giveaway_app/tests/playwright/admin-api.spec.ts).

Covered areas:

- `runtime_info`
- admin accounts/proxies collections
- validation errors for admin endpoints
- creating proxy + account + binding
- enqueuing account-scoped async jobs
- polling `job_status` / `job_result`

Current testing limitation:

- repository tests validate API contract and queue orchestration better than real Instagram behavior
- they do not solve server-side Instagram trust/challenge issues

## Current Functional Reality

Verified from recent staging behavior and user-provided logs:

- staging API and staging worker are both running
- account onboarding via `POST /api/admin/accounts/from_sessionid` returns `200`
- account-scoped fetch jobs enqueue and execute on the worker
- the worker reaches real Instagram API calls
- the worker hits Instagram `challenge` behavior when trying to fetch media/comments

This means:

- the account-affinity plumbing is active
- the queue/import issues have already been resolved
- the remaining blocker is not job scheduling, but Instagram rejecting server-side access context during media/comment fetch

## Known Risks And Constraints

1. The project still relies on Instagram private API behavior through `instagrapi`, which is brittle under server-side IP/device/session mismatches.
2. `from_sessionid` onboarding should not be confused with verified Instagram authentication; it only persists session context.
3. Without a trusted/sticky network context or proxy strategy, server-side comment fetch can still fail with challenge/checkpoint behavior.
4. `README.md` is stale and should not be treated as onboarding documentation.
5. Some older legacy paths still coexist with new account-affinity flows, so repo intent is transitional rather than fully cleaned up.

## Important Files

- [`lib/main.dart`](C:/dev/giveaway_app/lib/main.dart): app bootstrap, auth routing, env badge/debug entrypoint
- [`lib/services/auth_service.dart`](C:/dev/giveaway_app/lib/services/auth_service.dart): legacy auth/session checks plus `hasActiveAccount()`
- [`lib/services/appapi/app_auth_service.dart`](C:/dev/giveaway_app/lib/services/appapi/app_auth_service.dart): account onboarding from `sessionid`
- [`lib/services/appapi/app_participants_service.dart`](C:/dev/giveaway_app/lib/services/appapi/app_participants_service.dart): async fetch start and polling
- [`lib/screens/instagram_login_webview.dart`](C:/dev/giveaway_app/lib/screens/instagram_login_webview.dart): WebView cookie capture and account onboarding trigger
- [`api/main.py`](C:/dev/giveaway_app/api/main.py): Flask API, login/session/account-affinity endpoints, job status/result endpoints
- [`api/tasks.py`](C:/dev/giveaway_app/api/tasks.py): RQ worker logic and Instagram fetch behavior
- [`api/account_affinity.py`](C:/dev/giveaway_app/api/account_affinity.py): Redis-backed account/proxy records and account locks
- [`api/Procfile`](C:/dev/giveaway_app/api/Procfile): expected web/worker process commands
- [`api/Dockerfile`](C:/dev/giveaway_app/api/Dockerfile): backend image build and default web command
- [`tests/playwright/admin-api.spec.ts`](C:/dev/giveaway_app/tests/playwright/admin-api.spec.ts): API smoke tests

## Recommended Next Focus

If work continues from the current state, the next productive area is not the old login endpoint itself, but the account-scoped worker failure mode:

- classify Instagram challenge failures explicitly instead of surfacing them as generic internal errors
- update account status when worker-side challenge occurs
- improve client UX around account state and retry behavior
- only revisit proxy/network strategy if server-side Instagram comment fetch remains a required capability
