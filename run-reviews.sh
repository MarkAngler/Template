#!/usr/bin/env bash
# Run the two BMad adversarial diff reviews through the pi harness, each pinned to
# its own model so neither reviewer shares the authoring session's blind spots.
# See ./SKILL.md for full usage and exit-code contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLIND_SKILL="bmad-review-adversarial-general"
EDGE_SKILL="bmad-review-edge-case-hunter"

BLIND_MODEL="${PI_BLIND_MODEL:-openai-codex/gpt-5.6-sol:xhigh}"
EDGE_MODEL="${PI_EDGE_MODEL:-kimi-coding/k3:high}"

usage() {
    cat <<'EOF'
Usage: bash run-reviews.sh <diff-file> [output-dir]

  diff-file    Diff to review. Must exist and be non-empty.
  output-dir   Optional. Defaults to the directory holding <diff-file>.

Writes blind-hunter.md and edge-case-hunter.md into the output directory.

Environment overrides:
  PI_BLIND_MODEL     model:thinking for the Blind Hunter review
  PI_EDGE_MODEL      model:thinking for the Edge Case Hunter review
  BMAD_SKILLS_ROOT   directory holding the two bmad-review-* skills
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage >&2
    exit 2
fi

DIFF_FILE="$1"
OUT_DIR_ARG="${2:-}"

if ! command -v pi >/dev/null 2>&1; then
    echo "error: pi is not on PATH; install it with 'npm install --global @earendil-works/pi-coding-agent'" >&2
    exit 1
fi

if [[ ! -f "$DIFF_FILE" ]]; then
    echo "error: diff file not found: ${DIFF_FILE}" >&2
    exit 1
fi

if [[ ! -s "$DIFF_FILE" ]]; then
    echo "error: diff file is empty: ${DIFF_FILE}; nothing to review" >&2
    exit 1
fi

DIFF_FILE_ABS="$(cd "$(dirname "$DIFF_FILE")" && pwd)/$(basename "$DIFF_FILE")"

# Resolve the directory holding the two bmad-review-* skills. When this skill is
# deployed they are its siblings; when it is run from the catalog they are not.
resolve_skills_root() {
    if [[ -n "${BMAD_SKILLS_ROOT:-}" ]]; then
        printf '%s' "$BMAD_SKILLS_ROOT"
        return
    fi
    local sibling="${SCRIPT_DIR}/.."
    if [[ -f "${sibling}/${BLIND_SKILL}/SKILL.md" ]]; then
        (cd "$sibling" && pwd)
        return
    fi
    local repo_root
    if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        if [[ -f "${repo_root}/.claude/skills/${BLIND_SKILL}/SKILL.md" ]]; then
            printf '%s' "${repo_root}/.claude/skills"
            return
        fi
    fi
}

SKILLS_ROOT="$(resolve_skills_root)"

if [[ -z "$SKILLS_ROOT" ]]; then
    echo "error: cannot locate the bmad-review-* skills; set BMAD_SKILLS_ROOT to the directory containing them" >&2
    exit 1
fi

for skill in "$BLIND_SKILL" "$EDGE_SKILL"; do
    if [[ ! -f "${SKILLS_ROOT}/${skill}/SKILL.md" ]]; then
        echo "error: skill not found: ${SKILLS_ROOT}/${skill}/SKILL.md" >&2
        exit 1
    fi
done

if [[ -n "$OUT_DIR_ARG" ]]; then
    OUT_DIR="$OUT_DIR_ARG"
else
    OUT_DIR="$(dirname "$DIFF_FILE_ABS")"
fi
mkdir -p "$OUT_DIR"
OUT_DIR_ABS="$(cd "$OUT_DIR" && pwd)"

BLIND_OUT="${OUT_DIR_ABS}/blind-hunter.md"
EDGE_OUT="${OUT_DIR_ABS}/edge-case-hunter.md"

# --- Reviews -----------------------------------------------------------------

# --no-skills plus an explicit --skill loads exactly one skill instead of every
# skill on the machine. --tools read,ls is a strict allowlist across built-in,
# extension, and custom tools: the reviewer can load its own references/ files
# but cannot write, run commands, spawn subagents, or reach the network.
run_review() {
    local model="$1" skill="$2" out="$3"
    pi -p \
        --no-session \
        --no-skills \
        --no-prompt-templates \
        --model "$model" \
        --tools read,ls \
        --skill "${SKILLS_ROOT}/${skill}" \
        "Invoke the \`${skill}\` skill. The content to review is the diff included in this message. Output only the findings report: no preamble, no summary, no severity labels." \
        <"$DIFF_FILE_ABS" >"$out"
}

echo "Blind Hunter      ${BLIND_MODEL}"
echo "Edge Case Hunter  ${EDGE_MODEL}"
echo "Reviewing         ${DIFF_FILE_ABS}"
echo ""

run_review "$BLIND_MODEL" "$BLIND_SKILL" "$BLIND_OUT" &
BLIND_PID=$!
run_review "$EDGE_MODEL" "$EDGE_SKILL" "$EDGE_OUT" &
EDGE_PID=$!

set +e
wait "$BLIND_PID"
BLIND_STATUS=$?
wait "$EDGE_PID"
EDGE_STATUS=$?
set -e

FAILURES=()

record_outcome() {
    local label="$1" model="$2" out="$3" status="$4"
    if (( status != 0 )); then
        FAILURES+=("${label} [${model}]: pi exited ${status}")
    elif [[ ! -s "$out" ]]; then
        FAILURES+=("${label} [${model}]: empty report at ${out}")
    fi
}

record_outcome "Blind Hunter" "$BLIND_MODEL" "$BLIND_OUT" "$BLIND_STATUS"
record_outcome "Edge Case Hunter" "$EDGE_MODEL" "$EDGE_OUT" "$EDGE_STATUS"

if (( ${#FAILURES[@]} > 0 )); then
    echo "" >&2
    echo "error: ${#FAILURES[@]} of 2 reviews failed:" >&2
    printf '  %s\n' "${FAILURES[@]}" >&2
    exit 1
fi

echo ""
echo "Reviews written to:"
echo "  $BLIND_OUT"
echo "  $EDGE_OUT"
