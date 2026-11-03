# DB 작업 파일 (희망연봉2조 · DB·데이터 담당 이우진 · 11/02 v4.1)

## 계산 서버 전용 읽기 계정 (11/03 · 최소 권한 · 구조 변경 없음)

계산 서버(hope-refund-calc)는 기준값 테이블 3개(`DEDUCTION_TYPE` · `TAX_BRACKET` · `BENEFIT_CONDITION`)를 **읽기만** 해요.
그래서 테이블 주인 계정 대신, 이 3개만 읽을 수 있는 계정을 따로 써요. 계산 서버에 문제가 생겨도 회원 정보를 읽거나 데이터를 고치·지울 수 없어요.

- 계정 이름 · 비밀번호 · DB 주소: **팀 단톡에만** (노션 · GitHub에 적지 않음)
- 계산 서버 `.env`의 `DB_USERNAME` · `DB_PASSWORD`에 이 계정을 넣어요
- Spring 서버(back)는 소득 · 계산 결과를 저장해야 해서 테이블 주인 계정을 그대로 써요

만드는 SQL (DB 관리자 계정으로 실행 · `<계산서버계정>` · `<비밀번호>` · `<주인계정>`은 실제 값으로 바꾸기):

```sql
CREATE USER <계산서버계정> IDENTIFIED BY "<비밀번호>";
GRANT CREATE SESSION TO <계산서버계정>;

GRANT SELECT ON <주인계정>.DEDUCTION_TYPE    TO <계산서버계정>;
GRANT SELECT ON <주인계정>.TAX_BRACKET       TO <계산서버계정>;
GRANT SELECT ON <주인계정>.BENEFIT_CONDITION TO <계산서버계정>;

-- 계산 서버 코드가 테이블 이름만 쓰기 때문에 동의어로 연결 (코드 수정 없음)
CREATE SYNONYM <계산서버계정>.DEDUCTION_TYPE    FOR <주인계정>.DEDUCTION_TYPE;
CREATE SYNONYM <계산서버계정>.TAX_BRACKET       FOR <주인계정>.TAX_BRACKET;
CREATE SYNONYM <계산서버계정>.BENEFIT_CONDITION FOR <주인계정>.BENEFIT_CONDITION;
```

확인 (새 계정으로 접속): 기준값 3개 `SELECT COUNT(*)`는 숫자 · `<주인계정>.MEMBER` 조회는 ORA-00942 · `DELETE`/`UPDATE`는 ORA-01031이 나오면 정상 (11/03 학원 DB에서 확인)

**나중에 계산 서버가 다른 테이블을 읽게 되면** 그 테이블도 `GRANT SELECT` + `CREATE SYNONYM`을 추가해야 해요. 안 하면 계산 서버에서 ORA-00942가 나요.

## v4.1 (11/02 · 연금저축 단독 600만 한도 · 칸 2개 추가)

- **INCOME · PREDICTION_INPUT 연금 칸 두 개로:** `PENSION_SAVING` = **연금저축만**(이름·자리 그대로 · 설명 변경) · **`IRP_SAVING`** = IRP(퇴직연금계좌) 연 납입액(맨 뒤 · 기본 0)
  - 이유: 연금계좌 세액공제 한도는 합계 900만이지만 그중 연금저축은 600만까지(소득세법 §59의3) → 합친 금액만 있으면 연금저축만 600만 넘게 낸 사람의 공제를 크게 계산함
  - 화면(TaxInfoForm · SimulationPage)은 이미 「연금저축」 · 「IRP」 두 칸(`pensionSaving` · `irp`)으로 받고 있음 → DB를 화면에 맞춤
- **CHECK `CK_INCOME_AMOUNT` · `CK_PRED_INPUT_AMOUNT` 다시 만듦** (`IRP_SAVING >= 0` 추가 · 개수 그대로 50)
- **DEDUCTION_TYPE 2행 추가:** 연금저축 단독 한도 `PENSION_SAVING_LIMIT`(LIMIT 6,000,000 · RATE 0) × 2026·2025 귀속 → 기준값 50 → **52행** (2026 28 · 2025 24) · 공제율과 합계 한도 900만은 그대로 `PENSION` 행
- **가상 회원:** 국세통계 연금 값은 「연금계좌」(연금저축 + IRP) 합계라, 600만을 넘는 3명(INCOME_ID 93 · 239 · 254 · 각 664만)은 초과분 64만을 IRP로 옮김 → 합계·공제액 그대로 · `05_가상데이터_생성.py` · `가상데이터/INCOME.csv` · `03_데이터적재.sql` 모두 같은 값
- **이미 v4.0으로 만든 계정(교육원 공용 DB 포함): `79_v4.0에서_v4.1로.sql` 한 번 실행** — **11/02 교육원 공용 DB 적용 완료** (칸 212 · CHECK 50 · 새 칸 2 · 기준값 52 · 2025 24 / 2026 28 · 연금 600만 초과 가상 0 · 연금저축 + IRP 합계 579,730,000 · 옮긴 가상 회원 93 · 239 · 254 = 6,000,000 + 640,000 · 틀린 값 테스트 OK · 공용 DB 새 2행 TYPE_ID **57~58**) · 맨 위 확인 테이블 20 · 칸 210 · CHECK 50 · 새 칸 0 · 기준값 50 · 새 코드 0 · 연금 600만 초과 가상 3 → 맨 아래 칸 **212** · CHECK **50** · 새 칸 2 · 기준값 **52** · 새 코드 2 · 연금 600만 초과 가상 0 · 「연금저축 + IRP 합계」 = 맨 위 「연금 합계」 · 틀린 값 테스트 OK (ROLLBACK)
  - 공용 DB는 새 2행 TYPE_ID가 57~58로 새 계정(51~52)과 다름 → TYPE_CODE로 찾기
  - 직접 입력(INPUT) 소득 행은 바꾸지 않음 · PREDICTION_INPUT은 지난 계산 기록이라 IRP_SAVING = 0
- 새 계정은 01 → 02 → 03 그대로 (새 2행은 02의 2-3) · 03은 INCOME 행 맨 뒤에 IRP 값)
- 백엔드: 소득·계산 입력 저장 때 `IRP_SAVING` 같이 저장 (화면 `irp`) · 계산: 연금저축 min(PENSION_SAVING, 600만) + IRP → 합계 min(합계, 900만) × PENSION 공제율
- 숫자: 테이블 20 · 칸 210 → **212** · CHECK 50 · UNIQUE 12 · 인덱스 25 · 기준값 50 → **52** · 구간 30 · 혜택 6


## v4.0 (10/30 · 계산 결과 항목별 공제 내역 · 구조 변경 없음)

- **DEDUCTION_TYPE 4행 추가:** 근로소득공제(`EARNED_DEDUCTION`) · 근로소득세액공제(`EARNED_CREDIT`) × 2026·2025 귀속 → 기준값 46 → **50행** (2026 27 · 2025 23)
  - 이유: 항목별 공제 내역(PREDICTION_DETAIL)은 DEDUCTION_TYPE 행을 가리켜야 저장되는데, 이 두 항목은 기준값이 TAX_BRACKET에만 있어서 내역에 저장할 수 없었음
  - 이름·종류·근거만 담는 행이에요. RATE 0이고, 공제율·구간은 그대로 TAX_BRACKET의 같은 이름 구간을 써요. 근로소득공제 한도 2,000만은 LIMIT_AMOUNT에 있어요
- **카드 공제 저장 방식(10/30 결정):** 문턱(총급여 25%)은 신용카드부터 빼고, 분류별 행마다 공제액 저장 · 한도 초과분은 한도 행(CARD_LIMIT_*)에 **음수**로 저장 → 카드 공제 합계 = CARD 행 + CARD_RULE 행 합
- **이미 v3.9로 만든 계정(교육원 공용 DB 포함): `80_v3.9에서_v4.0로.sql` 한 번 실행** — **10/30 교육원 공용 DB 적용 완료** (기준값 50 · 2025 23 / 2026 27 · 중복 테스트 2줄 OK) · ⚠ 공용 DB는 새 4행 TYPE_ID가 **51~54**(새 계정은 47~50) → TYPE_CODE로 찾기 · 맨 위 확인 기준값 46 · 새 코드 0 · 구간 30 · 근로소득 구간 14 → 맨 아래 기준값 **50** · 새 코드 4 · 2025 23 / 2026 27 · 틀린 값 테스트 2줄 OK (ROLLBACK)
- 새 계정은 01 → 02 → 03 그대로 (새 4행은 02의 2-2), TYPE_ID 47~50)
- ERD 그림·테이블·칸·CHECK 변경 없음

## v3.9 (10/29 · 계산 기준 팀 결정 · 성별 필수)

| 결정 | 바뀐 것 | 비고 |
|---|---|---|
| 표준세액공제 13만원 자동 비교 (10/29 디코 · 「건강·고용보험료 공제 + 월세 세액공제」 vs 「13만원」 중 유리한 쪽) | `INCOME`·`PREDICTION_INPUT`: `SOCIAL_INSURANCE` → **`NATIONAL_PENSION`**(국민연금 · 이름 변경 · 같은 자리) · **`HEALTH_INSURANCE`**(건강·고용·노인장기요양보험료 · 맨 뒤 · 기본 0) · CHECK `CK_INCOME_AMOUNT`·`CK_PRED_INPUT_AMOUNT` 다시 만듦 | 국민연금 = 연금보험료공제(소득세법 §51의3) → 13만원과 같이 받음 · 건강·고용보험료 = 특별소득공제(§52①) → 13만원과 택1(§59의4⑨) · 근거 책자 103·107·170p |
| 〃 기준값 | `DEDUCTION_TYPE` 2026 귀속 3행: `NATIONAL_PENSION`(100% · 소득공제) · `HEALTH_INSURANCE`(100% · 소득공제) · `STANDARD_CREDIT`(세액공제 · 한도 130,000) → 22 → 25행 (TYPE_ID 23~25) | 결과 화면 「어느 쪽이 적용됐나」를 PREDICTION_DETAIL에 저장하려면 행이 있어야 함 |
| 1~3월은 작년 기준 (10/29 디코 · 고은님 제안 · 동석님 동의) | **2025 귀속 기준값**: `DEDUCTION_TYPE` 21행(TYPE_ID 26~46) · `TAX_BRACKET` 15행(16~30) · `BENEFIT_CONDITION` 3행(4~6) | 근거 책자가 2025 귀속판이라 값은 2026 행과 같음 · 다른 점: 카드 자녀 가산 한도 없음(2026 귀속부터) · 수영장·체력단련장은 2025.7.1 이후 사용분만(책자 132p) |
| 성별 가입 필수 (10/28 확정) | CHECK `CK_MEMBER_GENDER_REQ` (`GENDER IS NOT NULL OR ROLE = 'ADMIN' OR STATUS = 'WITHDRAWN'`) | 칸 변경 없음 · 성별 없는 관리자를 일반 회원으로 내리기는 백엔드에서 차단 |

