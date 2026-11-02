-- 87_v3.3에서_v3.4로.sql · 이미 v3.3으로 만든 계정(교육원 공용 DB 포함)을 v3.4로 올리는 스크립트 (10/25)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.5가 됨 · v3.4→v3.5는 85번을 이것 다음에 실행
-- v3.2 계정이면 88(v3.2→v3.3)을 먼저 실행하고 이것을 실행 (순서 바꾸면 88의 INSERT가 칸 수 안 맞아 실패)
--
-- v3.4에서 바뀐 것 - 보안 점검(해커 입장에서 DB 훑어본 결과) 중 DB에서 막을 수 있는 3가지
--   1) MEMBER.EMAIL_VERIFIED_YN       이메일 인증 여부 · 기본값 N · 남의 이메일로 가입하면 진짜 주인이 가입 못 하고 재설정 코드가 엉뚱한 데로 가는 것 방지
--                                     → 백엔드: 가입 때 인증 메일 → 코드 확인되면 'Y' · 비밀번호 재설정은 'Y'인 회원만
--                                     기존 가상 회원(GENERATED)은 'Y'로 채움 (테스트 로그인이 돼야 하므로)
--   2) ACCESS_LOG.IP_ADDRESS · RESULT  어디서 접속했고 성공했는지 · 지금은 공격당해도 누가 몇 번 시도했는지 볼 수가 없음
--                                     RESULT: SUCCESS(정상) / FAIL(로그인 실패 등) / DENIED(권한 없음·남의 데이터 접근 시도)
--                                     + 인덱스 (IP_ADDRESS, ACCESSED_AT) → IP 기준 횟수 제한(한 IP가 10분에 로그인 실패 20번이면 막기)에 씀
--   3) 세법 기준값 3개 테이블(DEDUCTION_TYPE · TAX_BRACKET · BENEFIT_CONDITION)에 UPDATED_AT · UPDATED_BY
--                                     관리자 화면에서 숫자 하나 바꾸면 전 회원 계산이 바뀌는데 누가 언제 바꿨는지 안 남았음
--                                     UPDATED_BY NULL = 스크립트(02·88)로 넣은 것 · 숫자 = 바꾼 관리자 회원번호 → MEMBER
-- DB 구조 변경 있음 (ERD v3.4) · 테이블 18 그대로 · 칸 166 → 175 · CHECK 40 → 42 · 인덱스 19 → 23
-- 맨 아래 4) 확인 · 5) 일부러 틀린 값 넣어 보기(전부 ROLLBACK) 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 새 칸 0 · CHECK 40 · 인덱스 19 이어야 함 (다르면 멈추고 알려 주세요)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE (TABLE_NAME = 'MEMBER' AND COLUMN_NAME = 'EMAIL_VERIFIED_YN')
                                                  OR (TABLE_NAME = 'ACCESS_LOG' AND COLUMN_NAME IN ('IP_ADDRESS', 'RESULT'))
                                                  OR (TABLE_NAME IN ('DEDUCTION_TYPE', 'TAX_BRACKET', 'BENEFIT_CONDITION') AND COLUMN_NAME IN ('UPDATED_AT', 'UPDATED_BY'))) AS 새칸,  -- 0
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,   -- 40
       (SELECT COUNT(*) FROM USER_INDEXES WHERE INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS 인덱스_수                                    -- 19
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 1) MEMBER.EMAIL_VERIFIED_YN (맨 뒤 · DEFAULT 'N' NOT NULL → 기존 행은 N으로 채워짐 → 가상 회원은 Y로)
-- ─────────────────────────────────────────────
ALTER TABLE MEMBER ADD (EMAIL_VERIFIED_YN CHAR(1) DEFAULT 'N' NOT NULL);
ALTER TABLE MEMBER ADD CONSTRAINT CK_MEMBER_EMAIL_VERIFIED CHECK (EMAIL_VERIFIED_YN IN ('Y', 'N'));
COMMENT ON COLUMN MEMBER.EMAIL_VERIFIED_YN IS '이메일 인증 여부 Y/N(가입 때 인증 메일 코드 확인되면 Y · 비밀번호 재설정은 Y인 회원만)';
UPDATE MEMBER SET EMAIL_VERIFIED_YN = 'Y' WHERE DATA_ORIGIN IN ('GENERATED', 'COLLECTED');   -- 가상 회원 1,000 + 관리자 admin 1 · 테스트 로그인용
COMMIT;

