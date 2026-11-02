-- 79_v4.0¿¡¼­_v4.1·Î.sql ¡¤ ÀÌ¹Ì v4.0À¸·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v4.1·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (11/02)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v4.1ÀÌ µÊ
-- v3.9 °èÁ¤ÀÌ¸é 80(v3.9¡æv4.0)À» ¸ÕÀú ½ÇÇàÇÏ°í ÀÌ°ÍÀ» ½ÇÇà
--
-- v4.1¿¡¼­ ¹Ù²ï °Í (11/02 ¡¤ °è»ê ´ã´ç °áÁ¤ ¡¸¿¬±ÝÀúÃà ´Üµ¶ 600¸¸ ÇÑµµ¡¹)
--   1) INCOME¡¤PREDICTION_INPUT: ¿¬±Ý ÇÑ Ä­ ¡æ µÎ Ä­
--        PENSION_SAVING = ¿¬±ÝÀúÃà¸¸ (¼³¸í º¯°æ ¡¤ ÀÌ¸§¡¤ÀÚ¸® ±×´ë·Î)
--        IRP_SAVING ¸Ç µÚ Ãß°¡ (IRP¡¤ÅðÁ÷¿¬±Ý°èÁÂ ¡¤ ±âº» 0)
--        ÀÌÀ¯: ¿¬±Ý°èÁÂ ¼¼¾×°øÁ¦ ÇÑµµ´Â ÇÕ°è 900¸¸ÀÌÁö¸¸ ±×Áß ¿¬±ÝÀúÃàÀº 600¸¸±îÁö (¼Òµæ¼¼¹ý ¡×59ÀÇ3)
--              ¡æ ÇÕÄ£ ±Ý¾×¸¸ ÀÖÀ¸¸é ¿¬±ÝÀúÃà¸¸ 600¸¸ ³Ñ°Ô ³½ »ç¶÷ÀÇ °øÁ¦¸¦ Å©°Ô °è»êÇÔ
--        È­¸é(TaxInfoForm ¡¤ SimulationPage)Àº ÀÌ¹Ì ¿¬±ÝÀúÃà / IRP µÎ Ä­À¸·Î ¹Þ°í ÀÖÀ½ ¡æ DB¸¦ È­¸é¿¡ ¸ÂÃã
--   2) °¡»ó È¸¿ø(GENERATED) Áß ¿¬±Ý 600¸¸ ÃÊ°ú Çà: 600¸¸ ³Ñ´Â ºÎºÐÀ» IRP_SAVINGÀ¸·Î ¿Å±è
--        °¡»ó ¿¬±Ý °ªÀº ±¹¼¼Åë°è ¡¸¿¬±Ý°èÁÂ¡¹(¿¬±ÝÀúÃà + IRP ÇÕ°è) ±âÁØÀÌ¶ó ÇÕ°è¡¤°øÁ¦¾×ÀÌ ¹Ù²îÁö ¾Ê°Ô ÇÏ·Á´Â °Í
--        Á÷Á¢ ÀÔ·Â(INPUT) ÇàÀº ±×´ë·Î µÒ (ÀÖÀ¸¸é ±× È¸¿øÀÌ È­¸é¿¡¼­ µÎ Ä­À» ´Ù½Ã ÀÔ·Â)
--        PREDICTION_INPUTÀº Áö³­ °è»ê ±â·ÏÀÌ¶ó °ªÀ» ¹Ù²ÙÁö ¾ÊÀ½ (IRP_SAVING = 0)
--   3) CHECK CK_INCOME_AMOUNT ¡¤ CK_PRED_INPUT_AMOUNT ´Ù½Ã ¸¸µê (IRP_SAVING >= 0 Ãß°¡ ¡¤ °³¼ö ±×´ë·Î)
--   4) DEDUCTION_TYPE 2Çà Ãß°¡: ¿¬±ÝÀúÃà ´Üµ¶ ÇÑµµ PENSION_SAVING_LIMIT (600¸¸) ¡¿ 2026¡¤2025 ±Í¼Ó
--        RATE 0 ¡¤ °øÁ¦À²Àº ±×´ë·Î PENSION Çà(5,500¸¸ ÀÌÇÏ 15% ¡¤ ÃÊ°ú 12%) ¡¤ ÇÕ°è ÇÑµµ 900¸¸µµ PENSION Çà
-- DB ±¸Á¶ º¯°æ ÀÖÀ½ (ERD v4.1) ¡¤ Å×ÀÌºí 20 ±×´ë·Î ¡¤ Ä­ 210 ¡æ 212 ¡¤ CHECK 50 ±×´ë·Î ¡¤ UNIQUE 12 ¡¤ ÀÎµ¦½º 25 ±×´ë·Î ¡¤ ±âÁØ°ª 50 ¡æ 52Çà
-- ¹é¿£µå: ¼Òµæ¡¤°è»ê ÀÔ·Â ÀúÀå ¶§ IRP_SAVING °°ÀÌ ÀúÀå (È­¸éÀÇ irp °ª) ¡¤ »õ ±âÁØ°ª Çàµµ TYPE_ID ¸»°í TAX_YEAR + TYPE_CODE·Î Ã£±â

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - Å×ÀÌºí 20 ¡¤ Ä­ 210 ¡¤ CHECK 50 ¡¤ »õ Ä­ 0 ¡¤ ±âÁØ°ª 50 ¡¤ »õ ÄÚµå 0 ÀÌ¾î¾ß ÇÔ (´Ù¸£¸é ¸ØÃß°í ¾Ë·Á ÁÖ¼¼¿ä)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_TABLES) AS Å×ÀÌºí_¼ö,           -- 20
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS Ä­_¼ö,   -- 210
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö,  -- 50
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE COLUMN_NAME = 'IRP_SAVING') AS »õ_Ä­,           -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS ±âÁØ°ª_Çà,                                          -- 50
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE = 'PENSION_SAVING_LIMIT') AS »õ_ÄÚµå,  -- 0
       (SELECT COUNT(*) FROM INCOME) AS ¼Òµæ_Çà,
       (SELECT COUNT(*) FROM INCOME WHERE DATA_ORIGIN = 'GENERATED' AND PENSION_SAVING > 6000000) AS ¿¬±Ý_600¸¸_ÃÊ°ú_°¡»ó,  -- 3 (°¡»óµ¥ÀÌÅÍ ±âÁØ)
       (SELECT COUNT(*) FROM INCOME WHERE DATA_ORIGIN <> 'GENERATED' AND PENSION_SAVING > 0) AS ¿¬±Ý_Á÷Á¢ÀÔ·Â_Çà,      -- º¸Åë 0
       (SELECT NVL(SUM(PENSION_SAVING), 0) FROM INCOME) AS ¿¬±Ý_ÇÕ°è,   -- ¸Ç ¾Æ·¡ ¡¸¿¬±ÝÀúÃà + IRP ÇÕ°è¡¹¿Í °°¾Æ¾ß ÇÔ
       (SELECT COUNT(*) FROM PREDICTION_INPUT) AS ¿¹ÃøÀÔ·Â_Çà
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) IRP Ä­ Ãß°¡ (¸Ç µÚ ¡¤ ±âº» 0) + ¿¬±ÝÀúÃà Ä­ ¼³¸í º¯°æ
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE INCOME ADD (IRP_SAVING NUMBER(10) DEFAULT 0 NOT NULL);
ALTER TABLE PREDICTION_INPUT ADD (IRP_SAVING NUMBER(10) DEFAULT 0 NOT NULL);

