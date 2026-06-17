--===========================================================================
--## 20240829_testando_password_rollover_time.sql
--## https://dbasobrinho.com.br
--## https://dbasobrinho.com.br/testando-o-password_rollover_time-com-alter-user-e-alter-profile-no-oracle-database/
--## Autor: Roberto Sobrinho
--## Data de criação: 29/08/2024
--===========================================================================

--## Introdução
--## Administrar trocas de senha em sistemas críticos é desafiador, especialmente quando há necessidade de atualizar 
--## credenciais sem interrupções. Oracle Database oferece uma solução com o parâmetro PASSWORD_ROLLOVER_TIME, que 
--## mantém a senha anterior válida por um tempo específico após sua alteração. Esse recurso, introduzido no Oracle 21c e 
--## disponível a partir da atualização 19.12 no Oracle 19c, facilita transições de senha.
--## A seguir, veremos como configurar e testar o PASSWORD_ROLLOVER_TIME com os comandos ALTER USER e ALTER PROFILE.

--===========================================================================

--## Caso Real
--## Um cliente necessitava implementar uma política de troca de senhas para usuários aplicacionais em um ambiente Oracle, 
--## mas encontrou dificuldades em evitar interrupções de serviço devido aos múltiplos pontos de acesso. A solução foi usar 
--## PASSWORD_ROLLOVER_TIME, permitindo ao cliente realizar a troca de senhas de forma gradual e mantendo a senha antiga 
--## válida por um tempo determinado.

--===========================================================================

--## Passo a Passo para Testes

--## 1. Criação do Ambiente de Teste
--## Vamos criar um perfil chamado PERFIL_DA_VILA e alguns usuários associados a este perfil:

CREATE PROFILE PERFIL_DA_VILA LIMIT PASSWORD_ROLLOVER_TIME 1D;

CREATE USER chaves IDENTIFIED BY senha123 PROFILE PERFIL_DA_VILA;
CREATE USER kiko IDENTIFIED BY senha123 PROFILE PERFIL_DA_VILA;
CREATE USER chiquinha IDENTIFIED BY senha123 PROFILE PERFIL_DA_VILA;

GRANT CREATE SESSION TO chaves;
GRANT CREATE SESSION TO kiko;
GRANT CREATE SESSION TO chiquinha;

--## O perfil PERFIL_DA_VILA permite que os usuários utilizem suas senhas antigas por 1 dia após a mudança.

--===========================================================================

--## 2. Alterando o Perfil com ALTER PROFILE
--## Se necessário, podemos ajustar o período de rollover para todo o perfil PERFIL_DA_VILA utilizando o comando ALTER PROFILE:

ALTER PROFILE PERFIL_DA_VILA LIMIT PASSWORD_ROLLOVER_TIME 6H;

--## Este comando ajusta o tempo de rollover para 6 horas para todos os usuários associados ao perfil.

--===========================================================================

--## 3. Verificando a Aplicação do PASSWORD_ROLLOVER_TIME
--## Após alterar o perfil, mude a senha de um dos usuários e teste se o PASSWORD_ROLLOVER_TIME está funcionando conforme esperado:

--## Alterando a senha do usuário
ALTER USER chaves IDENTIFIED BY nova_senha;

--## Teste o login com a senha antiga e nova:
--## Senha Anterior: Deve funcionar por 6 horas
sqlplus chaves/senha123@pdb

--## Nova Senha: Deve funcionar imediatamente
sqlplus chaves/nova_senha@pdb

--## Comandos de Teste
--## Comando 01: Altera a senha do usuário chaves para nova_senha.
--## Comando 02: Tenta login no banco de dados com a senha antiga, válida pelo período de rollover.
--## Comando 03: Tenta login no banco de dados com a nova senha, que deve ser aceita imediatamente.

--===========================================================================

--## 4. Compatibilidade
--## Oracle 19c: Disponível a partir da atualização 19.12.
--## Oracle 21c: Introdução inicial do recurso PASSWORD_ROLLOVER_TIME.

--===========================================================================

--## 5. Exclusão dos Objetos Criados
--## Após os testes, limpe o ambiente removendo os usuários e o perfil criado:

DROP USER chaves CASCADE;
DROP USER kiko CASCADE;
DROP USER chiquinha CASCADE;
DROP PROFILE PERFIL_DA_VILA;

--## O PASSWORD_ROLLOVER_TIME permite gerenciar transições de senha com segurança e eficiência, possibilitando ajustes 
--## no comportamento do banco conforme as necessidades do sistema. Realizar testes assegura que usuários passem pelas 
--## trocas de senha sem interrupções.

--===========================================================================
