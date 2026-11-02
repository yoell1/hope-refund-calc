-- 88_v3.2¿¡¼­_v3.3·Î.sql ¡¤ ÀÌ¹Ì v3.2·Î ¸¸µç °èÁ¤(±³À°¿ø °ø¿ë DB Æ÷ÇÔ)À» v3.3À¸·Î ¿Ã¸®´Â ½ºÅ©¸³Æ® (10/23)
-- »õ·Î ¸¸µå´Â °èÁ¤Àº ÀÌ ÆÄÀÏ ¾øÀÌ 01 ¡æ 02 ¡æ 03 ¸¸ ½ÇÇàÇÏ¸é v3.3ÀÌ µÊ
-- 89(°¡»ó È¸¿ø ÀÔ»çÀÏ ¼öÁ¤)¸¦ ÀÌ¹Ì ÇßÀ¸¸é ±×´ë·Î µÎ°í ÀÌ°Í¸¸ ½ÇÇà
-- ¡Ø v3.4(87)º¸´Ù ¸ÕÀú ½ÇÇàÇÒ °Í - 87À» ¸ÕÀú ÇÏ¸é ¾Æ·¡ 3)ÀÇ INSERT°¡ Ä­ ¼ö(UPDATED_AT¡¤UPDATED_BY) ¾È ¸Â¾Æ ORA-00947·Î ½ÇÆÐ
--
-- v3.3¿¡¼­ ¹Ù²ï °Í - Ä«µå ¼Òµæ°øÁ¦ ±âº»ÇÑµµ ÀÚ³à °¡»ê (Á¶Æ¯¹ý ¡×126ÀÇ2¨ð 2025.12.23 °³Á¤ ¡¤ 2026.1.1 ÀÌÈÄ ½ÃÀÛ °ú¼¼±â°£ = 2026 ±Í¼ÓºÎÅÍ)
--   ±âº»ÇÑµµ: ÃÑ±Þ¿© 7Ãµ¸¸ ÀÌÇÏ 300¸¸ ¡æ ÀÚ³à 1¸í 350¸¸ ¡¤ 2¸í ÀÌ»ó 400¸¸ / 7Ãµ¸¸ ÃÊ°ú 250¸¸ ¡æ ÀÚ³à 1¸í 275¸¸ ¡¤ 2¸í ÀÌ»ó 300¸¸
--   ÀÚ³àµî = 20¼¼ ÀÌÇÏ Á÷°èºñ¼Ó¡¤ÀÔ¾çÀÚ¡¤À§Å¹¾Æµ¿ Áß ¼Òµæ±Ý¾× 100¸¸ ÀÌÇÏ(±Ù·Î¼Òµæ¸¸ÀÌ¸é ÃÑ±Þ¿© 500¸¸ ÀÌÇÏ) ¡¤ ´Ù¸¥ »ç¶÷ ±âº»°øÁ¦ ´ë»ó ¾Æ´Ô (Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç×)
--   1) INCOME ¡¤ PREDICTION_INPUT ¸Ç µÚ¿¡ CHILDREN(20¼¼ ÀÌÇÏ ÀÚ³à ¼ö) Ä­ Ãß°¡ ¡¤ ±âº»°ª 0 ¡æ ±âÁ¸ ÇàÀº ¸ðµÎ 0
--   2) ±Ý¾× 0 ÀÌ»ó CHECK 2°³(CK_INCOME_AMOUNT ¡¤ CK_PRED_INPUT_AMOUNT)¿¡ CHILDREN >= 0 Ãß°¡ (CHECK °³¼ö 40 ±×´ë·Î)
--   3) DEDUCTION_TYPE¿¡ 2026³â ÀÚ³à ÇÑµµ 4Çà Ãß°¡ (18 ¡æ 22Çà)
-- ¸Ç ¾Æ·¡ 4) È®ÀÎ ¡¤ 5) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â(ÀüºÎ ROLLBACK) °á°ú¸¦ º¸¸é µÊ

SET DEFINE OFF
SET SERVEROUTPUT ON

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 0) ½ÇÇà Àü È®ÀÎ - CHILDREN Ä­ 0 ¡¤ ÀÚ³à ÇÑµµ Çà 0 ¡¤ 2026 ±âÁØ Çà 18 ÀÌ¾î¾ß ÇÔ (´Ù¸£¸é ¸ØÃß°í ¾Ë·Á ÁÖ¼¼¿ä)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME IN ('INCOME', 'PREDICTION_INPUT') AND COLUMN_NAME = 'CHILDREN') AS CHILDREN_Ä­,   -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TYPE_CODE LIKE 'CARD\_LIMIT\_CHILD%' ESCAPE '\') AS ÀÚ³àÇÑµµ_Çà,                                -- 0
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TAX_YEAR = 2026) AS ±âÁØ_2026,                                                                  -- 18
       (SELECT LAST_NUMBER FROM USER_SEQUENCES WHERE SEQUENCE_NAME = 'SEQ_DEDUCTION_TYPE') AS ´ÙÀ½_Ç×¸ñ¹øÈ£                                       -- 19
  FROM DUAL;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 1) CHILDREN Ä­ Ãß°¡ (DEFAULT + NOT NULLÀÌ¶ó ±âÁ¸ ÇàÀº 0À¸·Î Ã¤¿öÁü)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE INCOME ADD (CHILDREN NUMBER(2) DEFAULT 0 NOT NULL);
