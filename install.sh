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

mkdir -p "$target_dir/rules"
link "$repo_dir/global/CLAUDE.md" "$target_dir/CLAUDE.md"
for rule in "$repo_dir"/global/rules/*.md; do
  link "$rule" "$target_dir/rules/$(basename "$rule")"
done
