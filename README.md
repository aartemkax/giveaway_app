# giveaway_app

`giveaway_app` is a Flutter client with a Flask/Redis backend for running Instagram giveaways.

The project supports two main operating modes:

1. `Facebook / Instagram Graph API flow`
   For Facebook-connected Instagram business or creator accounts. The app uses Facebook OAuth, loads available Instagram accounts, fetches media and comments through Graph API, and can run a filtered draw with audit data.

2. `Instagram session / instagrapi flow`
   For private or less official scenarios. The app logs into Instagram with login/password or `sessionid`, stores the session server-side, fetches participants asynchronously through `instagrapi`, and lets the client pick winners from the returned pool.

## What The Product Does

At a high level the system combines:

- login and session handling;
- Instagram account/media/comment access;
- participant filtering;
- winner selection;
- account/proxy management for backend jobs;
- basic staging smoke coverage for admin endpoints.

## Tech Stack

- Flutter / Dart client
- Riverpod for state management
- Dio + cookie jar for HTTP and session cookies
- Flask API
- Redis for server session storage
- RQ for background jobs
- `instagrapi` for Instagram session-based access
- Facebook Graph API for official account-based access
- Playwright for API smoke tests

## Repository Structure

- [lib/main.dart](/Users/starlord/giveaway_app/lib/main.dart): Flutter entrypoint and routing
- [lib/screens/login/app_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/app_login_screen.dart): entry screen with flow selection
- [lib/screens/password_login_screen.dart](/Users/starlord/giveaway_app/lib/screens/password_login_screen.dart): Instagram login/password flow
- [lib/screens/fb_home_screen.dart](/Users/starlord/giveaway_app/lib/screens/fb_home_screen.dart): Facebook flow landing screen
- [lib/screens/ig_media_screen.dart](/Users/starlord/giveaway_app/lib/screens/ig_media_screen.dart): Graph API media browser
- [lib/screens/ig_comments_screen.dart](/Users/starlord/giveaway_app/lib/screens/ig_comments_screen.dart): comments, filters, draw
- [lib/screens/login/participants_screen.dart](/Users/starlord/giveaway_app/lib/screens/login/participants_screen.dart): session-based participant draw
- [api/main.py](/Users/starlord/giveaway_app/api/main.py): main Flask API
- [api/tasks.py](/Users/starlord/giveaway_app/api/tasks.py): background worker logic
- [api/account_affinity.py](/Users/starlord/giveaway_app/api/account_affinity.py): account/proxy registry in Redis
- [tests/playwright/admin-api.spec.ts](/Users/starlord/giveaway_app/tests/playwright/admin-api.spec.ts): staging admin API smoke tests
- [PROJECT_SUMMARY_FOR_CHAT.md](/Users/starlord/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md): handoff summary for other chats

## How To Run

### 1. Flutter Client

Prerequisites:

- Flutter SDK
- a root `.env` file

Minimal `.env`:

```env
API_BASE_URL=http://localhost:8080
```

You can also start from [.env.example](/Users/starlord/giveaway_app/.env.example).

Install dependencies and run:

```bash
flutter pub get
flutter run
```

The app reads `API_BASE_URL` from [lib/utils/constants.dart](/Users/starlord/giveaway_app/lib/utils/constants.dart). Default fallback is `http://10.0.2.2:8080`.

### 2. Backend API

Prerequisites:

- Python 3.11
- Redis
- a backend env file in `api/`

Create and activate a virtual environment, then install dependencies:

```bash
cd api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Start Redis locally if you do not already have it running.

Run the Flask API locally:

```bash
cd api
source .venv/bin/activate
python main.py
```

The API runs on port `8080` by default.

### 3. Background Worker

Async participant fetching depends on RQ, so for the session-based flow you also need a worker:

```bash
cd api
source .venv/bin/activate
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

The production-style commands are also documented in [api/Procfile](/Users/starlord/giveaway_app/api/Procfile).

## Deployment Notes

Current canonical deploy files:

