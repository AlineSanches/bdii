CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.cliente cascade;
drop table if exists aline.conta_corrente cascade;
drop table if exists aline.limite_credito cascade;
drop table if exists aline.movimento cascade;
drop table if exists aline.correntista cascade;


create table aline.cliente(
    id int primary key,
    nome varchar not null
);
create table aline.conta_corrente(
    id int primary key,
    abertura timestamp not null,
    encerramento timestamp
);
create table aline.correntista(
    cliente int references
    aline.cliente(id),
    conta_corrente int references
    aline.conta_corrente(id),
    primary key(cliente,
    conta_corrente)
);

create table aline.limite_credito(
    conta_corrente int references
    aline.conta_corrente(id),
    valor float not null,
    inicio timestamp not null,
    fim timestamp
);
create table aline.movimento(
    conta_corrente int references
    aline.conta_corrente(id),
    "data" timestamp,
    valor float not null,
    primary key (conta_corrente,"data")
);

-- after each row faz tabela temporaria com contas modificadas
-- after each statement
-- pegar o menor e o maior dia do itnervalo que teve modificação


CREATE OR REPLACE FUNCTION aline.verifica_saldo() RETURNS trigger AS $$
DECLARE
    conta int;
    s float;
    lim float;
    _data timestamp;
BEGIN
    -- tabela com o saldo de cada conta modificada
    drop table if exists aline.contas_modif cascade;
    CREATE TABLE aline.contas_modif AS
    SELECT conta_corrente, sum(valor) AS saldo, "data"  FROM aline.movimento GROUP BY conta_corrente, "data";

    -- itera sobre as contas, saldos e datas
    -- comparando se o saldo ficou menor do que o limite
    FOR conta, s, _data IN SELECT conta_corrente, saldo, "data" FROM aline.contas_modif LOOP
        SELECT valor FROM aline.limite_credito INTO lim WHERE (inicio <= _data OR inicio IS NULL) AND (_data <= fim OR fim IS NULL);
        --raise notice 'limite: %', lim;
        IF lim IS NULL THEN
            --raise notice 'nao tem limite';
            lim := 0;
        END IF;
        IF s < lim THEN
            raise exception 'operação não suportada, o limite da conta % foi ultrapassado', conta;
        END IF;
    END LOOP;
    RETURN NEW;

END; $$ language plpgsql;

CREATE OR REPLACE FUNCTION aline.verifica_limite() RETURNS trigger AS $$
DECLARE
BEGIN
    -- compara se o novo limite é maior do que o saldo da conta
    IF NEW.valor > (SELECT sum(valor) FROM aline.movimento WHERE conta_corrente=NEW.conta_corrente 
    GROUP BY conta_corrente) THEN
        raise exception 'operação não suportada, o limite da conta % foi se tornou menor do que o saldo', NEW.conta_corrente;
    END IF;

    RETURN NEW;

END; $$ language plpgsql;

insert into aline.cliente values (1, 'aline');
insert into aline.conta_corrente values (1, '2023-05-10', NULL);
insert into aline.correntista values (1, 1);
insert into aline.limite_credito values (1, -500.0, '2023-05-10', NULL); --'2023-05-11'

-- statement pois em um lote pode ter 2 linhas separadas que se justificam
CREATE TRIGGER saldo_negativo AFTER INSERT OR UPDATE OR DELETE ON aline.movimento
FOR EACH STATEMENT EXECUTE PROCEDURE aline.verifica_saldo();

CREATE TRIGGER limite_inferior AFTER INSERT OR UPDATE ON aline.limite_credito
FOR EACH ROW EXECUTE PROCEDURE aline.verifica_limite();


insert into aline.movimento values (1, '2023-05-13', -410);

update aline.limite_credito set valor = -420 where conta_corrente=1;
