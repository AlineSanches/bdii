CREATE SCHEMA IF NOT EXISTS aline;

drop table if exists aline.hotel cascade;
drop table if exists aline.reserva cascade;
drop table if exists aline.estadia cascade;

CREATE TABLE aline.hotel (
    numero integer NOT NULL,
    nome TEXT NOT NULL,
    CONSTRAINT hotel_pk PRIMARY KEY (numero)
);
CREATE TABLE aline.reserva (
    numero integer NOT NULL,
    hotel integer NOT NULL,
    cpf_cnpj integer NOT NULL,
    inicio timestamp not null,
    fim timestamp not null,
    CONSTRAINT reserva_pk PRIMARY KEY
    (numero),
    CONSTRAINT reserva_hotel_fk FOREIGN KEY
    (hotel) REFERENCES aline.hotel (numero)
);

CREATE TABLE aline.estadia (
    numero integer NOT NULL,
    quarto text not null,
    inicio timestamp not null,
    fim timestamp,
    CONSTRAINT estadia_pk PRIMARY KEY (numero),
    CONSTRAINT estadia_reserva_fk FOREIGN KEY
    (numero)
    REFERENCES aline.reserva (numero) ON DELETE
    RESTRICT ON UPDATE CASCADE
);

CREATE OR REPLACE FUNCTION aline.checa_intervalo() RETURNS trigger AS $$
DECLARE
    reserva record;
BEGIN
    SELECT inicio, fim INTO reserva FROM aline.reserva WHERE numero = NEW.numero;
    IF NEW.inicio < reserva.inicio OR 
    NEW.inicio > (reserva.inicio + interval '1' day) 
    OR NEW.fim > reserva.fim THEN
        raise exception 'período de estadia fora do período de reserva';
    END IF;
    RETURN NEW;

END; $$ language plpgsql;

CREATE OR REPLACE FUNCTION aline.checa_disponibilidade() RETURNS trigger AS $$
DECLARE
    reserva record;
    hotel_reserva int;
BEGIN
    SELECT R.hotel INTO hotel_reserva FROM aline.reserva AS R WHERE R.numero = NEW.numero;
    --raise notice 'quarto % hotel %', NEW.quarto, hotel_reserva;
    -- levanta exceção se existe alguma entrada em que o quarto e hotel são iguais
    -- e que o período overlaps o do novo
    IF (EXISTS(SELECT * FROM aline.estadia AS E JOIN aline.reserva AS R 
    ON E.numero = R.numero WHERE E.quarto = NEW.quarto AND R.hotel = hotel_reserva
    AND (NEW.inicio, NEW.fim) OVERLAPS (E.inicio, E.fim))) THEN
        raise exception 'quarto ja ocupado';
    END IF;
    RETURN NEW;

END; $$ language plpgsql;


CREATE OR REPLACE TRIGGER fora_intervalo AFTER INSERT OR UPDATE ON aline.estadia
FOR EACH ROW EXECUTE PROCEDURE aline.checa_intervalo();

CREATE OR REPLACE TRIGGER ocupado BEFORE INSERT OR UPDATE ON aline.estadia
FOR EACH ROW EXECUTE PROCEDURE aline.checa_disponibilidade();

INSERT INTO aline.hotel (numero, nome) VALUES 
    (1, 'hotel 1'),
    (2, 'hotel 2');
INSERT INTO aline.reserva (numero, hotel, cpf_cnpj, inicio, fim) VALUES 
    (1, 1, 123, '2023-06-03 08:00:00', '2023-06-05 10:00:00'),
    (2, 2, 456, '2023-05-10 08:00:00', '2023-05-17 10:00:00'),
    (3, 2, 789, '2023-05-17 08:00:00', '2023-05-20 10:00:00');
INSERT INTO aline.estadia (numero, quarto, inicio, fim) VALUES 
    (1, 'quarto 1', '2023-06-03 10:00:00', '2023-06-04 09:00:00'),
    (2, 'quarto 2', '2023-05-10 10:00:00', '2023-05-17 10:00:00');

INSERT INTO aline.estadia (numero, quarto, inicio, fim) VALUES 
    (3, 'quarto 2', '2023-05-17 10:00:00', '2023-05-20 09:00:00');