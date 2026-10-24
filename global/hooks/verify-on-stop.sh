#!/usr/bin/env bash
# Stop: 이번 세션에서 코드를 수정했다면, 끝내기 전에 관련 검사(타입 체크·린트·테스트)를 돌린다.
# 실패하면 종료를 막고 실패 로그를 Claude에게 돌려줘 고치게 한다.
#
# - 수정 파일이 없으면 아무것도 하지 않는다.
# - 프로젝트에 .claude/harness/verify.sh 가 있으면 그것만 실행한다(인자: 수정 파일 목록).
# - 없으면 수정 파일의 종류로 Node / Python / Gradle / Maven 검사를 자동 감지한다.
# - 같은 세션에서 연속 MAX_BLOCKS 번 실패하면 무한 루프를 막기 위해 경고만 하고 종료를 허용한다.
# - CLAUDE_HARNESS_VERIFY=off 로 끌 수 있다.
source "$(dirname "$0")/lib.sh"

[ "${CLAUDE_HARNESS_VERIFY:-on}" = "off" ] && exit 0
MAX_BLOCKS="${CLAUDE_HARNESS_MAX_BLOCKS:-3}"

input="$(cat)"
sid="$(jq -r '.session_id // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[ -n "$cwd" ] || cwd="$PWD"
state="$(harness_state_dir "$sid")"
[ -s "$state/edited" ] || exit 0

root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")"

# 저장소 안에 있고 아직 존재하는 파일만 대상으로 한다.
files=()
while IFS= read -r f; do
  [ -f "$f" ] && case "$f" in "$root"/*) files+=("$f") ;; esac
done <"$state/edited"
if [ ${#files[@]} -eq 0 ]; then
  : >"$state/edited"
  exit 0
fi

log="$state/verify.log"
: >"$log"
failed=()

run() { # run <라벨> <디렉터리> <명령...>
  local label="$1" dir="$2"
  shift 2
  echo "▶ $label ($dir)" >>"$log"
  if ! (cd "$dir" && CI=true "$@") >>"$log" 2>&1; then
    failed+=("$label")
    echo "✖ $label 실패" >>"$log"
  fi
}

# 파일에서 위로 올라가며 이름이 일치하는 항목이 있는 디렉터리를 찾는다.
find_up() { # find_up <시작 디렉터리> <이름...>
  local d="$1" name
  shift
  while :; do
    for name in "$@"; do [ -e "$d/$name" ] && { echo "$d"; return 0; }; done
    [ "$d" = "$root" ] || [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}

if [ -x "$root/.claude/harness/verify.sh" ]; then
  run "project verify" "$root" "$root/.claude/harness/verify.sh" "${files[@]}"
else
  declare -A node_dirs py_dirs gradle_tasks mvn_dirs
  for f in "${files[@]}"; do
    d="$(dirname "$f")"
    case "$f" in
      *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.cjs|*.vue)
        p="$(find_up "$d" package.json)" && [ -d "$p/node_modules" ] && node_dirs["$p"]=1 ;;
      *.py|*.pyi)
        p="$(find_up "$d" pyproject.toml setup.cfg)" && py_dirs["$p"]=1 ;;
      *.java|*.kt|*.kts|*.gradle|*.xml|*.sql|*.yml|*.yaml|*.properties)
        if g="$(find_up "$d" gradlew)"; then
          # 가장 가까운 build.gradle 디렉터리를 모듈로 보고 :a:b:check 형태로 실행한다.
          m="$(find_up "$d" build.gradle build.gradle.kts)" || m="$g"
          case "$m" in "$g"/*) ;; *) m="$g" ;; esac
          rel="${m#"$g"}"
          gradle_tasks["$g"]+=" ${rel//\//:}${rel:+:}check"
        elif mv="$(find_up "$d" mvnw)"; then
          mvn_dirs["$mv"]=1
        fi ;;
    esac
  done

  for p in "${!node_dirs[@]}"; do
    if [ -f "$p/pnpm-lock.yaml" ] || [ -f "$(git -C "$p" rev-parse --show-toplevel 2>/dev/null)/pnpm-lock.yaml" ]; then pm=pnpm
    elif [ -f "$p/yarn.lock" ]; then pm=yarn
    elif ls "$p"/bun.lock* >/dev/null 2>&1; then pm=bun
    else pm=npm; fi
    scripts="$(jq -r '.scripts // {} | keys[]' "$p/package.json" 2>/dev/null)"
    for s in typecheck type-check lint test; do
      grep -qx "$s" <<<"$scripts" && run "$pm $s" "$p" "$pm" run "$s"
    done
    if ! grep -qxE 'typecheck|type-check' <<<"$scripts" && [ -f "$p/tsconfig.json" ] && [ -x "$p/node_modules/.bin/tsc" ]; then
      run "tsc" "$p" "$p/node_modules/.bin/tsc" --noEmit
    fi
  done

  for p in "${!py_dirs[@]}"; do
    if [ -f "$p/uv.lock" ] && command -v uv >/dev/null 2>&1; then rp=(uv run)
    elif [ -d "$p/.venv/bin" ]; then rp=(env "PATH=$p/.venv/bin:$PATH")
    else rp=(); fi
    (cd "$p" && "${rp[@]}" ruff --version) >/dev/null 2>&1 && run "ruff check" "$p" "${rp[@]}" ruff check .
    grep -qs '^\[tool\.mypy\]' "$p/pyproject.toml" && run "mypy" "$p" "${rp[@]}" mypy .
    grep -qs '^\[tool\.pyright\]' "$p/pyproject.toml" && run "pyright" "$p" "${rp[@]}" pyright
    if [ -d "$p/tests" ] || grep -qs '^\[tool\.pytest' "$p/pyproject.toml"; then
      run "pytest" "$p" "${rp[@]}" python -m pytest -q -x
    fi
  done

  for g in "${!gradle_tasks[@]}"; do
    # shellcheck disable=SC2086
    run "gradle check" "$g" ./gradlew -q $(tr ' ' '\n' <<<"${gradle_tasks[$g]}" | sort -u)
  done
  for mv in "${!mvn_dirs[@]}"; do
    run "maven test" "$mv" ./mvnw -q test
  done
fi

if [ ${#failed[@]} -eq 0 ]; then
  : >"$state/edited"
  rm -f "$state/blocks"
  exit 0
fi

blocks=$(( $(cat "$state/blocks" 2>/dev/null || echo 0) + 1 ))
echo "$blocks" >"$state/blocks"

if [ "$blocks" -gt "$MAX_BLOCKS" ]; then
  rm -f "$state/blocks"
  jq -n --arg m "검증이 ${MAX_BLOCKS}번 연속 실패해 종료를 허용합니다: ${failed[*]} (로그: $log)" \
    '{systemMessage: $m}'
  exit 0
fi

reason="$(printf '종료 전 검증 실패 (%s/%s): %s\n수정한 파일과 관련된 실패라면 원인을 고치고 다시 끝내세요. 이번 변경과 무관한 기존 실패라면 그 근거를 사용자에게 보고하세요. 테스트를 건너뛰거나 기대값을 결과에 맞추지 마세요.\n\n--- 로그 마지막 80줄 (%s) ---\n%s' \
  "$blocks" "$MAX_BLOCKS" "${failed[*]}" "$log" "$(tail -n 80 "$log")")"
jq -n --arg r "$reason" '{decision: "block", reason: $r}'
exit 0
