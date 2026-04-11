# Architecture

## Purpose

This document describes the current architecture of `giveaway_app` as it actually exists in the repository.

It is intentionally pragmatic.
It documents the current system shape, transition areas, and known debt.

## System Overview

The project consists of four main layers:

1. Flutter client
2. Flask API
3. Redis-backed session and job infrastructure
4. External integrations:
   - Facebook / Instagram Graph API
   - Instagram private API through `instagrapi`

## High-Level Shape

```text
Flutter app
  -> Flask API
    -> Redis (sessions, account-affinity records, RQ queue)
    -> RQ worker
      -> Graph API or instagrapi / Instagram
```

## Flutter Layer

Main app entry:

- [`lib/main.dart`](../lib/main.dart)

Current frontend responsibilities:

- choose and route auth flow
- collect device information
- call backend auth and participant endpoints
- poll async job status
- run local winner selection UI
- expose current environment through env badge and debug screen

Important frontend flows:

- [`lib/screens/login/app_login_screen.dart`](../lib/screens/login/app_login_screen.dart)
  - top-level login entry
- [`lib/screens/password_login_screen.dart`](../lib/screens/password_login_screen.dart)
  - username/password flow
- [`lib/screens/instagram_login_webview.dart`](../lib/screens/instagram_login_webview.dart)
  - active Instagram WebView session capture
- [`lib/screens/fb_home_screen.dart`](../lib/screens/fb_home_screen.dart)
  - Facebook/Graph flow landing screen
- [`lib/screens/ig_media_screen.dart`](../lib/screens/ig_media_screen.dart)
  - media selection for Graph flow
- [`lib/screens/ig_comments_screen.dart`](../lib/screens/ig_comments_screen.dart)
  - comments and draw for Graph flow
- [`lib/screens/login/participants_screen.dart`](../lib/screens/login/participants_screen.dart)
  - active session/account-based participant draw flow

## Flask API Layer

Canonical backend entrypoint:

- [`api/main.py`](../api/main.py)

Backend responsibilities:

- session handling
- Facebook OAuth and callback flow
- device geo / device emulation helpers
- Instagram login and session endpoints
- account-affinity admin endpoints
- async job enqueueing
- job status and result endpoints

Important note:

- [`api/app.py`](../api/app.py) still exists, but it is a legacy stub and should not be treated as the real backend entrypoint

## Redis / RQ Layer

Infrastructure files:

- [`api/tasks.py`](../api/tasks.py)
- [`api/account_affinity.py`](../api/account_affinity.py)
- [`api/Procfile`](../api/Procfile)

Redis is used for:

- Flask session storage
- RQ queue backend
- account-affinity records
- account locks

RQ worker is used for:

- async participant fetch jobs
- account-scoped fetch execution

Important runtime rule:

- API and worker must stay on the same deploy version
- if the API changes a task signature and the worker is stale, jobs may enqueue successfully but fail at runtime

## Graph API Flow

Intent:

- official Facebook-connected Instagram flow

Typical path:

1. user starts Facebook login
2. backend generates OAuth URL
3. callback returns to backend
4. app loads connected IG accounts
5. app loads media
6. app loads comments
7. app performs draw in client/server flow depending on screen behavior

Main related backend modules:

- [`api/fb_graph.py`](../api/fb_graph.py)
- [`api/main.py`](../api/main.py)

Strength:

- this is the more official and lower-risk integration path

## instagrapi Flow

Intent:

- support Instagram access outside the official Graph API path

Typical legacy path:

1. app collects device info
2. app sends username/password or `sessionid`
3. backend tries to authenticate or restore Instagram session
4. backend stores session context
5. async participant fetch is triggered

Related files:

- [`api/main.py`](../api/main.py)
- [`api/tasks.py`](../api/tasks.py)
- [`lib/services/auth_service.dart`](../lib/services/auth_service.dart)
- [`lib/services/participants_service.dart`](../lib/services/participants_service.dart)

Main risk:

- server-side network/device/session mismatch causes challenge/checkpoint behavior

## Account-Affinity Flow

Intent:

- move from direct server-side login attempts toward persisted account-scoped work

Core file:

- [`api/account_affinity.py`](../api/account_affinity.py)

Flow shape:

1. app captures `sessionid` plus device settings
2. backend stores them in an account record
3. app stores `active_account_id`
4. participant fetch is started using `/api/admin/accounts/<id>/fetch_participants_async`
5. worker restores account context and attempts Instagram operations

Important clarification:

- `from_sessionid` onboarding stores account context
- it does not prove that Instagram fully trusts the session in the server-side worker context

## Current Transition State

The repo is in a mixed architecture state.

Both of these are currently true:

- legacy session-based paths still exist
- account-affinity migration is already active

That means the current system is not yet a clean single-path architecture.

## Duplicates And Technical Debt

Current visible overlap areas:

- auth services:
  - [`lib/services/auth_service.dart`](../lib/services/auth_service.dart)
  - [`lib/services/appapi/app_auth_service.dart`](../lib/services/appapi/app_auth_service.dart)
- participant services:
  - [`lib/services/participants_service.dart`](../lib/services/participants_service.dart)
  - [`lib/services/appapi/app_participants_service.dart`](../lib/services/appapi/app_participants_service.dart)
- legacy vs active screens:
  - [`lib/screens/instagram_login_webview.dart`](../lib/screens/instagram_login_webview.dart)
  - [`lib/screens/login/instagram_login_webview.dart`](../lib/screens/login/instagram_login_webview.dart)
  - [`lib/screens/participants_screen.dart`](../lib/screens/participants_screen.dart)
  - [`lib/screens/login/participants_screen.dart`](../lib/screens/login/participants_screen.dart)
  - [`lib/screens/home_screen.dart`](../lib/screens/home_screen.dart)
  - [`lib/screens/login_screen.dart`](../lib/screens/login_screen.dart)
- backend entrypoint duplication:
  - [`api/main.py`](../api/main.py)
  - [`api/app.py`](../api/app.py)

## Deploy Architecture

Current deploy files:

- [`railway.json`](../railway.json)
- [`api/Dockerfile`](../api/Dockerfile)
- [`api/Procfile`](../api/Procfile)

Observed deploy shape:

- Railway builds with `api/Dockerfile`
- web command in Docker image runs `main:app`
- `Procfile` documents expected web/worker command shapes
- staging and production should keep separate env and separate Redis when possible

## Current Blocker

The main architectural blocker right now is not queue wiring.

It is this:

- the worker reaches real Instagram media/comment requests
- Instagram still responds with challenge/checkpoint behavior in server-side execution

So the main next architecture work is not inventing a new flow, but deciding how to represent and handle that blocked account state cleanly.
