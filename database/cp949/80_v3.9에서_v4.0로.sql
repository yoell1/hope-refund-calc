-- 80_v3.9¿¡¼­_v4.0·Î.sql ¡¤ ÀÌ¹Ì v3.9·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v4.0À¸·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (10/30)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v4.0ÀÌ µÊ
-- v3.8 °èÁ¤ÀÌ¸é 81(v3.8¡æv3.9)À» ¸ÕÀú ½ÇÇàÇÏ°í ÀÌ°ÍÀ» ½ÇÇà
--
-- v4.0¿¡¼­ ¹Ù²ï °Í (10/30 ¡¤ °è»ê ´ã´ç °áÁ¤ ¡¸°è»ê °á°ú Ç×¸ñº° °øÁ¦ ³»¿ª¡¹)
--   1) DEDUCTION_TYPE 4Çà Ãß°¡: ±Ù·Î¼Òµæ°øÁ¦(EARNED_DEDUCTION) ¡¤ ±Ù·Î¼Òµæ¼¼¾×°øÁ¦(EARNED_CREDIT) ¡¿ 2026¡¤2025 ±Í¼Ó
--        ÀÌÀ¯: Ç×¸ñº° °øÁ¦ ³»¿ª(PREDICTION_DETAIL)Àº DEDUCTION_TYPE ÇàÀ» °¡¸®ÄÑ¾ß ÀúÀåµÇ´Âµ¥,
--              ÀÌ µÎ Ç×¸ñÀº ±âÁØ°ªÀÌ TAX_BRACKET(±¸°£Ç¥)¿¡¸¸ ÀÖ¾î¼­ ³»¿ª¿¡ ÀúÀåÇÒ ¼ö ¾ø¾úÀ½
--        ¡æ ÀÌ¸§¡¤Á¾·ù¡¤±Ù°Å¸¸ ´ã´Â Çà (RATE 0 ¡¤ °øÁ¦À²°ú ±¸°£Àº ±×´ë·Î TAX_BRACKETÀÇ °°Àº ÀÌ¸§ ±¸°£À» ¾¸)
--        ±Ù·Î¼Òµæ°øÁ¦ ÇÑµµ 2,000¸¸ ¿øÀº LIMIT_AMOUNT¿¡ ¡¤ ±Ù·Î¼Òµæ¼¼¾×°øÁ¦ ÇÑµµ(ÃÑ±Þ¿©º° 74¸¸¡¤66¸¸¡¤50¸¸¡¤20¸¸ ÇÏÇÑÀÌ ÀÖ´Â ½Ä)´Â °è»ê ÄÚµå
--   2) PREDICTION_DETAIL.DEDUCTION_AMOUNT ¼³¸í ¼öÁ¤: Ä«µå ÇÑµµ¸¦ ³ÑÀº ±Ý¾×Àº ÇÑµµ Çà(CARD_LIMIT_*)¿¡ À½¼ö·Î ÀúÀå (10/30 °áÁ¤ ¡¤ Ä­ Á¦¾à º¯°æ ¾øÀ½)
-- DB ±¸Á¶ º¯°æ ¾øÀ½ (ERD ±×¸² ±×´ë·Î) ¡¤ Å×ÀÌºí 20 ¡¤ Ä­ 210 ¡¤ CHECK 50 ¡¤ UNIQUE 12 ¡¤ ÀÎµ¦½º 25 ±×´ë·Î ¡¤ ±âÁØ°ª 46 ¡æ 50Çà
-- ¹é¿£µå: »õ Çàµµ TYPE_ID ¸»°í TAX_YEAR + TYPE_CODE·Î Ã£±â (°ø¿ë DB¿Í »õ °èÁ¤ÀÇ TYPE_ID°¡ ´Ù¸¦ ¼ö ÀÖÀ½)

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - ±âÁØ°ª 46 ¡¤ »õ ÄÚµå 0 ¡¤ ±¸°£ 30 ÀÌ¾î¾ß ÇÔ (´Ù¸£¸é ¸ØÃß°í ¾Ë·Á ÁÖ¼¼¿ä)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS ±âÁØ°ª_Çà,   -- 46 (2026 25 + 2025 21)
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT')) AS »õ_ÄÚµå,  -- 0
       (SELECT COUNT(*) FROM TAX_BRACKET) AS ±¸°£_Çà,        -- 30
       (SELECT COUNT(*) FROM TAX_BRACKET WHERE BRACKET_TYPE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT')) AS ±Ù·Î¼Òµæ_±¸°£  -- 14 (¿¬µµ¸¶´Ù °øÁ¦ 5 + ¼¼¾×°øÁ¦ 2)
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) DEDUCTION_TYPE 4Çà Ãß°¡ (2026 ¡æ 2025 ¼ø¼­ ¡¤ 02_±âÁØµ¥ÀÌÅÍ.sql 2-2)¿Í °°Àº ¼ø¼­)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'EARNED_DEDUCTION', '±Ù·Î¼Òµæ°øÁ¦', 'INCOME_DEDUCTION', 0, 20000000, NULL, NULL, NULL,
        '±¹¼¼Ã» ½Å°í¾È³» 94p ¡¤ ¼Òµæ¼¼¹ý ¡×47 (°øÁ¦À²¡¤±¸°£Àº TAX_BRACKET EARNED_DEDUCTION ¡¤ °øÁ¦¾× ÃÖ´ë 2,000¸¸)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'EARNED_CREDIT', '±Ù·Î¼Òµæ¼¼¾×°øÁ¦', 'TAX_CREDIT', 0, NULL, NULL, NULL, NULL,
        '±¹¼¼Ã» ½Å°í¾È³» 162p ¡¤ ¼Òµæ¼¼¹ý ¡×59 (°øÁ¦À²¡¤±¸°£Àº TAX_BRACKET EARNED_CREDIT ¡¤ ÃÑ±Þ¿©º° ÇÑµµ´Â °è»ê ÄÚµå)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, 'EARNED_DEDUCTION', '±Ù·Î¼Òµæ°øÁ¦', 'INCOME_DEDUCTION', 0, 20000000, NULL, NULL, NULL,
        '±¹¼¼Ã» ½Å°í¾È³» 94p ¡¤ ¼Òµæ¼¼¹ý ¡×47 (°øÁ¦À²¡¤±¸°£Àº TAX_BRACKET EARNED_DEDUCTION ¡¤ °øÁ¦¾× ÃÖ´ë 2,000¸¸)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, 'EARNED_CREDIT', '±Ù·Î¼Òµæ¼¼¾×°øÁ¦', 'TAX_CREDIT', 0, NULL, NULL, NULL, NULL,
        '±¹¼¼Ã» ½Å°í¾È³» 162p ¡¤ ¼Òµæ¼¼¹ý ¡×59 (°øÁ¦À²¡¤±¸°£Àº TAX_BRACKET EARNED_CREDIT ¡¤ ÃÑ±Þ¿©º° ÇÑµµ´Â °è»ê ÄÚµå)', 0);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) ¼³¸í ¼öÁ¤
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
COMMENT ON COLUMN PREDICTION_DETAIL.DEDUCTION_AMOUNT IS '°øÁ¦¡¤°¨¸é¾× (Ä«µå ÇÑµµ ÃÊ°úºÐÀº CARD_LIMIT_* Çà¿¡ À½¼ö ¡¤ v4.0)';