ALTER TABLE PREDICTION_INPUT ADD (CHILDREN NUMBER(2) DEFAULT 0 NOT NULL);
COMMENT ON COLUMN INCOME.CHILDREN IS '20¼¼ ÀÌÇÏ ÀÚ³à ¼ö(Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç× ÀÚ³àµî ¡¤ Ä«µå °øÁ¦ ÀÚ³à ÇÑµµ¿ë)';
COMMENT ON COLUMN PREDICTION_INPUT.CHILDREN IS '20¼¼ ÀÌÇÏ ÀÚ³à ¼ö(Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç× ÀÚ³àµî ¡¤ Ä«µå °øÁ¦ ÀÚ³à ÇÑµµ¿ë)';

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 2) ±Ý¾× 0 ÀÌ»ó CHECK ´Ù½Ã ¸¸µé±â (CHILDREN Ãß°¡)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
ALTER TABLE INCOME DROP CONSTRAINT CK_INCOME_AMOUNT;
ALTER TABLE INCOME ADD CONSTRAINT CK_INCOME_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND SOCIAL_INSURANCE >= 0 AND DEPENDENTS >= 0
                                     AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0);
ALTER TABLE PREDICTION_INPUT DROP CONSTRAINT CK_PRED_INPUT_AMOUNT;
ALTER TABLE PREDICTION_INPUT ADD CONSTRAINT CK_PRED_INPUT_AMOUNT CHECK (TOTAL_SALARY >= 0 AND WITHHELD_TAX >= 0 AND SOCIAL_INSURANCE >= 0 AND DEPENDENTS >= 0
                                         AND MONTHLY_RENT >= 0 AND HOUSING_SAVING >= 0 AND PENSION_SAVING >= 0 AND CHILDREN >= 0);

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 3) ÀÚ³à ÇÑµµ 4Çà Ãß°¡ (02_±âÁØµ¥ÀÌÅÍ.sql ¸Ç µÚ 4Çà°ú °°À½ ¡¤ »õ °èÁ¤°ú Ç×¸ñ¹øÈ£ 19~22·Î °°°Ô)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD1_LOW', 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à1¡¤7Ãµ¸¸ ÀÌÇÏ)', 'CARD_RULE', 0, 3500000, 70000000, NULL, NULL, 'Á¶Æ¯¹ý ¡×126ÀÇ2¨ð (2025.12.23 °³Á¤) ¡¤ Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç×');
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD2_LOW', 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à2+¡¤7Ãµ¸¸ ÀÌÇÏ)', 'CARD_RULE', 0, 4000000, 70000000, NULL, NULL, 'Á¶Æ¯¹ý ¡×126ÀÇ2¨ð (2025.12.23 °³Á¤) ¡¤ Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç×');
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD1_HIGH', 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à1¡¤7Ãµ¸¸ ÃÊ°ú)', 'CARD_RULE', 0, 2750000, NULL, NULL, NULL, 'Á¶Æ¯¹ý ¡×126ÀÇ2¨ð (2025.12.23 °³Á¤) ¡¤ Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç×');
INSERT INTO DEDUCTION_TYPE VALUES (SEQ_DEDUCTION_TYPE.NEXTVAL, 2026, 'CARD_LIMIT_CHILD2_HIGH', 'Ä«µå ±âº»ÇÑµµ(ÀÚ³à2+¡¤7Ãµ¸¸ ÃÊ°ú)', 'CARD_RULE', 0, 3000000, NULL, NULL, NULL, 'Á¶Æ¯¹ý ¡×126ÀÇ2¨ð (2025.12.23 °³Á¤) ¡¤ Á¶Æ¯·É ¡×121ÀÇ2 Á¦18Ç×');
COMMIT;
-- ¡Ø µÎ ¹ø ½ÇÇàÇÏ¸é UQ_DEDUCTION_YEAR_CODE(¿¬µµ¡¤ÄÚµå Áßº¹ ±ÝÁö)¿¡ °É·Á ORA-00001ÀÌ ³ª°í ÇàÀº ¾È ´Ã¾î³² (ALTERµµ ORA-01430À¸·Î ¸ØÃã)

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 4) È®ÀÎ (¿¹»ó °á°ú´Â ¿À¸¥ÂÊ ÁÖ¼®)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
SELECT (SELECT COUNT(*) FROM USER_CONSTRAINTS WHERE CONSTRAINT_TYPE = 'C' AND CONSTRAINT_NAME LIKE 'CK\_%' ESCAPE '\') AS CHECK_¼ö,   -- 40
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'INCOME') AS INCOME_Ä­,                                         -- 15
       (SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'PREDICTION_INPUT') AS ¿¹ÃøÀÔ·Â_Ä­,                              -- 11
       (SELECT COUNT(*) FROM DEDUCTION_TYPE WHERE TAX_YEAR = 2026) AS ±âÁØ_2026,                                                  -- 22
       (SELECT COUNT(*) FROM INCOME WHERE CHILDREN <> 0) AS ÀÚ³à¼ö_0¾Æ´Ñ_¼Òµæ,                                                    -- 0
       (SELECT COUNT(*) FROM INCOME) AS ¼Òµæ                                                                                      -- 1,000 (½ÇÇà Àü°ú °°À½)
  FROM DUAL;

