# AI Collaboration
**Lead:** Claude Code (architecture, integration, decisions). **Partner:** OpenAI Codex CLI 0.167.0, invoked via `codex exec` (verified available 2026-11-10).

## Protocol
Claude plans → delegates to Codex (review or isolated-branch implementation) → Claude reviews/integrates → tests → docs. No two agents edit the same files; use branches/worktrees.

## Status
- Phase: 0 (initialization)
- Claude: repo, license, docs, Flutter bootstrap
- Codex: architecture review DONE (raw output: docs/reviews-codex-phase0.md)
- Accepted from Codex: manual Riverpod, lifecycle state machine, atomic accept, permission matrix, multi-role flags, outbox notifications, privacy split, early signed-iOS proof, Google Maps pending benchmark.
- Disagreements (Claude keeps): English stays (cheap via ARB, in the brief); favorites stay but are late-sequenced; reviews stay in scope but ship only after completion flow is trustworthy. Cut candidates (offline cache, chat attachments, presence) are deferred past MVP.
- Note: `codex exec` needs `< /dev/null` or it hangs waiting on stdin.
