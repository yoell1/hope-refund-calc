# AGENTS.md

이 파일은 이 저장소에서 일하는 AI 코딩 에이전트(Claude Code, Codex, Cursor 등)를 위한 온보딩 문서다. 작업 전에 반드시 읽는다.

## 프로젝트 개요

희망환급: 청년 근로자가 소득·카드 내역을 넣으면 연말정산 예상 환급액을 계산하고, 절세 방법을 비교·안내받는 웹 서비스의 **계산 서버(Python · FastAPI)** 저장소다. 세액 계산 · 카드 공제 계산 · 청년 혜택 진단 · 카드사/홈택스 파일 정리 · 가맹점 기반 지출 분류를 맡는다.

- 함께 쓰는 저장소: `hope-refund-front`(React 화면) · `hope-refund-back`(Spring Boot API · DB 저장)
- 이 저장소는 **계산·정리만** 한다. back에서 요청을 받아 결과를 API 응답으로 돌려준다. DB는 기준값·목록을 읽기만 하고, 결과 저장은 back이 한다.
- 시뮬레이션 · 관리자 미리보기도 같은 계산 API를 쓴다.
- 범위 밖: 세액 계산에 LLM 사용(계산은 정해진 규칙으로만) · DB에 쓰기

## 명령어

Python 3.11. 가상환경(`.venv`)을 쓴다.

```bash
python -m venv .venv                         # 가상환경 만들기 (처음 한 번)
.venv\Scripts\activate                       # 가상환경 켜기 (Windows cmd · PowerShell은 .venv\Scripts\Activate.ps1)
pip install -r requirements-dev.txt          # 개발용 설치 (서버 의존성 + ruff · pytest)
uvicorn app.main:app --reload --port 8000    # 서버 실행
ruff check .                                 # 린트 검사
ruff check . --fix                           # 린트 자동 수정
pytest                                       # 테스트
```

## 기술 스택

Python 3.11.9 · FastAPI · oracledb · Oracle 21c XE(교육원 공용 DB 21.3) · ruff(린트) · pytest(테스트)

## 폴더 구조

```text
app/
├── main.py         # FastAPI 시작
├── api/            # /calculate · /benefit · /card
├── schemas/        # 요청·응답 모양 (노션 「동석님 전달」 이름 그대로)
├── db/             # Oracle 연결
├── repositories/   # 읽기 전용 (DEDUCTION_TYPE · TAX_BRACKET · BENEFIT_CONDITION · MERCHANT_LIST · SPEND_CATEGORY)
├── services/       # 세액 계산: bracket.py · tax_calculator.py · card_deduction.py · benefit.py
└── card/           # 카드 파일 정리 · 지출 분류: parser.py · classifier.py
database/           # DB 작업 파일 01~99번 · README · cp949/ (DB 담당만 수정 · 서버 코드 아님)
tests/
```

## 규칙

- 계산 로직(`services/` · `card/`)과 API 처리(`api/`)를 분리한다.
- 기존 계산식·분류 로직이 있으면 먼저 확인한다. 확인 없이 새 계산 방식을 도입하지 않는다.
- 세율·공제율·한도·구간 경계 같은 세법 숫자를 코드에 쓰지 않는다. DB 기준값에서 읽는다.
- 기준값은 번호(`TYPE_ID`)가 아니라 `TAX_YEAR` + `TYPE_CODE`(+ 총급여 구간)로 찾는다.
- 계산 연도와 기준값 연도는 같아야 한다 (1~3월은 작년 귀속).
- 구간 계산식은 `services/bracket.py` 하나만 쓴다: 결과 = 기본 금액 + (금액 − 구간 시작) × 비율 ÷ 100
- 금액은 원 단위 정수로 다룬다.
- 응답 이름은 노션 「동석님 전달」 기준(`taxableIncome` · `calculatedTax` · `decidedTax` · `expectedRefund` · `details` 등)을 그대로 쓴다.
- 새 함수를 만들면 `tests/test_*.py`에 테스트를 함께 작성한다. 테스트 하나 = 확인 하나.
- 가게 이름 정제 규칙은 DB 목록과 같게 유지한다. 카드 가맹점명을 정제한 뒤 `MERCHANT_LIST.NORMALIZED_NAME`과 비교한다 (규칙: 노션 「고은님 전달」). DB 공공 목록(8만 행)이 이 규칙으로 정제돼 있어서, 규칙이 다르면 분류가 틀어진다. 바꿔야 하면 DB 담당과 같이 바꾼다.
- 카드 금액은 취소 건이면 음수로 넘긴다. 결제수단은 신용 = CREDIT · 체크 = CHECK · 현금영수증 = CASH.
- `database/`는 DB 담당(이우진)만 수정한다. 서버 코드에서 import하지 않는다. `07_카드분류.py`는 `08_목록_파이프라인.py`가 불러 쓰므로 옮기거나 지우지 않는다.
- 담당: 세액 계산(`services/`) 이우진 · 카드 파일 정리·분류(`card/`) 이고은 · DB 작업 파일(`database/`) 이우진
- 코드 모양: 들여쓰기 4칸 · 변수·함수명 snake_case · 문자열은 큰따옴표 `"` · 주석은 한글

