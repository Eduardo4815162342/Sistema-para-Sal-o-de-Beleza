CREATE TABLE Clientes (
ClienteID serial PRIMARY KEY,
Nome VARCHAR(255) NOT NULL,
CPF VARCHAR(11) UNIQUE NOT NULL,
DataNascimento DATE NOT NULL,
Endereco VARCHAR(255) NOT NULL,
Telefone VARCHAR(15),
Alergias TEXT
);

CREATE TABLE Funcionarios (
FuncionarioID serial PRIMARY KEY,
Nome VARCHAR(255) NOT NULL,
CPF VARCHAR(11) UNIQUE NOT NULL,
DataNascimento DATE NOT NULL,
Endereco VARCHAR(255) NOT NULL,
Telefone VARCHAR(15),
Funcao VARCHAR(100) NOT NULL,
DataAdmissao DATE NOT NULL,
Salario DECIMAL(10, 2) NOT NULL
);

CREATE TABLE Produtos (
ProdutoID serial PRIMARY KEY,
Nome VARCHAR(255) NOT NULL,
Descricao TEXT,
CodigoUnico VARCHAR(50) UNIQUE NOT NULL,
Quantidade INT NOT NULL
);
ALTER TABLE Produtos
ADD COLUMN PrecoUnitario DECIMAL(10, 2);
CREATE TABLE Servicos (
ServicoID serial PRIMARY KEY,
Nome VARCHAR(255) NOT NULL,
Descricao TEXT,
Valor DECIMAL(10, 2) NOT NULL
);

CREATE TABLE Agendamentos (
AgendamentoID serial PRIMARY KEY,
ClienteID INT REFERENCES Clientes(ClienteID),
FuncionarioID INT REFERENCES Funcionarios(FuncionarioID),
DataHorario TIMESTAMP NOT NULL,
ServicoID INT REFERENCES Servicos(ServicoID)
);



CREATE TABLE HistoricoAtendimento (
HistoricoID serial PRIMARY KEY,
ClienteID INT REFERENCES Clientes(ClienteID),
Detalhes TEXT,
DataAtendimento DATE NOT NULL
);

CREATE TABLE Pagamentos (
PagamentoID serial PRIMARY KEY,
AgendamentoID INT REFERENCES Agendamentos(AgendamentoID),
ValorTotal DECIMAL(10, 2) NOT NULL,
FormaPagamento VARCHAR(50) NOT NULL
);

CREATE TABLE Atendimentos (
AtendimentoID serial PRIMARY KEY,
AgendamentoID INT REFERENCES Agendamentos(AgendamentoID),
FuncionarioID INT REFERENCES Funcionarios(FuncionarioID),
ServicoID INT REFERENCES Servicos(ServicoID),
DataHora TIMESTAMP NOT NULL,
Observacoes TEXT
);



CREATE TABLE ProdutosAtendimento (
ProdutosAtendimentoID serial PRIMARY KEY,
AtendimentoID INT REFERENCES Atendimentos(AtendimentoID),
ProdutoID INT REFERENCES Produtos(ProdutoID),
QuantidadeUtilizada INT
);

ALTER TABLE Atendimentos
ADD COLUMN idPagamento INT REFERENCES Pagamentos(PagamentoID);

ALTER TABLE Agendamentos
ADD COLUMN AtendimentoID INT REFERENCES Atendimentos(AtendimentoID);



--procedures, functions e triggers