-- ─────────────────────────────────────────────
-- 2) ACCESS_LOG.IP_ADDRESS · RESULT + IP 인덱스
-- ─────────────────────────────────────────────
ALTER TABLE ACCESS_LOG ADD (
  IP_ADDRESS  VARCHAR2(45),                                  -- IPv6 최대 45자 · NULL = 기록 못 함(배치 등)
  RESULT      VARCHAR2(10) DEFAULT 'SUCCESS' NOT NULL        -- SUCCESS/FAIL/DENIED
);
ALTER TABLE ACCESS_LOG ADD CONSTRAINT CK_ACCESS_LOG_RESULT CHECK (RESULT IN ('SUCCESS', 'FAIL', 'DENIED'));
CREATE INDEX IX_ACCESS_LOG_IP ON ACCESS_LOG (IP_ADDRESS, ACCESSED_AT);   -- IP 기준 횟수 제한 · 공격 IP 추적
COMMENT ON COLUMN ACCESS_LOG.IP_ADDRESS IS '접속 IP(IPv6 포함 최대 45자 · NULL = 기록 없음)';
COMMENT ON COLUMN ACCESS_LOG.RESULT IS '결과 SUCCESS(정상)/FAIL(로그인 실패 등)/DENIED(권한 없음·남의 데이터 접근 시도)';

-- ─────────────────────────────────────────────
-- 3) 세법 기준값 3개 테이블에 UPDATED_AT · UPDATED_BY (+ FK 인덱스 3개)
--    기존 행은 UPDATED_AT = 지금, UPDATED_BY = NULL(스크립트로 넣음)
-- ─────────────────────────────────────────────
ALTER TABLE DEDUCTION_TYPE ADD (UPDATED_AT DATE DEFAULT SYSDATE NOT NULL, UPDATED_BY NUMBER);
ALTER TABLE DEDUCTION_TYPE ADD CONSTRAINT FK_DEDUCTION_UPDATED_BY FOREIGN KEY (UPDATED_BY) REFERENCES MEMBER (MEMBER_ID);
CREATE INDEX IX_DEDUCTION_UPDATED_BY ON DEDUCTION_TYPE (UPDATED_BY);
COMMENT ON COLUMN DEDUCTION_TYPE.UPDATED_AT IS '마지막 수정일(스크립트 적재 시각 포함)';
COMMENT ON COLUMN DEDUCTION_TYPE.UPDATED_BY IS '마지막으로 바꾼 관리자 회원번호(NULL = 스크립트로 넣음)';

ALTER TABLE TAX_BRACKET ADD (UPDATED_AT DATE DEFAULT SYSDATE NOT NULL, UPDATED_BY NUMBER);
ALTER TABLE TAX_BRACKET ADD CONSTRAINT FK_TAX_BRACKET_UPDATED_BY FOREIGN KEY (UPDATED_BY) REFERENCES MEMBER (MEMBER_ID);
CREATE INDEX IX_TAX_BRACKET_UPDATED_BY ON TAX_BRACKET (UPDATED_BY);
COMMENT ON COLUMN TAX_BRACKET.UPDATED_AT IS '마지막 수정일(스크립트 적재 시각 포함)';
COMMENT ON COLUMN TAX_BRACKET.UPDATED_BY IS '마지막으로 바꾼 관리자 회원번호(NULL = 스크립트로 넣음)';