- **이미 v3.8로 만든 계정(교육원 공용 DB 포함): `81_v3.8에서_v3.9로.sql` 한 번 실행** — **10/29 교육원 공용 DB 적용 완료** (칸 210 · CHECK 50 · 기준값 46 · 구간 30 · 혜택 6 · 틀린 값 테스트 4줄 OK) · ⚠ 공용 DB는 시퀀스가 앞서 있어 새 3행 TYPE_ID가 26~28(새 계정은 23~25) → **백엔드는 TYPE_ID를 코드에 박지 말고 TAX_YEAR + TYPE_CODE(+ 총급여 구간)로 고를 것** · 맨 위 확인 테이블 20 · 칸 208 · CHECK 49 · UNIQUE 12 · 인덱스 25 · 옛 칸 2 · 새 칸 0 · 기준값 22 · 구간 15 · 혜택 3 · 성별 빈 일반회원 0 → 맨 아래 칸 **210** · CHECK **50** · 옛 칸 0 · 새 칸 4 · 기준값 **46** · 구간 **30** · 혜택 **6** · 건강보험료 빈 가상회원 0 · INCOME_ID 1 = 23840000 · 719260 · 657940 · 틀린 값 테스트 4줄 모두 OK (ROLLBACK)
- 가상 회원 1,000명: 국세통계 4-2-4(2024년 귀속)의 「연금보험료공제 국민연금보험료 금액」·「특별공제 보험료 금액」을 급여 구간별 총급여로 나눈 비율(소수 7자리)로 다시 계산 · 81의 MERGE · `05_가상데이터_생성.py` · `03_데이터적재.sql` · `가상데이터/INCOME.csv` 모두 같은 값 (옛 합계와 차이 0~±10원, 총급여 13억 1명만 100원)
- 새 계정: 01 → 02 → 03 그대로 (02에 2026 3행 + 2025 기준값 39행 · 03은 INCOME 행에 국민연금 값 + 맨 뒤 건강보험료 값)
- 백엔드·계산(③):
  - `SOCIAL_INSURANCE` 쓰던 곳 → `NATIONAL_PENSION` (안 고치면 ORA-00904) · 소득 저장 때 `HEALTH_INSURANCE` 같이 저장
  - 표준세액공제: A = 건강보험료 소득공제 + 월세 세액공제를 넣고 계산한 결정세액 · B = 둘 다 빼고 13만원 세액공제를 넣은 결정세액 → **작은 쪽** 적용 · 국민연금은 양쪽 다 공제 · 적용한 쪽만 PREDICTION_DETAIL에 저장
  - 귀속 연도: 1~3월은 `TAX_YEAR = 작년`, 4월부터 `올해` 기준값 행을 고름 · 2025 귀속이면 자녀 가산 한도 코드(CARD_LIMIT_CHILD1·2) 없음 → `CARD_LIMIT_BASE` · 수영장·체력단련장(MERCHANT_LIST 출처) 거래 중 사용일 < 2025-07-01은 일반으로
- 화면: 2단계 소득 정보에 「국민연금」 · 「건강·고용보험료」 두 칸 (지금 UI에는 사회보험료 칸 자체가 없음)
- 숫자: 테이블 20 · 칸 208 → **210** · CHECK 49 → **50** · UNIQUE 12 · 인덱스 25 · 시퀀스 18 · 기준값 22 → **46** · 구간 15 → **30** · 혜택 3 → **6**

## v3.8 (10/28 · 기능명세서 v1.4 「5_결정 필요」 확정분)

| 결정 | 바뀐 것 | 비고 |
|---|---|---|
| D-17 금융 정보 저장 동의 (가입 때 별도 필수 체크박스) | `MEMBER.FINANCE_AGREED_AT`(동의 일시) · `FINANCE_VERSION`(동의서 버전) 맨 뒤 · NOT NULL · 기본값 없음 | 약관·개인정보 동의와 같은 방식 · 기존 회원은 개인정보 동의 일시·버전과 같게 채움 |
| D-12 문의 유형 | `INQUIRY.INQUIRY_TYPE` 맨 뒤 · `ERROR`(오류)/`QUESTION`(문의)/`ETC`(기타) · NOT NULL · CHECK `CK_INQUIRY_TYPE` | 기존 문의는 QUESTION으로 채움 |
| D-22 문의 「확인 중」 | `INQUIRY.STATUS`에 `CHECKING` 추가 · `CK_INQUIRY_STATUS`·`CK_INQUIRY_ANSWER` 다시 만듦 | 확인 중도 답변 3칸은 비어 있음 (임시 안내 답변은 화면 고정 문구라 저장 안 함) |
| D-11 그룹 비교 통계 DB 적재 | 새 테이블 `STAT_FILE`(통계 파일 · 원본·정제 파일은 저장 경로만) · `GROUP_STAT`(그룹 1개 = 1행 · 10개 항목 전부) · FK 인덱스 2 · 시퀀스 2 | 국세통계 2024년 귀속 성별·연령대 12행 + 급여 구간 16행 = 28행 · 값 → 정제 csv(`FILE_ID`) → 원본 xlsx(`ORIGIN_FILE_ID`) |
| D-21 탈퇴 30일 유예 | 구조 변경 없음 · `97_데이터정리.sql` 2번: 탈퇴 요청은 상태만 바꿈 → **30일 지난 회원만** 아이디·이메일·비밀번호·이름 식별 불가 처리 | 소득·카드 내역 등 나머지 데이터는 지우지 않음(「데이터 활용」) · 활용 범위는 팀 결정 후 반영 |

- **이미 v3.7로 만든 계정(교육원 공용 DB 포함): `82_v3.7에서_v3.8로.sql` 한 번 실행** — 맨 위 확인 테이블 18 · 칸 175 · CHECK 42 · UNIQUE 10 · 인덱스 23 · 새 칸 0 · 새 테이블 0 → 맨 아래 테이블 20 · 칸 208 · CHECK 49 · UNIQUE 12 · 인덱스 25 · 동의 빈칸 0 · 유형 빈칸 0 · 파일 4 · 통계 28 · 회원·문의 행 수 그대로 · 조회 예 2행 · 틀린 값 테스트 5줄 모두 OK (ROLLBACK)
- 새 계정: 01 → 02 → 03 그대로 (02에 통계 28행 · 03은 MEMBER 행 끝에 금융 동의 일시·'1.0' 추가 · `가상데이터/MEMBER.csv`에도 칸 2개 추가 · `05_가상데이터_생성.py`도 맞춤)
- 백엔드:
  - 가입 INSERT에 `FINANCE_AGREED_AT = SYSDATE` · `FINANCE_VERSION = 현재 동의서 버전` (빠지면 ORA-01400)
  - 문의 INSERT에 `INQUIRY_TYPE` · 관리자 [확인중] = `UPDATE INQUIRY SET STATUS = 'CHECKING'` (답변 칸은 그대로 비움) · 답변 등록은 지금처럼 4칸 한 번에
  - 그룹 비교: 급여 구간 `WHERE GROUP_TYPE = 'SALARY' AND :총급여 > SALARY_MIN AND (SALARY_MAX IS NULL OR :총급여 <= SALARY_MAX)` · 성별·연령대 `WHERE GROUP_TYPE = 'GENDER_AGE' AND GENDER = :성별 AND (AGE_MIN IS NULL OR :나이 >= AGE_MIN) AND (AGE_MAX IS NULL OR :나이 <= AGE_MAX)` · 성별·연령대·급여 구간 교차 행은 없음 (국세통계에 교차 집계 없음)
  - 탈퇴: 상태만 WITHDRAWN · 30일 뒤 처리는 97번 2-2) (하루 한 번)
- 숫자: 테이블 18 → **20** · 칸 175 → **208** · CHECK 42 → **49** · UNIQUE 10 → **12** · 인덱스 23 → **25** · 시퀀스 16 → **18**

## v3.7 (10/27 · 기능명세서 v1.3 팀 댓글 「분류 직접 수정 불가」)
- 결정: 사용자는 잘못 분류된 거래를 **직접 고칠 수 없음** (F-02-04는 조회 · 업로드 삭제만) → 「사용자가 고쳤는지」 표시 칸이 필요 없어짐
- 바꾼 것 — `EXPENSE.USER_EDITED_YN` 칸과 CHECK `CK_EXPENSE_EDITED` **삭제** (지금 값은 전부 'N'이라 잃는 정보 없음)
- 분류 쿼리 `04_분류쿼리.sql` 3) · 파이썬 `07_카드분류.py` · `03_데이터적재.sql`: 「USER_EDITED_YN = 'N'인 행만」 조건을 빼고 업로드의 모든 행을 분류
- 가상데이터 `EXPENSE.csv` · `03_데이터적재.sql`: EXPENSE 행 끝 'N' 삭제 (10,453행 그대로) · `05_가상데이터_생성.py`도 맞춤
- **이미 v3.6으로 만든 계정(교육원 공용 DB 포함): `83_v3.6에서_v3.7로.sql` 한 번 실행** — **10/27 교육원 공용 DB 적용 완료** · 맨 위 확인 칸 1 · Y인 행 0 · CHECK 43 · 칸 176 → 맨 아래 칸 0 · CHECK 42 · 칸 175 · EXPENSE 칸 9 · 지출 행 수 그대로
- 새 계정: 01 → 02 → 03 그대로
- 백엔드: EXPENSE 쿼리에 USER_EDITED_YN이 남아 있으면 ORA-00904 → 지울 것
- 숫자: 테이블 18 · 칸 176 → **175** · CHECK 43 → **42** · 인덱스 23 · UNIQUE 10