- [railway.json](/Users/starlord/giveaway_app/railway.json)
- [api/Dockerfile](/Users/starlord/giveaway_app/api/Dockerfile)
- [api/Procfile](/Users/starlord/giveaway_app/api/Procfile)

Current deploy path:

- Railway should build using `api/Dockerfile`
- [api/Dockerfile](/Users/starlord/giveaway_app/api/Dockerfile) is written for repository-root build context
- active backend entrypoint remains [api/main.py](/Users/starlord/giveaway_app/api/main.py)
- [api/Procfile](/Users/starlord/giveaway_app/api/Procfile) uses `api.main:app` from the repository root
- [api/Dockerfile](/Users/starlord/giveaway_app/api/Dockerfile) runs `main:app` inside the container because `api/` contents are copied into `/app`

## Required Environment Variables

### Flutter `.env`

Required:

- `API_BASE_URL`: backend base URL used by the app

Optional:

- `GEO_SERVICE_URL`: overrides the geo lookup endpoint used by the device service

Reference file:

- [.env.example](/Users/starlord/giveaway_app/.env.example)

### Backend `api/.env`

Required for a working local backend:

- `FLASK_SECRET_KEY`
- `REDIS_URL`
- `SESSION_COOKIE_SECURE`

Required for Facebook / Graph API flow:

- `FB_APP_ID`
- `FB_APP_SECRET`
- `FB_REDIRECT_URI`

Optional for Instagram session handling and operations:

- `IG_USERNAME`
- `IG_PASSWORD`
- `SESSION_JSON_B64`
- `USE_PROXY`
- `INSTAGRAM_AUTH_PROXIES`
- `INSTAGRAM_PROXIES`
- `PROXIES`
- `CORS_ORIGIN`
- `PORT`

Reference file:

- [api/.env.example](/Users/starlord/giveaway_app/api/.env.example)

## Testing

### Flutter

The repo currently includes a minimal Flutter startup smoke test.
It is useful, but still narrower than real screen-level UI coverage:

```bash
flutter test
```

### Playwright API Smoke Tests

The main automated coverage in this repo is Playwright-based API smoke testing.

Install and run:

```bash
npm install
npm run test:api
```

Optional environment variables for smoke tests:

- `PLAYWRIGHT_BASE_URL`
- `PLAYWRIGHT_TEST_POST_URL`
- `PLAYWRIGHT_SESSION_COOKIE`

Related files:

- [package.json](/Users/starlord/giveaway_app/package.json)
- [playwright.config.ts](/Users/starlord/giveaway_app/playwright.config.ts)
- [tests/playwright/README.md](/Users/starlord/giveaway_app/tests/playwright/README.md)

## Architecture Docs

- [handbook/ARCHITECTURE.md](/Users/starlord/giveaway_app/handbook/ARCHITECTURE.md)
- [handbook/CODEBASE_NOTES.md](/Users/starlord/giveaway_app/handbook/CODEBASE_NOTES.md)
- [handbook/CLEANUP_PLAN.md](/Users/starlord/giveaway_app/handbook/CLEANUP_PLAN.md)
- [docs/DEV_SETUP.md](/Users/starlord/giveaway_app/docs/DEV_SETUP.md)
- [docs/DEFINITION_OF_DONE.md](/Users/starlord/giveaway_app/docs/DEFINITION_OF_DONE.md)
- [docs/TESTING.md](/Users/starlord/giveaway_app/docs/TESTING.md)
- [docs/RELEASE_CHECKLIST.md](/Users/starlord/giveaway_app/docs/RELEASE_CHECKLIST.md)
- [docs/PROCESS_RETRO.md](/Users/starlord/giveaway_app/docs/PROCESS_RETRO.md)

## Current State

This is already a working application with multiple real flows, but it is still in a cleanup phase.

Known weak spots:

- documentation is being built out now;
- some services and screens overlap old and new approaches;
- there is visible technical debt in configuration and file structure;
- test coverage is still narrow compared to the actual product surface.

## Handoff

If you need to transfer project context to another chat, start with:

- [PROJECT_SUMMARY_FOR_CHAT.md](/Users/starlord/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)

That file is intended to stay current and act as the fast project brief.
