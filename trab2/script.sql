DROP DATABASE IF EXISTS igor_faxinas;

CREATE DATABASE igor_faxinas;

\c igor_faxinas;

CREATE TABLE diarista (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cpf CHAR(11) UNIQUE NOT NULL 
);

CREATE TABLE responsavel(
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cpf CHAR(11) UNIQUE NOT NULL 
);


CREATE TABLE tamanho_residencia (
    id SERIAL PRIMARY KEY,
    tamanho VARCHAR(10) CHECK (tamanho IN ('pequena', 'media', 'grande'))
);

CREATE TABLE residencia (
    id SERIAL PRIMARY KEY,
    responsavel_id INT NOT NULL,
    cidade VARCHAR(100) NOT NULL,
    bairro VARCHAR(100) NOT NULL,
    rua VARCHAR(100) NOT NULL,
    complemento VARCHAR(100),
    numero INT NOT NULL,
    tamanho INT NOT NULL,
    FOREIGN KEY (tamanho) REFERENCES tamanho_residencia(id),
    FOREIGN KEY (responsavel_id) REFERENCES responsavel(id)
);

CREATE TABLE faxina (
    id SERIAL NOT NULL,
    diarista_id INT NOT NULL,
    residencia_id INT NOT NULL,
    data DATE NOT NULL,
    foi_realizada BOOLEAN NOT NULL,
    feedback TEXT,
    valor_pago DECIMAL(10, 2) NOT NULL CHECK(foi_realizada = TRUE AND valor_pago >= 0),
    PRIMARY KEY (id, data, diarista_id),
    FOREIGN KEY (diarista_id) REFERENCES diarista(id),
    FOREIGN KEY (residencia_id) REFERENCES residencia(id)
);


CREATE TABLE precoFaxina (
    id SERIAL PRIMARY KEY,
    preco DECIMAL(10, 2) NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE,
    tamanho_residencia INT NOT NULL,
    FOREIGN KEY (tamanho_residencia) REFERENCES tamanho_residencia(id)
);

CREATE OR REPLACE FUNCTION agendar_faxinas_data_limite(
    p_diarista_id INT,
    p_residencia_id INT,
    p_periodo VARCHAR,
    p_data_limite DATE
) RETURNS VOID AS $$
DECLARE
    v_data DATE;
BEGIN
    v_data := CURRENT_DATE;

    IF p_periodo = 'quinzenal' THEN
        v_data := v_data + INTERVAL '14 days';
    ELSIF p_periodo = 'mensal' THEN
        v_data := v_data + INTERVAL '1 month';
    ELSE
        RAISE EXCEPTION 'Período inválido. Use "quinzenal" ou "mensal".';
    END IF;

    WHILE v_data <= p_data_limite LOOP
        INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, valor_pago) 
        VALUES (p_diarista_id, p_residencia_id, v_data, FALSE, 0.00);
        
        IF p_periodo = 'quinzenal' THEN
            v_data := v_data + INTERVAL '14 days';
        ELSIF p_periodo = 'mensal' THEN
            v_data := v_data + INTERVAL '1 month';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION agendar_faxinas_quantidade(
    p_diarista_id INT,
    p_residencia_id INT,
    p_periodo VARCHAR,
    p_quantidade_max INT
) RETURNS VOID AS $$
DECLARE
    v_data DATE;
    v_count INT := 0;
