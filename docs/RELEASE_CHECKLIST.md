# giveaway_app Release Checklist

## Purpose

This document is the minimum pre-release checklist for `giveaway_app`.

It is intentionally operational.
Use it before any release, deploy, or staging promotion.

## Core Rule

Do not release if any critical item below is unchecked.

Critical in this project means:

- env mismatch
- Redis or RQ worker not running correctly
- broken login flow
- broken participant fetch flow
- broken draw flow
- failing staging smoke tests

## 1. Environment Check

Verify the environment values match the target release environment.

Flutter-side:

- confirm `API_BASE_URL` points to the intended backend
- confirm any optional `GEO_SERVICE_URL` override is intentional

Backend-side:

- confirm `FLASK_SECRET_KEY` is present
- confirm `REDIS_URL` points to the intended Redis instance
- confirm `SESSION_COOKIE_SECURE` matches the release target
- confirm `CORS_ORIGIN` is correct if used
- confirm `PORT` is correct if overridden

Flow-specific env:

- confirm `FB_APP_ID`, `FB_APP_SECRET`, and `FB_REDIRECT_URI` are correct for Graph API flow
- confirm proxy-related values are intentional if session-based or account-affinity flow depends on them

Reference files:

- [.env.example](/Users/starlord/giveaway_app/.env.example)
- [api/.env.example](/Users/starlord/giveaway_app/api/.env.example)
- [README.md](/Users/starlord/giveaway_app/README.md)
- [docs/DEV_SETUP.md](/Users/starlord/giveaway_app/docs/DEV_SETUP.md)

## 2. Redis And RQ Check

Verify backend background infrastructure is healthy.

- confirm Redis is reachable
- confirm backend and worker use the same `REDIS_URL`
- confirm RQ worker starts successfully
- confirm scheduler-enabled worker command still works

Recommended checks:

```bash
redis-cli ping
```

Expected:

```text
PONG
```

```bash
cd /Users/starlord/giveaway_app/api
source .venv/bin/activate
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

Also verify:

- [api/Procfile](/Users/starlord/giveaway_app/api/Procfile) still matches runtime expectations
- [railway.json](/Users/starlord/giveaway_app/railway.json) still points to the correct Docker path
- Railway service Root Directory is still `/api`
- [api/Dockerfile](/Users/starlord/giveaway_app/api/Dockerfile) still matches the intended deploy entrypoint

## 3. Login Flow Check

At least one login path must be verified before release.

Preferred scope:

- session-based Instagram login/password flow
- Facebook / Graph API login flow if that area was touched

Minimum sanity expectations:

- app boots to login entry
- password login screen opens
- login request reaches backend successfully
- session is stored when session-based login is used

Related endpoints:

- `/api/login`
- `/api/login_by_sessionid`
- `/api/session_status`
- `/api/fb/login_url`

## 4. Fetch Participants Check

Verify the participant loading path still works.

Session-based flow:

- participant fetch can be started
- worker picks up the job
- job reaches a terminal state
- participant result endpoint responds correctly

Account-affinity/admin flow:

- account-scoped async fetch can be enqueued
- invalid account or invalid URL paths still return expected errors

Related endpoints:

- `/api/fetch_participants_async`
- `/api/admin/accounts/<id>/fetch_participants_async`
- `/api/job_status/<job_id>`
- `/api/job_result/<job_id>`

## 5. Draw Check

Verify at least one draw path before release.

Session-based flow:

- participants screen can receive fetched participants
- winners can be selected from the returned pool

Graph API flow:

- IG comments/media data loads for the chosen scenario
- draw request returns winners successfully

Related endpoints:

- `/api/ig/comments`
- `/api/ig/draw`
- `/api/ig/run_draw`

## 6. Staging Smoke Tests

Run the current automated smoke suite before release.

```bash
cd /Users/starlord/giveaway_app
npm run test:api
```

Current scope:

- runtime info
- admin account and proxy endpoints
- account-scoped async participant fetch flow
- job status and result behavior

Important note:

- one `from_current_session` Playwright test may be skipped unless `PLAYWRIGHT_SESSION_COOKIE` is configured
- treat unexpected failures in the active smoke tests as release blockers

Related files:

- [tests/playwright/admin-api.spec.ts](/Users/starlord/giveaway_app/tests/playwright/admin-api.spec.ts)
- [playwright.config.ts](/Users/starlord/giveaway_app/playwright.config.ts)
- [tests/playwright/README.md](/Users/starlord/giveaway_app/tests/playwright/README.md)

## 7. Final Release Gate

Release only if all of the following are true:

- env values are verified
- Redis and RQ are healthy
- at least one relevant login path works
- at least one relevant participant fetch path works
- at least one relevant draw path works
- staging smoke tests pass
- any changed docs are already updated

If one of these is not true, the release should be treated as not ready.
