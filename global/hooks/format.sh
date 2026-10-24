#!/usr/bin/env bash
# PostToolUse(Write|Edit): 수정된 파일을 프로젝트가 쓰는 포매터로 정리한다.
# 프로젝트에 설치된 도구만 쓴다(npx 다운로드 없음). 포매터가 없으면 아무것도 하지 않는다.
# 포매팅 실패는 작업을 막지 않는다. 항상 exit 0.

f="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')"
[ -n "$f" ] && [ -f "$f" ] || exit 0

dir="$(cd "$(dirname "$f")" && pwd)"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")"

# 파일에서 위로 올라가며 이름이 일치하는 파일·디렉터리를 찾는다(저장소 루트까지).
find_up() {
  local d="$dir" name
  while :; do
    for name in "$@"; do
      [ -e "$d/$name" ] && { echo "$d"; return 0; }
    done
    [ "$d" = "$root" ] || [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}

case "$f" in
  *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.cjs|*.json|*.jsonc|*.css|*.scss|*.html|*.vue|*.md|*.yml|*.yaml)
    pkg="$(find_up node_modules)" || exit 0
    bin="$pkg/node_modules/.bin"
    if [ -x "$bin/biome" ] && find_up biome.json biome.jsonc >/dev/null; then
      (cd "$pkg" && "$bin/biome" format --write "$f") >/dev/null 2>&1
    elif [ -x "$bin/prettier" ]; then
      (cd "$pkg" && "$bin/prettier" --write --ignore-unknown "$f") >/dev/null 2>&1
    fi
    ;;
  *.py|*.pyi)
    if [ -x "$root/.venv/bin/ruff" ]; then
      "$root/.venv/bin/ruff" format --quiet "$f" >/dev/null 2>&1
    elif command -v ruff >/dev/null 2>&1; then
      (cd "$root" && ruff format --quiet "$f") >/dev/null 2>&1
    fi
    ;;
  *.java)
    # Spotless가 설정된 Gradle 프로젝트는 IDE 훅으로 이 파일만 포매팅한다.
    gdir="$(find_up gradlew)"
    if [ -n "$gdir" ] && grep -qs spotless "$gdir"/build.gradle* "$gdir"/*/build.gradle* 2>/dev/null; then
      (cd "$gdir" && ./gradlew -q spotlessApply -PspotlessIdeHook="$f") >/dev/null 2>&1
    elif command -v google-java-format >/dev/null 2>&1; then
      google-java-format --replace "$f" >/dev/null 2>&1
    fi
    ;;
esac
exit 0
