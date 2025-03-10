--===========================================================================
--## 20241001_evite_problemas_com_dblinks_ao_clonar_ambientes.sql
--## https://github.com/dbasobrinho/blog_post/blob/main/20241001_evite_problemas_com_dblinks_ao_clonar_ambientes.sql
--## https://dbasobrinho.com.br/evite-problemas-com-dblinks-ao-clonar-ambientes-oracle-guia-pratico-com-scripts/
--## Autor: Roberto Sobrinho
--## Data de criação: 01/10/2024
--===========================================================================

--## Clonar um ambiente de produção para homologação no Oracle Database é sempre problemático. 
--## Quem já passou por isso sabe que muita coisa pode dar errado, especialmente com os Database Links (DBLinks).
--## Um problema comum é que as senhas dos usuários nos DBLinks geralmente são diferentes entre os ambientes, 
--## causando falhas de conexão após a clonagem e, dependendo da configuração do DBLink e dos alcances entre 
--## as redes, até acessos indevidos entre ambientes. Vou compartilhar um passo a passo simples, com scripts, 
--## que uso para evitar esses problemas e garantir uma transição tranquila.

--===========================================================================

--## 01. Exportar os DBLinks do Ambiente Atual
--## Primeiro, execute um export dos DBLinks do ambiente que vai ser clonado. 
--## Isso garante que as informações dos links sejam preservadas, inclusive as senhas, 
--## para que possam ser restauradas após o clone.

-- LINUX
mkdir -p /u01/app/oracle/expdblink/backup_210624_1048

-- SQLPLUS
create or replace directory EXP_DBLINK as '/u01/app/oracle/expdblink/backup_210624_1048';

-- LINUX
expdp '/as sysdba' full=y directory=EXP_DBLINK cluster=n include=db_link dumpfile=EXPDP_DBLINK_`date '+%d%m%y'`.dmp logfile=DBLINK_`date '+%d%m%y_%H%M%S'`.log

--===========================================================================

--## 02. Apagar o Ambiente Destino e Clonar o Ambiente
--## Depois de fazer o export dos DBLinks, apague o ambiente atual e faça a clonagem do ambiente de produção para homologação.
--## Nota: Este guia não detalha o processo de clonagem em si.

--===========================================================================

--## 03. Apagar Todos os DBLinks no Ambiente Restaurado
--## Nota: Cuidado ao executar este script, ele vai excluir todos os DBLinks do ambiente. 
--## Saiba o que está fazendo e onde está executando.
--## Após restaurar o ambiente, exclua todos os DBLinks para evitar que as credenciais de produção sejam usadas de forma indevida.

-- db_links_DROP_ALL.sql
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => 'd[db_links_DROP_ALL.sql]', action_name => 'd[db_links_DROP_ALL.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;

SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/db_links_DROP_ALL.sql                     |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Remover Todos os DBLinks                              +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SET ECHO OFF
SET FEEDBACK 10
SET HEADING ON
SET LINES 188
SET PAGES 300 
SET TERMOUT ON
SET TIMING OFF
SET TRIMOUT ON
SET TRIMSPOOL ON
SET VERIFY OFF
UNDEFINE db_name
UNDEFINE proceed

COLUMN db_name NEW_VALUE db_name NOPRINT;
SELECT name AS db_name FROM v$database;

PROMPT Nome do Banco de Dados: &db_name
ACCEPT proceed CHAR PROMPT 'Para continuar e excluir TODOS os DBLinks, digite exatamente "dual": ';

WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR EXIT;

BEGIN
  IF nvl(LOWER(TRIM('&proceed')),'guina') != 'dual' THEN
    dbms_output.put_line('Operação cancelada pelo usuário. Nenhuma ação foi realizada.');
    RAISE_APPLICATION_ERROR(-20001, 'Script abortado pelo usuário.');
  END IF;
END;
/

COLUMN db_link FORMAT A30
COLUMN host FORMAT A60
COLUMN owner FORMAT A12
COLUMN username FORMAT A22

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Exibindo todos os DBLinks antes da exclusão                                               |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SELECT owner, db_link, username, host
FROM   dba_db_links
ORDER BY owner, db_link;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Realizando exclusão de TODOS os DBLinks                                                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SET SERVEROUTPUT ON
DECLARE
  vv_sql CLOB := 'CREATE PROCEDURE ##USU##.prc_auto_drop_db_links
                  IS
                  BEGIN
                    FOR i IN (SELECT * FROM user_db_links)
                    LOOP
                      EXECUTE IMMEDIATE ''DROP DATABASE LINK ''||i.db_link;
                    END LOOP;
                  END;';
  vv_sql1 clob;  
BEGIN
  FOR i IN (SELECT db_link FROM dba_db_links WHERE owner = 'PUBLIC' AND 1=1) LOOP
     EXECUTE IMMEDIATE 'DROP PUBLIC DATABASE LINK ' || i.db_link;
  END LOOP;

  FOR i in (SELECT DISTINCT owner 
             FROM dba_objects
            WHERE object_type='DATABASE LINK'
              AND owner IN (SELECT USERNAME FROM DBA_USERS) AND 1=1)
  LOOP
    vv_sql1 := REPLACE(vv_sql, '##USU##', i.owner);
    dbms_output.put_line('Excluindo DBLinks do usuario: ' || i.owner);
    EXECUTE IMMEDIATE vv_sql1;
    vv_sql1 := 'BEGIN ' || i.owner || '.prc_auto_drop_db_links; END;';
    EXECUTE IMMEDIATE vv_sql1;
    vv_sql1 := 'DROP PROCEDURE ' || i.owner || '.prc_auto_drop_db_links';
    EXECUTE IMMEDIATE vv_sql1;
  END LOOP;
END;
/

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Exibindo todos os DBLinks após a exclusão                                                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SELECT owner, db_link, username, host
FROM   dba_db_links
ORDER BY owner, db_link;

UNDEFINE db_name
UNDEFINE proceed

--===========================================================================

--## 04. Importar os DBLinks no Ambiente Restaurado
--## Agora, use o dump file criado no início para recriar os DBLinks no ambiente clonado.

-- LINUX
impdp '/as sysdba' directory=EXP_DBLINK dumpfile=EXPDP_DBLINK_300924.dmp logfile=IMPDP_DBLINK_`date '+%d%m%y_%H%M%S'`.log

--===========================================================================

--## 05. Validando
--## Execute o comando abaixo para validar a recriação dos DBLinks.

-- SQLPLUS
SET HEADING ON
SET LINES 188
COLUMN owner FORMAT A15
COLUMN db_link FORMAT A30
COLUMN username FORMAT A20
COLUMN host FORMAT A30

SELECT owner, db_link, username, host
FROM dba_db_links
ORDER BY owner, db_link;
SQLPLUS

--## Atualizar um ambiente de produção para homologação no Oracle Database pode ser um grande desafio, 
--## especialmente quando há DBLinks envolvidos. Com esse guia prático, você vai conseguir evitar grande 
--## parte dos problemas comuns que surgem durante a clonagem, garantindo que todas as credenciais e links 
--## estejam ajustados corretamente.
--===========================================================================

