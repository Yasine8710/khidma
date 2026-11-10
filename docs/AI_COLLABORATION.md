# AI Collaboration
**Lead:** Claude Code (architecture, integration, decisions). **Partner:** OpenAI Codex CLI 0.167.0, invoked via `codex exec` (verified available 2026-11-10).

## Protocol
Claude plans → delegates to Codex (review or isolated-branch implementation) → Claude reviews/integrates → tests → docs. No two agents edit the same files; use branches/worktrees.

## Status
- Phase: 1 (design system). Slices 1.0 tokens, 1.1 l10n, 1.2 navigation merged to develop; next 1.3 components.
- Claude: repo, license, docs, Flutter bootstrap
- Codex: architecture review DONE (raw output: docs/reviews-codex-phase0.md)
- Accepted from Codex: manual Riverpod, lifecycle state machine, atomic accept, permission matrix, multi-role flags, outbox notifications, privacy split, early signed-iOS proof, Google Maps pending benchmark.
- Disagreements (Claude keeps): English stays (cheap via ARB, in the brief); favorites stay but are late-sequenced; reviews stay in scope but ship only after completion flow is trustworthy. Cut candidates (offline cache, chat attachments, presence) are deferred past MVP.
- Note: `codex exec` needs `< /dev/null` or it hangs waiting on stdin.

## Phase 1, slice 1.1 (l10n): Codex review, 2026-11-10
Codex (read-only, static) raised 8 P2 and 4 P3 findings; all accepted and fixed:
- NaN, infinity and huge amounts now throw; the sign is decided after rounding.
- Arabic negative amounts are bidi-isolated; phone parsing strips all bidi controls.
- Phone numbers and language names keep their own direction but align to the screen start (`AlignedText`).
- `setLocale` returns success and tolerates save failures; each language option has its own speech locale.
- Tests: exact Arabic plural forms, tap-target guidelines, 2x text scale on a 320 px screen.
Codex confirmed the six Arabic plural branches and found no date or icon defects. Claude ran the tests: 26 pass, analyze clean.

Gotchas:
- `codex exec` needs `< /dev/null`, and its output file holds the full transcript (read the tail).
- The Edit tool can rewrite unicode escapes into invisible literal characters; `flutter analyze` flags them as `text_direction_code_point_in_literal`.
- GitHub Actions is blocked by an account billing lock (see below), so CI has not run yet.

## Phase 1, slice 1.2 (navigation): Codex review, 2026-11-10
Codex (read-only, static) confirmed the router instance is stable and disposed, indexed stacks and `goBranch` reset work, RTL mirroring is right. Findings accepted and fixed:
- `/` had no route (also `/?utm_source=...` on web): now redirects to `/home`, keeping the query.
- Bottom nav hid hover/focus ink behind an opaque box and dropped focus semantics: now `Material` surface with the border outside; tabs expose tap and focus actions.
- Saffron leaked through unset Material roles (segmented button, tertiary, secondaryFixed): defined explicitly in both themes.
- Nav labels clamp to 1.3x text scale (page text still scales).
Visual check: web build rendered on a 390 px viewport in French light and Arabic dark; layout mirrored, no saffron leaks. The old saffron segmented button was caught this way, not by tests.
Not done (deferred, stated): browser Back/Forward history tests and nested-detail restoration tests, because no detail routes exist yet; keyboard-focus ring visual check.
Test-env caveat: flutter test text widths are not representative of real fonts, so a truncation test at 2x was dropped.
Tests: 42 pass, analyze clean.