SELECT TYPE_ID, TYPE_CODE, LIMIT_AMOUNT, SALARY_LIMIT        -- 19 CHILD1_LOW 3500000 70000000 / 20 CHILD2_LOW 4000000 70000000
  FROM DEDUCTION_TYPE                                         -- 21 CHILD1_HIGH 2750000 (ºóÄ­) / 22 CHILD2_HIGH 3000000 (ºóÄ­)
 WHERE TYPE_CODE LIKE 'CARD_LIMIT%'
 ORDER BY TYPE_ID;

-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
-- 5) ÀÏºÎ·¯ Æ²¸° °ª ³Ö¾î º¸±â - 4ÁÙ ¸ðµÎ ¡¸OK¡¹°¡ ³ª¿Í¾ß Á¤»ó ¡¤ ¸¶Áö¸·¿¡ ROLLBACKÀÌ¶ó µ¥ÀÌÅÍ´Â ¾È ¹Ù²ñ
--    (º¸±â > DBMS Ãâ·Â Ã¢À» ÄÑ°í ½ÇÇà)
-- ¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡¦¡
DECLARE
  v_income NUMBER;
  PROCEDURE chk(p_name VARCHAR2, p_code NUMBER, p_expect NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN p_code = p_expect THEN 'OK   ' ELSE 'FAIL ' END
                         || p_name || ' (±â´ë ' || CASE WHEN p_expect = 0 THEN '¿À·ù ¾øÀ½' ELSE 'ORA' || TO_CHAR(p_expect) END
                         || ' / ½ÇÁ¦ ' || CASE WHEN p_code = 0 THEN '¿À·ù ¾øÀ½' ELSE 'ORA' || TO_CHAR(p_code) END || ')');
  END;
BEGIN
  SELECT MIN(INCOME_ID) INTO v_income FROM INCOME;

  -- ¨ç ÀÚ³à ¼ö À½¼ö ¡æ ORA-02290
  BEGIN
    UPDATE INCOME SET CHILDREN = -1 WHERE INCOME_ID = v_income;
    chk('¨ç ¼Òµæ ÀÚ³à ¼ö -1', 0, -2290);
  EXCEPTION WHEN OTHERS THEN chk('¨ç ¼Òµæ ÀÚ³à ¼ö -1', SQLCODE, -2290); END;

  -- ¨è ÀÚ³à ¼ö NULL ¡æ ORA-01407 (NOT NULL Ä­À» NULL·Î UPDATE)
  BEGIN
    UPDATE INCOME SET CHILDREN = NULL WHERE INCOME_ID = v_income;
    chk('¨è ¼Òµæ ÀÚ³à ¼ö NULL', 0, -1407);
  EXCEPTION WHEN OTHERS THEN chk('¨è ¼Òµæ ÀÚ³à ¼ö NULL', SQLCODE, -1407); END;

  -- ¨é Á¤»ó ÀÚ³à ¼ö 2 ¡æ ¿À·ù ¾øÀ½
  BEGIN
    UPDATE INCOME SET CHILDREN = 2 WHERE INCOME_ID = v_income;
    chk('¨é ¼Òµæ ÀÚ³à ¼ö 2', 0, 0);
  EXCEPTION WHEN OTHERS THEN chk('¨é ¼Òµæ ÀÚ³à ¼ö 2', SQLCODE, 0); END;

  -- ¨ê °°Àº ÀÚ³à ÇÑµµ Çà ¶Ç ³Ö±â ¡æ ORA-00001 (¿¬µµ¡¤ÄÚµå Áßº¹ ±ÝÁö)
  BEGIN
    INSERT INTO DEDUCTION_TYPE VALUES (-1, 2026, 'CARD_LIMIT_CHILD1_LOW', 'Å×½ºÆ®', 'CARD_RULE', 0, 1, NULL, NULL, NULL, NULL);
    chk('¨ê ÀÚ³à ÇÑµµ Áßº¹', 0, -1);
  EXCEPTION WHEN OTHERS THEN chk('¨ê ÀÚ³à ÇÑµµ Áßº¹', SQLCODE, -1); END;

  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('-- Å×½ºÆ® ³¡ ¡¤ ROLLBACK ¿Ï·á (µ¥ÀÌÅÍ º¯°æ ¾øÀ½)');
END;
/