COMMENT ON COLUMN INCOME.PENSION_SAVING IS '¿¬±ÝÀúÃà ¿¬ ³³ÀÔ¾×(¿¬±ÝÀúÃà 600¸¸ ÇÑµµ ¡¤ v4.1 IRP´Â IRP_SAVING)';
COMMENT ON COLUMN INCOME.IRP_SAVING IS 'IRP(ÅðÁ÷¿¬±Ý°èÁÂ) ¿¬ ³³ÀÔ¾×(¿¬±ÝÀúÃà°ú ÇÕ°è 900¸¸ ÇÑµµ ¡¤ v4.1)';
COMMENT ON COLUMN PREDICTION_INPUT.PENSION_SAVING IS '¿¬±ÝÀúÃà ¿¬ ³³ÀÔ¾×(¿¬±ÝÀúÃà 600¸¸ ÇÑµµ ¡¤ v4.1 IRP´Â IRP_SAVING)';
COMMENT ON COLUMN PREDICTION_INPUT.IRP_SAVING IS 'IRP(ÅðÁ÷¿¬±Ý°èÁÂ) ¿¬ ³³ÀÔ¾×(¿¬±ÝÀúÃà°ú ÇÕ°è 900¸¸ ÇÑµµ ¡¤ v4.1)';

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) °¡»ó È¸¿ø ¿¬±Ý 600¸¸ ÃÊ°úºÐ ¡æ IRP·Î (ÇÕ°è ±×´ë·Î ¡¤ ¼öÁ¤ÀÏÀº °¡»ó µ¥ÀÌÅÍ¶ó ±×´ë·Î µÒ)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
UPDATE INCOME
   SET IRP_SAVING = PENSION_SAVING - 6000000,
       PENSION_SAVING = 6000000
 WHERE DATA_ORIGIN = 'GENERATED'
   AND PENSION_SAVING > 6000000;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) À½¼ö ¸·´Â CHECK ´Ù½Ã ¸¸µé±â (IRP_SAVING Ãß°¡)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE INCOME DROP CONSTRAINT CK_INCOME_AMOUNT;
