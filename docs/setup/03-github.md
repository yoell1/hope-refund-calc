# 03. GitHub 세팅 (Git 저장소 + 원격 연결)

> 이 문서는 **AI 코딩 에이전트가 읽고 그대로 실행**하기 위한 작업 지시서다.
> 사용자는 개발 입문자다. 각 단계에서 무엇을 했는지 쉬운 말로 짧게 설명해 준다.
> 선행 조건: `01-linter.md`, `02-testing.md` 완료 (`ruff check .`, `pytest` 통과 상태)

## 목표

> 우리 팀은 저장소 생성과 01~04 초기 세팅을 **형상 관리 담당(김동석)**이 한 번 하고, 팀원은 끝난 저장소를 `git clone`해서 쓴다.

이 프로젝트가 GitHub 저장소에 올라가 있고, 앞으로 **수정 → `git add` → `git commit` → `git push`** 루틴으로 작업을 저장할 수 있는 상태를 만든다.

## 배경 (사용자 설명용)

- **Git** = 내 컴퓨터 안의 기록 장치. 커밋은 "그 순간의 스냅샷 + 짧은 메모"(게임 세이브 포인트).
- **GitHub** = 그 기록을 올려두는 온라인 보관함. 백업·협업·포트폴리오가 된다.
- AI가 코드를 망가뜨려도, 커밋해 둔 지점으로 언제든 되돌아갈 수 있다. **바이브코딩의 안전벨트**다.

## 작업 순서

1. **사전 확인** (하나라도 실패하면 멈추고 사용자에게 설치/로그인 방법을 안내한다)

   ```bash
   git --version
   git config user.name
   git config user.email
   gh --version        # GitHub CLI (없어도 진행 가능 — 아래 5-B 참고)
   gh auth status      # gh가 있다면 로그인 여부
   ```

   - `user.name`/`user.email`이 비어 있으면 사용자에게 값을 물어보고 `git config --global`로 설정한다. **임의로 지어내지 않는다.**

2. **`.gitignore` 점검** — 아래 항목이 들어 있는지 확인하고 없으면 추가한다.

   ```
   .venv/
   __pycache__/
   .pytest_cache/
   .ruff_cache/
   .env*
   !.env.example
   .DS_Store
   ```

   - DB 주소·계정·비밀번호를 코드에 직접 쓰지 않았는지 확인한다. `.env`에서 읽어야 한다.

   - `.env` 계열 파일이 이미 Git에 추적되고 있다면 즉시 사용자에게 알린다. (`AGENTS.md` 규칙: `.env*` 파일 내용 출력·커밋 금지)

3. **로컬 저장소 확인**
   - `git status`로 이미 Git 저장소가 초기화되어 있는지 확인한다.
   - 초기화되어 있지 않다면 `git init -b main`을 실행한다.
   - 기본 브랜치 이름이 `main`인지 확인한다 (`git branch --show-current`).

4. **첫 커밋** (이미 커밋이 있다면 지금까지의 세팅을 새 커밋으로)

   ```bash
   git add .
   git commit -m "chore: 초기 세팅 (FastAPI, ruff, pytest)"
   ```

   - 커밋 메시지는 `종류: 무엇을 했는지` 형식으로 쓴다. 종류 예: `feat`(기능), `fix`(버그), `chore`(설정), `docs`(문서), `test`(테스트), `refactor`(구조 정리), `ci`(자동 검사).

5. **GitHub 저장소 만들고 연결**
   - 저장소 이름은 `hope-refund-calc`다. **공개(public)/비공개(private)** 여부는 사용자에게 묻는다.
     (GitHub Actions는 public 저장소에서 무료. private도 월 무료 사용량이 있다.)
   - **A. `gh`가 설치·로그인된 경우**

     ```bash
     gh repo create <저장소이름> --public --source=. --remote=origin
     ```

   - **B. `gh`가 없는 경우** — 사용자에게 다음을 안내하고 기다린다.
     1. https://github.com/new 에서 저장소 생성 (README, .gitignore 추가 **체크하지 않기**)
     2. 생성된 주소(`https://github.com/아이디/저장소이름.git`)를 알려달라고 요청
     3. 받은 주소로 `git remote add origin <주소>`

6. **푸시** — **반드시 사용자에게 "푸시해도 될까요?"라고 확인을 받은 뒤** 실행한다. (`AGENTS.md` 규칙: 사용자 확인 없이 `git push` 금지)

   ```bash
   git push -u origin main
   ```

## 완료 기준 (모두 확인 후 결과를 보여줄 것)

- [ ] `git remote -v`에 origin이 GitHub 주소로 연결됨
- [ ] `git status` → "working tree clean"
- [ ] `git log --oneline -3` 출력
- [ ] GitHub 저장소 주소를 사용자에게 알려줌 (브라우저에서 파일이 보이는지 확인 요청)
- [ ] `.env` 계열 파일이 커밋에 포함되지 않음

## 마지막 보고

저장소 주소와 함께, 사용자가 매일 쓸 **하루 루틴 3단계**를 정리해 준다. (04가 끝난 뒤에는 `feature/기능명` 브랜치에서 하고, 끝나면 develop으로 PR)

```bash
git add .
git commit -m "feat: 무엇을 했는지"
git push
```

> 팁: 바이브코딩 중에는 **AI에게 큰 작업을 시키기 전에 커밋**해 두면, 결과가 마음에 안 들 때 쉽게 되돌릴 수 있다.
