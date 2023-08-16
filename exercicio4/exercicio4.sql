CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.produto cascade;
create table aline.produto(
    id bigint not null,
    nome varchar not null,
    constraint produto_pk PRIMARY KEY
    (id)
);

drop table if exists aline.venda cascade;
create table aline.venda(
    "data" timestamp not null,
    produto bigint not null,
    qtd integer not null,
    constraint venda_produto_fk FOREIGN KEY
    (produto) REFERENCES aline.produto(id)
);

DROP TABLE IF EXISTS aline.best_sellers cascade;
CREATE TABLE aline.best_sellers (
    ano_mes bigint not null,
    lista varchar[] not null
);

DO $$
BEGIN
    EXECUTE (SELECT coalesce(string_agg(format('DROP FUNCTION IF EXISTS %s CASCADE;', oid::regprocedure), E'\n'),'')
        FROM pg_proc WHERE proname IN ('lista_best_sellers'));
END;$$;

CREATE OR REPLACE FUNCTION aline.lista_best_sellers(data_inicio timestamp, data_fim timestamp) RETURNS table (ano_mes bigint, lista_ varchar[]) AS $$
DECLARE
    best_sellers varchar[];
    anomes_ bigint;
    registro aline.vendas_produto_mes%ROWTYPE;
BEGIN
    -- 1)
    -- cria uma tabela que agrupa o total de vendas dos produtos por produtos e mes_ano 
    -- (nao consegui deixar o mes março, por exemplo, como 03, pois o extract retorna 3)
    drop table if exists aline.vendas_produto_mes cascade;
    CREATE TABLE aline.vendas_produto_mes AS
    SELECT ((extract(year from "data")::text || extract(month from "data")::text))::bigint as mes_ano, produto, SUM(qtd)::integer as total
    FROM aline.venda
    WHERE "data" BETWEEN data_inicio AND data_fim
    GROUP BY produto, mes_ano;

    -- 2)
    -- cria uma tabela com a média da quantidade vendida de todos os produtos naquele mes
    drop table if exists aline.vendas_mes cascade;
    CREATE TABLE aline.vendas_mes AS
    SELECT mes_ano, AVG(total)::real as media
    FROM aline.vendas_produto_mes
    GROUP BY mes_ano;

    -- 3) 
    -- cria uma tabela com os best-sellers por mês
    -- para cada anomes_, cria a lista de best_sellers e insere os valores na tabela
    FOR anomes_ IN SELECT mes_ano FROM aline.vendas_mes LOOP
        best_sellers := '{}';
        FOR registro IN SELECT * FROM aline.vendas_produto_mes WHERE mes_ano = anomes_ LOOP
            IF registro.total > 1.6*(SELECT media FROM aline.vendas_mes WHERE mes_ano = registro.mes_ano) THEN
                best_sellers := array_append(best_sellers, (SELECT nome FROM aline.produto WHERE id = registro.produto));
            END IF;
        END LOOP;
        INSERT INTO aline.best_sellers VALUES (anomes_, best_sellers);
    END LOOP;
    
    return query select * from aline.best_sellers order by ano_mes;
END;$$ LANGUAGE plpgsql;

-- inserção de valores nas tabelas produto e venda
INSERT INTO aline.produto VALUES (1, 'monitor');
INSERT INTO aline.produto VALUES (2, 'gabinete');
INSERT INTO aline.produto VALUES (3, 'webcam');
INSERT INTO aline.produto VALUES (4, 'microfone');


INSERT INTO aline.venda VALUES ('2023-02-08', 1, 8);

INSERT INTO aline.venda VALUES ('2023-03-08', 3, 2);
INSERT INTO aline.venda VALUES ('2023-03-24', 3, 4);
INSERT INTO aline.venda VALUES ('2023-03-14', 1, 2);
INSERT INTO aline.venda VALUES ('2023-03-24', 4, 1);

INSERT INTO aline.venda VALUES ('2023-04-08', 3, 1);
INSERT INTO aline.venda VALUES ('2023-04-15', 1, 2);
INSERT INTO aline.venda VALUES ('2023-04-10', 4, 2);
INSERT INTO aline.venda VALUES ('2023-04-09', 4, 3);
INSERT INTO aline.venda VALUES ('2023-04-12', 4, 3);
INSERT INTO aline.venda VALUES ('2023-04-18', 2, 2);
INSERT INTO aline.venda VALUES ('2023-04-19', 2, 1);
INSERT INTO aline.venda VALUES ('2023-04-28', 2, 4);
INSERT INTO aline.venda VALUES ('2023-04-29', 2, 1);

INSERT INTO aline.venda VALUES ('2023-05-01', 3, 12);


select * from aline.lista_best_sellers('2023-03-07', '2023-04-30');