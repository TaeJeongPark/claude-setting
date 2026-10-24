#!/usr/bin/env bash
# PreToolUse(Bash): 위험한 셸 명령을 막거나 사용자 확인을 강제한다.
# - deny: 되돌릴 수 없고 정당한 용도가 거의 없는 명령
# - ask : 정당한 용도가 있지만 사람이 확인해야 하는 명령
# 정규식 기반의 안전망일 뿐 완전한 방어가 아니다. 셸 우회까지 막지는 못한다.

cmd="$(jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

decide() {
  jq -n --arg d "$1" --arg r "$2" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $d,
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

has() { grep -Eiq -- "$1" <<<"$cmd"; }

# rm 에 재귀(-r/-R/--recursive)와 강제(-f/--force) 옵션이 함께 있는가
rm_rf='(^|[;&|`(]|\$\()[[:space:]]*(sudo[[:space:]]+)?rm[[:space:]]+([^;&|]*[[:space:]])?(-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR]|(-[rR]|--recursive)[[:space:]]+([^;&|]*[[:space:]])?(-f|--force)|(-f|--force)[[:space:]]+([^;&|]*[[:space:]])?(-[rR]|--recursive))'
# 루트, 홈, 현재/상위 디렉터리, 와일드카드 전체 같은 치명적인 대상
rm_danger='[[:space:]](/|/\*|~|~/|~/\*|\$HOME|\$HOME/|\$HOME/\*|"\$HOME"|\.|\./|\.\.|\.\./|\*)([[:space:]]|$|;|&|\|)'

# ---- deny ----
if has "$rm_rf" && has "$rm_danger"; then
  decide deny "루트·홈·현재 디렉터리 전체를 지우는 rm -rf는 차단됩니다. 지울 경로를 구체적으로 지정하세요."
fi
has '(^|[[:space:]])(mkfs(\.[a-z0-9]+)?|dd[[:space:]]+[^;&|]*of=/dev/(sd|nvme|disk|hd))' \
  && decide deny "디스크를 포맷하거나 덮어쓰는 명령은 차단됩니다."
has ':\(\)[[:space:]]*\{[[:space:]]*:\|:&[[:space:]]*\};:' && decide deny "fork bomb은 차단됩니다."
has '(curl|wget)[^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh([[:space:]]|$)' \
  && decide deny "원격 스크립트를 바로 셸로 실행하는 것은 차단됩니다. 내려받아 내용을 확인한 뒤 실행하세요."

# ---- ask ----
has 'git[[:space:]]+push([^;&|]*[[:space:]])(-f|--force|--force-with-lease|--mirror|--delete|-d)([[:space:]=]|$)|git[[:space:]]+push[^;&|]*[[:space:]]\+[^[:space:]]+' \
  && decide ask "원격 히스토리를 덮어쓰거나 지우는 push입니다. 실행해도 되는지 확인해 주세요."
has 'git[[:space:]]+(reset[[:space:]]+[^;&|]*--hard|clean[[:space:]]+[^;&|]*-[a-zA-Z]*f|checkout[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)|restore[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)|branch[[:space:]]+[^;&|]*-D|stash[[:space:]]+(drop|clear))' \
  && decide ask "커밋되지 않은 변경이나 브랜치를 버릴 수 있는 git 명령입니다. 확인해 주세요."
has '(^|[^a-z_])(drop[[:space:]]+(table|schema|database|index|view|materialized)|truncate([[:space:]]+table)?[[:space:]]+[a-z_"]|alter[[:space:]]+table[^;]*drop[[:space:]]+column)' \
  && decide ask "DROP/TRUNCATE 등 데이터를 지우는 SQL이 포함돼 있습니다. 대상 DB와 범위를 확인해 주세요."
has '(^|[^a-z_])delete[[:space:]]+from[[:space:]]+[a-z_."]+[[:space:]]*(;|"|'"'"'|$)' \
  && decide ask "WHERE 조건 없는 DELETE입니다. 확인해 주세요."
has '(flyway[^;&|]*[[:space:]](migrate|clean|repair)|liquibase[^;&|]*[[:space:]](update|drop-all|dropAll)|alembic[[:space:]]+(upgrade|downgrade)|prisma[[:space:]]+(migrate[[:space:]]+(deploy|reset)|db[[:space:]]+push)|gradlew?[^;&|]*[[:space:]]flyway(Migrate|Clean))' \
  && decide ask "DB 마이그레이션을 실제로 적용하는 명령입니다. 대상 DB를 확인해 주세요."
has '(^|[[:space:]/])(cat|less|more|head|tail|bat|grep|source|\.)[[:space:]]+([^;&|]*[[:space:]/])?\.env(\.[a-z]+)?([[:space:]]|$)' \
  && ! has '\.env\.(example|sample|template|dist)' \
  && decide ask ".env 파일 내용을 읽으려는 명령입니다. 비밀값이 노출될 수 있으니 확인해 주세요."

exit 0