COMMIT;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) È®ÀÎ - ±âÁØ°ª 50 ¡¤ »õ ÄÚµå 4 ¡¤ ¿¬µµº° 2026 27 / 2025 23
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS ±âÁØ°ª_Çà,   -- 50
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT')) AS »õ_ÄÚµå  -- 4
  FROM DUAL;

SELECT TAX_YEAR, COUNT(*) AS Çà FROM DEDUCTION_TYPE GROUP BY TAX_YEAR ORDER BY TAX_YEAR;   -- 2025 23 ¡¤ 2026 27

SELECT TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT
  FROM DEDUCTION_TYPE WHERE TYPE_CODE IN ('EARNED_DEDUCTION', 'EARNED_CREDIT') ORDER BY TAX_YEAR DESC, TYPE_ID;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â - ÀüºÎ ¸·Çô¾ß Á¤»ó (ROLLBACK)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DECLARE
  PROCEDURE t(p_name VARCHAR2, p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE(p_name || ': ½ÇÆÐ - ¸·È÷Áö ¾ÊÀ½');
    ROLLBACK;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(p_name || ': OK (' || SUBSTR(SQLERRM, 1, 40) || ')');
    ROLLBACK;
  END;
BEGIN
  t('2026 ±Ù·Î¼Òµæ°øÁ¦ Áßº¹',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''EARNED_DEDUCTION'', ''t'', ''INCOME_DEDUCTION'', 0, 0)');
  t('2025 ±Ù·Î¼Òµæ¼¼¾×°øÁ¦ Áßº¹',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, ''EARNED_CREDIT'', ''t'', ''TAX_CREDIT'', 0, 0)');
END;
/
