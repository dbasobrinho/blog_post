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

https://github.com/dbasobrinho/g_gold/blob/master/find_text_view_source.sql