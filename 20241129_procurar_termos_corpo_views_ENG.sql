--===========================================================================
--## 20241129_find_terms_in_view_source.sql
--## https://github.com/dbasobrinho/blog_post/blob/main/20241129_find_terms_in_view_source.sql
--## https://dbasobrinho.com.br/procurar-tabelas-colunas-ou-termos-no-corpo-das-views/
--## Author: Roberto Fernandes Sobrinho
--## Creation Date: 2024-11-29
--===========================================================================

--===========================================================================
--## Find tables, columns, or terms in view definitions
--## Have you ever needed to figure out where a table, column, or any keyword 
--## appears in the code of views?
--## 
--## Using DBA_DEPENDENCIES seems like the obvious solution, but it only shows 
--## structural dependencies. In other words, it does not help locate keywords 
--## directly in the code of views. When you need to search for something like 
--## a table name or a specific column, you need a different approach.
--##
--## The script `find_text_view_source.sql` searches directly in the code of 
--## views using the DBMS_METADATA package. It allows you to locate any 
--## keyword you specify, whether it is a table, column, alias, or any other term.
--===========================================================================

--===========================================================================
--## How to use:
--## 1. Download the script: It is available in the GitHub repository.
--## 2. Save it in your environment: Save it as "find_text_view_source.sql".
--## 3. Run it in SQL*Plus or a similar tool.
--## 
--## Example scenario:
--## You are the DBA responsible for the database, and the development team 
--## urgently requests your help. They need to know all the views that reference 
--## the table or term "CT_CONTRATO" because a planned change might directly 
--## impact these objects. This script helps you quickly locate where this term 
--## appears.
--===========================================================================

https://github.com/dbasobrinho/g_gold/blob/master/find_text_view_source.sql