## 팀 공통 규칙 (희망연봉2조 · 세 저장소 동일)

### 저장소 구성

| 저장소 | 역할 | 스택 |
| --- | --- | --- |
| `hope-refund-front` | React 화면 | Node 22+, Vite + React (JSX), ESLint, Vitest |
| `hope-refund-back` | Spring Boot API, DB 저장, 회원, 관리자 | Java 17, Spring Boot 4.1.0, Maven, MyBatis, Oracle |
| `hope-refund-calc` | 세액 계산, 카드 파일 정리·분류 | Python 3.11, FastAPI, oracledb |

- 하나의 기능은 세 저장소에 걸칠 수 있다.
- 통신 흐름: front → back → Oracle DB. 계산이 필요하면 front → back → calc → back → Oracle DB.
- front는 calc나 DB를 직접 부르지 않는다. back의 `prediction/`이 calc를 호출하고 결과 · 입력값 · 항목별 내역을 저장한다.
- AI 절세 가이드(챗봇)는 Ollama로 실행하는 Gemma를 쓴다. 세액 계산에는 LLM을 쓰지 않는다.

### 기능별 담당 · 폴더 (분담표 10/29 기준)

| 파트 | 기능 | 담당 | back | calc | front |
| --- | --- | --- | --- | --- | --- |
| ① 회원·보안 | F-01~F-05 · F-22 · F-23 | 윤경 | `member/` · `common/` | — | `pages/auth` · `pages/profile` |
| ② 소득·카드 | F-06~F-09 | 고은 | `income/` · `expense/` | `card/` | `pages/tax` (S-02 소득·업로드) |
| ③ 세액 계산·진단 | F-10~F-12 | 이우진 | `prediction/` | `services/` | `pages/tax` (S-05 혜택 진단) |
| ④ 대시보드·시뮬레이션 | F-13 · F-15 · F-16 | 미정 | `statistics/` | — | `pages/dashboard` · `pages/simulation` |
| ⑤ 챗봇 | F-14 | 동석 | `chat/` | 챗봇 위치 미정 | `pages/chatbot` |
| ⑥ 고객센터·관리자 | F-17~F-21 | 홍은 | `inquiry/` · `admin/` | — | `pages/support` · `pages/admin` |

- 다른 파트 폴더를 고쳐야 하면 먼저 사용자에게 묻고, 그 파트 담당에게 공유한다.

### 기본 원칙

- 기존 구조와 기능을 우선한다. 새로 만들기 전에 기존 구현을 먼저 확인한다.
- 수정 범위는 요청된 기능에 필요한 만큼으로 제한한다. 요청받지 않은 기능 추가 · 기존 기능 삭제를 하지 않는다.
- 중복 코드를 줄이고 기존 공통 기능을 재사용한다. 변수·함수 이름은 역할이 드러나게 짓는다.
- 내 기능 폴더만 수정한다. 다른 기능 폴더나 공통 폴더, 다른 팀원 담당 코드를 고쳐야 하면 먼저 사용자에게 묻는다.
- 공통 UI · 공통 API · API 설정은 기존 사용처와 영향 범위를 확인한 뒤 수정한다. 다른 팀원 작업과 충돌할 수 있으면 먼저 공유한다.
- 사용자에게 보이는 문구는 한글로 쓴다.
- 요청받지 않은 외부 라이브러리를 설치하지 않는다. 필요하면 먼저 이유를 말하고 묻는다.

