--Listar Todos os Agendamentos para uma Data Específica

SELECT * 
FROM Agendamentos 
WHERE DataHorario::date = '2023-11-15'
order by datahorario



--Verificar a Agenda de um Funcionário em Particular para um Dia Específico:

SELECT A.AgendamentoID, A.DataHorario, C.Nome AS Cliente, S.Nome AS Servico
FROM Agendamentos A
JOIN Clientes C ON A.ClienteID = C.ClienteID
JOIN Servicos S ON A.ServicoID = S.ServicoID
WHERE A.FuncionarioID = 2 AND A.DataHorario::date = '2023-11-15'
order by datahorario



--Listar Atendimentos Realizados por um Funcionário Específico:

SELECT At.AtendimentoID, At.DataHora, C.Nome AS Cliente, S.Nome AS Servico, At.Observacoes
FROM Atendimentos At
JOIN Clientes C ON At.AgendamentoID = C.ClienteID
JOIN Servicos S ON At.ServicoID = S.ServicoID
WHERE At.FuncionarioID = 2;



--Verificar Atendimentos Que Ainda Não Foram Pagos:

SELECT At.AtendimentoID, At.DataHora, C.Nome AS Cliente, S.Nome AS Servico
FROM Atendimentos At
JOIN Clientes C ON At.AgendamentoID = C.ClienteID
JOIN Servicos S ON At.ServicoID = S.ServicoID
WHERE At.idPagamento IS NULL;



--Detalhar Produtos Utilizados em um Atendimento Específico:

SELECT P.Nome, PA.QuantidadeUtilizada
FROM ProdutosAtendimento PA
JOIN Produtos P ON PA.ProdutoID = P.ProdutoID
WHERE PA.AtendimentoID = 1;



-Histórico de Atendimentos de um Cliente:

SELECT HA.HistoricoID, HA.DataAtendimento, HA.Detalhes
FROM HistoricoAtendimento HA
WHERE HA.ClienteID = 1;



--Listar Todos os Pagamentos Realizados em um Dia Específico:

SELECT 
    P.PagamentoID, 
    MIN(A.DataHora) AS PrimeiroAtendimento, 
    MAX(A.DataHora) AS UltimoAtendimento, 
    P.ValorTotal, 
    P.FormaPagamento, 
    STRING_AGG(C.Nome, ', ') AS Clientes
FROM Pagamentos P
JOIN Atendimentos A ON P.AgendamentoID = A.AgendamentoID
JOIN Agendamentos AG ON A.AgendamentoID = AG.AgendamentoID
JOIN Clientes C ON AG.ClienteID = C.ClienteID
GROUP BY P.PagamentoID, P.ValorTotal, P.FormaPagamento
HAVING MIN(A.DataHora)::date = '2023-11-15';

