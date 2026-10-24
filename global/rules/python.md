---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
---

# Python

- 환경·의존성 도구는 기존 파일로 판단한다(`uv.lock` → uv, `poetry.lock` → poetry). 새 프로젝트는 uv를 기본으로 쓴다.
- 의존성은 `pyproject.toml`과 도구 명령(`uv add`)으로 관리한다. 전역 `pip install`을 하지 않는다.
- 검증: `ruff check`, `ruff format --check`, 타입 체커(pyright 또는 mypy, 프로젝트 설정을 따름), `pytest`.
- 새로 쓰는 공개 함수와 메서드에는 타입 힌트를 단다. 최신 문법을 쓴다(`list[str]`, `X | None`).
- 경로는 `pathlib`, 로그는 `logging`을 쓴다. 라이브러리 코드에 `print`를 남기지 않는다.
- 뮤터블 기본 인자(`def f(x=[])`)를 쓰지 않는다. bare `except:`와 `except Exception: pass`도 쓰지 않는다.
- 데이터 구조는 프로젝트가 쓰는 것(dataclass, Pydantic 등)을 따른다. 외부 입력 검증에는 Pydantic을 우선한다.
- 테스트는 pytest 스타일(fixture, `parametrize`)로 쓴다.
