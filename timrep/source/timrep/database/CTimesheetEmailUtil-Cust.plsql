-----------------------------------------------------------------------------
--
--  Logical unit: CTimesheetEmailUtil
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
FUNCTION Fetch_From_Mail_Template___(
   company_          IN VARCHAR2,
   email_template_   IN VARCHAR2 ) RETURN CLOB
IS 
   template_      CLOB;
   file_size_     INTEGER := dbms_lob.lobmaxsize;
   dest_offset_   INTEGER := 1;
   src_offset_    INTEGER := 1;
   blob_csid_     NUMBER  := dbms_lob.default_csid;
   lang_context_  NUMBER  := dbms_lob.default_lang_ctx;
   warning_       INTEGER;
   $IF Component_Docman_SYS.INSTALLED $THEN
      key_ref_       DOC_REFERENCE_OBJECT_TAB.key_ref%TYPE := 'COMPANY=:P1^ID=:P2^';   
      --
      CURSOR get_doc_ref IS
         SELECT doc_class, doc_no, doc_sheet, doc_rev
         FROM DOC_REFERENCE_OBJECT_TAB
         WHERE lu_name = 'CCompanyEmail'
         AND key_ref = key_ref_      
         ORDER BY doc_no DESC; 
   $END
BEGIN   
   $IF Component_Docman_SYS.INSTALLED $THEN
      key_ref_ := replace(key_ref_, ':P1', company_);
      key_ref_ := replace(key_ref_, ':P2', email_template_);
      --
      FOR doc_ref_ IN get_doc_ref LOOP              
         file_size_     := dbms_lob.lobmaxsize;
         dest_offset_   := 1;
         src_offset_    := 1;
         blob_csid_     := dbms_lob.default_csid;
         lang_context_  := dbms_lob.default_lang_ctx;
         warning_       := NULL;
         --      
         dbms_lob.createtemporary(template_, TRUE);
         dbms_lob.converttoclob(
            template_, 
            Fetch_Document___(doc_ref_.doc_class, doc_ref_.doc_no, doc_ref_.doc_sheet, doc_ref_.doc_rev), 
            file_size_, 
            dest_offset_, 
            src_offset_, 
            blob_csid_, 
            lang_context_, 
            warning_);
         EXIT;      
      END LOOP;
      --   
      RETURN template_;
   $ELSE
      RETURN NULL;
   $END
END Fetch_From_Mail_Template___;

FUNCTION Fetch_Document___ (
   doc_class_  IN VARCHAR2,
   doc_no_     IN VARCHAR2,
   doc_sheet_  IN VARCHAR2,
   doc_rev_    IN VARCHAR2 ) RETURN BLOB 
IS
   doc_type_            VARCHAR2(20) := 'ORIGINAL';
   error_msg_           VARCHAR2(2000);
   file_data_           BLOB;
   loc_name_            VARCHAR2(30);
   edm_repository_type_ NUMBER;
BEGIN
   $IF Component_Docman_SYS.INSTALLED $THEN
     loc_name_            := Edm_Location_API.Get_Current_Location(doc_class_);
      edm_repository_type_ := Edm_Location_API.Get_Location_Type_Db(loc_name_);
      IF (edm_repository_type_ = 3) THEN   
         Edm_File_Op_Announce_API.Announce_File_Operation(doc_class_, doc_no_, doc_sheet_, doc_rev_, 'READ');
         file_data_ := Edm_File_Storage_API.Get_File_Data(doc_class_, doc_no_, doc_sheet_, doc_rev_, doc_type_);
      ELSIF (edm_repository_type_ IN (1, 2, 4)) THEN           
         Batch_Transfer_Handler_API.Copy_From_Repo_To_Db(error_msg_, doc_class_, doc_no_, doc_sheet_, doc_rev_, doc_type_);     
         Edm_File_Op_Announce_API.Announce_File_Operation(doc_class_, doc_no_, doc_sheet_, doc_rev_, 'READ');
         file_data_ := Edm_File_Storage_API.Get_File_Data(doc_class_, doc_no_, doc_sheet_, doc_rev_, doc_type_);      
         Doc_Issue_API.Delete_Db_File(doc_class_, doc_no_, doc_sheet_, doc_rev_, doc_type_, 1);
      END IF;
      --
      RETURN file_data_;
   $ELSE
      RETURN NULL;
   $END  