CREATE OR REPLACE PROCEDURE realizar_atendimento(
    _clienteID INT, 
    _funcionarioID INT, 
    _servicoID INT, 
    _produtoID INT, 
    _quantidadeProduto INT, 
    _dataHorario TIMESTAMP,
    _detalhesBase TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    _agendamentoID INT;
    _atendimentoID INT;
    _detalhes TEXT;
BEGIN
    
    SELECT AgendamentoID INTO _agendamentoID FROM Agendamentos
    WHERE ClienteID = _clienteID AND FuncionarioID = _funcionarioID AND DataHorario = _dataHorario;

    IF _agendamentoID IS NULL THEN
        
        INSERT INTO Agendamentos (ClienteID, FuncionarioID, ServicoID, DataHorario)
        VALUES (_clienteID, _funcionarioID, _servicoID, _dataHorario)
        RETURNING AgendamentoID INTO _agendamentoID;
 END IF;


    INSERT INTO Atendimentos (AgendamentoID, FuncionarioID, ServicoID, DataHora)
    VALUES (_agendamentoID, _funcionarioID, _servicoID, _dataHorario)
    RETURNING AtendimentoID INTO _atendimentoID;


    INSERT INTO ProdutosAtendimento (AtendimentoID, ProdutoID, QuantidadeUtilizada)
    VALUES (_atendimentoID, _produtoID, _quantidadeProduto);

 
    UPDATE Agendamentos
    SET AtendimentoID = _atendimentoID
    WHERE AgendamentoID = _agendamentoID;

   
    _detalhes := _atendimentoID || ' - ' || _detalhesBase;

   
    INSERT INTO HistoricoAtendimento (ClienteID, Detalhes, DataAtendimento)
    VALUES (_clienteID, _detalhes, _dataHorario::date);

    RAISE NOTICE 'Atendimento realizado com sucesso.';
END;
$$;

CREATE OR REPLACE PROCEDURE registrar_pagamento(_agendamentoID INT, _valorTotal DECIMAL(10, 2), _formaPagamento VARCHAR(50))
LANGUAGE plpgsql
AS $$
DECLARE
    _pagamentoID INT;
    _atendimentoID INT;
    _totalAtendimento DECIMAL(10, 2) := 0;
    _totalProdutos DECIMAL(10, 2) := 0;
BEGIN
    
    SELECT AtendimentoID INTO _atendimentoID FROM Atendimentos
    WHERE AgendamentoID = _agendamentoID;

    IF _atendimentoID IS NOT NULL THEN
       
        SELECT COALESCE(SUM(Servicos.Valor), 0) INTO _totalAtendimento
        FROM Atendimentos
        JOIN Servicos ON Atendimentos.ServicoID = Servicos.ServicoID
        WHERE Atendimentos.AtendimentoID = _atendimentoID;

        
        SELECT COALESCE(SUM(Produtos.PrecoUnitario * ProdutosAtendimento.QuantidadeUtilizada), 0) INTO _totalProdutos
        FROM ProdutosAtendimento
        JOIN Produtos ON ProdutosAtendimento.ProdutoID = Produtos.ProdutoID
        WHERE ProdutosAtendimento.AtendimentoID = _atendimentoID;

        _totalAtendimento := _totalAtendimento + _totalProdutos;

       
        IF _valorTotal = _totalAtendimento THEN
          
            INSERT INTO Pagamentos (AgendamentoID, ValorTotal, FormaPagamento)
            VALUES (_agendamentoID, _valorTotal, _formaPagamento)
            RETURNING PagamentoID INTO _pagamentoID;

           
            UPDATE Atendimentos
            SET idPagamento = _pagamentoID
            WHERE AtendimentoID = _atendimentoID;

            RAISE NOTICE 'Pagamento registrado e atendimento atualizado com sucesso.';
        ELSE
            RAISE EXCEPTION 'Falha no registro de pagamento: o valor do pagamento não corresponde ao total do atendimento.';
        END IF;
    ELSE
        RAISE EXCEPTION 'Falha no registro de pagamento: nenhum atendimento encontrado para o agendamento fornecido.';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION agendar_atendimento(_clienteID INT, _funcionarioID INT, _servicoID INT, _dataHorario TIMESTAMP)
RETURNS VARCHAR AS $$
DECLARE
    conflito INT;
BEGIN
    -- Verifica se há conflito de horário
    SELECT COUNT(*) INTO conflito FROM Agendamentos
    WHERE FuncionarioID = _funcionarioID AND DataHorario = _dataHorario;

    IF conflito = 0 THEN
        -- Insere o novo agendamento
        INSERT INTO Agendamentos (ClienteID, FuncionarioID, ServicoID, DataHorario)
        VALUES (_clienteID, _funcionarioID, _servicoID, _dataHorario);

        RETURN 'Agendamento realizado com sucesso.';
    ELSE
        -- Conflito de horário
        RETURN 'Falha no agendamento: o funcionário já tem um compromisso neste horário.';
    END IF;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION update_estoque()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE Produtos
  SET Quantidade = Quantidade - NEW.QuantidadeUtilizada
  WHERE ProdutoID = NEW.ProdutoID;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION check_funcionario_disponibilidade()
RETURNS TRIGGER AS $$
BEGIN
  -- Verifica se existe algum agendamento no mesmo horário para o funcionário
  IF EXISTS (
    SELECT 1 FROM Agendamentos
    WHERE FuncionarioID = NEW.FuncionarioID
    AND DataHorario = NEW.DataHorario
  ) THEN
    -- Se existir, lança um erro
    RAISE EXCEPTION 'Funcionário já possui um agendamento para este horário.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_estoque_after_atendimento
AFTER INSERT ON ProdutosAtendimento
FOR EACH ROW
EXECUTE FUNCTION update_estoque();

CREATE TRIGGER trg_check_disponibilidade
BEFORE INSERT ON Agendamentos
FOR EACH ROW
EXECUTE FUNCTION check_funcionario_disponibilidade();
