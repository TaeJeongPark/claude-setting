#!/usr/bin/env bash
# PostToolUse(Write|Edit|NotebookEdit): 이번 세션에서 수정한 파일을 기록한다.
# verify-on-stop.sh 가 이 목록으로 검증 범위를 정한다.
source "$(dirname "$0")/lib.sh"

input="$(cat)"
f="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_response.filePath // empty' <<<"$input")"
[ -n "$f" ] || exit 0
sid="$(jq -r '.session_id // empty' <<<"$input")"

state="$(harness_state_dir "$sid")"
grep -qxF -- "$f" "$state/edited" 2>/dev/null || echo "$f" >>"$state/edited"
exit 0