## v3.6 (10/27 · 멘토 피드백 「급여 ↔ 공제 관계」 반영)
- 피드백: 급여에 따라 공제 비율·한도가 달라지는데 급여 정보와 연결돼 있지 않다 → 관계를 정립할 것
- 지금까지는 총급여 7천만 기준 행을 **코드 이름(_LOW/_HIGH)** 으로 나눠서, 백엔드가 「7천만 이하면 _LOW」를 코드에 박아야 했음
- 바꾼 것 — `DEDUCTION_TYPE`에 **총급여 구간 두 칸**: `SALARY_MIN`(구간 시작 · 초과 · 맨 뒤 칸 · 기본 0) · `SALARY_MAX`(구간 끝 · 이하 · NULL = 상한 없음 · 옛 `SALARY_LIMIT` 이름 변경) · CHECK `CK_DEDUCTION_SALARY`(끝 > 시작) · UNIQUE `(TAX_YEAR, TYPE_CODE, SALARY_MIN)`
- 코드 통합(행 수 22 그대로): `CARD_LIMIT_BASE` · `CARD_LIMIT_EXTRA` · `CARD_LIMIT_CHILD1` · `CARD_LIMIT_CHILD2`(각 0~7천만 / 7천만~) · `PENSION`(0~5,500만 15% / 5,500만~ 12%) · `RENT`(0~5,500만 17% / 5,500만~8천만 15%) — `_LOW`·`_HIGH`·`PENSION_HIGH`·`RENT_HIGH` 코드 없어짐
- 백엔드: 기준값 행은 **코드 + 총급여**로 고름 → `WHERE TAX_YEAR = :y AND TYPE_CODE = :code AND :총급여 > SALARY_MIN AND (SALARY_MAX IS NULL OR :총급여 <= SALARY_MAX)` · 구간 경계(7천만·5,500만·8천만)가 행의 숫자라 관리자 화면에서 한 행 수정, 구간 추가는 행 INSERT, 코드 변경 없음
- **이미 v3.5로 만든 계정(교육원 공용 DB 포함): `84_v3.5에서_v3.6로.sql` 한 번 실행** — **10/27 교육원 공용 DB 적용 완료** · 맨 위 확인 0·1·10·42 → 맨 아래 칸 176 · CHECK 43 · UNIQUE 10 · 기준값 22 · LOW/HIGH 0 · 구간 행 6 · 조회 예 3행 · 틀린 값 테스트 3개 OK (ROLLBACK)
- 새 계정: 01 → 02 → 03 그대로 (02는 DEDUCTION_TYPE 행 끝에 SALARY_MIN 값 추가됨)
- ERDCloud 반영 완료 (10/27)
- 숫자: 테이블 18 · 칸 175 → **176** · CHECK 42 → **43** · 인덱스 23 · UNIQUE 10

## v3.5 (10/26 · 팀 회의 「실명 미수집」 반영)
- 10/26 팀 회의 결정: **실명(본명)은 수집하지 않음 · 화면 호칭은 "고객님/사용자님"** → `MEMBER.NAME` 을 **NOT NULL → NULL 허용**으로 바꿈 (칸은 유지 · 나중에 닉네임 등으로 재활용 가능 · 테이블 18 · 칸 175 · CHECK 42 · 인덱스 23 전부 그대로)
- **이미 v3.4로 만든 계정(교육원 공용 DB 포함): `85_v3.4에서_v3.5로.sql` 한 번 실행** — 맨 위 확인 NULLABLE = N → 맨 아래 NULLABLE = Y · 이름 있는 회원 1,001(가상데이터 그대로) · 이름 없이 가입 테스트 OK (ROLLBACK)
- 백엔드: 가입 INSERT에 NAME 안 넣음 · 화면: 이름 자리에 "고객님/사용자님" · 가상 회원 1,001명의 이름('가상회원0001' …)은 테스트용으로 유지 (회의 결정)
- 로그인 잠금 정책(5회/10분)은 회의에서 **후순위 반영**으로 미룸 — 백엔드 설정값이라 DB 변경 없음 (LOGIN_FAIL_COUNT·LOCKED_UNTIL 칸은 v3.0부터 있음)

## v3.4 (10/25 · 보안 점검 반영)

해커 입장에서 DB를 훑어본 결과 중 **DB에서 막을 수 있는 3가지**만 반영. 나머지(다른 사람 데이터 열람·권한 상승·XSS·업로드 제한 등)는 백엔드·프론트 몫이라 회의 안건 문서로 따로 올림.

| 바뀐 것 | 내용 | 이유 |
|---|---|---|
| `MEMBER.EMAIL_VERIFIED_YN` (맨 뒤) | 이메일 인증 여부 Y/N · 기본값 N · CHECK · 가상 회원은 Y | 남의 이메일로 가입하면 진짜 주인이 가입 못 하고, 비밀번호 재설정 코드가 엉뚱한 데로 감 |
| `ACCESS_LOG.IP_ADDRESS` · `RESULT` + 인덱스 `IX_ACCESS_LOG_IP` | 접속 IP(45자) · 결과 SUCCESS/FAIL/DENIED · (IP, 시각) 인덱스 | 공격당해도 누가 어디서 몇 번 시도했는지 볼 수 없었음 · IP 기준 횟수 제한에 씀 |
| 세법 기준값 3개 테이블 `UPDATED_AT` · `UPDATED_BY` (+ FK 인덱스 3) | 마지막 수정일 · 바꾼 관리자 회원번호 → MEMBER (NULL = 스크립트) | 관리자가 숫자 하나 바꾸면 전 회원 계산이 바뀌는데 누가 언제 바꿨는지 안 남았음 |
| 숫자 | 테이블 18 · 칸 166 → **175** · 인덱스 19 → **23** · UNIQUE 10 · CHECK 40 → **42** | |

- 새 계정: 01 → 02 → 03 그대로 (02는 기준값 행마다 `SYSDATE, NULL` · 03은 MEMBER 행마다 `'Y'` 추가됨 · `가상데이터/MEMBER.csv`에도 칸 추가)
- **이미 v3.3으로 만든 계정(교육원 공용 DB 포함): `87_v3.3에서_v3.4로.sql` 한 번 실행** — 맨 위 확인 0·40·19 → 맨 아래 CHECK 42 · 인덱스 23 · 칸 175 · MEMBER 24 · 접근기록 6 · 틀린 값 테스트 4줄 모두 OK (ROLLBACK) · **10/25 교육원 공용 DB 적용 완료** (인증된 회원 1,001 = 가상 회원 전부)
- v3.2 계정은 88 → 87 순서 (87을 먼저 하면 88의 INSERT가 칸 수 안 맞아 실패)
- 백엔드:
  - 가입: 인증 메일 코드 확인되면 `EMAIL_VERIFIED_YN = 'Y'` · 비밀번호 재설정은 `'Y'`인 회원만 · 로그인 자체를 막을지는 팀 결정
  - 접근 기록: 로그인 성공/실패, 남의 데이터 접근 시도(DENIED)는 꼭 IP와 함께 INSERT · `(IP_ADDRESS, ACCESSED_AT)`로 「한 IP가 10분에 실패 N번」 조회
  - 관리자 화면에서 기준값을 바꾸면 `UPDATED_AT = SYSDATE, UPDATED_BY = 관리자 번호`를 같은 UPDATE에
  - 기준값 INSERT는 칸 이름을 적어서 (`INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, …) VALUES (…)`) — 위치로 넣으면 칸이 늘 때마다 깨짐

## 10/23 데이터 정비 — 포함 대조 85행 EXACT로 (구조 변경 없음)
- `86_포함대조_정리.sql`: MERCHANT_LIST 포함 대조(CONTAINS) 행 중 일반 단어라 오분류되던 85행(무인양품 · ○○교육 27 · ○○기독교 58)을 정확히 일치(EXACT)로. 가맹점명에 그 단어가 들어가기만 하면 문화체육(4)으로 잡히던 문제
- 실행 전 확인 → UPDATE 2개 → 확인(EXACT 85 · 남은 CONTAINS 697 → 612) → COMMIT · 10/23 교육원 공용 DB 적용 완료
- 가상 카드 내역 10,453건 중 그 85행으로 분류된 건 0 → 재분류 불필요 · 새 업로드는 자동으로 새 기준 적용 (04·07은 목록을 그때그때 읽음)

## v3.3 (10/23 · 카드 공제 자녀 한도)

| 바뀐 것 | 내용 | 이유 |
|---|---|---|
| 칸 `CHILDREN` (INCOME · PREDICTION_INPUT 맨 뒤) | 20세 이하 자녀 수 · 기본값 0 · NOT NULL · 금액 0 이상 CHECK 2개에 `CHILDREN >= 0` 추가 | 조특법 §126의2⑩ 개정(2025.12.23)으로 2026 귀속부터 카드 기본한도가 자녀 수에 따라 늘어남 |
| 기준값 `DEDUCTION_TYPE` 4행 (18 → 22) | 기본한도 자녀 가산: 7천만 이하 자녀 1명 350만 · 2명 이상 400만 / 7천만 초과 자녀 1명 275만 · 2명 이상 300만 | 자녀등 = 20세 이하 직계비속·입양자·위탁아동 중 소득금액 100만 이하(근로소득만이면 총급여 500만 이하) · 다른 사람 기본공제 대상 아님 (조특령 §121의2 제18항) |
| 가상 데이터 | INCOME.csv에 `CHILDREN` 칸 추가 · 모두 0 | 급여구간별 자녀 수 공공 통계가 없어 만들지 않음 (근거 없는 값은 넣지 않음) |
| 숫자 | 테이블 18 · 칸 164 → **166** · 인덱스 19 · UNIQUE 10 · CHECK 40 (개수 그대로) · 기준값 36 → **40행** | |

