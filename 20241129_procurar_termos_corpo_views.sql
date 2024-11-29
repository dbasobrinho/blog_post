--===========================================================================
--## 20241129_procurar_termos_corpo_views.sql
--## https://github.com/dbasobrinho/blog_post/blob/main/20241129_procurar_termos_corpo_views.sql
--## https://dbasobrinho.com.br/procurar-tabelas-colunas-ou-termos-no-corpo-das-views/
--## Autor: Roberto Fernandes Sobrinho
--## Data de criação: 2024-11-29
--===========================================================================

--===========================================================================
--## Procurar tabelas, colunas ou termos no corpo das views
--## Já se viu em uma situação em que precisava descobrir onde uma tabela, coluna 
--## ou qualquer texto-chave aparece no código das views?
--## 
--## Usar a DBA_DEPENDENCIES parece a solução óbvia, mas ela só mostra dependências 
--## estruturais. Ou seja, não ajuda a localizar palavras-chave diretamente no 
--## código das views. Quando você quer buscar algo como o nome de uma tabela ou 
--## uma coluna específica, precisa de algo diferente.
--## 
--## O script find_text_view_source.sql busca diretamente no código das views, 
--## utilizando o pacote DBMS_METADATA. Ele permite localizar qualquer 
--## palavra-chave que você informar, seja uma tabela, coluna, alias ou qualquer 
--## termo desejado.
--===========================================================================
 
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR EXIT;
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => 'find_text_view_source', action_name => 'search_text');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;

PROMPT
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/blog_post/blob/main/20241129_procurar_termos_corpo_views.sql |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | Script   : LOCALIZAR TEXTO DENTRO DE VIEWS                       +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT | Instância: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|   |
PROMPT | Versão   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT

SET ECHO        OFF
SET FEEDBACK    OFF
SET HEADING     ON
SET LINES       188
SET PAGES       300
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
SET TIME        OFF
SET TIMING      OFF
SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ================================================================================
PROMPT |            *** BUSCA DEPENDÊNCIAS EM VIEWS POR PALAVRA-CHAVE ***             |
PROMPT ================================================================================
PROMPT |                  Informe o texto a ser buscado nas views e pressione [Enter]:|
PROMPT ================================================================================
ACCEPT p_busca CHAR PROMPT '| Palavra-chave: '
PROMPT ================================================================================
--===========================================================================
--## Bloco PL/SQL para realizar a busca no corpo das views.
DECLARE
    v_busca VARCHAR2(200) := UPPER(TRIM('&p_busca'));
BEGIN
    IF LENGTH(nvl(v_busca, 'x')) <= 3 THEN
        DBMS_OUTPUT.PUT_LINE('       A palavra-chave deve ter mais de 3 caracteres. Busca cancelada.');
        RETURN;
    END IF;

    FOR rec IN (
        SELECT view_name, owner
        FROM   dba_views
        ORDER  BY owner, view_name
    ) LOOP
        IF DBMS_LOB.INSTR(UPPER(DBMS_METADATA.GET_DDL('VIEW', rec.view_name, rec.owner)), v_busca) > 0 THEN
            DBMS_OUTPUT.PUT_LINE('       View : ' || rec.owner || '.' || rec.view_name);
        END IF;
    END LOOP;
END;
/
--===========================================================================

PROMPT ================================================================================
PROMPT |                       *** BUSCA FINALIZADA! ***                             |
PROMPT ================================================================================
SET FEEDBACK ON
SET VERIFY ON

--===========================================================================
--## Como usar:
--## 1. Baixe o script: Ele está disponível no repositório do GitHub.
--## 2. Salve no ambiente: Guarde como "find_text_view_source.sql".
--## 3. Execute no SQL*Plus ou em uma ferramenta similar.
--## 
--## Cenário exemplo:
--## Você é o DBA responsável pelo banco de dados e recebe uma solicitação urgente do time de desenvolvimento. 
--## Eles precisam saber todas as views que mencionam a tabela ou termo "CT_CONTRATO", pois há uma alteração 
--## planejada que pode impactar diretamente esses objetos. Este script ajuda a localizar rapidamente onde 
--## esse termo aparece.
--===========================================================================

