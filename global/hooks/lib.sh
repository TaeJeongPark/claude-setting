# 훅 스크립트 공용 함수. source 해서 쓴다.

# 세션별 상태 디렉터리 (수정 파일 목록, 검증 재시도 횟수 등)
harness_state_root="${XDG_STATE_HOME:-$HOME/.local/state}/claude-harness"

harness_state_dir() {
  local sid="${1:-unknown}"
  local d="$harness_state_root/${sid//[^A-Za-z0-9_-]/_}"
  mkdir -p "$d"
  echo "$d"
}