### 기능명세서 · ERD

- 기능 사양은 기능명세서(구글 시트)를 기준으로 한다: https://docs.google.com/spreadsheets/d/1qW5xjOhPqrWkCn9KLUUbylKfsFJCacfOAgBiXm27v9w/edit
- 테이블·칸은 ERD v4.1(ERDCloud)이 기준이다: https://www.erdcloud.com/d/mL4eEnZLQ3QjgbWF4
- 기능명세서 · ERD · 노션 링크는 로그인이 필요해 열리지 않을 수 있다. 열 수 없으면 내용을 추측하지 말고, 사용자에게 필요한 부분(복사본 · 캡처)을 요청한다.
- 화면에 있다고 실제 구현된 것으로 판단하지 않는다. UI만 / 데모 데이터 / back 연결 / DB 연결 / calc 연결 상태를 구분하고, 실제 상태와 다른 안내문을 쓰지 않는다.
- DB 테이블·칸과 기존 데이터는 바꾸거나 지우지 않는다. 필요하면 노션 「요청·전달」에 DB 변경 요청을 남긴다 (DB 담당: 이우진). ERD와 코드가 다르면 임의로 판단하지 말고 차이를 알린다.
- DB 이름 규칙: 테이블·칸은 대문자 SNAKE_CASE(예: `CARD_UPLOAD`, `MEMBER_ID`) · PK는 `테이블명_ID` 또는 `테이블명_NO` · Oracle 예약어 금지.

### Git

- 브랜치: `main`(최종본 · 12/09) · `develop`(기능이 끝나면 머지) · `feature/기능명`(기능 브랜치 → develop으로 PR). `main`·`develop`에 직접 커밋하지 않는다. (예외: 저장소를 처음 만들 때 `docs/setup` 01~04 초기 세팅은 형상 관리 담당이 `main`에서 진행)
- 브랜치는 저장소별이 아니라 기능별로 만든다 (예: `feature/signup` · `feature/tax-input` · `feature/card-upload` · `feature/dashboard` · `feature/simulation`). 한 기능이 여러 저장소에 걸치면 각 저장소에 같은 이름으로 만든다.
- 통합 테스트가 끝난 `develop`은 PR로 `main`에 병합한다.
- 커밋은 의미 있는 기능 구현·수정 단위로 한다. 메시지: `종류: 무엇을 했는지` (feat · fix · chore · docs · test · refactor · ci) · 설명은 한글 (예: `feat: 카드내역 CSV 업로드 및 파싱 구현`)

### 보안

- DB 비밀번호 · API 키 · JWT Secret · 이메일 인증 Secret · 개인 인증정보는 코드에 쓰지 않는다. `.env`에만 쓰고 `.env.example`에는 이름만 적는다.

### 작업 방식

- 처음 맡은 작업이나 큰 변경은 먼저 분석한다: 기존 폴더 구조 · 데이터 흐름 · 구현된/안 된 기능 · 필요한 연동 범위(back · DB · calc · Ollama). 분석 결과를 먼저 보고하고, 이 단계에서는 승인 없이 코드 수정·파일 생성을 하지 않는다.
- 새 파일이 필요하면 파일별 역할과 만드는 이유를 설명하고 승인 후 만든다. 기능 파일과 그 테스트 파일은 함께 적어 한 번에 승인받는다.
- 진행 순서: 요청 확인 → 기능명세서 · ERD 확인 → 기존 코드 분석 → 데이터 흐름 설계 → 필요한 파일 구성 → 필요한 부분만 구현 → 다른 기능 영향 확인 → 테스트 → 문서 갱신
- 수정 후 보고: 목적·결과 · 수정한 파일과 역할 · 바뀐 동작을 짧게 요약한다. 해당될 때만 데이터 흐름(저장소 간 연결) · 관련 테이블 · 추가 환경변수 · 테스트 결과와 미검증 항목 · 아직 안 된 부분 · 갱신한 문서를 덧붙인다.

### 테스트 기준

