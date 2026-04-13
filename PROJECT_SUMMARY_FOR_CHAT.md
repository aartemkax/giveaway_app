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
- a staging recovery runbook in [`docs/ACCOUNT_RECOVERY_RUNBOOK.md`](C:/dev/giveaway_app/docs/ACCOUNT_RECOVERY_RUNBOOK.md)

The long-term direction is moving from direct session-based Instagram server login toward account-scoped async jobs backed by persisted session/device context.

## Repository State

Verified from repository state:

- `README.md` is now a real onboarding document and no longer just the default Flutter template.
- There is no separate `handbook/` directory in this repo.
- `docs/` currently contains built Flutter web artifacts and is not only handwritten engineering documentation.
- `docs/ARCHITECTURE.md` and `docs/CODEBASE_NOTES.md` now exist and document current structure and overlap areas.
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
- participants screen now reads active account state from the backend
- challenge, cooldown, and unverified account states are surfaced as a visible banner instead of only snackbars
- the draw action is blocked in the UI when the active account is already known to be blocked
- the participants banner can now trigger a fresh account verification attempt instead of only reloading stale state

Important frontend service flows:

- [`lib/services/auth_service.dart`](C:/dev/giveaway_app/lib/services/auth_service.dart)
  - legacy auth/session checks
  - `hasActiveAccount()` for account-affinity mode
- [`lib/services/appapi/app_auth_service.dart`](C:/dev/giveaway_app/lib/services/appapi/app_auth_service.dart)
  - new API-facing auth helper
  - `createAccountFromSessionId()` stores:
    - `auth_method = ig_account`
    - `active_account_id`
  - onboarding now follows `from_sessionid` with an explicit account verification call
- [`lib/services/appapi/app_participants_service.dart`](C:/dev/giveaway_app/lib/services/appapi/app_participants_service.dart)
  - starts async participant fetch
  - prefers `/api/admin/accounts/<account_id>/fetch_participants_async` when `active_account_id` exists
  - otherwise falls back to the legacy `/api/fetch_participants_async`
  - can read active account state from `/api/admin/accounts/<account_id>`
- [`lib/screens/instagram_login_webview.dart`](C:/dev/giveaway_app/lib/screens/instagram_login_webview.dart)
  - extracts `sessionid` from Instagram WebView cookies
  - sends it to `/api/admin/accounts/from_sessionid`
  - triggers an immediate verification step for the new account
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
- `POST /api/admin/accounts/<account_id>/verify`
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
- the client now follows onboarding with `POST /api/admin/accounts/<account_id>/verify`
- that verification is a lightweight authenticated probe, not a guarantee that media/comment fetch will succeed

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

- jobs are considered technically successful by RQ even when they return an error dict
- API maps domain errors from `/api/job_result/<job_id>` into HTTP statuses such as:
  - `400` for invalid post URL
  - `401` for login/session invalid
  - `412` for Instagram challenge
  - `429` for cooldown / rate limit

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
- challenge-state account blocking before enqueue
- enqueuing account-scoped async jobs
- polling `job_status` / `job_result`
- Flutter widget coverage for blocked account banner behavior on the participants screen
- Flutter widget coverage for navigating back to `/login` from blocked account state

Current testing limitation:

- repository tests validate API contract and queue orchestration better than real Instagram behavior
- they do not solve server-side Instagram trust/challenge issues

## Progress Snapshot

Current stage of the recent account-affinity milestone:

- Done:
  - staging environment separated and verified
  - account-affinity store and admin endpoints added
  - onboarding via `from_sessionid` works
  - onboarding now includes an explicit verification step
  - manual `sessionid -> onboarding -> verify -> participants` was verified on the staging emulator flow
  - account-scoped jobs enqueue and run on the worker
  - Playwright smoke coverage exists for internal API flows
  - canonical summary and docs policy were added
- In progress:
  - migration from legacy session-based flows to `account_id`-based flows
  - full cleanup of old session-based client paths
- Blocked:
  - real server-side Instagram media/comment fetch still hits challenge/checkpoint behavior

This means the architectural foundation of the milestone is in place, but the end-to-end business outcome is not yet fully complete.

## Current Functional Reality

Verified from recent staging behavior and user-provided logs:

- staging API and staging worker are both running
- account onboarding via `POST /api/admin/accounts/from_sessionid` returns `200`
- onboarding is now followed by `POST /api/admin/accounts/<account_id>/verify`
- manual sessionid login on the emulator now reaches that exact backend sequence
- the verified account created during that run was `515132743b69dd7e`
- account-scoped fetch jobs enqueue and execute on the worker
- the worker reaches real Instagram API calls
- the worker hits Instagram `challenge` behavior when trying to fetch media/comments
- the verification step can already classify the account before draw/fetch:
  - `412`
  - `status = challenge`
  - `challenge_reason = verify_session_challenge`
- the participants screen now lands in a blocked-state UX with:
  - visible banner
  - `Перейти до входу`
  - `Перевірити ще раз`
  - blocked draw action

This means:

- the account-affinity plumbing is active
- the queue/import issues have already been resolved
- the verification boundary is now proven end to end in the real staging app flow
- the remaining blocker is not job scheduling, but Instagram rejecting server-side access context during verification and media/comment fetch
- the repository code is being updated to describe that blocker more honestly in account/API state
- the Flutter client now reflects blocked account states before retrying draw/fetch actions

## Known Risks And Constraints

1. The project still relies on Instagram private API behavior through `instagrapi`, which is brittle under server-side IP/device/session mismatches.
2. `from_sessionid` onboarding plus verification should still not be confused with guaranteed media/comment fetch success.
3. Without a trusted/sticky network context or proxy strategy, server-side comment fetch can still fail with challenge/checkpoint behavior.
4. Staging verification can lag behind repository behavior when backend code changes have not yet been deployed.
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

- improve client UX around account state and retry behavior
- add one more focused verification path around the new account-state UX or retry behavior
- only revisit proxy/network strategy if server-side Instagram comment fetch remains a required capability
- use the new `/verify` step as the main boundary between "saved account" and "usable account"

Concrete finish-plan reference:

- [`docs/DELIVERY_PLAN_FINISH_FLOW.md`](C:/dev/giveaway_app/docs/DELIVERY_PLAN_FINISH_FLOW.md) is the current execution plan for finishing the account-based giveaway flow without drifting into unrelated work
- [`docs/ACCOUNT_RECOVERY_RUNBOOK.md`](C:/dev/giveaway_app/docs/ACCOUNT_RECOVERY_RUNBOOK.md) is the support-oriented diagnosis path for staging account recovery and verification failures
