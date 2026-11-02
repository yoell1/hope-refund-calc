-- 97_데이터정리.sql · 운영할 때 쓰는 정리 SQL (v3.8 · 탈퇴 30일 유예)
-- 1) 쌓이기만 하는 데이터 정리 - 바로 실행해도 되는 부분 (프로젝트 기간에는 안 돌려도 됨)
-- 2) 회원 탈퇴 처리 - 2-1) 탈퇴 요청은 백엔드 참고용(주석) · 2-2) 30일 지난 회원 식별 불가 처리는 바로 실행해도 됨
-- 실행: 프로젝트 계정으로 접속 → 스크립트 실행(F5)

-- ─────────────────────────────────────────────
-- 1) 정리
-- ─────────────────────────────────────────────
-- 1-1) 비밀번호 재설정 인증 코드: 만료되고 하루 지난 것 삭제 (사용한 코드도 포함)
DELETE FROM PASSWORD_RESET
 WHERE EXPIRES_AT < SYSDATE - 1;

-- 1-2) 접근 기록: 보관 기간(12개월)이 지난 것 삭제 - 기간은 팀에서 정하면 숫자만 바꿈
DELETE FROM ACCESS_LOG
 WHERE ACCESSED_AT < ADD_MONTHS(SYSDATE, -12);

COMMIT;

-- ─────────────────────────────────────────────
-- 2) 회원 탈퇴 처리 (v3.8 · D-21 「30일 유예기간 · 유예기간 동안 아이디·이메일 유지 · 지나면 식별 불가하게 처리 후 데이터 활용」)
--    · 회원 행은 지우지 않음 → 문의·접근 기록 FK가 안 깨짐
--    · 2-1) 탈퇴 요청: 상태만 바꿈 (아이디·이메일 유지 → 유예기간 중에는 같은 아이디·이메일로 재가입 불가 · 로그인도 막힘)
--    · 2-2) 30일 지난 회원: 아이디·이메일·비밀번호·이름을 식별 불가하게 바꿈 → 이때부터 같은 아이디·이메일로 재가입 가능
--    · 소득·카드 내역·예측 등 나머지 데이터는 지우지 않음 (D-21 「데이터 활용」) · 생년월일·성별 등 나머지 칸과 활용 범위는 팀 결정 후 반영
--    · v3.1: 가입 때 아이디·이메일이 'withdrawn_'으로 시작하면 백엔드에서 막기 (안 막으면 그 번호 회원이 식별 불가 처리될 때 ORA-00001)
--    · v3.1: 관리자가 탈퇴해도 권한이 남지 않게 ROLE = 'USER'
-- ─────────────────────────────────────────────
-- 2-1) 탈퇴 요청 (백엔드 참고용 · :member_id는 바인드 변수)
-- UPDATE MEMBER
--    SET STATUS = 'WITHDRAWN',
--        WITHDRAWN_AT = SYSDATE,
--        ROLE = 'USER',                               -- v3.1
--        LOGIN_FAIL_COUNT = 0, LOCKED_UNTIL = NULL,   -- v3.0
--        UPDATED_AT = SYSDATE
--  WHERE MEMBER_ID = :member_id AND STATUS = 'ACTIVE';
-- DELETE FROM PASSWORD_RESET WHERE MEMBER_ID = :member_id;   -- 남은 인증 코드는 쓸 일이 없음
-- COMMIT;

-- 2-2) 30일 지난 탈퇴 회원 식별 불가 처리 (하루 한 번 실행 · 스케줄러나 이 파일 실행 · 여러 번 돌려도 이미 처리된 회원은 건너뜀)
UPDATE MEMBER
   SET LOGIN_ID = 'withdrawn_' || MEMBER_ID,
       EMAIL = 'withdrawn_' || MEMBER_ID || '@deleted.invalid',   -- .invalid는 실제로 쓰이지 않는 예약 도메인
       PASSWORD = '-',
       NAME = NULL,                                               -- v3.5 NULL 허용
       UPDATED_AT = SYSDATE
 WHERE STATUS = 'WITHDRAWN'
   AND WITHDRAWN_AT <= SYSDATE - 30
   AND LOGIN_ID NOT LIKE 'withdrawn\_%' ESCAPE '\';
COMMIT;

-- ─────────────────────────────────────────────
-- 3) 확인용
-- ─────────────────────────────────────────────
-- 탈퇴 회원 수: SELECT COUNT(*) FROM MEMBER WHERE STATUS = 'WITHDRAWN';
-- 유예 중(30일 안 지남): SELECT COUNT(*) FROM MEMBER WHERE STATUS = 'WITHDRAWN' AND LOGIN_ID NOT LIKE 'withdrawn\_%' ESCAPE '\';
-- 남은 인증 코드: SELECT COUNT(*) FROM PASSWORD_RESET;
