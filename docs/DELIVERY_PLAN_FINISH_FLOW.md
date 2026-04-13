# Delivery Plan To Finish The Giveaway Flow

## Why This Plan Exists

The project is no longer blocked by missing docs, queue wiring, or staging setup.

The current blocker is narrower and more concrete:

- direct Instagram login on the backend can return `401 invalid_credentials`
- `from_sessionid` onboarding now creates an account and triggers explicit verification, but that still does not guarantee usable server-side fetch
- worker-side media/comment fetch can still fail with:
  - `412 instagram_challenge`
  - `challenge_reason = worker_media_fetch_challenge`

So the remaining work is not "build more architecture". It is to make one giveaway flow behave predictably end to end, even when Instagram rejects the server-side access context.

## Finish Definition

This phase is complete only when all of the following are true:

1. A user can understand the exact state of the active Instagram account from the app UI.
2. The app does not invite repeated retries when the backend already knows the account cannot proceed.
3. The backend exposes clear account/job states instead of generic server errors.
4. The team has one explicit decision for server-side fetch:
   - either make it reliable enough for the chosen production path
   - or formally treat it as unsupported and provide a different supported flow
5. Release and support docs explain the real runtime behavior, not the intended one.

## Current Verified Reality

Verified from staging and emulator runs:

- direct app login reaches `/api/login` and can return `401`
- the sessionid fallback reaches `/api/admin/accounts/from_sessionid`
- a new account record is created with saved `sessionid` and `deviceInfo`
- the app now follows that with `/api/admin/accounts/<account_id>/verify`
- the verify step has been confirmed live on staging in the real emulator flow
- that verification can already return:
  - `412`
  - `status = challenge`
  - `challenge_reason = verify_session_challenge`
- after that verification failure, the participants screen lands in a blocked account UX instead of a generic error
- participant fetch jobs enqueue and run on the worker
- worker can reach real Instagram media calls
- worker can fail on media/comment fetch with `instagram_challenge`

This means:

- the account-affinity system is working
- the verification boundary is real and no longer theoretical
- the remaining problem is Instagram trust/challenge behavior during verification and server-side fetch

## Product Decision We Need To Lock

Before more code is added, keep this project rule:

- the primary flow is now `sessionid -> account onboarding -> account-scoped fetch`
- the old direct backend login flow is secondary and should not drive new product decisions

This does not mean the old flow must be deleted immediately. It means new fixes should optimize the account-based path first.

## Workstream A: Make Account State First-Class

### Goal

The user should always know whether the active Instagram account is:

- usable
- unverified
- in challenge
- in cooldown
- requires re-login

### Tasks

1. Keep `AccountRecord.status` authoritative for user-facing account state.
2. Keep `challenge_reason` and `cooldown_until` filled whenever the worker can classify the failure.
3. Add or refine lightweight account-state refresh points:
   - after onboarding
   - after a failed fetch
   - when reopening the participants screen
4. Ensure the client never treats `401`, `412`, or `429` as generic unknown errors.

### Acceptance Criteria

- user sees a clear blocked-state banner
- draw/fetch actions are disabled when retry is known to be pointless
- returning to login is a first-class action, not a fallback hidden in logs

## Workstream B: Add A Real Verification Step After Onboarding

### Goal

`from_sessionid` currently stores a session context, but that is not the same as proving the worker can use it.

We need one explicit verification step so the app can distinguish:

- "account was stored"
- "account is actually usable for fetch"

### Tasks

1. Keep the backend verification action for an account:
   - `POST /api/admin/accounts/<account_id>/verify`
   - it runs a cheap authenticated Instagram probe using the stored session/device context
2. Keep that verification wired directly after `from_sessionid` onboarding.
3. If the verification fails:
   - set `status = challenge` or `status = unverified`
   - store a precise reason
   - do not pretend the account is ready
4. Keep surfacing the verification result in the client before the user tries to draw.

### Acceptance Criteria

- the app can tell the difference between "account saved" and "account usable"
- blocked accounts are detected before a full participant-fetch job is launched when possible
- staging emulator flow proves that blocked verification lands in the intended blocked-state screen

## Workstream C: Decide The Network Strategy

### Goal

We need one explicit answer to the question:

- can the chosen production flow reliably fetch Instagram comments from the server?

### Paths

#### Path 1: Make Server-Side Fetch Reliable

This path requires validating a trusted runtime context, likely involving:

- sticky proxy per account
- stable device profile per account
- stable session reuse
- reduced login churn

#### Path 2: Stop Treating Server-Side Fetch As Guaranteed

If Instagram keeps challenging server-side fetch:

- formally mark this path as best-effort or unsupported
- move the supported product flow to a different mechanism
- keep challenge handling honest in UI and docs

### Immediate Rule

Do not mix these paths implicitly.

The team must explicitly choose one of:

- "we will invest in making worker fetch reliable"
- "we will not promise reliable server-side fetch without a different runtime strategy"

## Workstream D: Close The Loop In The Client

### Goal

The app should guide the user through the real supported recovery path.

### Tasks

1. Keep the participants screen as the main recovery surface for blocked account states.
2. Refine copy so each state tells the user exactly what to do:
   - re-login
   - retry later
   - use another account
3. Prevent loops where the user:
   - logs in
   - lands on a blocked account
   - retries blindly
   - gets the same failure again
4. Add one focused UI verification for the post-onboarding blocked state.

### Acceptance Criteria

- the user is never left with "something went wrong"
- retry loops are intentional and bounded

## Workstream E: Finish The Operational Runbook

### Goal

The runtime path should be supportable without guessing.

### Tasks

1. Add a short runbook for diagnosing the active account flow in staging:
   - emulator/app state
   - API logs
   - worker logs
   - account record inspection
   - job result inspection
2. Document the exact log signatures for:
   - `invalid_credentials`
   - `login_required`
   - `instagram_challenge`
   - `worker_media_fetch_challenge`
3. Update release guidance so API and worker are always redeployed together when job signatures change.

### Acceptance Criteria

- a fresh chat or teammate can reproduce the diagnosis path from docs

## Recommended Execution Order

1. Use the new verification step to tighten account-state transitions.
2. Refine client recovery UX around verification/challenge states.
3. Block obviously wasted worker fetch attempts for accounts still known to be unusable.
4. Document the exact staging diagnosis flow.
5. Only then decide whether to invest in sticky proxy/network strategy.

## What Not To Do

- Do not start another large feature before this flow is settled.
- Do not add more fallback paths without clarifying which one is primary.
- Do not treat `from_sessionid` success as equivalent to a verified Instagram session.
- Do not rely on memory or chat history instead of updating docs.

## Concrete Next Step

The next implementation step should be:

- document and tighten the recovery path after `verify_session_challenge`

Why this is next:

- the verification boundary now exists and has been verified on the real app flow
- the next value comes from turning that blocked state into a stable user recovery path
- it gives the project a cleaner decision point before any proxy/network work
