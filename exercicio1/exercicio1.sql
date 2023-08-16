/**
 * 1) Escreva uma função em PL/pgSQL para criar uma tabela com uma quantidade N de números aleatórios entre 0 e 99, onde N é um valor informado como parâmetro.
 * 2) Escreva uma função em PL/pgSQL para calcular um histograma dos números gerados no item anterior
 */

CREATE SCHEMA IF NOT EXISTS aline;

CREATE OR REPLACE FUNCTION gera_sequencia(n INT) RETURNS table(id int) LANGUAGE plpgsql AS $$
DECLARE
    max int := 99;
    min int := 0;
BEGIN
-- parte procedural da funcao
    RETURN QUERY SELECT floor(random() * (max-min + 1) + min)::int FROM generate_series(1, n);
    -- inclui minimo e m�ximo no range
END; $$;

CREATE OR REPLACE FUNCTION cria_histograma(n INT) RETURNS table(hist int) LANGUAGE plpgsql AS $$
DECLARE
    max int := 99;
    min int := 0;
    qtd int :=0;
    i int;
    linha int;
BEGIN
    FOR i IN min..max LOOP
        qtd :=0;
        FOR linha IN SELECT id from aline.sequencia LOOP
            IF linha = i THEN
                qtd := qtd+1;
            END IF;
        END LOOP;
        INSERT INTO aline.histograma(valor) VALUES (qtd);
    END LOOP;
    RETURN QUERY SELECT * FROM aline.histograma;
END; $$;


drop table if exists aline.sequencia cascade;
create table if not exists aline.sequencia as
select * from gera_sequencia(10000);

drop table if exists aline.histograma cascade;
create table if not exists aline.histograma(valor int);
select * from cria_histograma(10);