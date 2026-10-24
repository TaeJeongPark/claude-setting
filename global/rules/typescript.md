---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/*.cts"
  - "**/*.js"
  - "**/*.jsx"
  - "**/package.json"
  - "**/tsconfig*.json"
---

# TypeScript / Node

- 패키지 매니저는 lockfile로 판단한다(`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock*` → bun, `package-lock.json` → npm). 섞어 쓰지 않는다.
- lockfile은 손으로 고치지 않는다. 패키지 매니저 명령으로 다시 만든다.
- 검증은 `package.json`의 스크립트를 쓴다(`typecheck`, `lint`, `test`). 없으면 `tsc --noEmit`을 돌린다.
- `strict` 모드를 전제로 쓴다. `any`, `as` 단언, `@ts-ignore`, non-null 단언(`!`)으로 타입 에러를 덮지 않는다. 어쩔 수 없으면 `@ts-expect-error`에 이유를 단다.
- 외부 입력(HTTP 요청, 환경 변수, JSON 파싱 결과)은 `unknown`으로 받아 스키마(zod, valibot 등 프로젝트가 쓰는 것)로 검증한 뒤 쓴다.
- 문자열 리터럴 유니온과 판별 유니온(discriminated union)을 `enum`보다 우선한다. 프로젝트가 이미 `enum`을 쓰면 그대로 따른다.
- Promise는 반드시 `await`하거나 명시적으로 처리한다. floating promise를 남기지 않는다.
- 모듈 시스템(ESM/CJS)과 import 스타일(확장자 포함 여부, 경로 alias)은 기존 파일을 따른다.