BEGIN
    v_data := CURRENT_DATE;

    IF p_periodo = 'quinzenal' THEN
        v_data := v_data + INTERVAL '14 days';
    ELSIF p_periodo = 'mensal' THEN
        v_data := v_data + INTERVAL '1 month';
    ELSE
        RAISE EXCEPTION 'Período inválido. Use "quinzenal" ou "mensal".';
    END IF;

    WHILE v_count < p_quantidade_max LOOP
        INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, valor_pago) 
        VALUES (p_diarista_id, p_residencia_id, v_data, FALSE, 0.00);
        
        v_count := v_count + 1;

        IF p_periodo = 'quinzenal' THEN
            v_data := v_data + INTERVAL '14 days';
        ELSIF p_periodo = 'mensal' THEN
            v_data := v_data + INTERVAL '1 month';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION calcular_presenca_diarista(
    p_diarista_id INT,
    p_ano INT
) RETURNS NUMERIC AS $$
DECLARE
    v_total INT;
    v_presencas INT;
    v_porcentagem NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_total 
    FROM faxina 
    WHERE diarista_id = p_diarista_id 
    AND EXTRACT(YEAR FROM data) = p_ano;

    SELECT COUNT(*) INTO v_presencas 
    FROM faxina 
    WHERE diarista_id = p_diarista_id 
    AND EXTRACT(YEAR FROM data) = p_ano
    AND foi_realizada = TRUE;

    IF v_total = 0 THEN
        RETURN 0;
    ELSE
        v_porcentagem := (v_presencas::NUMERIC / v_total::NUMERIC) * 100;
        RETURN v_porcentagem;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION verificar_presenca_diarista() RETURNS TRIGGER AS $$
DECLARE
    v_presenca NUMERIC;
BEGIN
    SELECT calcular_presenca_diarista(NEW.diarista_id, CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS INTEGER)) INTO v_presenca;

    IF v_presenca < 75 THEN
        DELETE FROM Diarista WHERE id = NEW.diarista_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_verificar_presenca AFTER INSERT OR UPDATE ON faxina
FOR EACH ROW EXECUTE FUNCTION verificar_presenca_diarista();


-- Insert data
INSERT INTO diarista (nome, cpf) VALUES ('Ana Silva','12345678901');
INSERT INTO diarista (nome, cpf) VALUES ('Beatriz Souza','23456789012');
INSERT INTO diarista (nome, cpf) VALUES ('Clara Oliveira','34567890123',);
INSERT INTO diarista (nome, cpf) VALUES ('Maria Silva', '12345678901');
INSERT INTO diarista (nome, cpf) VALUES ('Ana Oliveira', '23456789012');
INSERT INTO diarista (nome, cpf) VALUES ('João Souza', '34567890123');
INSERT INTO diarista (nome, cpf) VALUES ('Paula Mendes', '45678901234');
INSERT INTO diarista (nome, cpf) VALUES ('Lucas Pereira', '56789012345');
INSERT INTO diarista (nome, cpf) VALUES ('Pedro Lima', '67890123456');


INSERT INTO responsavel (nome, cpf) VALUES ('Carlos Pereira', '45678901234');
INSERT INTO responsavel (nome, cpf) VALUES ('Daniela Lima','56789012345');
INSERT INTO responsavel (nome, cpf) VALUES ('Eduardo Santos','67890123456');
INSERT INTO responsavel (nome, cpf) VALUES ('Carlos Almeida', '67890123456');
INSERT INTO responsavel (nome, cpf) VALUES ('Fernanda Costa', '78901234567');
INSERT INTO responsavel (nome, cpf) VALUES ('Rafael Santos', '89012345678');
INSERT INTO responsavel (nome, cpf) VALUES ('Juliana Ramos', '90123456789');
INSERT INTO responsavel (nome, cpf) VALUES ('Bruno Ferreira', '01234567890');
INSERT INTO responsavel (nome, cpf) VALUES ('Mariana Oliveira', '12345678901');


INSERT INTO tamanho_residencia (tamanho) VALUES ('pequena');
INSERT INTO tamanho_residencia (tamanho) VALUES ('media');
INSERT INTO tamanho_residencia (tamanho) VALUES ('grande');

INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (1, 'São Paulo', 'Centro', 'Rua A', 'Apto 101', 123, 1);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (2, 'Rio de Janeiro', 'Copacabana', 'Rua B', '', 456, 2);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (3, 'Belo Horizonte', 'Savassi', 'Rua C', 'Casa', 789, 3);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (1, 'São Paulo', 'Vila Mariana', 'Rua das Flores', 'Apto 12', 120, 1);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (2, 'Rio de Janeiro', 'Copacabana', 'Avenida Atlântica', '', 85, 2);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (3, 'Belo Horizonte', 'Savassi', 'Rua Pernambuco', 'Bloco B', 45, 3);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (4, 'Curitiba', 'Centro', 'Rua XV de Novembro', 'Casa 3', 37, 1);
INSERT INTO residencia (responsavel_id, cidade, bairro, rua, complemento, numero, tamanho) 
VALUES (5, 'Porto Alegre', 'Moinhos de Vento', 'Rua Padre Chagas', '', 95, 2);


INSERT INTO precoFaxina (tamanho_residencia, preco, data_inicio, data_fim) 
VALUES (1, 100.00, '2024-01-01', NULL);
INSERT INTO precoFaxina (tamanho_residencia, preco, data_inicio, data_fim) 
VALUES (2, 150.00, '2024-01-01', NULL);
INSERT INTO precoFaxina (tamanho_residencia, preco, data_inicio, data_fim) 
VALUES (3, 200.00, '2024-01-01', NULL);
INSERT INTO precoFaxina (preco, data_inicio, data_fim, tamanho_residencia) 
VALUES (80.00, '2024-01-01', '2024-06-30', 1);
INSERT INTO precoFaxina (preco, data_inicio, data_fim, tamanho_residencia) 
VALUES (120.00, '2024-01-01', '2024-06-30', 2);
INSERT INTO precoFaxina (preco, data_inicio, data_fim, tamanho_residencia) 
VALUES (160.00, '2024-01-01', '2024-06-30', 3);
INSERT INTO precoFaxina (preco, data_inicio, data_fim, tamanho_residencia) 
VALUES (90.00, '2024-07-01', NULL, 1);
INSERT INTO precoFaxina (preco, data_inicio, data_fim, tamanho_residencia) 
VALUES (130.00, '2024-07-01', NULL, 2);


INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (1, 1, '2024-02-01', TRUE, 'Excelente trabalho!', 100.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (2, 2, '2024-02-02', TRUE, 'Muito bom, mas chegou atrasada.', 140.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (3, 3, '2024-02-03', FALSE, '', 0.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (1, 4, '2024-02-05', TRUE, 'Trabalho satisfatório, mas poderia ser mais rápido.', 120.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (2, 5, '2024-02-06', TRUE, 'Excelente, muito detalhista.', 150.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (3, 6, '2024-02-07', TRUE, 'Fez tudo conforme solicitado, muito bom.', 130.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (4, 7, '2024-02-08', TRUE, 'Cumpriu o horário e fez um bom trabalho.', 110.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (5, 8, '2024-02-09', TRUE, 'A limpeza foi boa, mas o atendimento poderia melhorar.', 125.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (1, 1, '2024-02-10', FALSE, 'Diarista não apareceu.', 0.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (2, 2, '2024-02-11', TRUE, 'Ótima limpeza, muito cuidadosa.', 140.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (3, 3, '2024-02-12', TRUE, 'Fez além do que foi solicitado, excelente!', 160.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (4, 4, '2024-02-13', TRUE, 'Um pouco apressada, mas o trabalho foi bom.', 100.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (5, 5, '2024-02-14', TRUE, 'Muito profissional e eficiente.', 180.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (1, 6, '2024-02-15', TRUE, 'Fez um ótimo trabalho, mas teve dificuldade em algumas tarefas.', 115.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (2, 7, '2024-02-16', TRUE, 'Tudo foi bem organizado e limpo.', 155.00);
INSERT INTO faxina (diarista_id, residencia_id, data, foi_realizada, feedback, valor_pago) 
VALUES (3, 8, '2024-02-17', TRUE, 'Muito simpática e competente.', 145.00);