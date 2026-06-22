/goal $ARGUMENTS

━━━ DEFINITION OF DONE — do not stop until every gate below passes ━━━

The goal above is complete ONLY when all gates are objectively true AND
demonstrated with real command output pasted in your final message.
Self-reported success without pasted evidence does not count. If a gate
fails, fix it and re-run; keep iterating until it passes or is provably
blocked.

GATE 1 — FULLY IMPLEMENTED
Real, working code end to end. No stubs, no placeholders, no TODO
comments, no "in a real implementation this would…" notes, no hardcoded
fake return values, no mocks standing in for actual logic. If you declare
a function, you implement its body.

GATE 2 — NO REGRESSIONS
Run the COMPLETE existing test suite, not only the tests you added. Every
test that passed before your change still passes. If a test was already
failing before you started, state that explicitly so it is not counted
against this goal. Paste the suite output.

GATE 3 — UNIT TESTS AT 100% COVERAGE
Write unit tests covering every new or changed line and branch. Run the
coverage tool and paste the report showing 100% for the code in scope.
Tests must assert real behavior and must fail if the logic is wrong — no
assert-true filler, no over-mocking that makes a test pass regardless of
the implementation. If a specific line is genuinely unreachable (e.g., a
defensive branch), name that exact line and the reason and exclude it
explicitly rather than silently dropping coverage.

GATE 4 — LIVE TEST
First, determine what this goal actually produces and what entry point a real
user would touch — e.g. a web page in a browser, an HTTP endpoint, a CLI
command, a rendered UI component, an imported library function, or a batch
script. Exercise ONLY the entry points this goal actually exposes. Do not
invent, assume, or test an interface the project does not have. If the goal
is a website with no command-line tool, do NOT run or fabricate a CLI — load
the page and drive the real user flow instead. If you are unsure which entry
point applies, that is a signal to inspect the project, not to guess.
Then run that entry point for real in an actual runtime — not the test
harness — with real inputs. Paste the exact command(s) or steps and the
actual output (server response, rendered page, command stdout, etc.) that
prove the feature works.

GATE 5 — VERIFY, DON'T CLAIM
Before asserting any gate is met, run the command that proves it and read
the output. If you did not run it, you do not know it. Never write "this
should work" — run it and show that it does.

GATE 6 — HONEST GAPS
If you cannot satisfy a gate, STOP and state exactly which gate, which line
or command, and why. Do not fake output, paper over the gap, or quietly
narrow the goal. A truthful "blocked at X because Y" is required over a
false "done."

End your final message with a checklist: each gate marked [PASS] with its
evidence, or [BLOCKED] with the reason.

━━━ END DEFINITION OF DONE ━━━