ALTER TABLE INCOME ADD CONSTRAINT CK_INCOME_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND NATIONAL_PENSION >= 0 AND DEPENDENTS >= 0
                                     AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0 AND HEALTH_INSURANCE >= 0
                                     AND IRP_SAVING >= 0);

ALTER TABLE PREDICTION_INPUT DROP CONSTRAINT CK_PRED_INPUT_AMOUNT;
ALTER TABLE PREDICTION_INPUT ADD CONSTRAINT CK_PRED_INPUT_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND NATIONAL_PENSION >= 0 AND DEPENDENTS >= 0
                                         AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0 AND HEALTH_INSURANCE >= 0
                                         AND IRP_SAVING >= 0);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) DEDUCTION_TYPE 2Çà Ãß°¡ (2026 ¡æ 2025 ¼ø¼­ ¡¤ 02_±âÁØµ¥ÀÌÅÍ.sql 2-3)°ú °°Àº ¼ø¼­)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'PENSION_SAVING_LIMIT', '¿¬±ÝÀúÃà ´Üµ¶ ÇÑµµ', 'TAX_CREDIT', 0, 6000000, NULL, NULL, NULL,
        '±¹¼¼Ã» ½Å°í¾È³» ¿ä¾àÇ¥ ¡¤ ¼Òµæ¼¼¹ý ¡×59ÀÇ3 (¿¬±Ý°èÁÂ 900¸¸ Áß ¿¬±ÝÀúÃàÀº 600¸¸±îÁö ¡¤ °øÁ¦À²Àº PENSION Çà)', 0);
INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MAX, CATEGORY_ID, PAY_METHOD, SOURCE_NOTE, SALARY_MIN)
VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2025, 'PENSION_SAVING_LIMIT', '¿¬±ÝÀúÃà ´Üµ¶ ÇÑµµ', 'TAX_CREDIT', 0, 6000000, NULL, NULL, NULL,
        '±¹¼¼Ã» ½Å°í¾È³» ¿ä¾àÇ¥ ¡¤ ¼Òµæ¼¼¹ý ¡×59ÀÇ3 (¿¬±Ý°èÁÂ 900¸¸ Áß ¿¬±ÝÀúÃàÀº 600¸¸±îÁö ¡¤ °øÁ¦À²Àº PENSION Çà)', 0);

