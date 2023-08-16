CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.venda cascade;
drop table if exists aline.item_venda cascade;
drop table if exists aline.produto cascade;
drop table if exists aline.ordem_reposicao cascade;

CREATE TABLE aline.venda (
    id integer NOT NULL,
    data timestamp NOT NULL,
    CONSTRAINT venda_pk PRIMARY KEY (id));

CREATE TABLE aline.produto (
    id integer NOT NULL,
    nome varchar NOT NULL,
    preco real NOT NULL,
    estoque integer NOT NULL,
    estoque_minimo integer NOT NULL,
    estoque_maximo integer NOT NULL,
    CONSTRAINT produto_pk PRIMARY KEY
    (id));
  
CREATE TABLE aline.item_venda (
    venda integer NOT NULL,
    item integer NOT NULL,
    produto integer NOT NULL,
    qtd integer NOT NULL,
    CONSTRAINT item_venda_pk PRIMARY KEY
    (venda, item),
    CONSTRAINT i_venda_produto_fk FOREIGN KEY
    (produto) REFERENCES aline.produto (id));

CREATE TABLE aline.ordem_reposicao (
    produto integer NOT NULL,
    qtd integer NOT NULL,
    CONSTRAINT ordem_rep_pk PRIMARY KEY (produto),
    CONSTRAINT ordem_produto_fk FOREIGN KEY
    (produto) REFERENCES aline.produto (id));

DO $$
BEGIN
    EXECUTE (SELECT coalesce(string_agg(format('DROP FUNCTION IF EXISTS %s CASCADE;', oid::regprocedure), E'\n'),'')
        FROM pg_proc WHERE proname IN ('cria_ordem'));
END;$$;

CREATE OR REPLACE FUNCTION aline.cria_ordem() RETURNS trigger AS $$
DECLARE
    estoque_atual integer;
    estoque_min integer;
    estoque_max integer;
    reg record;
BEGIN
    -- para cada registro na tabela de inseridos, verifica se o novo estoque 
    -- (estoque subtraído da soma de qtd) é menor do que o estoque mínimo
    for reg in select sum(qtd) as soma, produto from inseridos group by produto loop
        --raise notice 'produto % soma %', reg.produto, reg.soma;
        SELECT estoque, estoque_minimo INTO estoque_atual, estoque_min FROM aline.produto WHERE id = reg.produto;
        -- se for, cria uma ordem ou faz update em qtd
        if (estoque_atual - reg.soma) < estoque_min then
            select estoque_maximo into estoque_max from aline.produto where id = reg.produto;
            if reg.produto in (select produto from aline.ordem_reposicao) then
                update aline.ordem_reposicao 
                set qtd = estoque_max - (estoque_atual - reg.soma) 
                where produto = reg.produto;
            else
                insert into aline.ordem_reposicao values 
                    (reg.produto, estoque_max - (estoque_atual - reg.soma));
            end if;
        end if;
        -- obs.: como não especifica no enunciado, não fiz update no estoque (acredito que seja papel de outra funçao)
    end loop;
    return new;

END; $$ language plpgsql;


CREATE TRIGGER ordem_reposicao AFTER INSERT ON aline.item_venda 
    REFERENCING NEW TABLE AS inseridos 
    FOR EACH STATEMENT EXECUTE PROCEDURE aline.cria_ordem();

INSERT INTO aline.produto VALUES 
(1, 'microfone', 50, 10, 5, 20),
(2, 'teclado', 250, 12, 10, 25),
(3, 'mouse', 200, 15, 8, 18);

INSERT INTO aline.venda VALUES 
(1, '2023-06-03 08:00:00'),
(2, '2023-06-05 08:00:00');

INSERT INTO aline.item_venda VALUES 
(1, 1, 3, 2),
(2, 1, 2, 4),
(2, 2, 3, 1);

INSERT INTO aline.item_venda VALUES 
(1, 2, 1, 3),
(1, 3, 2, 5),
(2, 3, 1, 3);