- 새 계정: 01 → 02 → 03 그대로
- **이미 v3.2로 만든 계정(교육원 공용 DB 포함): `88_v3.2에서_v3.3로.sql` 한 번 실행** — 맨 위 확인 0·0·18·19 → 맨 아래 CHECK 40 · INCOME 칸 15 · 예측입력 칸 11 · 기준 22 · 틀린 값 테스트 4줄 모두 OK (ROLLBACK)
- 백엔드:
  - 카드 기본한도는 `CHILDREN` 0이면 `CARD_LIMIT_BASE`, 1이면 `CARD_LIMIT_CHILD1`, 2 이상이면 `CARD_LIMIT_CHILD2` · 그 코드 안에서 총급여 구간(`SALARY_MIN`~`SALARY_MAX`)으로 행 선택 (v3.6 · 예전 `_LOW/_HIGH` 코드 없음) · 추가한도(`CARD_LIMIT_EXTRA`)는 자녀 수와 무관
  - 항목은 `TYPE_ID` 숫자 말고 **`TAX_YEAR` + `TYPE_CODE` + 총급여 구간으로 찾기** (v3.6)
  - 입력 화면: 「20세 이하 자녀 수」는 부양가족 수 이하인지 백엔드에서 확인 (DB CHECK 아님 · 부양가족에 부모 등도 포함돼서)

## v3.2 (10/23 · 문의 답변 검사 · 분류 사용 여부)

| 바뀐 것 | 내용 | 이유 |
|---|---|---|
| 문의 답변 CHECK `CK_INQUIRY_ANSWER` | 답변 완료(ANSWERED)면 **답변 내용·답변일·답변자 모두 필수** · 접수(WAITING)면 셋 다 비어 있어야 함 | 예전에는 답변일만 확인해서 내용·답변자 없이도 「답변 완료」로 저장됐음 |
| 분류 쿼리 04 · 07 (파일만) | 사용 중인 분류(`SPEND_CATEGORY.USE_YN = 'Y'`)의 목록만 대조 | 분류를 'N'으로 꺼도 그 분류로 들어가던 것 방지 · 지금 5개 모두 사용 중이라 결과 변화 없음 |
| 숫자 | 테이블 18 · 칸 164 · 인덱스 19 · UNIQUE 10 · CHECK 40 (변화 없음) | |

- 새 계정: 01 → 02 → 03 그대로
- **이미 v3.1로 만든 계정(교육원 공용 DB 포함): `90_v3.1에서_v3.2로.sql` 한 번 실행** — 맨 위 확인 0 → 맨 아래 CHECK 40 · 답변CHECK ENABLED · 틀린 값 테스트 5줄 모두 OK (ROLLBACK)
- 백엔드: 관리자 답변 저장은 `STATUS = 'ANSWERED', ANSWER, ANSWERED_AT = SYSDATE, ANSWERED_BY = 관리자 번호`를 한 UPDATE로

## v3.1 (10/23 · 재검토 후 보완)

| 바뀐 것 | 내용 | 이유 |
|---|---|---|
| 인덱스 `IX_EXPENSE_UPLOAD` | (UPLOAD_ID) → **(UPLOAD_ID, MEMBER_ID)** | v3.0에서 지출 → 업로드 FK가 두 칸이 됐는데 인덱스는 한 칸이라, Oracle이 FK에 인덱스가 없다고 보고 업로드 삭제·탈퇴 때 EXPENSE 전체를 잠글 수 있음 (개수는 19 그대로) |
| 정제 함수 `FN_NORMALIZE_NAME` (04) | ℃ · 아래첨자 숫자(₂ 등) · ⅵ~ⅹ · 원 숫자 11~20 · ㈕도 파이썬(07, NFKC)과 같게 바꿈 | 예전에는 이 글자를 지워서 목록 4행(예: 「카페(cafe)66℃」)이 SQL 분류로는 안 걸렸음 · 목록 8만 행 + 가상 카드 내역 전부로 SQL·파이썬 정제 결과가 같은지 확인 |
| 분류 쿼리 (04) | 같은 분류·같은 길이면 `LIST_ID`가 작은 목록 선택 | 07(파이썬)과 분류 근거(LIST_ID)까지 같게 |
| 07 카드 분류 | 목록에 다른 분류 번호가 있어도 멈추지 않음 (04와 같이 맨 뒤 순위) | 예외 상황에서 오류로 멈추던 것 방지 |
| 97 탈퇴 처리 | `ROLE = 'USER'` 추가 | 관리자가 탈퇴해도 권한이 남지 않게 |
| 99 적재 | `--truncate`는 새 계정 전용 (서비스 데이터가 있으면 멈춤) · 로그인 실패 횟수·잠금 시각 칸 처리 | 공용 DB에서 FK 오류·지우면 안 되는 데이터 삭제 방지 |

- 새 계정: 01 → 02 → 03 그대로
- **이미 v3.0으로 만든 계정(교육원 공용 DB 포함): `91_v3.0에서_v3.1로.sql` 한 번 실행** — 테이블·데이터는 안 바뀜 (인덱스 1개 · 함수 1개만 다시 만듦)
  - 맨 아래 확인: 인덱스 칸 UPLOAD_ID·MEMBER_ID 두 줄 · 일반 인덱스 19 · 함수 VALID · 정제 테스트 4줄 OK · 목록 4행 OK
- 가상 카드 내역은 이 글자들이 없어서 분류 결과 변화 없음 (다시 분류 안 해도 됨)

## v3.0 (10/23 · 서비스 기준 점검)

| 바뀐 것 | 내용 | 이유 |
|---|---|---|
| 로그인 잠금 `MEMBER.LOGIN_FAIL_COUNT` · `LOCKED_UNTIL` | 연속 실패 횟수 NUMBER(2) DEFAULT 0 + CHECK(0 이상) · 잠금 해제 시각 DATE | 비밀번호 대입 막기 (비밀번호 재설정 FAIL_COUNT와 같은 방식 · 서버 재시작·여러 대에도 유지) |
| 동의 버전 `MEMBER.TERMS_VERSION` · `PRIVACY_VERSION` | VARCHAR2(10) NOT NULL · **기본값 없음** · 기존·가상 회원은 '1.0' | 약관이 바뀌면 어떤 버전에 동의했는지 알아야 다시 동의를 받을 수 있음 · 기본값이 있으면 빠뜨려도 '1.0'으로 잘못 기록됨 |
| 지출-업로드 회원 일치 | `UQ_CARD_UPLOAD_MEMBER (UPLOAD_ID, MEMBER_ID)` + `FK_EXPENSE_UPLOAD`를 (UPLOAD_ID, MEMBER_ID) 두 칸으로 | 다른 회원의 업로드에 지출이 붙는 실수를 DB가 막음 |
| 목록 중복 금지 | `UQ_MERCHANT_LIST_NAME (NORMALIZED_NAME, CATEGORY_ID)` · 이름 인덱스 `IX_MERCHANT_LIST_NAME`은 삭제(이 인덱스가 대신함) | 목록을 다시 넣을 때 같은 행이 두 번 들어가는 것 방지 |
| 예측 결과 NOT NULL | PREDICTION의 TAXABLE_INCOME · CALCULATED_TAX · DECIDED_TAX · EXPECTED_REFUND | 계산하면 항상 값이 있음 (v2.7 NULL 막기 원칙) |
| 세법 기준값 검사 6개 | 비율 0~100(공제·구간·감면) · 구간 끝 > 시작 · 최소 나이 ≤ 최대 나이 · 카드 공제 행은 분류 필수 | 관리자 「공제 기준 관리」 화면의 오타가 계산에 들어가는 것 방지 |
| 인덱스 삭제 `IX_EXPENSE_CATEGORY` | 지출 분류 인덱스 | 분류 행은 지우지 않아 잠금 걱정 없음 · 값 5개라 조회에 안 쓰임 · 목록 인덱스 `IX_EXPENSE_LIST`는 「고친 목록 행으로 분류된 지출」 확인용으로 남김 |
| 문서 | README · 01 주석 · 97을 **파이썬(oracledb) 기준**으로 수정 (`#{...}` → `:바인드`) | 팀 백엔드는 파이썬 |
| 숫자 | 테이블 18 · 칸 160 → **164** · 시퀀스 16 · 일반 인덱스 21 → **19** · UNIQUE 10 · **CHECK 40** · CASCADE 5 · SET NULL 2 | |

- 새 계정: 01 → 02 → 03 그대로 (가상 회원 1,001명은 버전 '1.0' · 실패 0으로 들어감)
- **이미 v2.9로 만든 계정(교육원 공용 DB 포함): `92_v2.9에서_v3.0로.sql` 한 번 실행**
  - 맨 위 「실행 전 확인」 3개가 모두 0인지 먼저 봐요.
  - 맨 아래 확인 결과: CHECK 40 · UNIQUE 10 · 일반 인덱스 19 · 지출FK 칸 2 · 회원 1,001 · MEMBER 칸 23
  - 「일부러 틀린 값 넣어 보기」 12줄이 모두 `OK`면 정상 (끝에 ROLLBACK이라 데이터는 안 바뀜 · 보기 > DBMS 출력 창 켜기)

### 운영 규칙: DB 변경은 DB 담당을 거쳐서

- 백엔드·화면은 이 설계(v3.8)에 맞춰 개발해요. 칸·테이블·제약이 더 필요하면 **이유와 함께 DB 담당(이우진)에게 요청**해요.
- DB 담당이 `01_schema.sql` 수정 + 변경 스크립트(예: `87_v3.3에서_v3.4로.sql`) + ERDCloud + 노션을 함께 맞춘 뒤, 교육원 공용 DB에는 그 변경 스크립트로 적용해요.
- **공용 DB에 각자 직접 ALTER·DROP 하지 않기** — SQL 파일·ERDCloud·노션이 실제 DB와 달라져요. (데이터 INSERT·UPDATE 테스트는 괜찮아요)