ALTER TABLE BENEFIT_CONDITION ADD (UPDATED_AT DATE DEFAULT SYSDATE NOT NULL, UPDATED_BY NUMBER);
ALTER TABLE BENEFIT_CONDITION ADD CONSTRAINT FK_BENEFIT_UPDATED_BY FOREIGN KEY (UPDATED_BY) REFERENCES MEMBER (MEMBER_ID);
CREATE INDEX IX_BENEFIT_UPDATED_BY ON BENEFIT_CONDITION (UPDATED_BY);
COMMENT ON COLUMN BENEFIT_CONDITION.UPDATED_AT IS '마지막 수정일(스크립트 적재 시각 포함)';
COMMENT ON COLUMN BENEFIT_CONDITION.UPDATED_BY IS '마지막으로 바꾼 관리자 회원번호(NULL = 스크립트로 넣음)';
-- ※ 두 번 실행하면 ALTER가 ORA-01430(칸 이미 있음)으로 멈추고 아무것도 안 바뀜

-- ─────────────────────────────────────────────
-- 4) 확인 (예상 결과는 오른쪽 주석)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,   -- 42
       (SELECT COUNT(*) FROM USER_INDEXES WHERE INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS 인덱스_수,                                   -- 23
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 전체_칸,                  -- 175
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'MEMBER') AS MEMBER_칸,                                             -- 24
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'ACCESS_LOG') AS 접근기록_칸,                                        -- 6
       (SELECT COUNT(*) FROM MEMBER WHERE EMAIL_VERIFIED_YN = 'Y') AS 인증된_회원,                                                     -- 1,001 (가상 회원 1,000 + admin)
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE UPDATED_BY IS NULL) AS 기준값_스크립트행                                             -- 22 (전부)
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 5) 일부러 틀린 값 넣어 보기 - 4줄 모두 「OK」가 나와야 정상 · 마지막에 ROLLBACK이라 데이터는 안 바뀜
--    (보기 > DBMS 출력 창을 켜고 실행)
-- ─────────────────────────────────────────────
DECLARE
  v_member NUMBER;
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (기대 ' || CASE WHEN p_expect = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_expect) END
                         || ' / 실제 ' || CASE WHEN p_code = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MIN(MEMBER_ID) INTO v_member FROM MEMBER;

  -- ① 인증 여부에 Y/N 아닌 값 → ORA-02290
  BEGIN
    UPDATE MEMBER SET EMAIL_VERIFIED_YN = 'X' WHERE MEMBER_ID = v_member;
    chk('① 이메일 인증 여부 X', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('① 이메일 인증 여부 X', SQLCODE, -2290); END;

  -- ② 접근 기록 결과에 없는 값 → ORA-02290
  BEGIN
    INSERT INTO ACCESS_LOG (LOG_ID, MEMBER_ID, SCREEN, IP_ADDRESS, RESULT) VALUES (-1, v_member, '/login', '127.0.0.1', 'HACKED');
    chk('② 접근 결과 HACKED', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('② 접근 결과 HACKED', SQLCODE, -2290); END;

  -- ③ 정상 접근 기록(실패 · IP 포함) → 오류 없음
  BEGIN
    INSERT INTO ACCESS_LOG (LOG_ID, MEMBER_ID, SCREEN, IP_ADDRESS, RESULT) VALUES (-2, v_member, '/login', '127.0.0.1', 'FAIL');
    chk('③ 로그인 실패 기록', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('③ 로그인 실패 기록', SQLCODE, 0); END;

  -- ④ 없는 회원번호를 기준값 수정자로 → ORA-02291 (FK)
  BEGIN
    UPDATE DEDUCTION_TYPE SET UPDATED_BY = -999, UPDATED_AT = SYSDATE WHERE TYPE_CODE = 'CARD_THRESHOLD' AND TAX_YEAR = 2026;
    chk('④ 없는 회원이 기준값 수정', 0, -2291);
  EXCEPTION WHEN OTHERS THEN chk('④ 없는 회원이 기준값 수정', SQLCODE, -2291); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- 테스트 끝 · ROLLBACK 완료 (데이터 변경 없음)');
END;
/
