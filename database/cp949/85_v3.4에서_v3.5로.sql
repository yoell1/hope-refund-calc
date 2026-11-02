-- 85_v3.4에서_v3.5로.sql · 이미 v3.4로 만든 계정(교육원 공용 DB 포함)을 v3.5로 올리는 스크립트 (10/26)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.6이 됨 · v3.5→v3.6은 84번을 이것 다음에 실행
-- v3.3 계정이면 87(v3.3→v3.4)을 먼저 실행하고 이것을 실행
--
-- v3.5에서 바뀐 것 - 10/26 팀 회의 「개인정보 최소화: 실명(본명)은 수집하지 않음 · 화면 호칭은 고객님/사용자님」 반영
--   1) MEMBER.NAME  NOT NULL → NULL 허용 (칸은 그대로 둠 · 회원가입 때 이름을 받지 않으므로 새 회원은 NULL)
--                   → 백엔드: 가입 INSERT에 NAME 안 넣음 · 화면: 이름 자리에 "고객님/사용자님" 표시
--                   기존 가상 회원 1,001명의 이름('가상회원0001' …)은 테스트용으로 그대로 둠 (회의 결정)
--                   칸을 지우지 않은 이유: 나중에 닉네임 등을 쓰게 되면 그대로 재활용 · ALTER 한 줄로 끝남
-- DB 구조 변경 있음 (ERD v3.5) · 테이블 18 · 칸 175 · CHECK 42 · 인덱스 23 전부 그대로 (NOT NULL 하나만 풀림)
-- 맨 아래 2) 확인 · 3) 이름 없이 가입해 보기(ROLLBACK) 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - MEMBER.NAME 의 NULLABLE 이 'N'(필수) 이어야 함 ('Y'면 이미 v3.5 · 실행 안 해도 됨)
-- ─────────────────────────────────────────────
SELECT COLUMN_NAME, NULLABLE, DATA_TYPE, DATA_LENGTH
  FROM USER_TAB_COLUMNS
 WHERE TABLE_NAME = 'MEMBER' AND COLUMN_NAME = 'NAME';          -- NULLABLE = N

-- ─────────────────────────────────────────────
-- 1) MEMBER.NAME NULL 허용
-- ─────────────────────────────────────────────
ALTER TABLE MEMBER MODIFY (NAME NULL);
COMMENT ON COLUMN MEMBER.NAME IS '이름(v3.5부터 수집 안 함 · NULL = 실명 미수집 회원 · 화면 호칭 고객님/사용자님 · 가상데이터만 값 있음)';

-- ─────────────────────────────────────────────
-- 2) 확인 - NULLABLE = Y · 칸 175 · CHECK 42 · 인덱스 23 · 이름 있는 회원 1,001(가상데이터 그대로)
-- ─────────────────────────────────────────────
SELECT (SELECT NULLABLE FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'MEMBER' AND COLUMN_NAME = 'NAME') AS NAME_NULLABLE,  -- Y
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS
         WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS 칸_수,                                              -- 175
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,  -- 42
       (SELECT COUNT(*) FROM USER_INDEXES WHERE INDEX_NAME LIKE 'IX\_%' ESCAPE '\') AS 인덱스_수,                         -- 23
       (SELECT COUNT(*) FROM MEMBER WHERE NAME IS NOT NULL) AS 이름있는_회원,                                             -- 1001
       (SELECT COUNT(*) FROM MEMBER WHERE NAME IS NULL)     AS 이름없는_회원                                              -- 0
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 3) 이름 없이 가입해 보기 - v3.4까지는 ORA-01400 으로 실패하던 INSERT · 이제 들어가야 함 · 확인만 하고 ROLLBACK
--    (MEMBER 칸 중 NOT NULL 이면서 DEFAULT 없는 것만 채움 · 나머지는 DEFAULT)
-- ─────────────────────────────────────────────
DECLARE
  v_cnt NUMBER;
BEGIN
  INSERT INTO MEMBER (MEMBER_ID, LOGIN_ID, PASSWORD, EMAIL, BIRTH_DATE,
                      TERMS_AGREED_AT, PRIVACY_AGREED_AT, TERMS_VERSION, PRIVACY_VERSION, DATA_ORIGIN)
  VALUES (SEQ_MEMBER.NEXTVAL, 'test_noname', 'hash_test', 'noname@test.local', DATE '1990-01-01',
          SYSDATE, SYSDATE, 'v1.0', 'v1.0', 'INPUT');   -- NAME 없음 · 실제 가입 INSERT와 같은 모양
  SELECT COUNT(*) INTO v_cnt FROM MEMBER WHERE LOGIN_ID = 'test_noname' AND NAME IS NULL;
  DBMS_OUTPUT.PUT_LINE('이름 없는 가입 테스트: ' || CASE WHEN v_cnt = 1 THEN 'OK (NAME NULL로 들어감)' ELSE '실패' END);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('이름 없는 가입 테스트: 실패 - ' || SQLERRM);
    ROLLBACK;
END;
/