### 운영 규칙: 분류·목록 행은 지우지 않음

- `SPEND_CATEGORY`·`MERCHANT_LIST` 행은 **DELETE하지 않고 `USE_YN = 'N'`** 으로 바꿔요. 이름이 바뀌면 'N'으로 두고 새 이름으로 새 행을 추가해요.
- 이유: 지출(EXPENSE)의 `LIST_ID`가 어느 목록 행과 일치해 분류됐는지(분류 근거)를 가리켜요. 행을 지우면 근거가 사라지고, 그 행을 가리키는 지출이 있으면 Oracle이 삭제를 막아요(ORA-02292).
- **같은 이름·같은 분류를 다시 쓰게 되면 새 행을 넣지 말고 기존 행을 `USE_YN = 'Y'`로 되돌려요.** 'N' 행도 중복 금지(UQ_MERCHANT_LIST_NAME)에 포함돼서 새로 넣으면 ORA-00001이 나요. 분류 근거 번호도 그대로 유지돼요.
- 대조 쿼리(04)는 `USE_YN = 'Y'` 행만 써요. 목록 파이프라인(08) `--sql`은 기존 행의 `LIST_ID`를 그대로 두고, 이름이 바뀐 행은 UPDATE · 없어진 행은 `USE_YN = 'N'` · 새 행은 INSERT로 맞춰요 (DELETE 없음 · v3.2).
- 새 행이 없어진 행과 (정제 이름, 분류)가 같으면 08이 새 행을 넣지 않고 기존 행을 다시 'Y'로 켜요. 그래도 다른 행과 겹치는 것은 SQL을 만들지 않고 파일 맨 위에 「확인 필요」로 남겨요 (중복 금지 ORA-00001 방지). 새 행을 넣은 뒤에는 `98_시퀀스_재설정.sql` 실행.

### 백엔드 규칙 (v3.0)

| 기능 | 규칙 |
|---|---|
| 로그인 | ① `LOCKED_UNTIL > SYSDATE`면 「10분 뒤 다시 시도」 (잠긴 동안은 실패 횟수를 올리지 않음) ② 틀리면 `UPDATE MEMBER SET LOGIN_FAIL_COUNT = LOGIN_FAIL_COUNT + 1 WHERE MEMBER_ID = :member_id` (읽고 +1 해서 쓰지 말 것 → 동시에 틀리면 덜 셈) ③ 5번째 실패면 `SET LOGIN_FAIL_COUNT = 0, LOCKED_UNTIL = SYSDATE + 10/1440` (잠글 때 0으로 → 풀리자마자 다시 잠기거나 99를 넘어 ORA-01438 나는 것 방지) ④ 성공하면 `SET LOGIN_FAIL_COUNT = 0, LOCKED_UNTIL = NULL` · 시각 비교는 파이썬 시각 말고 DB의 `SYSDATE`로 |
| 가입 | `TERMS_VERSION`·`PRIVACY_VERSION`에 **현재 버전을 꼭 넣기** (기본값 없음 → 빠뜨리면 ORA-01400) · 약관이 바뀌면 로그인할 때 회원 버전과 현재 버전을 비교해 다르면 다시 동의 → 버전·동의 일시 함께 UPDATE |
| 예측 저장 | **계산을 끝내고 결과 4칸을 채워 한 번에 INSERT** (빈 값으로 먼저 넣고 나중에 UPDATE하면 ORA-01400) |
| 지출 저장 | `MEMBER_ID`는 그 업로드의 회원번호와 같아야 함 (다르면 ORA-02291) |
| 분류·목록 | DELETE 쓰지 않기 (위 운영 규칙) |

### DB로는 못 막아서 백엔드가 확인할 것

1. **만 14세 미만 가입 차단** — CHECK에는 오늘 날짜(SYSDATE)를 쓸 수 없어서 가입할 때 생년월일로 확인
2. **문의 답변자는 관리자** — `INQUIRY.ANSWERED_BY`가 `ROLE = 'ADMIN'`인 회원인지 (다른 테이블 값이라 CHECK 불가)
3. **연도 맞추기** — 예측(`PREDICTION.TAX_YEAR`)과 계산에 쓴 공제 기준값(`DEDUCTION_TYPE.TAX_YEAR` 등)의 연도가 같은지
4. **`withdrawn_`으로 시작하는 아이디·이메일 가입 막기** (v3.1) — 탈퇴 회원 행이 `withdrawn_회원번호`로 바뀌기 때문에, 누가 미리 그 이름으로 가입해 두면 그 번호 회원이 탈퇴할 때 ORA-00001

나중에 정할 것 (P1): 세법 기준값 변경 이력(이전 값까지 · v3.4에서 수정일·수정자는 반영) · IP 차단 목록(v3.4에서 접근 기록 IP·결과는 반영) · DDoS는 배포할 때 서버 앞단(Nginx 요청 수 제한 등)에서 막음

## v2.9 (10/23 · 기획발표 후)

| 바뀐 것 | 내용 |
|---|---|
| 데이터 구분 `DATA_ORIGIN` | `COLLECTED`(수집) · `GENERATED`(생성·더미) · `INPUT`(사이트 입력) · MEMBER·INCOME·CARD_UPLOAD 기본값 INPUT, MERCHANT_LIST 기본값 COLLECTED · 카드 내역(EXPENSE)은 업로드의 구분을 따름 · 강사님 피드백(수집/생성 구분) + 팀 협의(입력 추가) |
| 세법 근거 `SOURCE_NOTE` | DEDUCTION_TYPE·TAX_BRACKET·BENEFIT_CONDITION · 국세청 신고안내 쪽수·법 조문 (2026년 40행 모두 채움) · 관리자 「공제 기준 관리」 화면 메모 칸으로도 씀 |
| `MERCHANT_LIST.UPDATED_AT` | 목록 수정일 · 08 파이프라인 `--sql`이 만드는 UPDATE도 수정일을 갱신 |
| 숫자 | 테이블 18 · 시퀀스 16 · 인덱스 21 · **CHECK 33** · CASCADE 5 · SET NULL 2 |

- 새 계정: 01 → 02 → 03 그대로 (가상 데이터는 GENERATED, 가맹점 목록은 COLLECTED로 들어감)
- **이미 v2.8로 만든 계정(교육원 공용 DB 포함): `93_v2.8에서_v2.9로.sql` 한 번 실행** → 맨 아래 확인 결과가 GENERATED 1,001/1,000/100 · COLLECTED 80,665 · 근거 없음 0/0/0 · CHECK 33 · 수정일 10/22 행 9
- 백엔드: 사이트에서 가입·입력·업로드하는 INSERT는 DATA_ORIGIN을 안 넣으면 기본값 INPUT이 들어감 (칸 이름을 적는 INSERT 기준)

이 폴더는 `희망환급_데이터` 폴더 안에 두고 써요. 파이썬 스크립트는 바로 위 폴더의 MERCHANT_LIST 정제본, 국세통계 xlsx, 상가정보 샘플을 읽어요.

## 가장 쉬운 방법: SQL Developer만으로 (10/20 실제 실행 확인)

1. **인코딩 확인**
   - 한글 Windows의 SQL Developer는 기본 인코딩이 MS949예요.
   - 그대로 쓰려면 **`cp949` 폴더 안의 파일**을 실행해요.
   - 도구 > 환경설정 > 환경 > 인코딩을 UTF-8로 바꿨다면 이 폴더(UTF-8) 파일을 써요.
   - 잘못 고르면 한글 주석·이름이 깨져요.
2. 워크시트에서 아래를 순서대로 **스크립트 실행(F5)** 해요. 경로는 각자 위치로 바꿔요.

```sql
@"C:\...\희망환급_데이터\DB_작업\cp949\01_schema.sql"
@"C:\...\희망환급_데이터\DB_작업\cp949\02_기준데이터.sql"
@"C:\...\희망환급_데이터\DB_작업\cp949\03_데이터적재.sql"
```

3. `03_데이터적재.sql`은 약 3~5분 걸려요. 마지막에 통계 수집 후 라벨별 건수와 테이블별 건수가 나오면 끝이에요.

