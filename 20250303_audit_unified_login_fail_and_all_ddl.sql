--===========================================================================
--## 20250303_audit_unified_login_fail_and_all_ddl.sql
--## https://github.com/dbasobrinho/blog_post/blob/main/20250303_audit_unified_login_fail_and_all_ddl.sql
--## Autor: Roberto Sobrinho
--## Data de criação: 2025-03-03
--===========================================================================

--## Verificar o status do Unified Auditing  

SELECT VALUE FROM V$OPTION WHERE PARAMETER = 'Unified Auditing';

SHOW PARAMETER AUDIT_TRAIL;

--===========================================================================

--## Configurar a tablespace da auditoria  
--## Verificar a tablespace usada pela auditoria  

SET LINES 188
SET PAGES 300 
COLUMN PARAMETER_NAME FORMAT A30
COLUMN PARAMETER_VALUE FORMAT A30
COLUMN AUDIT_TRAIL FORMAT A30

SELECT PARAMETER_NAME, PARAMETER_VALUE, AUDIT_TRAIL  
FROM DBA_AUDIT_MGMT_CONFIG_PARAMS  
WHERE PARAMETER_NAME = 'DB AUDIT TABLESPACE';

--===========================================================================

--## Criar nova tablespace dedicada (opcional)  

CREATE TABLESPACE TBS_AUDIT  
DATAFILE '/u01/app/oracle/oradata/ORCL/tbs_audit01.dbf'  
SIZE 1G AUTOEXTEND O?N NEXT 512M MAXSIZE 10G;

--===========================================================================

--## Mover a auditoria para a nova tablespace  

BEGIN  
  DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_LOCATION(
    AUDIT_TRAIL_TYPE => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,  
    AUDIT_TRAIL_LOCATION_VALUE => 'TBS_AUDIT'  
  );  
END;
/

--===========================================================================

--## Verificar se a alteração foi aplicada  

SELECT PARAMETER_NAME, PARAMETER_VALUE, AUDIT_TRAIL  
FROM DBA_AUDIT_MGMT_CONFIG_PARAMS  
WHERE PARAMETER_NAME = 'DB AUDIT TABLESPACE';

--===========================================================================

--## Criar e ativar auditorias  
--## Criar auditoria para logins malsucedidos  

CREATE AUDIT POLICY AUDIT_LOGON_FAIL ACTIONS LOGON;

AUDIT POLICY AUDIT_LOGON_FAIL WHENEVER NOT SUCCESSFUL;

--===========================================================================

--## Criar auditoria para alterações em objetos  

CREATE AUDIT POLICY AUDIT_DDL_CHANGES  
ACTIONS  
    CREATE TABLE, ALTER TABLE, DROP TABLE,  
    CREATE INDEX, ALTER INDEX, DROP INDEX,  
    CREATE VIEW, ALTER VIEW, DROP VIEW,  
    CREATE SEQUENCE, ALTER SEQUENCE, DROP SEQUENCE,  
    CREATE PROCEDURE, ALTER PROCEDURE, DROP PROCEDURE,  
    CREATE FUNCTION, ALTER FUNCTION, DROP FUNCTION,  
    CREATE PACKAGE, ALTER PACKAGE, DROP PACKAGE,  
    CREATE TRIGGER, ALTER TRIGGER, DROP TRIGGER,  
    CREATE SYNONYM, DROP SYNONYM,  
    CREATE TYPE, ALTER TYPE, DROP TYPE,  
    CREATE USER, ALTER USER, DROP USER;
    
AUDIT POLICY AUDIT_DDL_CHANGES;

--===========================================================================

--## Verificar políticas de auditoria ativas  

SELECT POLICY_NAME FROM AUDIT_UNIFIED_ENABLED_POLICIES;

--===========================================================================

--## Consultar auditorias registradas  

SET LINESIZE 200
SET PAGESIZE 100
SET TRIMOUT ON
SET TRIMSPool ON
SET LONG 2000
COLUMN EVENT_TIMESTAMP FORMAT A30
COLUMN DBUSERNAME FORMAT A20
COLUMN ACTION_NAME FORMAT A30
COLUMN OBJECT_NAME FORMAT A30
COLUMN RETURN_CODE FORMAT 99999
COLUMN UNIFIED_AUDIT_POLICIES FORMAT A30

SELECT EVENT_TIMESTAMP, 
       DBUSERNAME, 
       ACTION_NAME, 
       OBJECT_NAME, 
       RETURN_CODE, 
       UNIFIED_AUDIT_POLICIES
FROM UNIFIED_AUDIT_TRAIL
ORDER BY EVENT_TIMESTAMP DESC;

--===========================================================================

--## Remover registros de auditoria com mais de 30 dias  

BEGIN  
  DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
    AUDIT_TRAIL_TYPE => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,  
    LAST_ARCHIVE_TIME => SYSTIMESTAMP - INTERVAL '30' DAY  
  );  

  DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
    AUDIT_TRAIL_TYPE => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,  
    USE_LAST_ARCH_TIMESTAMP => TRUE  
  );  
END;
/

--===========================================================================

--## Remover todos os registros da auditoria  

BEGIN
  DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
    AUDIT_TRAIL_TYPE => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    USE_LAST_ARCH_TIMESTAMP => FALSE
  );
END;
/

--===========================================================================

--## Desativar políticas de auditoria (sem excluir)  

NOAUDIT POLICY AUDIT_LOGON_FAIL;
NOAUDIT POLICY AUDIT_DDL_CHANGES;

--===========================================================================

--## Excluir políticas de auditoria  

DROP AUDIT POLICY AUDIT_LOGON_FAIL;
DROP AUDIT POLICY AUDIT_DDL_CHANGES;

--===========================================================================
