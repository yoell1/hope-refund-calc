-- 90_v3.1에서_v3.2로.sql · 이미 v3.1로 만든 계정(교육원 공용 DB 포함)을 v3.2로 올리는 스크립트 (10/23)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 v3.2가 됨
-- 테이블·칸·데이터는 바뀌지 않음 (CHECK 1개만 다시 만듦 · 개수 40 그대로)
--
-- v3.2에서 바뀐 것
--   1) 문의 답변 CHECK CK_INQUIRY_ANSWER
--      예전: 답변 완료(ANSWERED)면 답변일만 확인 → 답변 내용·답변자가 비어 있어도 「답변 완료」로 저장됐음
--      지금: 답변 완료면 답변 내용 · 답변일 · 답변자 모두 필수 / 접수(WAITING)면 셋 다 비어 있어야 함
--   2) (파일만) 04 분류 쿼리 · 07 카드 분류가 사용 중인 분류(SPEND_CATEGORY.USE_YN = 'Y')의 목록만 대조
--      → DB에 저장된 것이 아니라 이 스크립트에는 없음 · 지금 분류 5개 모두 사용 중이라 결과 변화 없음
-- 맨 아래 3) 확인 · 4) 일부러 틀린 값 넣어 보기(전부 ROLLBACK) 결과를 보면 됨

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ─────────────────────────────────────────────
-- 0) 실행 전 확인 - 0이어야 함 (0이 아니면 멈추고 알려 주세요 · 새 규칙에 안 맞는 문의 수)
-- ─────────────────────────────────────────────
SELECT COUNT(*) AS 규칙에_안_맞는_문의
  FROM INQUIRY
 WHERE (STATUS = 'ANSWERED' AND (ANSWER IS NULL OR ANSWERED_AT IS NULL OR ANSWERED_BY IS NULL))
    OR (STATUS = 'WAITING'  AND (ANSWER IS NOT NULL OR ANSWERED_AT IS NOT NULL OR ANSWERED_BY IS NOT NULL));

-- ─────────────────────────────────────────────
-- 1) 문의 답변 CHECK 다시 만들기
-- ─────────────────────────────────────────────
ALTER TABLE INQUIRY DROP CONSTRAINT CK_INQUIRY_ANSWER;
ALTER TABLE INQUIRY ADD CONSTRAINT CK_INQUIRY_ANSWER CHECK (
      (STATUS = 'WAITING'  AND ANSWER IS NULL     AND ANSWERED_AT IS NULL     AND ANSWERED_BY IS NULL)
   OR (STATUS = 'ANSWERED' AND ANSWER IS NOT NULL AND ANSWERED_AT IS NOT NULL AND ANSWERED_BY IS NOT NULL));

-- ─────────────────────────────────────────────
-- 2) (변경 없음) 04 · 07은 파일만 바뀜 - 새 파일을 쓰면 됨
-- ─────────────────────────────────────────────

-- ─────────────────────────────────────────────
-- 3) 확인 (예상 결과는 오른쪽 주석)
-- ─────────────────────────────────────────────
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_수,   -- 40
       (SELECT STATUS FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = 'CK_INQUIRY_ANSWER') AS 답변CHECK_상태,                       -- ENABLED
       (SELECT COUNT(*) FROM MEMBER) AS 회원,                                                                                   -- 1,001 (테스트 데이터가 더 있으면 그만큼)
       (SELECT COUNT(*) FROM INQUIRY) AS 문의                                                                                   -- 실행 전과 같음
  FROM DUAL;

-- ─────────────────────────────────────────────
-- 4) 일부러 틀린 값 넣어 보기 - 5줄 모두 「OK」가 나와야 정상 · 마지막에 ROLLBACK이라 데이터는 안 바뀜
--    (보기 > DBMS 출력 창을 켜고 실행)
-- ─────────────────────────────────────────────
DECLARE
  v_user  NUMBER;   -- 일반 회원
  v_admin NUMBER;   -- 관리자
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (기대 ' || CASE WHEN p_expect = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_expect) END
                         || ' / 실제 ' || CASE WHEN p_code = 0 THEN '오류 없음' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MIN(MEMBER_ID) INTO v_user  FROM MEMBER WHERE ROLE = 'USER';
  SELECT MIN(MEMBER_ID) INTO v_admin FROM MEMBER WHERE ROLE = 'ADMIN';

  -- ① 답변 완료인데 답변 내용 없음 → ORA-02290
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT, STATUS, ANSWER, ANSWERED_AT, ANSWERED_BY)
    VALUES (-1, v_user, '테스트', '문의', 'ANSWERED', NULL, SYSDATE, v_admin);
    chk('① 답변 완료 + 답변 내용 없음', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('① 답변 완료 + 답변 내용 없음', SQLCODE, -2290); END;

  -- ② 답변 완료인데 답변자 없음 → ORA-02290
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT, STATUS, ANSWER, ANSWERED_AT, ANSWERED_BY)
    VALUES (-2, v_user, '테스트', '문의', 'ANSWERED', '답변', SYSDATE, NULL);
    chk('② 답변 완료 + 답변자 없음', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('② 답변 완료 + 답변자 없음', SQLCODE, -2290); END;

  -- ③ 접수 상태인데 답변 내용이 있음 → ORA-02290
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT, STATUS, ANSWER)
    VALUES (-3, v_user, '테스트', '문의', 'WAITING', '답변');
    chk('③ 접수 + 답변 내용 있음', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('③ 접수 + 답변 내용 있음', SQLCODE, -2290); END;

  -- ④ 정상 접수 → 오류 없음
  BEGIN
    INSERT INTO INQUIRY (INQUIRY_ID, MEMBER_ID, TITLE, CONTENT)
    VALUES (-4, v_user, '테스트', '문의');
    chk('④ 정상 접수', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('④ 정상 접수', SQLCODE, 0); END;

  -- ⑤ 정상 답변 (④를 답변 완료로) → 오류 없음
  BEGIN
    UPDATE INQUIRY SET STATUS = 'ANSWERED', ANSWER = '답변', ANSWERED_AT = SYSDATE, ANSWERED_BY = v_admin
     WHERE INQUIRY_ID = -4;
    chk('⑤ 정상 답변', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('⑤ 정상 답변', SQLCODE, 0); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- 테스트 끝 · ROLLBACK 완료 (데이터 변경 없음)');
END;
/