COMMIT;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 5) È®ÀÎ - Ä­ 212 ¡¤ CHECK 50 ¡¤ »õ Ä­ 2 ¡¤ ±âÁØ°ª 52 ¡¤ »õ ÄÚµå 2 ¡¤ ¿¬±Ý 600¸¸ ÃÊ°ú °¡»ó 0 ¡¤ ¿¬±Ý ÇÕ°è´Â ¸Ç À§¿Í °°À½
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN (SELECT TABLE_NAME FROM USER_TABLES)) AS Ä­_¼ö,   -- 212
       (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö,  -- 50
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE COLUMN_NAME = 'IRP_SAVING') AS »õ_Ä­,           -- 2
       (SELECT COUNT(*) FROM DEDUCTION_TYPE) AS ±âÁØ°ª_Çà,                                          -- 52
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE = 'PENSION_SAVING_LIMIT') AS »õ_ÄÚµå,  -- 2
       (SELECT COUNT(*) FROM INCOME WHERE DATA_ORIGIN = 'GENERATED' AND PENSION_SAVING > 6000000) AS ¿¬±Ý_600¸¸_ÃÊ°ú_°¡»ó,  -- 0
       (SELECT NVL(SUM(PENSION_SAVING + IRP_SAVING), 0) FROM INCOME) AS ¿¬±ÝÀúÃà_IRP_ÇÕ°è   -- ¸Ç À§ ¡¸¿¬±Ý_ÇÕ°è¡¹¿Í °°À½
  FROM DUAL;

SELECT TAX_YEAR, COUNT(*) AS Çà FROM DEDUCTION_TYPE GROUP BY TAX_YEAR ORDER BY TAX_YEAR;   -- 2025 24 ¡¤ 2026 28

SELECT INCOME_ID, TOTAL_SALARY, PENSION_SAVING, IRP_SAVING
  FROM INCOME WHERE IRP_SAVING > 0 ORDER BY INCOME_ID;   -- ¿Å±ä °¡»ó È¸¿ø (°¡»óµ¥ÀÌÅÍ ±âÁØ 3Çà)

SELECT TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT
  FROM DEDUCTION_TYPE WHERE TYPE_CODE = 'PENSION_SAVING_LIMIT' ORDER BY TAX_YEAR DESC;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 6) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â - ÀüºÎ ¸·Çô¾ß Á¤»ó (ROLLBACK)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DECLARE
  v_cnt NUMBER;
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
  t('¼Òµæ IRP À½¼ö',
    'UPDATE INCOME SET IRP_SAVING = -1 WHERE INCOME_ID = (SELECT MIN(INCOME_ID) FROM INCOME)');
  SELECT COUNT(*) INTO v_cnt FROM PREDICTION_INPUT;
  IF v_cnt > 0 THEN
    t('°è»ê ÀÔ·Â IRP À½¼ö',
      'UPDATE PREDICTION_INPUT SET IRP_SAVING = -1 WHERE PREDICTION_ID = (SELECT MIN(PREDICTION_ID) FROM PREDICTION_INPUT)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('°è»ê ÀÔ·Â IRP À½¼ö: °Ç³Ê¶Ü (PREDICTION_INPUT 0Çà)');
  END IF;
  t('2026 ¿¬±ÝÀúÃà ´Üµ¶ ÇÑµµ Áßº¹',
    'INSERT INTO DEDUCTION_TYPE (TYPE_ID, TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, SALARY_MIN) VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, ''PENSION_SAVING_LIMIT'', ''t'', ''TAX_CREDIT'', 0, 0)');
END;
/
