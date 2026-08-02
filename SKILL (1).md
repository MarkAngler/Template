---
name: pi-adversarial-review
description: Run the two BMad adversarial diff reviews (Blind Hunter and Edge Case Hunter) through the pi CLI on models independent of the current session — GPT-5.6 Sol and Kimi K3 — and write both findings reports to disk. Use when a diff needs adversarial review from something other than the authoring model, and at step 4 of the bmad-quick-dev workflow. Trigger on phrases like "adversarial review this diff", "review this on a different model", "run the pi review", "blind hunter and edge case hunter", or "second opinion from another vendor".
---

# Pi Adversarial Review

## Overview

Runs `bmad-review-adversarial-general` (Blind Hunter) and
`bmad-review-edge-case-hunter` (Edge Case Hunter) against one diff, each in its
own `pi` process on its own model, concurrently. Both findings reports land on
disk for the calling session to classify.

The point is reviewer independence. When the workflow that wrote the code also
reviews it, the reviewer inherits the author's blind spots. Here the diff is
reviewed by GPT-5.6 Sol and Kimi K3 regardless of which model wrote it.

This skill produces **raw findings only**. Deduplication, severity, and triage
belong to the caller — both review skills deliberately emit unranked findings.

## Prerequisites

- `pi` on `PATH` (`npm install --global @earendil-works/pi-coding-agent`).
- `pi` authenticated for the `openai-codex` and `kimi-coding` providers. Check
  with `pi --list-models`; a provider with no credentials shows no models.
- The two `bmad-review-*` skills reachable on disk (see **Skill resolution**).

## Usage

```bash
bash pi-adversarial-review/run-reviews.sh <diff-file> [output-dir]
```

- `diff-file` — the diff to review. Must exist and be non-empty.
- `output-dir` (optional) — defaults to the directory holding `diff-file`.

**Example** — review everything since the last commit:

```bash
git diff HEAD~1 > /tmp/review.diff
bash pi-adversarial-review/run-reviews.sh /tmp/review.diff ./review-output
```

Both reviews start together and the script waits for both, so wall-clock time is
the slower of the two, not their sum.

## Output

| File | Produced by | Format |
|---|---|---|
| `blind-hunter.md` | `bmad-review-adversarial-general` on Sol | Markdown list of findings, descriptions only — no severity, priority, or ranking |
| `edge-case-hunter.md` | `bmad-review-edge-case-hunter` on K3 | Unhandled paths and boundaries only; handled ones are discarded silently |

## Model routing

| Reviewer | Default route | Why this model |
|---|---|---|
| Blind Hunter | `openai-codex/gpt-5.6-sol:xhigh` | Judgment-heavy work — skepticism, "what is missing", at least ten findings. Sol is the premium reasoning route. |
| Edge Case Hunter | `kimi-coding/k3:high` | Mechanical exhaustive path enumeration. K3's 1M-token context absorbs large diffs without truncation. |

Both defaults use each model's **second-highest** thinking level. Those are
different rungs because the two models expose different ladders. pi's full
ladder is `off, minimal, low, medium, high, xhigh, max`, but every model
declares which rungs it actually supports:

| Model | Supported levels | Highest | Second highest |
|---|---|---|---|
| `openai-codex/gpt-5.6-sol` | off, minimal, low, medium, high, xhigh, max | `max` | `xhigh` |
| `kimi-coding/k3` | low, high, max | `max` | `high` |

K3 has no `xhigh` rung — pi clamps unsupported levels away silently, so `high`
is the correct literal value rather than an approximation of one. Confirm the
current ladder for any model with `pi --list-models` and the `thinkingLevelMap`
entries in `~/.pi/agent/models-store.json`.

Override either route without editing this skill:

```bash
PI_BLIND_MODEL=kimi-coding/k3:max \
PI_EDGE_MODEL=openai-codex/gpt-5.6-sol:xhigh \
  bash pi-adversarial-review/run-reviews.sh /tmp/review.diff
```

## Skill resolution

The script needs the two `bmad-review-*` skill directories. It resolves them in
this order:

1. `BMAD_SKILLS_ROOT`, if set.
2. The script's own parent directory — correct once this skill is deployed,
   because the `bmad-review-*` skills are then its siblings.
3. `<git repo root>/.claude/skills` — correct when running from the catalog
   source tree, where the siblings do not exist.

If none resolve, the script exits 1 and names `BMAD_SKILLS_ROOT`.

## Exit codes

Parent skills and automation should rely on these:

| Code | Meaning |
|---|---|
| `0` | Both reviews succeeded and wrote non-empty reports. |
| `1` | Error. Possible causes: `pi` not on `PATH`; missing or empty diff file; unresolvable skills root; either review exited non-zero or wrote an empty report. |
| `2` | Usage error (wrong number of arguments). |

A partial failure is exit 1, and stderr names which reviewer failed and on which
model. The report that did succeed is still written — read it rather than
discarding the run.

## Use from bmad-quick-dev step 4

`bmad-quick-dev` step 4 (`step-04-review.md`) launches Blind Hunter and Edge
Case Hunter as subagents of the current session. To route them here instead:

1. Construct the diff from `{baseline_commit}` as step 4 describes and write it
   to a file under `{implementation_artifacts}`. Do not `git add` anything.
2. Run `run-reviews.sh <diff-file> {implementation_artifacts}`.
3. Read `blind-hunter.md` and `edge-case-hunter.md`.
4. Continue at step 4's **Classify** section with those findings.

This supersedes step 4's rule that "All review subagents must run at the same
model capability as the current session." That rule exists to stop reviews from
being downgraded to a weaker model; pinning Sol and K3 at their second-highest
thinking levels raises reviewer independence without lowering capability.

Step 4 already anticipates this path — its fallback branch tells the human to
run each review "in a separate session (ideally a different LLM)" and paste the
findings back. This skill automates that branch.

## Notes and edge cases

- **Reviewers cannot modify anything.** Each `pi` process runs with
  `--tools read,ls`, a strict allowlist spanning built-in, extension, and custom
  tools. No writes, no shell, no subagent fan-out, no network.
- **No session files.** `--no-session` keeps review runs ephemeral. Nothing to
  clean up, and no session pollutes `--continue`.
- **Only one skill is loaded per reviewer.** `--no-skills` plus an explicit
  `--skill` keeps every unrelated skill description out of the child's system
  prompt, which matters when a machine has dozens installed.
- **Project rules still apply.** Extensions stay enabled, so the `pi-rules`
  extension keeps injecting the project's `.claude` rule files into the
  reviewer's `read` results.
- **The diff travels on stdin,** not in `argv`, so large diffs do not hit the
  argument-length limit.
- **Empty diff is an error** (exit 1), not a silent success, so a parent skill
  never proceeds as though a clean review had happened.
