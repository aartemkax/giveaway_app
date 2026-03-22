# giveaway_app Dev Setup

## Purpose

This document explains how to run `giveaway_app` locally.

It covers:

- what needs to be installed;
- which `.env` files are required;
- how to start Flutter;
- how to start Redis;
- how to start the Flask API;
- how to run Playwright smoke tests.

Important note:

- the `docs/` directory currently also contains Flutter web build artifacts;
- this file is a human-facing setup guide stored there because it was explicitly requested in this location.

## What You Need Installed

### Required

- Flutter SDK
- Dart SDK through Flutter
- Python 3.11
- `pip`
- Redis
- Node.js and `npm`

### Recommended

- `venv` support for Python virtual environments
- `git`
- a local shell environment with `bash` or `zsh`

## Project Files You Will Use

- [README.md](/Users/starlord/giveaway_app/README.md)
- [PROJECT_SUMMARY_FOR_CHAT.md](/Users/starlord/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)
- [handbook/ARCHITECTURE.md](/Users/starlord/giveaway_app/handbook/ARCHITECTURE.md)
- [.env.example](/Users/starlord/giveaway_app/.env.example)
- [api/.env.example](/Users/starlord/giveaway_app/api/.env.example)
- [api/Procfile](/Users/starlord/giveaway_app/api/Procfile)
- [tests/playwright/README.md](/Users/starlord/giveaway_app/tests/playwright/README.md)

## Environment Files

There are two main env layers.

### 1. Root `.env` for Flutter

Path:

- [/.env](/Users/starlord/giveaway_app/.env)

Start from:

- [.env.example](/Users/starlord/giveaway_app/.env.example)

Minimum required value:

```env
API_BASE_URL=http://localhost:8080
```

Optional:

```env
GEO_SERVICE_URL=https://ipapi.co/json/
```

What it is used for:

- tells the Flutter app which backend to call.

### 2. `api/.env` for Flask backend

Path:

- [api/.env](/Users/starlord/giveaway_app/api/.env)

Start from:

- [api/.env.example](/Users/starlord/giveaway_app/api/.env.example)

Minimum practical local values:

```env
FLASK_SECRET_KEY=change-me
REDIS_URL=redis://localhost:6379/0
SESSION_COOKIE_SECURE=false
PORT=8080
```

Needed for Facebook / Graph API flow:

```env
FB_APP_ID=...
FB_APP_SECRET=...
FB_REDIRECT_URI=...
```

Optional operational values:

```env
IG_USERNAME=
IG_PASSWORD=
SESSION_JSON_B64=
USE_PROXY=
INSTAGRAM_AUTH_PROXIES=
INSTAGRAM_PROXIES=
PROXIES=
CORS_ORIGIN=
```

## Setup Order

For a normal local environment, use this order:

1. install dependencies
2. create `.env` files
3. start Redis
4. start Flask API
5. start RQ worker
6. start Flutter
7. optionally run Playwright smoke tests

## 1. Install Flutter Dependencies

From project root:

```bash
cd /Users/starlord/giveaway_app
flutter pub get
```

## 2. Install Backend Dependencies

From project root:

