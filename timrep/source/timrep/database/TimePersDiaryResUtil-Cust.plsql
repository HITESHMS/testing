-----------------------------------------------------------------------------
--
--  Logical unit: TimePersDiaryResUtil
--  Component:    TIMREP
--
--  IFS Developer Studio Template Version 3.0
--
--  Date    Sign    History
--  ------  ------  ---------------------------------------------------------
--  250501  hweerasinghe SYS-1192 Created.
-----------------------------------------------------------------------------

layer Cust;

-------------------- PUBLIC DECLARATIONS ------------------------------------


-------------------- PRIVATE DECLARATIONS -----------------------------------


-------------------- LU SPECIFIC IMPLEMENTATION METHODS ---------------------


-------------------- LU SPECIFIC PRIVATE METHODS ----------------------------


-------------------- LU SPECIFIC PROTECTED METHODS --------------------------


-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------


-------------------- LU CUST NEW METHODS -------------------------------------
PROCEDURE C_Validate_Confirm_Day (
   company_id_       IN VARCHAR2,
   emp_no_           IN VARCHAR2,
   account_date_     IN DATE,
   wage_class_       IN VARCHAR2)
IS
   CURSOR get_rec IS
      SELECT sum(wage_hours) wage_hours, wage_code      
      FROM  time_pers_diary_result_tab
      WHERE company_id = company_id_
      AND   emp_no = emp_no_
      AND   account_date = account_date_ 
      AND   wage_class = wage_class_
      AND   transaction_type = '3'
      GROUP BY wage_code;
BEGIN   
   $IF Component_Prjrep_SYS.INSTALLED $THEN
      FOR rec_ IN get_rec LOOP
         Project_Transaction_API.C_Validate_Confirm_Day(company_id_, emp_no_, account_date_, wage_class_, rec_.wage_code, rec_.wage_hours);
      END LOOP;
   $ELSE
      NULL;
   $END
END C_Validate_Confirm_Day;