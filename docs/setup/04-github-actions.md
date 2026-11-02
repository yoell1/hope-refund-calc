# 04. GitHub Actions 세팅 (CI 자동 검사)

> 이 문서는 **AI 코딩 에이전트가 읽고 그대로 실행**하기 위한 작업 지시서다.
> 사용자는 개발 입문자다. 각 단계에서 무엇을 했는지 쉬운 말로 짧게 설명해 준다.
> 선행 조건: `01`~`03` 완료 (`ruff check .`·`pytest` 통과, GitHub에 push 된 상태)

## 목표

GitHub에 push하거나 Pull Request를 올릴 때마다 **GitHub이 자동으로 검사를 실행**하고, 결과를 ✓/✗로 보여주는 상태를 만든다. main과 develop 둘 다 대상이다.

## 배경 (사용자 설명용)

- **CI(지속적 통합)** = 코드를 올릴 때마다 **같은 조건**에서 자동으로 검사하는 시스템.
- "내 컴퓨터에선 되는데?" 문제와 "검사를 깜빡하는 일"이 사라진다.
- 우리 팀은 feature → develop으로 PR을 올리므로, PR 화면에서 ✓가 떠야 머지한다.

## 작업 순서

1. **로컬에서 먼저 통과시키기** — `AGENTS.md`의 작업 완료 조건과 같은 명령이 성공해야 다음 단계로 간다.

   ```bash
   ruff check . && pytest
   ```

2. **워크플로 파일 생성** — `.github/workflows/ci.yml`을 만든다. 버전은 팀 기준(Python 3.11)이다.

   ```yaml
   name: CI

   on:
     push:
       branches: [main, develop]
     pull_request:
       branches: [main, develop]

   jobs:
     lint-test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4          # 1. 코드 받아오기
         - uses: actions/setup-python@v5      # 2. Python 설정
           with:
             python-version: "3.11"           #    팀 기준 Python 버전
             cache: pip                       #    pip 캐시로 속도 향상
         - run: pip install -r requirements-dev.txt   # 3. 의존성 설치
         - run: ruff check .                  # 4. 린트 검사
         - run: pytest                        # 5. 테스트
   ```

3. **커밋 & 푸시** — 사용자에게 확인을 받은 뒤 실행한다. (`AGENTS.md` 규칙: 사용자 확인 없이 `git push` 금지)

   ```bash
   git add .github/workflows/ci.yml
   git commit -m "ci: GitHub Actions 자동 검사"
   git push
   ```

4. **실행 결과 확인**
   - `gh`가 있으면: `gh run list --limit 1` → `gh run watch`
   - 없으면: GitHub 저장소의 **Actions 탭**에서 초록 체크(✓)를 확인해 달라고 안내한다.
   - 실패(✗)하면 실패한 스텝의 로그를 읽고 원인을 고친 뒤 다시 push한다.


5. **develop 브랜치 만들기** (팀 규칙: 앞으로 기능 브랜치는 develop으로 PR) — 사용자 확인 후 실행한다.

   ```bash
   git switch -c develop
   git push -u origin develop
   ```

   - 초기 세팅(01~04)은 여기까지 `main`에서 했다. 이후 기능 작업은 `git switch develop` → `git switch -c feature/기능명`으로 시작하고, 끝나면 develop으로 PR을 올린다.

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `ModuleNotFoundError` | `requirements*.txt`에 빠진 패키지 | 로컬에서 쓰는 패키지를 `requirements.txt`에 추가 후 커밋 |
| `ModuleNotFoundError: app` | 테스트가 `app`을 못 찾음 | `pyproject.toml`의 `pythonpath = ["."]` 확인 |
| 러너에서만 테스트 실패 | 테스트가 DB에 접속함 | CI에는 DB가 없음 → 기준값은 테스트 안에 직접 넣어서 테스트 |
| 워크플로가 안 뜸 | 파일 위치/이름 오류 | `.github/workflows/ci.yml` 경로 확인 |

## 완료 기준 (모두 확인 후 결과를 보여줄 것)

- [ ] `.github/workflows/ci.yml` 존재, Python 3.11 · main·develop 푸시와 PR에서 실행
- [ ] GitHub Actions 최신 실행 결과가 **성공(✓)**
- [ ] 사용자에게 Actions 탭 주소 안내
- [ ] `git branch -a`에 main · develop이 둘 다 있음

## 마지막 보고

CI가 무엇을 언제 검사하는지 한 줄, 실행 결과, 앞으로 빨간 X가 뜨면 "로그 보고 고쳐줘"라고 AI에게 요청하면 된다는 안내를 3~5줄로 정리한다.
