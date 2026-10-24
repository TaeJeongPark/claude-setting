#!/usr/bin/env bash
# 전역 설정을 ~/.claude 에 심볼릭 링크로 설치한다.
# 기존 파일이 링크가 아니면 .bak.<타임스탬프> 로 백업한다.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
stamp="$(date +%Y%m%d%H%M%S)"

link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    mv "$dest" "$dest.bak.$stamp"
    echo "백업: $dest -> $dest.bak.$stamp"
  fi
  ln -s "$src" "$dest"
  echo "링크: $dest -> $src"
}

command -v jq >/dev/null 2>&1 || echo "경고: jq가 없으면 hooks가 동작하지 않습니다. jq를 설치하세요." >&2

mkdir -p "$target_dir/rules" "$target_dir/skills"
link "$repo_dir/global/CLAUDE.md" "$target_dir/CLAUDE.md"
link "$repo_dir/global/settings.json" "$target_dir/settings.json"
link "$repo_dir/global/hooks" "$target_dir/hooks"
for rule in "$repo_dir"/global/rules/*.md; do
  link "$rule" "$target_dir/rules/$(basename "$rule")"
done
for skill in "$repo_dir"/global/skills/*/; do
  skill="${skill%/}"
  link "$skill" "$target_dir/skills/$(basename "$skill")"
done

if ls "$target_dir"/settings.json.bak.* >/dev/null 2>&1; then
  echo "참고: 기존 settings.json이 백업돼 있습니다. 필요한 개인 설정은 global/settings.json에 옮기세요."
fi