- 정상 입력과 예외 입력을 모두 확인한다.
- 해당되는 연결 구간을 확인한다: front ↔ back API 요청·응답 · back ↔ DB 저장·조회 · back ↔ calc 데이터 전달·결과 반환 · Ollama(Gemma) 요청·응답·오류 처리
- 공통 컴포넌트를 고치면 그것을 쓰는 기존 화면이 정상인지 확인한다 (회귀 테스트).
- 테스트하지 않은 항목은 「미검증」으로 적는다. 하지 않은 작업·테스트를 완료했다고 보고하지 않는다.

### 문서 관리

각 저장소의 `docs/`에 아래 세 가지로만 기록한다 (예외: 초기 세팅 절차 `docs/setup/`). 다른 문서 분류를 임의로 추가하지 않는다.

- `docs/history.md`: 작업·변경 내역. 작업을 마칠 때마다 기록하고, 최신 작업이 맨 위에 오도록 쌓는다.
- `docs/decisions/`: 기술 스택 · 구조 · 데이터 구조 등 주요 결정과 그 이유
- `docs/tasks.md`: 구현 예정 · 진행 중 · 남은 작업

`docs/history.md` 형식:

```markdown
### [YYYY-MM-DD] 작업 요약 제목
- **작업 내용**: 수정한 파일 및 핵심 변경점
- **변경 사유**: 변경 목적 또는 해결한 문제
- **검증 결과**: 실행/테스트한 명령어 및 결과
```

- 여러 브랜치에서 `docs/history.md`를 같이 고쳐 develop에 합칠 때 충돌이 나면, 두 기록을 모두 남기고 날짜순(최신이 위)으로 둔다.

### 도메인 용어 사전

| 용어 | Python 변수(calc) | API 응답 이름 | 설명 |
| --- | --- | --- | --- |
| 총급여 | `total_salary` | — | 비과세 제외 연간 급여 합계 |
| 근로소득공제 | `earned_income_deduction` | — | 총급여에서 자동 차감 |
| 근로소득금액 | `earned_income_amount` | — | 총급여 - 근로소득공제 |
| 소득공제 | `income_deduction` | — | 과세표준을 줄이는 공제 (인적, 신용카드 등) |
| 과세표준 | `tax_base` | `taxableIncome` | 근로소득금액 - 소득공제 |
| 산출세액 | `calculated_tax` | `calculatedTax` | 과세표준 × 세율 |
| 세액공제 | `tax_credit` | — | 산출세액에서 직접 차감 |
| 결정세액 | `determined_tax` | `decidedTax` | 산출세액 - 세액공제 |
| 기납부세액 | `prepaid_tax` | `withheldTax` | 원천징수로 이미 낸 세금 |
| 환급액 | `refund_amount` | `expectedRefund` | 기납부세액 - 결정세액 (양수면 환급) |
| 추가납부액 | `additional_tax` | — | 결정세액 - 기납부세액 (양수면 추가 납부) |

API 응답 이름은 노션 「동석님 전달」이 기준이다. `—` 칸은 노션에서 확인한다.

## 작업 완료 조건

작업을 "끝났다"고 말하기 전에 아래를 실행하고, 모두 통과한 결과를 보여준다.

```bash
ruff check . && pytest
```

## 하지 말 것

- `.env*` 파일을 읽거나 내용을 출력·커밋하지 않는다.
- 사용자 확인 없이 `git push`, 브랜치 삭제, 강제 푸시(`git push -f`) 금지. 커밋 이력을 지우지 않는다.
- 안 쓰는 import·변수를 남긴 채 커밋하지 않는다.
- 린터 규칙을 끄거나 주석으로 숨기지 않는다. 꼭 필요하면 이유를 말하고 허락을 받는다.
- `__pycache__/` · `.venv/` 같은 빌드·환경 산출물을 커밋하지 않는다.
- 기존 프로젝트를 새로 재작성하거나, 정상 기능·기존 파일을 임의로 삭제·이동하지 않는다.

## 참고 문서 (필요할 때만 읽는다)

- 개발 환경 세팅 절차: `docs/setup/` (01-linter → 02-testing → 03-github → 04-github-actions)
- 작업 이력: `docs/history.md` · 주요 결정: `docs/decisions/` · 남은 작업: `docs/tasks.md`