| 순서 | 파일 | 하는 일 |
|---|---|---|
| 1 | `01_schema.sql` | 20개 테이블 + 시퀀스 18 + 인덱스 25 + UNIQUE 12 + CHECK 49 + CASCADE 5·SET NULL 2 (v3.8 · 칸 208) (칸마다 옆에 한글 설명 주석, 끝에 COMMENT ON) |
| 2 | `02_기준데이터.sql` | SPEND_CATEGORY 5, DEDUCTION_TYPE 22(v3.6 총급여 구간 행), TAX_BRACKET 15, BENEFIT_CONDITION 3 넣기 (2026년 귀속) + 그룹 비교 통계 STAT_FILE 4 · GROUP_STAT 28 (v3.8 · 2024년 귀속 국세통계) |
| 3 | `03_데이터적재.sql` | MERCHANT_LIST 80,665 + 가상 MEMBER 1,001 · INCOME 1,000 · CARD_UPLOAD 100 · EXPENSE 10,453 적재 → 시퀀스 번호 맞춤 → 가맹점명 정제 함수 생성 → 카드 내역 자동 분류 → 통계 수집 |
| (v3.7 계정만, 10/28) | `82_v3.7에서_v3.8로.sql` | 이미 v3.7로 만든 계정에 v3.8 변경(금융 동의 칸 2 · 문의 유형 · 확인 중 상태 · 통계 테이블 2 + 28행)만 적용 + 확인 조회 + 틀린 값 테스트 5개(ROLLBACK). 새 계정은 01~03만 실행 |
| (v3.6 계정만, 10/27) | `83_v3.6에서_v3.7로.sql` | 이미 v3.6으로 만든 계정에 v3.7 변경(EXPENSE.USER_EDITED_YN · CK_EXPENSE_EDITED 삭제)만 적용 + 확인 조회. 새 계정은 01~03만 실행 |
| (v3.5 계정만, 10/27) | `84_v3.5에서_v3.6로.sql` | 이미 v3.5로 만든 계정에 v3.6 변경(DEDUCTION_TYPE 총급여 구간 SALARY_MIN·SALARY_MAX · UNIQUE · _LOW/_HIGH 코드 통합)만 적용 + 확인 조회 + 틀린 값 테스트 3개(ROLLBACK). 새 계정은 01~03만 실행 |
| (v3.4 계정만, 10/26) | `85_v3.4에서_v3.5로.sql` | 이미 v3.4로 만든 계정에 v3.5 변경(MEMBER.NAME NULL 허용)만 적용 + 확인 조회 + 이름 없이 가입 테스트(ROLLBACK). 새 계정은 01~03만 실행 |
| (v3.3 계정만, 10/25) | `87_v3.3에서_v3.4로.sql` | 이미 v3.3으로 만든 계정에 v3.4 변경(이메일 인증 여부 · 접근 기록 IP·결과 · 기준값 수정일·수정자 · 인덱스 4)만 적용 + 확인 조회 + 틀린 값 테스트 4개(ROLLBACK). 새 계정은 01~03만 실행 · 10/25 교육원 공용 DB 적용 완료 |
| (v3.2 계정만, 10/23) | `88_v3.2에서_v3.3로.sql` | 이미 v3.2로 만든 계정에 v3.3 변경(자녀 수 칸 2개 · CHECK 2개 · 자녀 한도 4행)만 적용 + 확인 조회 + 틀린 값 테스트 4개(ROLLBACK). 새 계정은 01~03만 실행 |
| (v3.1 계정만, 10/23) | `90_v3.1에서_v3.2로.sql` | 이미 v3.1로 만든 계정에 v3.2 변경(문의 답변 CHECK)만 적용 + 확인 조회 + 틀린 값 테스트 5개(ROLLBACK). 새 계정은 01~03만 실행 |
| (v3.0 계정만, 10/23) | `91_v3.0에서_v3.1로.sql` | 이미 v3.0으로 만든 계정에 v3.1 변경(지출 업로드 인덱스 두 칸 · 정제 함수)만 적용 + 확인 조회. 테이블·데이터는 안 바뀜. 새 계정은 01~03만 실행 |
| (v2.9 계정만, 10/23) | `92_v2.9에서_v3.0로.sql` | 이미 v2.9로 만든 계정에 v3.0 변경(로그인 잠금·동의 버전·지출-업로드 회원 일치·목록 중복 금지·예측 NOT NULL·기준값 검사·인덱스 정리)만 적용 + 확인 조회 + 일부러 틀린 값 테스트(ROLLBACK). 새 계정은 01~03만 실행 |
| (v2.8 계정만, 10/23) | `93_v2.8에서_v2.9로.sql` | 이미 v2.8로 만든 계정에 v2.9 변경(데이터 구분·세법 근거·목록 수정일)만 ALTER로 적용 + 더미 범위 GENERATED·근거 채우기 + 확인 조회. 새 계정은 01~03만 실행 |
| (v2.7 계정만) | `95_v2.7에서_v2.8로.sql` | 이미 v2.7로 만든 계정(데이터 있음)에 v2.8 변경(INCOME 등록일)만 ALTER로 적용. 새 계정은 01만 실행 |
| (v2.6 계정만) | `96_v2.6에서_v2.7로.sql` | 이미 v2.6으로 만든 계정(데이터 있음)에 v2.7 변경만 ALTER로 적용. 새 계정은 01만 실행 |
| (운영할 때) | `97_데이터정리.sql` | 만료된 인증 코드·오래된 접근 기록 삭제 + **회원 탈퇴 처리 (v3.8: 탈퇴 요청은 상태만 · 30일 지난 회원 식별 불가 처리는 바로 실행 가능)** |
| (필요할 때) | `98_시퀀스_재설정.sql` | 번호(PK)를 직접 지정해 데이터를 더 넣은 뒤 시퀀스 16개를 「최대 번호 + 1」로 다시 맞춤 (안 하면 다음 가입·INSERT에서 ORA-00001) · 팀원이 안 쓰는 시간에 실행 |
| (목록 만들 때) | `08_목록_파이프라인.py` | 가공본 CSV(희망환급_데이터 폴더) → 정제 → 중복 제거 → 대조 방식 → 기존 정제본과 비교 → `새목록/`에 결과·비교 리포트 (`--sql`이면 `새목록/목록_반영.sql`: 이름 수정 · 없어진 행 끄기 · 새 행 추가 · 같은 이름 다시 켜기, DELETE 없음 · v3.2) · 정제 함수는 07과 같음 · 기존 행은 LIST_ID 유지 (10/22) |
| (가상 데이터 넣은 계정, 10/23) | `89_가상회원_입사일수정.sql` | 가상 회원 45번 입사일이 만 14세(2021-07-16)인데 중소기업 감면 Y → 2021-10-25(만 15세)로 1행만 수정 + 확인 조회. 05는 「입사일은 만 15세 이후」로 고침(다른 회원 값은 그대로). 새 계정은 03에 이미 반영 |
| (이미 만든 계정, 10/23) | `86_포함대조_정리.sql` | 포함 대조(CONTAINS) 행 중 일반 단어라 오분류되던 85행(무인양품 · ○○교육 27 · ○○기독교 58)을 EXACT로. 실행 전 확인 → UPDATE 2개 → 확인(EXACT 85 · 남은 CONTAINS 612) → COMMIT · DB 구조 변경 없음 · 가상 카드 내역 분류 결과 변화 없음 · 10/23 교육원 공용 DB 적용 완료 |
| (v2.8 계정, 10/22) | `94_가맹점목록_정제수정.sql` | 08로 찾은 예전 정제 오류 9행만 고침(LIST_ID 그대로): 「(주」만 있어도 지우던 버그 7행 · 「(주식회사」 1행 · 「CGV거제 6관」→「CGV거」 1행. 카드 분류 결과는 가상 데이터 기준 변화 없음 · 새 계정은 03에 이미 반영 |
| (백엔드용) | `07_카드분류.py` | 카드 내역 자동 분류 파이썬 버전 (04와 같은 규칙) · 서버 시작 때 `MerchantMatcher.from_db(conn)` 1번 → 업로드마다 `classify_upload(conn, upload_id, matcher)` · `python 07_카드분류.py`로 CSV 확인 시 Oracle 결과와 5개 분류 건수 같음 (10/22) |
| (참고) | `04_분류쿼리.sql` | 업로드 전 중복 확인 조회(0) + 가맹점명 정제 함수 + 업로드 1건 분류 쿼리 (**백엔드가 카드 파일 업로드 직후 호출**, `:upload_id` 바인드) |

## 파이썬으로 다시 만들 때

| 파일 | 하는 일 |
|---|---|
| `05_가상데이터_생성.py` | 가상 회원·소득·카드 내역 CSV 다시 만들기 → `가상데이터/`, 업로드 파일 예시 100개 → `카드내역_업로드_예시/` 폴더 (zip은 이 폴더를 따로 압축한 것) · 입사일은 만 15세 이후 (v3.2) |
| `03_데이터적재_SQL만들기.py` | CSV로 `03_데이터적재.sql` 다시 만들기 (`python 03_데이터적재_SQL만들기.py cp949` 하면 `cp949/03_데이터적재.sql`에 MS949판 · 실행 안내와 같은 위치) |
| `99_load_csv.py` | 파이썬(oracledb)으로 바로 적재: `python 99_load_csv.py --user 계정 --password 비번 --dsn localhost:1521/XEPDB1` (주소는 예시 · `--truncate`는 새 계정 전용, 서비스 데이터가 있으면 멈춤) |
| `06_비교통계_정리.py` | 대시보드 「나와 비슷한 사람들은」용 국세통계 2024년 귀속 정리 → `비교통계/` |

`pip install pandas openpyxl bcrypt oracledb`

## 10/21 실제 실행 결과 (스키마 v2.4 · SQL Developer · 학원 PC Oracle · 테스트 계정 HEEMANG)

계정을 새로 만들고 01 → 02 → 03 순서로 처음부터 실행했고 모두 정상이에요. (v2.3 이메일·비밀번호 재설정도 이때 같이 확인)

| 확인 항목 | 결과 |
|---|---|
| 스키마 | 테이블 17 · 시퀀스 16 · 인덱스(IX_) 21 · CHECK(CK_) 22 · CASCADE/SET NULL 5 |
| 기준데이터 | SPEND_CATEGORY 5 · DEDUCTION_TYPE 22 · TAX_BRACKET 15 · BENEFIT_CONDITION 3 |
| 적재 | MERCHANT_LIST 80,665 · MEMBER 1,001 · INCOME 1,000 · CARD_UPLOAD 100 · EXPENSE 10,453 |
| 자동 분류 | 일반 5,811 · 문화체육 1,590 · 대중교통 1,258 · 공제 대상 아님 1,007 · 전통시장 787 (10/20 결과·Python 검증과 같음) |
| 통계 수집 | 17개 테이블 모두 LAST_ANALYZED 있음 |
| 시퀀스 | SEQ_EXPENSE 10,454 · SEQ_MEMBER 1,002부터 (테스트에서 NEXTVAL 한 번 써서 확인 시점엔 1,003 — 번호가 건너뛰는 건 정상) |
| 탈퇴 → CASCADE | 회원 1번 업로드 삭제 → 그 회원 지출 0건(EXPENSE 자동 삭제) |
| 재가입 | 탈퇴 회원의 아이디·이메일을 `withdrawn_1`로 바꾼 뒤 같은 `test0001`·`test0001@example.com`으로 INSERT 성공 |
| 값 제한 | 탈퇴일 없이 `STATUS='WITHDRAWN'` → ORA-02290(CK_MEMBER_WITHDRAWN)으로 막힘 |
| 되돌림 | 테스트는 ROLLBACK → 회원 1번 `test0001 / ACTIVE` 그대로 |

<details><summary>10/20 결과 (스키마 v2.2)</summary>

테이블 16 · 시퀀스 15 · 인덱스 18 · CHECK 18 · 적재·분류 건수는 위와 같음

</details>

테스트 계정 만들기 (SYS 접속 워크시트):

```sql
ALTER SESSION SET "_ORACLE_SCRIPT" = true;
CREATE USER HEEMANG IDENTIFIED BY heemang;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO HEEMANG;
ALTER SESSION SET CURRENT_SCHEMA = HEEMANG;   -- 이 워크시트에서 만드는 테이블이 HEEMANG 소유가 됨
```

※ SYS로 접속한 채 확인할 때는 `USER_SEQUENCES`·`USER_INDEXES`가 아니라 `ALL_SEQUENCES WHERE SEQUENCE_OWNER = 'HEEMANG'`, `ALL_INDEXES WHERE OWNER = 'HEEMANG'`으로 봐야 해요. (`USER_` 뷰는 접속 계정인 SYS 것을 보여 줌)

테스트하면서 고친 것

1. 공제 항목 이름이 50바이트를 넘어 3줄이 안 들어감 → 이름을 짧게
2. 분류 쿼리가 느림(업로드 100건에 4분 넘게) → 가맹점명을 먼저 한 번만 정제하게 바꿈(업로드 1건 약 0.8초)
3. 「상영관Ⅰ」 같은 로마 숫자가 Python과 다르게 정제됨 → 함수에서 Ⅰ→I, ①→1 변환 추가

## 스키마 v2.8 — INCOME 등록일 추가 (10/22)

| 바꾼 것 | 이유 | 백엔드 규칙 |
| --- | --- | --- |
| `INCOME.CREATED_AT` DATE DEFAULT SYSDATE NOT NULL (맨 뒤 칸) | 다른 테이블처럼 등록일·수정일을 둘 다 둠 (팀 질문 반영) | INSERT에서 빼면 SYSDATE가 들어감 · NULL을 넣으면 ORA-01400 |

합계: 테이블 18 · 시퀀스 16 · 인덱스 21 · CHECK 29 · CASCADE 5 · SET NULL 2 · INCOME 칸 12 → 13 · 가상 데이터 INCOME.csv에 CREATED_AT 추가(수정일과 같은 날짜)
이미 v2.7로 만든 계정: `95_v2.7에서_v2.8로.sql` 실행 (기존 행은 등록일 = 수정일로 채움)

## 스키마 v2.7 — NULL·중복·음수 막기 (10/21)

| 바꾼 것 | 이유 | 백엔드 규칙 |
|---|---|---|
| 기본값(DEFAULT) 있는 칸 37개에 `NOT NULL` (예: `INQUIRY.STATUS`, `*_YN`, `CREATED_AT`, 금액 칸) | INSERT에 칸 이름을 적고 값으로 `NULL`(파이썬 `None`)을 넣으면 DEFAULT가 적용되지 않음. 예: STATUS가 NULL인 문의는 CHECK도 통과해 버림 | 기본값을 쓰려면 INSERT에서 그 칸을 빼거나 값을 직접 넣기 (NULL을 넣으면 ORA-01400) |
| `CK_MEMBER_EMAIL_LOWER` : `EMAIL = LOWER(EMAIL)` | UNIQUE는 대소문자를 구분 → `A@x.com`과 `a@x.com`이 따로 가입되던 문제 | 가입·아이디 찾기·재설정 모두 `LOWER(:email)`로 저장·조회 |
| `PREDICTION.WITHHELD_TAX` 삭제 | `PREDICTION_INPUT.WITHHELD_TAX`와 같은 값(중복) → 둘이 달라질 위험 | 기납부세액은 `PREDICTION_INPUT`에서 조회 |
| `CK_INCOME_AMOUNT` · `CK_PRED_INPUT_AMOUNT` · `CK_MEMBER_MILITARY` (0 이상) | 급여·세액·월세·인원·개월에 음수 입력 방지 | 카드 금액(`EXPENSE.AMOUNT`)은 취소 건 음수가 올 수 있어 제외 |

합계: 테이블 18 · 시퀀스 16 · 인덱스 21 · CHECK 29 · CASCADE 5 / SET NULL 2 · PREDICTION 칸 11 → 10
기존 데이터: 가상 데이터·기준 데이터에 해당 칸 NULL·음수·대문자 이메일 없음 (CSV와 03 SQL로 확인) → 02·03 그대로 사용
이미 v2.6으로 만든 계정: `96_v2.6에서_v2.7로.sql` 실행 (맨 위 확인 쿼리가 전부 0인지 먼저 봄)

## 스키마 v2.6 — 조건 변경 시뮬레이션 입력값 저장 (10/21 · Oracle 실행 확인)

시뮬레이션 흐름(결과 대시보드 → 「조건 변경」 → 이전 값이 채워진 입력 화면 → 다시 계산 → 이전 결과와 비교 설명)을 위해 추가.

| 바꾼 것 | 이유 | 백엔드 규칙 |
|---|---|---|
| `PREDICTION.BASE_PREDICTION_ID` (자기 참조 FK, `ON DELETE SET NULL`) + 인덱스 `IX_PREDICTION_BASE` | 새 결과가 어떤 결과를 기준으로 조건을 바꾼 건지 연결 → 이전 결과와 비교 | 첫 계산(「현재」)은 NULL, 시뮬레이션은 바꾸기 전 결과의 PREDICTION_ID |
| 새 테이블 `PREDICTION_INPUT` (예측 1건당 1행, PK = PREDICTION_ID, `ON DELETE CASCADE`) | 시뮬레이션 조건을 실제 회원 정보(INCOME)에 덮어쓰지 않고 따로 저장 · 그때 어떤 조건으로 계산했는지 남김 | 계산할 때마다(「현재」 포함) 입력값을 1행 저장 · INCOME은 사용자가 내 정보에서 직접 고칠 때만 수정 |
| 카드 사용액 | 분류별 금액은 이미 `PREDICTION_DETAIL.BASE_AMOUNT`에 저장됨 → 별도 칸 없음 | 「전통시장 10만 원 더」 같은 조정은 해당 항목 BASE_AMOUNT에 반영해 저장 |

합계: 테이블 18 · 시퀀스 16(새 테이블은 PREDICTION_ID를 그대로 써서 시퀀스 없음) · 인덱스 21 · CHECK 25 · CASCADE 5 / SET NULL 2

10/21 확인: 새 01을 임시 계정에서 처음부터 실행 → 테이블 18 · 시퀀스 16 · 인덱스 21 · CHECK 25 · CASCADE/SET NULL 7 / 데이터 있는 HEEMANG 계정엔 ALTER로 적용 → 기준·시나리오 비교 조회 정상(423,000 → 561,000, 월세 0 → 500,000) · 같은 예측에 입력값 두 번 → ORA-00001 · 기준 결과 삭제 시 시나리오의 BASE만 NULL, 기준의 입력값은 함께 삭제 (테스트는 ROLLBACK)

※ SYS로 접속해 임시 계정을 만들 때는 `ALTER SESSION SET "_ORACLE_SCRIPT" = true;`가 먼저 있어야 해요. 빠지면 CREATE USER가 실패하고, 이어서 실행한 01이 SYS 계정 안에 테이블을 만들어요. (10/21 실제로 겪음 → SYS에서 지움)

비교 조회 예:
```sql
SELECT S.SCENARIO_NAME, B.EXPECTED_REFUND 기준_환급, S.EXPECTED_REFUND 시나리오_환급,
       BI.MONTHLY_RENT 기준_월세, SI.MONTHLY_RENT 시나리오_월세
  FROM PREDICTION S
  JOIN PREDICTION B        ON B.PREDICTION_ID = S.BASE_PREDICTION_ID
  JOIN PREDICTION_INPUT SI ON SI.PREDICTION_ID = S.PREDICTION_ID
  JOIN PREDICTION_INPUT BI ON BI.PREDICTION_ID = B.PREDICTION_ID
 WHERE S.PREDICTION_ID = :prediction_id;
```

## 스키마 v2.5 — 작은 안전장치 3개 (10/21 · Oracle 실행 확인)

| 바꾼 것 | 이유 | 백엔드 규칙 |
|---|---|---|
| 인덱스 `IX_CHAT_MESSAGE_SESSION`을 `(SESSION_ID, MESSAGE_ID)`로 변경 | CREATED_AT(DATE)은 초 단위라 질문·답변을 같은 초에 저장하면 순서가 안 정해짐 | 대화 불러오기는 `ORDER BY MESSAGE_ID` |
| `PREDICTION_DETAIL`에 `UQ_DETAIL_PREDICTION_TYPE (PREDICTION_ID, TYPE_ID)` (기존 `IX_DETAIL_PREDICTION`은 삭제, 이 제약의 인덱스가 대신함) | 같은 계산을 두 번 저장하면 공제액이 두 배로 보이는 것 방지 | 예측 1건당 **공제 항목별 1행(합계)**으로 저장 |
| `PASSWORD_RESET.FAIL_COUNT` NUMBER(2) DEFAULT 0 + CHECK | 6자리 인증 코드를 계속 대입해 맞히는 것 방지 | 틀릴 때마다 +1, **5번 틀리면 그 코드는 무효**(새 코드 발급) |

10/21 확인: 새 01을 임시 계정에서 처음부터 실행 → 테이블 17 · 시퀀스 16 · 인덱스 20 · CHECK 23 · UQ 정상 / 데이터 있는 HEEMANG 계정엔 ALTER로 적용 → 같은 예측·같은 항목 두 번 INSERT 시 ORA-00001로 막힘 (테스트는 ROLLBACK)

## 스키마 v2.4 — 회원 관리·문의 답변·삭제 정리·통계 (10/21 · Oracle 실행 확인)

| 바꾼 것 | 이유 |
|---|---|
| `MEMBER.UPDATED_AT` | 회원정보 수정일 |
| `MEMBER.WITHDRAWN_AT` + CHECK `CK_MEMBER_WITHDRAWN` | 탈퇴일. 「탈퇴인데 탈퇴일 없음」·「활동 중인데 탈퇴일 있음」을 DB가 막음 |
| `MEMBER.TERMS_AGREED_AT`, `PRIVACY_AGREED_AT` (필수) | 이용약관·개인정보 수집·이용 동의 일시 기록 (가상 회원은 가입일로 채움) |
| `INQUIRY.ANSWER`, `ANSWERED_AT`, `ANSWERED_BY` → MEMBER + CHECK `CK_INQUIRY_ANSWER` | 상태는 ANSWERED인데 답변을 저장할 칸이 없던 문제. 답변 완료면 답변일 필수 (v3.2부터 답변 내용·답변자도 필수) |
| 인덱스 `IX_INQUIRY_STATUS (STATUS, CREATED_AT)`, `IX_INQUIRY_ANSWERED_BY` | 관리자 「답변 대기 문의 최신순」 · 새 FK 칸 |
| `ON DELETE CASCADE` 4곳: CARD_UPLOAD→EXPENSE, CHAT_SESSION→CHAT_MESSAGE, PREDICTION→PREDICTION_DETAIL·RECOMMENDATION | 부모만 지우면 자식도 삭제 → 탈퇴·업로드 삭제 코드가 단순해짐 |
| `ON DELETE SET NULL`: CHAT_SESSION.PREDICTION_ID | 예측을 지워도 대화방은 남고 연결만 끊김 |
| 03·99 적재 끝에 `DBMS_STATS.GATHER_SCHEMA_STATS` | 대량 적재 직후 통계가 없으면 Oracle이 인덱스를 안 쓸 수 있음 |
| `97_데이터정리.sql` 신규 | 만료 인증 코드·오래된 접근 기록 정리 + 탈퇴 처리 SQL |

**회원 정책 (10/21 확정)**
- 탈퇴: 회원 행은 남기고 아이디·이메일을 `withdrawn_회원번호`(이메일은 `@deleted.invalid`), 이름은 「탈퇴회원」으로 바꿈 → 같은 아이디·이메일로 재가입 가능, 문의·접근 기록 FK 유지
- 탈퇴 시 카드 내역·소득·예측·챗봇 대화·인증 코드는 바로 삭제 (문의·접근 기록은 남김)
- 만 14세 미만은 가입 차단 (백엔드에서 생년월일로 확인, DB 변경 없음)
- 주소·전화번호는 받지 않음 (쓰는 기능이 없음)
- ~~한계: 가입할 때 이메일 인증은 하지 않음 (비밀번호 재설정 때만 메일 인증)~~ → **팀 협의 필요**

## 스키마 v2.3 — 이메일·비밀번호 재설정 (10/21 · Oracle 실행 확인)

- `MEMBER.EMAIL` VARCHAR2(100) 추가: 필수 · 중복 불가(UQ_MEMBER_EMAIL) · 형식 CHECK(`@`와 `.` 포함)
  - 쓰는 곳: 아이디 찾기(이메일 → 마스킹한 아이디 안내), 비밀번호 재설정(이메일로 인증 코드)
  - 개인정보라 화면 표시 시 마스킹 대상
  - 가상 회원은 `test0001@example.com` 형식(example.com은 예시 전용 도메인이라 실제 메일이 가지 않음), 관리자 `admin@example.com`
- `PASSWORD_RESET` 테이블 신규(17번째): RESET_ID · MEMBER_ID → MEMBER · CODE_HASH(인증 코드 해시, 원문 저장 X) · EXPIRES_AT(만료) · USED_YN(한 번만 사용) · CREATED_AT
  - 비밀번호는 BCrypt라 원래 비밀번호를 알려줄 수 없음 → 「찾기」가 아니라 인증 후 **새 비밀번호로 재설정**
  - 백엔드 흐름: 이메일 입력 → 코드 생성·해시 저장·메일 발송 → 코드 확인(만료 전·USED_YN='N') → 새 비밀번호 BCrypt 저장 → USED_YN='Y'
- 인덱스 19 · CHECK 20 · 시퀀스 16 (SEQ_PASSWORD_RESET 추가, 98번 스크립트에도 반영)

## 스키마 v2.2 최적화 (10/20)

- 인덱스 18개: Oracle은 FK 칸에 인덱스를 자동으로 만들지 않아서 추가
  - 분류 쿼리 `EXPENSE (UPLOAD_ID)`, 대시보드 `EXPENSE (MEMBER_ID, USED_DATE)`, 대화 불러오기 `CHAT_MESSAGE (SESSION_ID, CREATED_AT)` 등
- 값 제한(CHECK) 18개: Y/N, 성별, 권한, 상태, 결제수단, 대조 방식, 회사 규모, 공제 종류, 문의 상태
- `TAX_BRACKET` 중복 방지 UNIQUE `(TAX_YEAR, BRACKET_TYPE, LOWER_AMOUNT)`
- `BENEFIT_CONDITION.BENEFIT_CODE` 추가: SME_YOUTH / RENT / HOUSING_SAVING (한글 이름 대신 코드로 찾기)
- 시퀀스: 한 번에 많이 들어가는 EXPENSE·CHAT_MESSAGE·ACCESS_LOG는 `CACHE 20`
- `CARD_UPLOAD.FILE_NAME` 200 → 255바이트

## 백엔드(파이썬 oracledb)에서 쓰는 법

- 바인드 변수는 `:이름` 형식이에요. 값은 딕셔너리로 넘겨요.
- PK 번호: INSERT 안에서 시퀀스를 쓰고, 새 번호가 필요하면 `RETURNING`으로 받아요.

```python
import oracledb
new_id = cur.var(oracledb.NUMBER)
cur.execute("""
    INSERT INTO CARD_UPLOAD (UPLOAD_ID, MEMBER_ID, FILE_NAME, ROW_COUNT)
    VALUES (SEQ_CARD_UPLOAD.NEXTVAL, :member_id, :file_name, :row_count)
    RETURNING UPLOAD_ID INTO :new_id""",
    member_id=member_id, file_name=file_name, row_count=len(rows), new_id=new_id)
upload_id = int(new_id.getvalue()[0])
# 지출은 executemany로 한 번에 (MEMBER_ID는 업로드 회원과 같게 · v3.0)
cur.executemany("""
    INSERT INTO EXPENSE (EXPENSE_ID, MEMBER_ID, UPLOAD_ID, USED_DATE, MERCHANT_NAME, PAY_METHOD, AMOUNT, CATEGORY_ID)
    VALUES (SEQ_EXPENSE.NEXTVAL, :member_id, :upload_id, :used_date, :merchant_name, :pay_method, :amount, 1)""", rows)
conn.commit()
```

- 기본값을 쓰려면 INSERT에서 그 칸을 빼요. `None`을 넣으면 NOT NULL 칸은 ORA-01400이에요.
- 카드 파일 저장 전: `04_분류쿼리.sql`의 0) 조회로 기존 지출과 겹치는 결제 수를 세서, 1건 이상이면 「이미 올린 내역과 같은 결제가 N건 있어요」 경고 → 사용자가 확인하면 저장 (막지는 않음 · DB 변경 없음)
- 카드 파일 업로드 직후 분류: `07_카드분류.py`의 `classify_upload(conn, upload_id, matcher)`를 부르거나, `04_분류쿼리.sql`의 3-1) UPDATE, 3-2) MERGE를 `:upload_id` 바인드 그대로 실행

