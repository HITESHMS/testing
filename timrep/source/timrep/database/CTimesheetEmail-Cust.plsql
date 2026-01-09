-- 260109   ArcHitesS   M-CRIM-SYS-1809-01: Automated IFS Code Review
--(+) 260109 ArcHitesS M-CRIM-SYS-1809-01(START)
-----------------------------------------------------------------------------
--
--  Logical unit: CTimesheetEmail
--  Component:    TIMREP
--
--  IFS Developer Studio Template Version 3.0
--
--  Date    Sign    History
--  ------  ------  ---------------------------------------------------------
--  251009   hweerasinghe SYS-1469 Created
-----------------------------------------------------------------------------

layer Cust;

-------------------- PUBLIC DECLARATIONS ------------------------------------


-------------------- PRIVATE DECLARATIONS -----------------------------------


-------------------- LU SPECIFIC IMPLEMENTATION METHODS ---------------------
@Override
PROCEDURE Prepare_Insert___ (
   attr_ IN OUT VARCHAR2 )
IS
BEGIN   
   super(attr_);
   --
   Client_SYS.Add_To_Attr('INCLUDE_MANAGER_DB', 'FALSE', attr_);
   Client_SYS.Add_To_Attr('ACTIVE_DB', 'TRUE', attr_);
END Prepare_Insert___;

@Override
PROCEDURE Check_Common___ (
   oldrec_ IN     c_timesheet_email_tab%ROWTYPE,
   newrec_ IN OUT c_timesheet_email_tab%ROWTYPE,
   indrec_ IN OUT Indicator_Rec,
   attr_   IN OUT VARCHAR2 )
IS
BEGIN   
   super(oldrec_, newrec_, indrec_, attr_);
   --
   Validate_Time___(newrec_.time_of_day);
END Check_Common___;

@Override
PROCEDURE Insert___ (
   objid_      OUT    VARCHAR2,
   objversion_ OUT    VARCHAR2,
   newrec_     IN OUT c_timesheet_email_tab%ROWTYPE,
   attr_       IN OUT VARCHAR2 )
IS
BEGIN
   newrec_.time_of_day := lpad(newrec_.time_of_day, 5, '0');
   newrec_.modified_by := Fnd_Session_API.Get_Fnd_User;
   newrec_.modified_at := Time_Util_API.Get_Current_Time_In_Timezone(newrec_.time_zone_code);
   --
   super(objid_, objversion_, newrec_, attr_);
END Insert___;

@Override
PROCEDURE Update___ (
   objid_      IN     VARCHAR2,
   oldrec_     IN     c_timesheet_email_tab%ROWTYPE,
   newrec_     IN OUT c_timesheet_email_tab%ROWTYPE,
   attr_       IN OUT VARCHAR2,
   objversion_ IN OUT VARCHAR2,
   by_keys_    IN     BOOLEAN DEFAULT FALSE )
IS
BEGIN
   newrec_.time_of_day := lpad(newrec_.time_of_day, 5, '0');
   newrec_.modified_by := Fnd_Session_API.Get_Fnd_User;
   newrec_.modified_at := Time_Util_API.Get_Current_Time_In_Timezone(newrec_.time_zone_code);
   newrec_.last_sent_at := Time_Util_API.Convert_Timezone(newrec_.last_sent_at, oldrec_.time_zone_code, newrec_.time_zone_code);
   --
   super(objid_, oldrec_, newrec_, attr_, objversion_, by_keys_);
END Update___;

PROCEDURE Validate_Time___ (
   time_of_day_ IN VARCHAR2 )
IS
   temp_hrs_            NUMBER;
   temp_mins_           NUMBER; 
BEGIN
   IF (REGEXP_INSTR (time_of_day_, '([[:digit:]])|([[:digit:]][[:digit:]]):([[:digit:]])|([[:digit:]][[:digit:]])')=1) THEN
      IF (REGEXP_LIKE(SUBSTR(time_of_day_,1,INSTR(time_of_day_,':')-1),'^[[:digit:]]+$') AND REGEXP_LIKE(SUBSTR(time_of_day_,INSTR(time_of_day_,':')+1),'^[[:digit:]]+$')) THEN
         temp_hrs_ := to_number(SUBSTR(time_of_day_,1,INSTR(time_of_day_,':')-1));
         temp_mins_ :=to_number(SUBSTR(time_of_day_,INSTR(time_of_day_,':')+1));
         IF NOT ((temp_hrs_ >= 0 AND temp_hrs_ <= 23) AND (temp_mins_ >= 0 AND temp_mins_ <= 59)) THEN
            Error_SYS.Appl_General(lu_name_, 'INTERVAL_ERROR: Time requires a value greater than 00:00 and less than 23:59');
         END IF;
      ELSE
         Error_SYS.Appl_General(lu_name_, 'FORMAT_ERROR: Time is invalid.');
      END IF; 
   ELSE
     Error_SYS.Appl_General(lu_name_, 'FORMAT_ERROR: Time is invalid.');
   END IF;
END Validate_Time___;
-------------------- LU SPECIFIC PRIVATE METHODS ----------------------------


-------------------- LU SPECIFIC PROTECTED METHODS --------------------------


-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------
PROCEDURE Set_Last_Sent_At (
   company_          IN VARCHAR2,
   email_template_   IN VARCHAR2 )
IS
   newrec_  c_timesheet_email_tab%ROWTYPE;
BEGIN
   newrec_ := Get_Object_By_Keys___(company_, email_template_);
   newrec_.last_sent_at := Time_Util_API.Get_Current_Time_In_Timezone(newrec_.time_zone_code);
   Modify___(newrec_);
END Set_Last_Sent_At; 

FUNCTION Is_Time_Right (
   company_          IN VARCHAR2,
   email_template_   IN VARCHAR2 ) RETURN VARCHAR2
IS
   newrec_        c_timesheet_email_tab%ROWTYPE;
   curr_time_tz_  DATE;
BEGIN   
   newrec_ := Get_Object_By_Keys___(company_, email_template_);
   --
   IF (newrec_.active = 'TRUE') THEN 
      curr_time_tz_ := Time_Util_API.Get_Current_Time_In_Timezone(newrec_.time_zone_code);
      IF (newrec_.date_from IS NULL OR trunc(newrec_.date_from) <= trunc(curr_time_tz_)) THEN 
         IF (to_char(curr_time_tz_, 'DY') = newrec_.day_of_week) THEN         
            IF (to_date('01/01/1900 ' || to_char(curr_time_tz_, 'HH24:MI'), 'DD/MM/YYYY HH24:MI') >= 
               to_date('01/01/1900 ' || newrec_.time_of_day, 'DD/MM/YYYY HH24:MI')) THEN
               IF (Validate_SYS.Is_Different(trunc(newrec_.last_sent_at), trunc(curr_time_tz_))) THEN
                  RETURN 'TRUE';
               END IF;         
            END IF;      
         END IF;   
      END IF;
   END IF;
   --
   RETURN 'FALSE';
END Is_Time_Right;
-------------------- LU CUST NEW METHODS -------------------------------------
--(+) 260109 ArcHitesS M-CRIM-SYS-1809-01(FINISH)