END Fetch_Document___;

PROCEDURE Send_Email___(
    company_         IN VARCHAR2,
    email_template_  IN VARCHAR2,
    include_manager_ IN VARCHAR2,
    emp_template_    IN VARCHAR2,
    subject_         IN VARCHAR2,
    date_from_       IN DATE,
    template_        IN CLOB )
IS
   emp_tab_       Emp_Template_API.EMP_TAB;
   person_id_     company_emp_tab.Person_Id%TYPE;
   emp_no_        company_person_tab.emp_no%TYPE; 
   cc_            VARCHAR2(32000);
   line_          VARCHAR2(50) := '<tr><td>{:P1}</td></tr>';
   body_          CLOB;
   table_         CLOB;   
   row_           VARCHAR2(32000);
   attachments_   Command_SYS.attachment_arr;
   base_url_      VARCHAR2(200) := Fnd_Setting_API.Get_Value('SYSTEM_URL');
   --
   CURSOR get_sup IS
     SELECT Person_Info_API.Get_User_Id(person_id) sup_user
     FROM Company_Pers_Assign_API.Get_Direct_Supervisor_Table(company_, emp_no_); 
   --
   CURSOR get_timesheet_count (emp_no_ VARCHAR2) IS
      SELECT emp_no, week_from, Company_Emp_API.Get_Person_Id(company_, emp_no) person_id
      FROM (
         SELECT emp_no, trunc(account_date, 'IW') week_from
         FROM TIME_PERS_DIARY_TAB t 
         WHERE company_id = company_
         AND emp_no LIKE emp_no_
         AND trunc(account_date) BETWEEN trunc(nvl(date_from_, sysdate - 6)) and trunc(sysdate - 1)
         AND Company_Person_API.Is_Active(company_id, emp_no, sysdate) = 'TRUE'      
         GROUP BY emp_no, account_date
         HAVING sum(TIME_PERS_DIARY_API.Is_Confirmed(company_id, emp_no, account_date)) < sum(decode(Company_Person_API.Is_Active(company_id, emp_no, account_date), 'TRUE', 1, 0))
         UNION
         SELECT emp_no, trunc(sysdate, 'IW') week_from
         FROM company_person_tab
         WHERE company_id = company_
         AND emp_no LIKE emp_no_
         AND TIME_PERS_DIARY_API.Is_Confirmed(company_id, emp_no, trunc(sysdate)) = 0      
         AND Company_Person_API.Is_Active(company_id, emp_no, sysdate) = 'TRUE'
      ) ORDER BY emp_no, week_from ASC;
