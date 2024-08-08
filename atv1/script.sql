DROP DATABASE IF EXISTS system_registro;


CREATE DATABASE system_registro;

\c system_registro;

CREATE TABLE funcionario (
    id SERIAL ,
    nome VARCHAR(100) NOT NULL,
    senha VARCHAR(100) NOT NULL,
    CONSTRAINT pk_funcionario PRIMARY KEY (id)
);

CREATE TABLE registro (
    id SERIAL,
    data_hora_entrada TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_hora_saida TIMESTAMP,
    funcionario_id INTEGER,
    CONSTRAINT fk_funcionario_id FOREIGN KEY (funcionario_id)
        REFERENCES funcionario (id)
);

INSERT INTO funcionario (nome, senha) VALUES 
('John Silveira', '123456'),
('Teste 1', '123456'),
('Teste 2', '123456'),
('Teste 3', '123456'),
('Teste 4', '123456');

INSERT INTO registro(funcionario_id, data_hora_entrada) VALUES
(1, NOW() - INTERVAL '1 hour'),
(3, NOW() - INTERVAL '2 hour'),
(5, NOW() - INTERVAL '3 hour');

CREATE OR REPLACE FUNCTION registrar_entrada() RETURNS VOID AS
$$
DECLARE 
    colaboradores RECORD;
BEGIN
 FOR colaboradores IN 
        SELECT f.id FROM funcionario f LEFT JOIN registro r ON f.id=r.funcionario_id WHERE r.data_hora_entrada is null
    LOOP         
        INSERT INTO registro(funcionario_id, data_hora_entrada) 
        VALUES (colaboradores.id, NOW() - INTERVAL '8 hour');
        UPDATE registro SET data_hora_saida = NOW() WHERE funcionario_id = colaboradores.id AND data_hora_saida IS NULL;
    END LOOP;    
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION listar_funcionarios_mais_horas_trabalhadas() RETURNS TABLE(nome VARCHAR, horas_trabalhadas INTERVAL) AS
$$
BEGIN
    RETURN QUERY
    SELECT f.nome, SUM(r.data_hora_saida - r.data_hora_entrada) AS horas_trabalhadas FROM funcionario f JOIN registro r ON f.id = r.funcionario_id WHERE r.data_hora_entrada IS NOT NULL AND r.data_hora_saida IS NOT NULL GROUP BY f.id ORDER BY horas_trabalhadas DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION listar_funcionarios_sem_registro_de_saida() RETURNS TABLE(funcionario_id INTEGER, nome VARCHAR, data_hora_entrada TIMESTAMP) AS
$$
BEGIN
    RETURN QUERY
    SELECT f.id AS funcionario_id, f.nome, r.data_hora_entrada FROM funcionario f JOIN registro r ON f.id = r.funcionario_id WHERE r.data_hora_saida IS NULL ORDER BY r.data_hora_entrada;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM registrar_entrada();

SELECT * FROM listar_funcionarios_mais_horas_trabalhadas();

SELECT * FROM listar_funcionarios_sem_registro_de_saida();