# /init

Project: `giveaway_app`

Read first:

- [PROJECT_SUMMARY_FOR_CHAT.md](C:/dev/giveaway_app/PROJECT_SUMMARY_FOR_CHAT.md)

Quick orientation:

- current branch: `codex/account-affinity-architecture`
- app is Flutter + Flask + Redis/RQ
- strategic direction is `account-affinity`, not deeper Railway login debugging

Current reality in one paragraph:

- onboarding from raw `sessionid` now creates an internal account record successfully
- account-scoped jobs enqueue and execute
- the remaining hard blocker is Instagram challenge behavior during server-side media/comment fetch in the worker

If starting from another window:

- use `PROJECT_SUMMARY_FOR_CHAT.md` as the main context document
- use the rest of `project_init/` only as short navigation pointers