```bash
cd /Users/starlord/giveaway_app/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 3. Install Playwright Dependencies

From project root:

```bash
cd /Users/starlord/giveaway_app
npm install
```

If Playwright browsers are missing, install them:

```bash
npx playwright install
```

## 4. Start Redis

The project depends on Redis for:

- Flask sessions;
- RQ jobs;
- account/proxy storage.

If you already have Redis installed locally, a common start command is:

```bash
redis-server
```

If Redis is already running as a background service, verify it:

```bash
redis-cli ping
```

Expected response:

```text
PONG
```

Default local Redis URL assumed by the project:

```env
REDIS_URL=redis://localhost:6379/0
```

## 5. Start Flask API

From the `api/` directory:

```bash
cd /Users/starlord/giveaway_app/api
source .venv/bin/activate
python main.py
```

Expected behavior:

- backend starts on port `8080` by default;
- it loads env values through `load_dotenv()`;
- it connects to Redis;
- it exposes endpoints under `/api/*`.

Health check:

```bash
curl http://localhost:8080/healthz
```

Expected response:

```text
ok
```

You can also inspect:

```bash
curl http://localhost:8080/api/runtime_info
```

## 6. Start RQ Worker

Session-based participant fetching requires a worker.

From the `api/` directory:

```bash
cd /Users/starlord/giveaway_app/api
source .venv/bin/activate
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

This matches the worker process shape declared in [api/Procfile](/Users/starlord/giveaway_app/api/Procfile).

If `REDIS_URL` is not exported in the shell, run:

```bash
export REDIS_URL=redis://localhost:6379/0
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

## 7. Start Flutter

From project root:

```bash
cd /Users/starlord/giveaway_app
flutter run
```

Before starting Flutter, confirm your root `.env` points to the backend:

```env
API_BASE_URL=http://localhost:8080
```

Notes:

- Android emulator fallback in code is `http://10.0.2.2:8080`;
- if you run on emulator and use localhost incorrectly, the app may fail to reach the backend;
- for web, ensure CORS settings are compatible with your local frontend origin.

## 8. Run Playwright Smoke Tests

From project root:

```bash
cd /Users/starlord/giveaway_app
npm run test:api
```

These tests target HTTP endpoints, mainly staging-oriented admin/account-affinity behavior.

Optional environment variables:

```bash
export PLAYWRIGHT_BASE_URL="https://stage-exemplary-appreciation-staging.up.railway.app"
export PLAYWRIGHT_TEST_POST_URL="https://www.instagram.com/p/C4k_m8HNr7v/"
export PLAYWRIGHT_SESSION_COOKIE="<flask session cookie>"
```

Files involved:

- [package.json](/Users/starlord/giveaway_app/package.json)
- [playwright.config.ts](/Users/starlord/giveaway_app/playwright.config.ts)
- [tests/playwright/admin-api.spec.ts](/Users/starlord/giveaway_app/tests/playwright/admin-api.spec.ts)

## Minimal Local Run Scenarios

### A. Basic app boot only

Use this if you only want the client and backend running:

1. start Redis
2. start Flask API
3. start Flutter

### B. Full session-based participant flow

Use this if you want `/api/fetch_participants_async` to work:

1. start Redis
2. start Flask API
3. start RQ worker
4. start Flutter

### C. Graph API flow

Use this if you want Facebook login and Graph-backed comments/media:

1. start Redis
2. set `FB_APP_ID`, `FB_APP_SECRET`, `FB_REDIRECT_URI`
3. start Flask API
4. start Flutter

Worker is not the primary dependency for pure Graph API browsing and draw flow, but it is still fine to keep it running.

## Common Problems

### Backend starts but app cannot connect

Check:

- root `.env` points to the correct API URL;
- emulator uses the right host;
- backend is listening on `8080`;
- CORS config is not blocking your frontend origin.

### Login works badly or session disappears

Check:

- Redis is running;
- `REDIS_URL` is correct;
- `SESSION_COOKIE_SECURE` is appropriate for your local environment;
- client cookie jar is not stale from another environment.

### Async participant loading hangs

Check:

- RQ worker is running;
- Redis is reachable;
- backend and worker use the same `REDIS_URL`;
- job status endpoints are reachable.

### Facebook flow does not work

Check:

- `FB_APP_ID`, `FB_APP_SECRET`, `FB_REDIRECT_URI` are set;
- callback URL matches the app config;
- the Facebook account has the required page and IG business/creator access.

### Playwright tests fail immediately

Check:

- `npm install` was run;
- Playwright browsers are installed;
- `PLAYWRIGHT_BASE_URL` points to the intended target;
- test expectations still match the current API behavior.

## Recommended Terminal Layout

For local development, keep separate terminals for:

1. Redis
2. Flask API
3. RQ worker
4. Flutter
5. optional Playwright runs

## Quick Start Summary

If you just need the shortest working path:

```bash
cd /Users/starlord/giveaway_app
flutter pub get
npm install

cd /Users/starlord/giveaway_app/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Then run, in separate terminals:

```bash
redis-server
```

```bash
cd /Users/starlord/giveaway_app/api
source .venv/bin/activate
python main.py
```

```bash
cd /Users/starlord/giveaway_app/api
source .venv/bin/activate
export REDIS_URL=redis://localhost:6379/0
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

```bash
cd /Users/starlord/giveaway_app
flutter run
```
