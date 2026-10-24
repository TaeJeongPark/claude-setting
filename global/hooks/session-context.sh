#!/usr/bin/env bash
# SessionStart: 세션 시작·재개·압축 직후에 작업 상태(브랜치, 변경, 최근 커밋, 루프 계획)를 컨텍스트에 넣는다.
# 컨텍스트가 압축돼도 장기 작업을 이어갈 수 있게 하는 것이 목적이다.
source "$(dirname "$0")/lib.sh"

input="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[ -n "$cwd" ] || cwd="$PWD"

# 7일 넘은 세션 상태는 정리한다.
find "$harness_state_root" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
root="$(git -C "$cwd" rev-parse --show-toplevel)"

ctx=""
add() { ctx+="$1"$'\n'; }

branch="$(git -C "$root" branch --show-current 2>/dev/null)"
default="$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
default="${default#origin/}"
add "## 작업 상태 (SessionStart 훅)"
add "- 브랜치: ${branch:-(detached)}${default:+ / 기본 브랜치: $default}"
[ -n "$branch" ] && [ "$branch" = "$default" ] && add "- 주의: 기본 브랜치에 있다. 코드를 바꾸기 전에 작업 브랜치를 만든다."

changes="$(git -C "$root" status --short 2>/dev/null)"
if [ -n "$changes" ]; then
  add "- 커밋되지 않은 변경 $(wc -l <<<"$changes" | tr -d ' ')개 (사용자 작업일 수 있으니 덮어쓰지 않는다):"
  add "$(head -n 15 <<<"$changes" | sed 's/^/    /')"
fi
add "- 최근 커밋:"
add "$(git -C "$root" log --oneline -5 2>/dev/null | sed 's/^/    /')"

for plan in "$root/PLAN.md" "$root/.claude/loop/PLAN.md"; do
  [ -f "$plan" ] || continue
  todo="$(grep -cE '^\s*- \[ \]' "$plan")"
  done_="$(grep -cE '^\s*- \[[xX]\]' "$plan")"
  add "- 루프 계획 ${plan#"$root"/}: 완료 $done_ / 남음 $todo"
  add "$(grep -E '^\s*- \[ \]' "$plan" | head -n 3 | sed 's/^/    /')"
done
for progress in "$root/PROGRESS.md" "$root/.claude/loop/PROGRESS.md"; do
  [ -f "$progress" ] || continue
  add "- 최근 진행 기록 (${progress#"$root"/}):"
  add "$(tail -n 12 "$progress" | sed 's/^/    /')"
done

jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
