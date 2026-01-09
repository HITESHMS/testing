-----------------------------------------------------------------------------
--
--  Logical unit: TimePersDiary
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
@Override
PROCEDURE Insert___ (
   objid_      OUT    VARCHAR2,
   objversion_ OUT    VARCHAR2,
   newrec_     IN OUT TIME_PERS_DIARY_TAB%ROWTYPE,
   attr_       IN OUT VARCHAR2 )
IS
   enabled_    BOOLEAN := C_Mod_Register_API.Is_Enabled('SYS-1192', newrec_.company_id);
BEGIN      
   IF (enabled_ AND nvl(newrec_.confirmed, '0') = '1') THEN         
      Time_Pers_Diary_Res_Util_API.C_Validate_Confirm_Day(newrec_.company_id, newrec_.emp_no, newrec_.account_date, newrec_.wage_class);
   END IF;   
   --      
   super(objid_, objversion_, newrec_, attr_);   
END Insert___;

@Override
PROCEDURE Update___ (
   objid_      IN     VARCHAR2,
   oldrec_     IN     TIME_PERS_DIARY_TAB%ROWTYPE,
   newrec_     IN OUT TIME_PERS_DIARY_TAB%ROWTYPE,
   attr_       IN OUT VARCHAR2,
   objversion_ IN OUT VARCHAR2,
   by_keys_    IN     BOOLEAN DEFAULT FALSE )
IS
   enabled_    BOOLEAN := C_Mod_Register_API.Is_Enabled('SYS-1192', newrec_.company_id);
BEGIN   
   IF (enabled_ AND nvl(newrec_.confirmed, '0') = '1' AND Validate_SYS.Is_Changed(oldrec_.confirmed, newrec_.confirmed)) THEN         
      Time_Pers_Diary_Res_Util_API.C_Validate_Confirm_Day(newrec_.company_id, newrec_.emp_no, newrec_.account_date, newrec_.wage_class);
   END IF;   
   --   
   super(objid_, oldrec_, newrec_, attr_, objversion_, by_keys_);
END Update___;






-------------------- LU CUST NEW METHODS -------------------------------------
