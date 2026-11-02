-- 89_가상회원_입사일수정.sql · 이미 가상 데이터를 넣은 계정(교육원 공용 DB 포함)의 가상 회원 1명 입사일 수정 (10/23)
-- 새로 만드는 계정은 이 파일 없이 01 → 02 → 03 만 실행하면 됨 (03에 이미 반영)
-- 테이블 구조는 그대로 (ERD 버전 v3.2 그대로) · 데이터 1행만 바뀜
--
-- 무엇: 가상 회원 45번(test0045, 2006-10-25생)의 입사일이 2021-07-16 → 만 14세 입사인데 중소기업 감면 Y
--       → 중소기업 취업자 감면 나이 조건(만 15~34세)에 안 맞음
-- 원인: 05_가상데이터_생성.py가 입사일을 생년월일과 상관없이 뽑았음 → 05에서 「만 15세 이후」로 고침
--       (난수 순서는 그대로라 다시 만들어도 다른 회원 값은 안 바뀜 · 확인함)
-- 고친 값: 2021-10-25 (만 15세가 되는 날)

SET DEFINE OFF

-- 0) 실행 전 확인 - 1행 (MEMBER_ID 45 · 2021-07-16)
SELECT MEMBER_ID, LOGIN_ID, BIRTH_DATE, HIRE_DATE FROM MEMBER
 WHERE HIRE_DATE < ADD_MONTHS(BIRTH_DATE, 12 * 15);

-- 1) 수정 (조건에 예전 값까지 넣어서 다른 행은 절대 안 바뀜)
UPDATE MEMBER SET HIRE_DATE = DATE '2021-10-25'
 WHERE MEMBER_ID = 45 AND LOGIN_ID = 'test0045' AND HIRE_DATE = DATE '2021-07-16';
COMMIT;

-- 2) 확인 - 만 15세 전에 입사한 회원 0 · 45번 입사일 2021-10-25
SELECT (SELECT COUNT(*) FROM MEMBER WHERE HIRE_DATE < ADD_MONTHS(BIRTH_DATE, 12 * 15)) AS 만15세전_입사,   -- 0
       (SELECT TO_CHAR(HIRE_DATE, 'YYYY-MM-DD') FROM MEMBER WHERE MEMBER_ID = 45) AS 회원45_입사일          -- 2021-10-25
  FROM DUAL;