## 데이터 근거

- 공제율·한도·세율: 국세청 「2025년 원천징수의무자를 위한 연말정산 신고안내」(26.02.03 수정본) + 국가법령정보센터 현행 조문
- 가상 회원·소득: 국세청 TASIS 2024년 귀속 4-2-3(성·연령), 4-2-4(급여 구간)
  - 성별·연령대 비율과 급여 구간 비율을 국세통계에 맞췄어요. 비교표는 `가상데이터/검증_*.csv`
  - 기납부세액, 사회보험료, 부양가족, 월세·청약·연금계좌, 중소기업 감면 비율은 4-2-4 구간별 실제 값으로 계산했어요.
- 카드 내역 금액·결제수단·라벨 비율은 **테스트용**이에요(공식 통계 없음). 그룹 비교 통계에는 쓰지 않아요.

## 정해 둔 값 (팀 확인 필요)

1. **카드 업로드 양식**: `이용일자, 가맹점명, 이용금액, 결제수단` (`카드내역_업로드양식.csv`)
   - DB 저장값: 신용 → `CREDIT`, 체크 → `CHECK`, 현금영수증 → `CASH`
   - 백엔드와 확정 필요
2. **회사 규모 COMPANY_SIZE**: `SME`(중소) / `MID`(중견) / `LARGE`(대기업)
   - 회원이 가입·자격 정보 화면에서 직접 고르는 값이에요(화면 선택지 → 이 코드).
   - 가상 회원은 중소기업 감면 대상만 `SME`이고 나머지는 비어 있어요.
   - 회사 규모 분포 공식 통계를 쓰지 않았기 때문이에요.
3. **월세 MONTHLY_RENT**: 월 금액(ERD 정의). 연간 = ×12
4. 가상 회원 비밀번호는 모두 `test1234!`(BCrypt), 관리자 아이디는 `admin`
5. **화면 마스킹 (10/21 확정)**: DB에는 원문 그대로 저장하고, 화면에 보여줄 때만 가려요(백엔드·화면에서 처리).
   - 이름 `NAME`: 가운데 글자 가림 — 홍길동 → 홍*동 (두 글자면 뒤 글자: 김철 → 김*)
   - 이메일 `EMAIL`: @ 앞 2글자만 보이고 나머지 가림 — test0001@example.com → te******@example.com
   - 주민번호: 저장하지 않기로 함
   - 주소·전화번호: 받지 않기로 함(10/21). 나중에 추가하게 되면 주소는 시·구까지만, 전화번호는 뒷자리 가림 — 010-1234-5678 → 010-1234-****
6. 근로소득공제 최대 2,000만 원, 근로소득세액공제 한도(max 식), 연금저축 단독 600만 원 한도는 계산 코드에서 처리해요(SQL 주석에 식이 있어요).
