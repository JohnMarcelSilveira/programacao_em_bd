DROP DATABASE IF EXISTS blog_igor;

CREATE DATABASE blog_igor;

\c blog_igor;

CREATE TABLE pessoa (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    senha VARCHAR(100) NOT NULL,
    tipo CHAR(1) NOT NULL CHECK (tipo IN ('L', 'A')),
    email VARCHAR(100) UNIQUE
);

INSERT INTO pessoa (nome, email, tipo, senha) VALUES 
('João Silva', 'joao.silva@example.com', 'L', 'senha123'),
('Maria Oliveira', 'maria.oliveira@example.com', 'A', 'senha456'),
('Carlos Souza', 'carlos.souza@example.com', 'L', 'senha789'),
('Ana Lima', 'ana.lima@example.com', 'A', 'senha101'),
('Fernanda Costa', 'fernanda.costa@example.com', 'L', 'senha102');

CREATE TABLE post(
    id SERIAL PRIMARY KEY,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    titulo VARCHAR(100) NOT NULL,
    texto TEXT,
    compartilhado BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO post (titulo, texto, compartilhado) VALUES 
('Introdução à Programação', 'Este é um post sobre introdução à programação.', TRUE),
('Desenvolvimento Web', 'Técnicas e ferramentas para desenvolvimento web moderno.', TRUE),
('Machine Learning', 'Explorando o mundo do aprendizado de máquina.', TRUE),
('Arquitetura de Software', 'Padrões e práticas para arquitetura de software eficiente.', TRUE),
('Banco de Dados', 'Conceitos básicos sobre banco de dados.', TRUE);

--Um Stored Procedured para ser usado na cláusula check que permita que somente autores (pessoa do tipo = 'A') escrevam posts
CREATE OR REPLACE FUNCTION ehLeitor(pessoa_id INTEGER) RETURNS BOOLEAN AS $$
    DECLARE
        tipo_p CHAR(1);
    BEGIN
        SELECT tipo INTO tipo_p FROM pessoa WHERE id = pessoa_id;
        IF tipo_p = 'L' THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END;

$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION postPermiteMultiplosAutores(post_id INTEGER) RETURNS BOOLEAN AS $$
BEGIN
    -- Retorna TRUE se o post permite múltiplos autores
    RETURN (SELECT compartilhado FROM post WHERE id = post_id);
END;
$$ LANGUAGE plpgsql;

CREATE TABLE endereco(
    id SERIAL PRIMARY KEY,
    bairro VARCHAR(100),
    rua VARCHAR(100),
    nro VARCHAR(5),
    cep VARCHAR(10),
    pessoa_id INTEGER REFERENCES pessoa(id) CHECK (ehLeitor(pessoa_id) is TRUE)
);

CREATE TABLE pessoa_post(
    pessoa_id INTEGER REFERENCES pessoa(id),
    post_id INTEGER REFERENCES post(id),
    PRIMARY KEY (pessoa_id, post_id),
    CONSTRAINT chk_eh_autor CHECK (ehLeitor(pessoa_id) IS FALSE),
    CONSTRAINT chk_post_autores CHECK (
        (postPermiteMultiplosAutores(post_id) IS TRUE)
       -- OR
       -- (SELECT COUNT(*) FROM pessoa_post WHERE post_id = post_id) = 0
    )
);

INSERT INTO pessoa_post (pessoa_id, post_id) VALUES 
(2, 1),  -- Maria Oliveira é autora do primeiro post
(4, 1), -- Ana Lima é autora do primeiro post
(2, 3),  -- Maria Oliveira é autora do terceiro post
(4, 4),  -- Ana Lima é autora do quarto post
--(1, 2),  -- João Silva é leitor do segundo post
--(3, 5),  -- Carlos Souza é leitor do quinto post
--(5, 1),  -- Fernanda Costa é leitor do primeiro post
--(1, 3),  -- João Silva é leitor do terceiro post
--(3, 1),  -- Carlos Souza é leitor do primeiro post
--(5, 4),  -- Fernanda Costa é leitor do quarto post
--(1, 4),  -- João Silva é leitor do quarto post
(2, 5);  -- Maria Oliveira é autora do quinto post


INSERT INTO endereco (bairro, rua, nro, cep, pessoa_id) VALUES 
('Centro', 'Rua A', '123', '12345-678', 1),  -- João Silva
('Jardim das Flores', 'Rua B', '456', '23456-789', 3),  -- Carlos Souza
('Bela Vista', 'Rua C', '789', '34567-890', 5);  -- Fernanda Costa


--Um Stored Procedured que mostre as informações de todos as pessoas (leitores e autores)
CREATE OR REPLACE FUNCTION mostrarPessoas() RETURNS TABLE(
    id_consulta INTEGER,
    nome_consulta VARCHAR(100),
    email_consulta VARCHAR(100),
    tipo_consulta CHAR(1),
    detalhes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.nome,
        p.email,
        p.tipo,
        CASE
            WHEN p.tipo = 'L' THEN 
                COALESCE(
                    STRING_AGG(
                        CONCAT(e.bairro, ', ', e.rua, ', ', e.nro, ', ', e.cep),
                        '; '
                    ),
                    'LEITOR - SEM ENDEREÇO CADASTRADO'
                )
            WHEN p.tipo = 'A' THEN 
                'AUTOR - NÃO PODE TER ENDEREÇO CADASTRADO'
        END AS detalhes
    FROM pessoa p
    LEFT JOIN endereco e ON p.id = e.pessoa_id
    GROUP BY p.id, p.nome, p.email, p.tipo;
END;
$$ LANGUAGE plpgsql;


--Um Stored Procedured que mostre a quantidade de autores envolvidos na escrita de cada Post (0,5)

-- Mostre o título de cada Post, sua data de publicação (formatada) e a quantidade correspondente de autores.
-- Função para contar autores por post
CREATE OR REPLACE FUNCTION contarAutoresPorPost() RETURNS TABLE(
    titulo VARCHAR(100),
    data_publicacao_formatada TEXT,
    quantidade_autores BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.titulo,
        TO_CHAR(p.data_hora, 'DD/MM/YYYY') AS data_publicacao_formatada,
        COUNT(pp.pessoa_id) AS quantidade_autores
    FROM
        post p
    LEFT JOIN
        pessoa_post pp ON p.id = pp.post_id
    GROUP BY
        p.id, p.titulo, p.data_hora
    ORDER BY
        p.data_hora DESC;
END;
$$ LANGUAGE plpgsql;

-- Função para listar autores por post
CREATE OR REPLACE FUNCTION listarAutoresPorPost() RETURNS TABLE(
    titulo VARCHAR(100),
    autores TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.titulo,
        STRING_AGG(pe.nome, ', ') AS autores
    FROM
        post p
    LEFT JOIN
        pessoa_post pp ON p.id = pp.post_id
    LEFT JOIN
        pessoa pe ON pp.pessoa_id = pe.id
    GROUP BY
        p.id, p.titulo
    ORDER BY
        p.titulo;
END;
$$ LANGUAGE plpgsql;


-- Um Stored Procedure que autentique (login) Pessoas (Leitores e Autores)
-- As senhas devem ser armazenadas em md5

ALTER TABLE pessoa
    ADD COLUMN senha_md5 CHAR(32);

UPDATE pessoa
SET senha_md5 = MD5(senha);

CREATE OR REPLACE FUNCTION autenticarPessoa(email_input VARCHAR(100), senha_input VARCHAR(100)) 
RETURNS TABLE(
    id INTEGER,
    nome VARCHAR(100),
    tipo CHAR(1)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.nome,
        p.tipo
    FROM
        pessoa p
    WHERE
        p.email = email_input
        AND p.senha_md5 = MD5(senha_input);
END;
$$ LANGUAGE plpgsql;


-- TESTES DAS FUNÇÕES E PROCEDURES

-- Teste para mostrarPessoas
SELECT * FROM mostrarPessoas();

-- Teste para contarAutoresPorPost
SELECT * FROM contarAutoresPorPost();

-- Teste para listarAutoresPorPost
SELECT * FROM listarAutoresPorPost();

-- Teste para autenticarPessoa
-- Autenticação bem-sucedida para João Silva
SELECT * FROM autenticarPessoa('joao.silva@example.com', 'senha123');

-- Autenticação bem-sucedida para Maria Oliveira
SELECT * FROM autenticarPessoa('maria.oliveira@example.com', 'senha456');

-- Autenticação falhada para um email ou senha incorretos
SELECT * FROM autenticarPessoa('joao.silva@example.com', 'senha_errada');
