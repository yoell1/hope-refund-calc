# 01. Linter 세팅 (ruff)

> 이 문서는 **AI 코딩 에이전트가 읽고 그대로 실행**하기 위한 작업 지시서다.
> 사용자는 개발 입문자다. 각 단계에서 무엇을 했는지 쉬운 말로 짧게 설명해 준다.

## 목표

`ruff check .` 한 줄로 프로젝트 전체 코드를 검사할 수 있고, **현재 에러가 0개인 깨끗한 상태(baseline)**를 만든다.

## 배경 (사용자 설명용)

- ruff는 파이썬 코드를 **실행하지 않고 읽어서** 실수(안 쓰는 import·변수, 위험한 패턴)를 찾아 주는 도구다. 아주 빠르다.
- 린터는 "실행 전" 검사, 테스트는 "실행 중" 검사다. 둘은 역할이 다르다.

## 작업 순서

1. **환경 확인**
   - `python --version`이 **3.11.x**인지 확인한다.
   - 가상환경이 없으면 만든다: `python -m venv .venv` → 켜기(Windows cmd): `.venv\Scripts\activate` · PowerShell: `.venv\Scripts\Activate.ps1`
   - `requirements.txt`가 없으면 만든다 (`fastapi`, `uvicorn`, `oracledb`).

2. **설치** — 개발용 도구는 `requirements-dev.txt`에 따로 적는다.

   ```text
   -r requirements.txt
   ruff
   pytest
   ```

   ```bash
   pip install -r requirements-dev.txt
   ```

3. **설정 파일** — 프로젝트 루트에 `pyproject.toml`을 만들고 아래를 넣는다.

   ```toml
   [tool.ruff]
   target-version = "py311"
   line-length = 100
   extend-exclude = ["database"]   # DB 작업 파일(01~99번)은 서버 코드가 아니라 검사에서 뺀다

   [tool.ruff.lint]
   select = ["E", "F", "I", "B"]   # 기본 오류 · 안 쓰는 코드 · import 순서 · 흔한 버그
   ```

4. **에디터 연동 (권장)** — `.vscode/extensions.json`에 ruff 확장을 추천한다.

   ```json
   { "recommendations": ["charliermarsh.ruff"] }
   ```

5. **실행하고 baseline 만들기**
   - `ruff check .` 실행
   - 에러가 있으면 먼저 `ruff check . --fix`로 자동 수정하고, 남은 것은 코드를 직접 고친다.
   - **규칙을 빼거나 `# noqa` 주석으로 숨기지 않는다.** 꼭 필요하면 이유를 사용자에게 설명하고 허락을 받는다.

## 완료 기준 (모두 확인 후 결과를 보여줄 것)

- [ ] `ruff check .` 에러 0개
- [ ] `pyproject.toml` · `requirements-dev.txt` 존재
- [ ] 일부러 안 쓰는 import(`import os`)를 넣으면 `ruff check .`가 잡아내는지 확인한 뒤, 그 코드는 다시 지운다

## 마지막 보고

무엇을 설치/수정했는지, `ruff check .` 최종 출력, 기억할 명령어(`ruff check .`, `ruff check . --fix`)를 3~5줄로 정리한다.
