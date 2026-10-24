---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# React

- 함수 컴포넌트와 훅만 쓴다.
- 서버 상태(API 데이터)는 프로젝트가 쓰는 데이터 패칭 라이브러리(TanStack Query, SWR, RSC 등)로 다룬다. `useEffect` + `useState`로 직접 패칭하는 코드를 새로 만들지 않는다.
- `useEffect`는 외부 시스템과 동기화할 때만 쓴다. props나 state에서 계산할 수 있는 값은 렌더링 중에 계산한다.
- `useMemo`/`useCallback`/`memo`는 측정된 성능 문제가 있거나 프로젝트가 React Compiler를 쓰지 않을 때만 필요한 곳에 쓴다.
- 리스트의 `key`에는 안정적인 ID를 쓴다. 배열 인덱스는 순서가 바뀌지 않는 정적 리스트에만 쓴다.
- 접근성: 클릭 가능한 요소는 `button`/`a`를 쓰고, 이미지에는 `alt`, 폼 입력에는 label을 붙인다.
- 스타일링 방식(Tailwind, CSS Modules, styled-components 등)은 기존 컴포넌트를 따른다.
- UI 변경은 가능하면 실제로 띄워서(개발 서버, 스토리북, 브라우저 자동화) 확인한다. 확인하지 못했으면 그렇다고 보고한다.
