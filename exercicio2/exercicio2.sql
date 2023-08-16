CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.campeonato cascade;
CREATE TABLE aline.campeonato (
    codigo text NOT NULL,
    nome text NOT NULL,
    ano integer not null,
    CONSTRAINT campeonato_pk PRIMARY KEY
    (codigo));

drop table if exists aline.time_ cascade;
CREATE TABLE aline.time_ (
    sigla text NOT NULL,
    nome text NOT NULL,
    CONSTRAINT time_pk PRIMARY KEY
    (sigla));

drop table if exists aline.jogo cascade;
CREATE TABLE aline.jogo (
    campeonato text not null,
    numero integer NOT NULL,
    time1 text NOT NULL,
    time2 text NOT NULL,
    gols1 integer not null,
    gols2 integer not null,
    data_ date not null,
    CONSTRAINT jogo_pk PRIMARY KEY
    (campeonato,numero),
    CONSTRAINT jogo_campeonato_fk FOREIGN KEY
    (campeonato) REFERENCES aline.campeonato(codigo),
    CONSTRAINT jogo_time_fk1 FOREIGN KEY
    (time1) REFERENCES aline.time_ (sigla),
    CONSTRAINT jogo_time_fk2 FOREIGN KEY
    (time2) REFERENCES aline.time_ (sigla));

drop table if exists aline.tabela cascade;
CREATE TABLE aline.tabela (
    posicao int,
    time_ text NOT NULL,
    pontos integer,
    vitorias integer,
    derrotas integer,
    empates integer,
    CONSTRAINT tabela_pk PRIMARY KEY
    (time_),
    CONSTRAINT tabela_time_fk FOREIGN KEY
    (time_) REFERENCES aline.time_ (sigla));

DO $$
BEGIN
    EXECUTE (SELECT coalesce(string_agg(format('DROP FUNCTION IF EXISTS %s CASCADE;', oid::regprocedure), E'\n'),'')
        FROM pg_proc WHERE proname IN ('insere_empate', 'insere_nao_empate', 'cria_tabela'));
END;$$;

CREATE OR REPLACE FUNCTION aline.insere_nao_empate(vencedor text, perdedor text) RETURNS void AS $$
DECLARE
BEGIN
    IF vencedor IN (SELECT time_ FROM aline.tabela) THEN
        UPDATE aline.tabela 
        SET pontos = pontos+3,
        vitorias = vitorias+1
        WHERE time_ = vencedor;
    ELSE
        INSERT INTO aline.tabela VALUES (null, vencedor, 3, 1, 0, 0);
    END IF;

    -- insere derrota time 2
    IF perdedor IN (SELECT time_ FROM aline.tabela) THEN
        UPDATE aline.tabela 
        SET derrotas = derrotas+1
        WHERE time_ = perdedor;
    ELSE
        INSERT INTO aline.tabela VALUES (null, perdedor, 0, 0, 1, 0);
    END IF;
END;$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION aline.insere_empate(time_empate text) RETURNS void AS $$
DECLARE
BEGIN
    IF time_empate IN (SELECT time_ FROM aline.tabela) THEN
                UPDATE aline.tabela 
                SET pontos = pontos+1,
                empates = empates+1
                WHERE time_ = time_empate;
            ELSE
                INSERT INTO aline.tabela VALUES (null, time_empate, 1, 0, 0, 1);
            END IF;

END;$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION aline.cria_tabela(camp text, pos_inicial integer, pos_final integer) 
RETURNS table(pos int, time__ text, pontos int, vitorias int, derrotas int, empates int) AS $$
DECLARE
    registro record;
    pos int :=1;
BEGIN
    -- seleciona os jogos do campeonato do parametro e itera por eles
    FOR registro IN SELECT aline.jogo.numero, aline.jogo.time1, aline.jogo.time2, aline.jogo.gols1, aline.jogo.gols2 
    FROM aline.jogo 
    WHERE aline.jogo.campeonato = camp LOOP
        -- vitoria time 1
        IF registro.gols1 > registro.gols2 THEN
            PERFORM aline.insere_nao_empate(registro.time1, registro.time2);
        -- vitória time 2
        ELSIF registro.gols2 > registro.gols1 THEN
            PERFORM aline.insere_nao_empate(registro.time2, registro.time1);
        -- empate
        ELSE
            PERFORM aline.insere_empate(registro.time1);
            PERFORM aline.insere_empate(registro.time2);
        END IF;       
    END LOOP;
    
    ALTER TABLE aline.tabela
    DROP CONSTRAINT tabela_time_fk;
    FOR registro IN SELECT * FROM aline.tabela ORDER BY pontos DESC, vitorias DESC LOOP
        -- insere a posição na tabela
        UPDATE aline.tabela SET posicao = pos WHERE time_=registro.time_;
        pos := pos+1;
        -- substitui a sigla pelo nome do time
        UPDATE aline.tabela SET time_ = (SELECT nome FROM aline.time_ WHERE sigla=time_) WHERE time_=registro.time_;
    END LOOP;

    
    -- retorna query de valores com posicao entre pos_inicial e pos_final (escolhi fazer assim apesar da dica)
    RETURN QUERY SELECT * FROM aline.tabela WHERE aline.tabela.posicao BETWEEN pos_inicial AND pos_final;
END;
$$ LANGUAGE plpgsql;

-- inserção de valores nas tabelas time_, campeonato e jogos
INSERT INTO aline.time_ VALUES ('FLA', 'flamengo');
INSERT INTO aline.time_ VALUES ('FLU', 'fluminense');
INSERT INTO aline.time_ VALUES ('VAS', 'vasco');
INSERT INTO aline.time_ VALUES ('BOT', 'botafogo');

INSERT INTO aline.campeonato VALUES ('20221', 'carioca', 2022);
INSERT INTO aline.campeonato VALUES ('20211', 'carioca', 2021);


INSERT INTO aline.jogo VALUES('20221', 1, 'FLA', 'FLU', 1, 2, '2022-08-10');
INSERT INTO aline.jogo VALUES('20221', 2, 'FLA', 'VAS', 2, 2, '2022-08-15');
INSERT INTO aline.jogo VALUES('20221', 3, 'VAS', 'FLU', 0, 2, '2022-08-18');
INSERT INTO aline.jogo VALUES('20221', 4, 'BOT', 'FLU', 3, 2, '2022-08-21');
INSERT INTO aline.jogo VALUES('20221', 5, 'VAS', 'BOT', 3, 0, '2022-08-25');
INSERT INTO aline.jogo VALUES('20221', 6, 'FLA', 'VAS', 0, 0, '2022-08-28');
INSERT INTO aline.jogo VALUES('20221', 7, 'VAS', 'FLA', 1, 1, '2022-08-29');

INSERT INTO aline.jogo VALUES('20211', 1, 'FLU', 'FLA', 3, 0, '2021-10-12');

SELECT * FROM aline.cria_tabela('20221'::text, 2, 3);
