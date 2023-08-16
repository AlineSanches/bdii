CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.bairro cascade;
CREATE TABLE aline.bairro (
    bairro_id integer NOT NULL,
    nome character varying NOT NULL,
    CONSTRAINT bairro_pk PRIMARY KEY
    (bairro_id));

drop table if exists aline.municipio cascade;
CREATE TABLE aline.municipio (
    municipio_id integer NOT NULL,
    nome character varying NOT NULL,
    CONSTRAINT municipio_pk PRIMARY KEY
    (municipio_id));

drop table if exists aline.antena cascade;
CREATE TABLE aline.antena (
    antena_id integer NOT NULL,
    bairro_id integer NOT NULL,
    municipio_id integer NOT NULL,
    CONSTRAINT antena_pk PRIMARY KEY
    (antena_id),
    CONSTRAINT bairro_fk FOREIGN KEY
    (bairro_id) REFERENCES aline.bairro
    (bairro_id),
    CONSTRAINT municipio_fk FOREIGN KEY
    (municipio_id) REFERENCES aline.municipio
    (municipio_id));

drop table if exists aline.ligacao cascade;
CREATE TABLE aline.ligacao (
    ligacao_id bigint NOT NULL,
    numero_orig integer NOT NULL,
    numero_dest integer NOT NULL,
    antena_orig integer NOT NULL,
    antena_dest integer NOT NULL,
    inicio timestamp NOT NULL,
    fim timestamp NOT NULL,
    CONSTRAINT ligacao_pk PRIMARY KEY
    (ligacao_id),
    CONSTRAINT antena_orig_fk FOREIGN KEY
    (antena_orig) REFERENCES aline.antena
    (antena_id),
    CONSTRAINT antena_dest_fk FOREIGN KEY
    (antena_dest) REFERENCES aline.antena
    (antena_id));

DROP FUNCTION aline.lista_media_ligacoes(timestamp without time zone,timestamp without time zone);

CREATE OR REPLACE FUNCTION aline.lista_media_ligacoes(inicio_per timestamp, fim_per timestamp) 
RETURNS table (bairro_origem varchar, municipio_origem varchar, bairro_destinto varchar, 
municipio_destino varchar, media_duracao time) AS $$
DECLARE
    id bigint;
    ini timestamp;
    fi timestamp;
BEGIN
    -- cria tabela com id de bairro e município de origem e destino das ligações entre o período dos parametros
    drop table if exists aline.ligacoes_periodo cascade;
    CREATE TABLE aline.ligacoes_periodo AS
    SELECT L.ligacao_id, A_orig.bairro_id as bairro_orig, A_orig.municipio_id as municipio_orig, 
    A_dest.bairro_id as bairro_dest, A_dest.municipio_id as municipio_dest, L.inicio, L.fim
    FROM aline.ligacao as L
    JOIN aline.antena as A_orig ON L.antena_orig = A_orig.antena_id 
    JOIN aline.antena as A_dest ON L.antena_dest = A_dest.antena_id
    WHERE (L.inicio, L.fim) OVERLAPS (inicio_per, fim_per);

    -- modifica o timestamp de início ou fim caso esteja fora do período, para que o cálculo da média seja correto
    FOR id, ini, fi IN SELECT ligacao_id, inicio, fim FROM aline.ligacoes_periodo LOOP
        IF ini < inicio_per THEN
            UPDATE aline.ligacoes_periodo
            SET inicio = inicio_per
            WHERE ligacao_id = id;
        END IF;
        IF fi > fim_per THEN
            UPDATE aline.ligacoes_periodo
            SET fim = fim_per
            WHERE ligacao_id = id;
        END IF;
    END LOOP;

    -- cria tabela que calcula a media da duração das ligações, agrupado por região (bairro, municipio) de origem e destino
    drop table if exists aline.duracao_media_regioes cascade;  
    CREATE TABLE aline.duracao_media_regioes AS
    -- obs.: como não foi especificado, coloquei o formato time para a média
    SELECT BAI_ORIG.nome as b_orig, MUN_ORIG.nome as m_orig, BAI_DEST.nome as b_dest, 
    MUN_DEST.nome as m_dest, AVG(LP.fim - LP.inicio)::time as media
    FROM aline.ligacoes_periodo as LP
    -- join das tabelas para conseguir o nome em varchar dos bairros e municípios 
    -- (tenho dúvida nisso, se seria melhor fazer update do valor)
    JOIN aline.bairro as BAI_ORIG ON LP.bairro_orig = BAI_ORIG.bairro_id
    JOIN aline.municipio as MUN_ORIG ON LP.municipio_orig = MUN_ORIG.municipio_id
    JOIN aline.bairro as BAI_DEST ON LP.bairro_dest = BAI_DEST.bairro_id
    JOIN aline.municipio as MUN_DEST ON LP.municipio_dest = MUN_DEST.municipio_id
    
    GROUP BY (b_orig, m_orig, b_dest, m_dest);

    -- retorna a tabela ordenada pela media da duração da ligação em ordem descendente
    RETURN QUERY SELECT * FROM aline.duracao_media_regioes ORDER BY media DESC;
   
    
END;$$ language plpgsql;

INSERT INTO aline.bairro VALUES 
(1, 'ingá'), (2, 'icaraí'), (3, 'tijuca'), (4, 'méier');
 
INSERT INTO aline.municipio VALUES 
(1, 'niteroi'), (2, 'rio de janeiro');
 
INSERT INTO aline.antena VALUES 
(10, 1, 1), (20, 2, 1), (30, 3, 2), (40, 4, 2), (50, 3, 2);
 
INSERT INTO aline.ligacao VALUES
(1, 9999, 8888, 10, 20, '2022-10-19 10:22:00', '2022-10-19 10:24:50'),
(2, 9999, 7777, 50, 20, '2023-03-24 14:00:00', '2023-03-24 14:10:51'),
(4, 8888, 9999, 20, 40, '2023-03-24 18:10:00', '2023-03-24 18:13:40'),
(3, 7777, 9999, 20, 30, '2023-03-25 22:52:00', '2023-03-25 23:12:35'),
(5, 8888, 9999, 30, 20, '2023-03-25 21:20:00', '2023-03-25 21:25:20'),
(6, 5555, 8888, 10, 20, '2023-04-27 15:23:00', '2023-04-27 16:04:00');


SELECT * FROM aline.lista_media_ligacoes('2023-03-24 14:05:00', '2023-03-25 23:00:00');