CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.restaurante cascade;
drop table if exists aline.menu cascade;
drop table if exists aline.prato cascade;
drop table if exists aline.pedido cascade;
drop table if exists aline.item_pedido cascade;

CREATE TABLE aline.restaurante (
    cnpj integer NOT NULL,
    endereco character varying NOT NULL,
    CONSTRAINT rest_pk PRIMARY KEY (cnpj));
    
CREATE TABLE aline.prato (
    prato_id integer NOT NULL,
    nome character varying NOT NULL,
    CONSTRAINT prato_pk PRIMARY KEY
    (prato_id));

CREATE TABLE aline.menu (
    cnpj integer NOT NULL,
    prato_id integer NOT NULL,
    preco real NOT NULL,
    CONSTRAINT menu_pk PRIMARY KEY
    (cnpj,prato_id),
    CONSTRAINT menu_rest_fk FOREIGN KEY
    (cnpj) REFERENCES aline.restaurante (cnpj),
    CONSTRAINT menu_prato_fk FOREIGN KEY
    (prato_id) REFERENCES aline.prato (prato_id));

CREATE TABLE aline.pedido (
    pedido_id integer NOT NULL,
    cnpj integer NOT NULL,
    CONSTRAINT pedido_pk PRIMARY KEY
    (pedido_id),
    CONSTRAINT pedido_rest_fk FOREIGN KEY
    (cnpj) REFERENCES aline.restaurante (cnpj));

CREATE TABLE aline.item_pedido (
    pedido_id integer NOT NULL,
    item integer NOT NULL,
    cnpj integer NOT NULL,
    prato_id integer NOT NULL,
    qtd integer NOT NULL,
    CONSTRAINT item_pk PRIMARY KEY
    (pedido_id,item),
    CONSTRAINT item_pedido_fk FOREIGN KEY
    (pedido_id) REFERENCES aline.pedido
    (pedido_id),
    CONSTRAINT item_menu_fk FOREIGN KEY
    (cnpj,prato_id) REFERENCES aline.menu
    (cnpj,prato_id));

CREATE OR REPLACE FUNCTION aline.checa_res_item() RETURNS trigger AS $$
DECLARE

BEGIN
    IF (NEW.cnpj <> (select cnpj from aline.pedido where pedido_id = NEW.pedido_id)) THEN
        raise exception 'restaurante do item não é consistente com pedido';
    END IF;
    RETURN NEW;

END; $$ language plpgsql;

CREATE OR REPLACE FUNCTION aline.checa_res_pedido() RETURNS trigger AS $$
DECLARE

BEGIN
    IF (NEW.cnpj <> OLD.cnpj AND EXISTS(select * from aline.item_pedido where pedido_id = NEW.pedido_id)) THEN
        raise exception 'não é possível mudar o restaurante de um pedido já iniciado'; 
        -- pelo menos foi assim que entendi...
    END IF;
    RETURN NEW;

END; $$ language plpgsql;

CREATE OR REPLACE TRIGGER restaurante_item_pedido BEFORE INSERT OR UPDATE ON aline.item_pedido
FOR EACH ROW EXECUTE PROCEDURE aline.checa_res_item();
CREATE OR REPLACE TRIGGER restaurante_pedido BEFORE UPDATE ON aline.pedido
FOR EACH ROW EXECUTE PROCEDURE aline.checa_res_pedido();

INSERT INTO aline.restaurante VALUES 
    (12, 'restaurante 1'),
    (34, 'restaurante 2');

INSERT INTO aline.prato VALUES 
    (1, 'arroz e feijao'),
    (2, 'hamburguer de lentilha'),
    (3, 'hamburguer de grao de bico'),
    (4, 'moqueca de banana');

INSERT INTO aline.menu VALUES 
    (12, 1, 15),
    (34, 1, 17),
    (12, 2, 28),
    (34, 3, 30),
    (12, 4, 25);

INSERT INTO aline.pedido VALUES
    (1, 12),
    (2, 12),
    (3, 34);

INSERT INTO aline.item_pedido VALUES
    (1, 1, 12, 1, 2),
    (1, 2, 12, 2, 1),
    (3, 1, 34, 3, 1);

INSERT INTO aline.item_pedido VALUES
    (3, 2, 34, 1, 2);
UPDATE aline.pedido SET cnpj = 12 where pedido_id = 1;