BEGIN
   IF (emp_template_ IS NOT NULL) THEN
      Emp_Template_API.Get_Employees(company_, emp_template_, sysdate, NULL, emp_tab_);
   ELSE
      emp_tab_(1) := '%';
   END IF;
   --   
   IF NVL(emp_tab_.LAST, 0) > 0 THEN
      Dbms_Lob.CreateTemporary(table_, TRUE, Dbms_Lob.CALL);  
      Dbms_Lob.CreateTemporary(body_, TRUE, Dbms_Lob.CALL);
      FOR i_ IN 1..emp_tab_.LAST LOOP          
         FOR rec_ IN get_timesheet_count(emp_tab_(i_)) LOOP            
            IF (emp_no_ IS NULL) THEN
               person_id_ := rec_.person_id;
               emp_no_ := rec_.emp_no;               
               Dbms_Lob.WriteAppend(body_, LENGTH(template_), template_);               
            ELSIF (emp_no_ != rec_.emp_no) THEN
               body_ := replace(body_, '{:P1}', Person_Info_API.Get_Name(person_id_));               
               body_ := replace(body_, '{:P2}', table_);  
               body_ := replace(body_, '{:P3}', base_url_);               
               --
               cc_ := NULL;
               IF (include_manager_ = 'TRUE') THEN
                  FOR sup_ IN get_sup LOOP
                     cc_ :=  sup_.sup_user || ';' || cc_;
                  END LOOP;
               END IF;
               --
               Command_SYS.Mail( NULL,
                                 NULL,
                                 Person_Info_API.Get_User_Id(person_id_),
                                 cc_,
                                 NULL,
                                 subject_,
                                 body_,
                                 attachments_,
                                 NULL);
               --
               DBMS_LOB.freetemporary(body_);
               DBMS_LOB.freetemporary(table_);
               Dbms_Lob.CreateTemporary(table_, TRUE, Dbms_Lob.CALL);  
               Dbms_Lob.CreateTemporary(body_, TRUE, Dbms_Lob.CALL);               
               Dbms_Lob.WriteAppend(body_, LENGTH(template_), template_);
               person_id_ := rec_.person_id;
               emp_no_ := rec_.emp_no;
            ELSE
               NULL;
            END IF; 
            --
            IF (emp_no_ = rec_.emp_no) THEN
               row_ := line_;
               row_ := replace(row_, '{:P1}', to_char(rec_.week_from, 'DD-MON-YYYY'));               
               --
               IF (length(body_) + length(table_) + length(row_) < 32000) THEN
                  Dbms_Lob.WriteAppend(table_, LENGTH(row_), row_);  
               END IF;                    
            END IF;            
         END LOOP;
         --
         IF (emp_no_ IS NOT NULL) THEN
            body_ := replace(body_, '{:P1}', Person_Info_API.Get_Name(person_id_)); 
            body_ := replace(body_, '{:P2}', table_); 
            body_ := replace(body_, '{:P3}', base_url_);
            --
            cc_ := NULL;
            IF (include_manager_ = 'TRUE') THEN
               FOR sup_ IN get_sup LOOP
                  cc_ :=  sup_.sup_user || ';' || cc_;
               END LOOP;
            END IF;
            --
            Command_SYS.Mail( NULL,
                              NULL,
                              Person_Info_API.Get_User_Id(person_id_),
                              cc_,
                              NULL,
                              subject_,
                              body_,
                              attachments_,
                              NULL);            
         END IF;
      END LOOP;
      DBMS_LOB.freetemporary(body_);
      DBMS_LOB.freetemporary(table_);
   END IF;
   --
   C_Timesheet_Email_API.Set_Last_Sent_At(company_, email_template_);   
END Send_Email___;

-------------------- LU SPECIFIC PRIVATE METHODS ----------------------------


-------------------- LU SPECIFIC PROTECTED METHODS --------------------------


-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------
PROCEDURE Process_Emails
IS
   template_      CLOB;   
   --
   CURSOR get_rec IS
      SELECT company, email_template, employee_template, include_manager, date_from, subject
      FROM c_timesheet_email_tab
      WHERE active = 'TRUE';
BEGIN
   FOR rec_ IN get_rec LOOP
      BEGIN
         IF C_Timesheet_Email_API.Is_Time_Right(rec_.company, rec_.email_template) = 'TRUE' THEN
            @ApproveTransactionStatement(2025-10-09,hweerasinghe)
            SAVEPOINT start_;
            template_ := Fetch_From_Mail_Template___(rec_.company, rec_.email_template);
            IF (template_ IS NULL OR length(template_) = 0) THEN
               Error_SYS.Record_General(lu_name_, 'NOTEMPLATE: No email template attached for :P1-:P2', rec_.company, rec_.email_template);
            END IF;
            --
            Send_Email___(rec_.company, rec_.email_template, rec_.include_manager, rec_.employee_template, rec_.subject, rec_.date_from, template_);
            DBMS_LOB.freetemporary(template_);
            --
            Transaction_SYS.Log_Status_Info('SUCCESS>>'|| rec_.company || '>>' || rec_.email_template, 'INFO');
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            @ApproveTransactionStatement(2025-10-09,hweerasinghe)
            ROLLBACK TO start_;
            Transaction_SYS.Log_Status_Info('FAILED>>'|| rec_.company || '>>' || rec_.email_template ||'>>' || SQLERRM);
      END;
   END LOOP;     
END Process_Emails;

-------------------- LU CUST NEW METHODS -------------------------------------
