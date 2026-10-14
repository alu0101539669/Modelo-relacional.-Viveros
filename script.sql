-- ==============================================================================
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ==============================================================================
-- NOTA: Ejecuta esta instrucción y luego conéctate a la base de datos 'viveros' 
-- antes de ejecutar el resto del script.
-- CREATE DATABASE viveros;
-- \c viveros

-- ==============================================================================
-- 2. CREACIÓN DE TABLAS Y RESTRICCIONES
-- ==============================================================================
CREATE EXTENSION IF NOT EXISTS btree_gist;

DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS cliente_plus CASCADE;
DROP TABLE IF EXISTS empleado_puesto CASCADE;
DROP TABLE IF EXISTS empleado_zona CASCADE;
DROP TABLE IF EXISTS empleado_vivero CASCADE;
DROP TABLE IF EXISTS stock_zona CASCADE;
DROP TABLE IF EXISTS registro_productividad CASCADE;
DROP TABLE IF EXISTS zona CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS puesto CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS empleado CASCADE;
DROP TABLE IF EXISTS vivero CASCADE;

CREATE TABLE vivero (
    id_vivero   INTEGER PRIMARY KEY CHECK (id_vivero > 0),
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    latitud     NUMERIC(8,5) NOT NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud    NUMERIC(8,5) NOT NULL CHECK (longitud BETWEEN -180 AND 180)
);


CREATE TABLE zona (
    id_vivero   INTEGER NOT NULL,
    id_zona     INTEGER NOT NULL CHECK (id_zona > 0),
    nombre      VARCHAR(100) NOT NULL,
    tipo        VARCHAR(40) NOT NULL,
    latitud     NUMERIC(8,5) NOT NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud    NUMERIC(8,5) NOT NULL CHECK (longitud BETWEEN -180 AND 180),
    CONSTRAINT pk_zona PRIMARY KEY (id_vivero, id_zona),
    CONSTRAINT fk_zona_vivero FOREIGN KEY (id_vivero)
        REFERENCES vivero(id_vivero) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT uq_zona_nombre_vivero UNIQUE (id_vivero, nombre)
);

CREATE TABLE producto (
    id_producto INTEGER PRIMARY KEY CHECK (id_producto > 0),
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    precio      NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    categoria   VARCHAR(50) NOT NULL
);


CREATE TABLE empleado (
    dni_empleado VARCHAR(15) PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL CHECK (length(trim(nombre)) > 0)
);

CREATE TABLE puesto (
    id_puesto INTEGER PRIMARY KEY CHECK (id_puesto > 0),
    nombre    VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE cliente (
    dni_cliente VARCHAR(15) PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL CHECK (length(trim(nombre)) > 0),
    telefono    VARCHAR(20) NOT NULL CHECK (telefono ~ '^[0-9+() -]{7,20}$')
);

CREATE TABLE cliente_plus (
    dni_cliente VARCHAR(15) PRIMARY KEY,
    fecha_alta  DATE NOT NULL CHECK (fecha_alta <= CURRENT_DATE),
    CONSTRAINT fk_cliente_plus_cliente FOREIGN KEY (dni_cliente)
        REFERENCES cliente(dni_cliente) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE registro_productividad (
    id_vivero    INTEGER NOT NULL,
    id_zona      INTEGER NOT NULL,
    fecha        DATE NOT NULL,
    productividad NUMERIC(7,2) NOT NULL CHECK (productividad >= 0),
    CONSTRAINT pk_registro_productividad
        PRIMARY KEY (id_vivero, id_zona, fecha),
    CONSTRAINT fk_registro_zona FOREIGN KEY (id_vivero, id_zona)
        REFERENCES zona(id_vivero, id_zona)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE stock_zona (
    id_vivero   INTEGER NOT NULL,
    id_zona     INTEGER NOT NULL,
    id_producto INTEGER NOT NULL,
    cantidad    INTEGER NOT NULL CHECK (cantidad > 0),
    CONSTRAINT pk_stock_zona PRIMARY KEY (id_vivero, id_zona, id_producto),
    CONSTRAINT fk_stock_zona FOREIGN KEY (id_vivero, id_zona)
        REFERENCES zona(id_vivero, id_zona)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_stock_producto FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
        ON UPDATE CASCADE ON DELETE RESTRICT
);


CREATE TABLE empleado_vivero (
    id_vivero    INTEGER NOT NULL,
    dni_empleado VARCHAR(15) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin    DATE,
    CONSTRAINT pk_empleado_vivero
        PRIMARY KEY (id_vivero, dni_empleado, fecha_inicio),
    CONSTRAINT fk_ev_vivero FOREIGN KEY (id_vivero)
        REFERENCES vivero(id_vivero) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ev_empleado FOREIGN KEY (dni_empleado)
        REFERENCES empleado(dni_empleado) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_ev_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    -- Un empleado no puede tener destinos solapados, aunque sean en viveros distintos.
    CONSTRAINT ex_empleado_destinos_sin_solape
        EXCLUDE USING gist (
            dni_empleado WITH =,
            daterange(fecha_inicio, COALESCE(fecha_fin + 1, 'infinity'::date), '[)') WITH &&
        )
);

CREATE TABLE empleado_zona (
    dni_empleado VARCHAR(15) NOT NULL,
    id_vivero    INTEGER NOT NULL,
    id_zona      INTEGER NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin    DATE,
    tarea        VARCHAR(100) NOT NULL,
    productividad NUMERIC(7,2) NOT NULL CHECK (productividad >= 0),
    CONSTRAINT pk_empleado_zona
        PRIMARY KEY (dni_empleado, id_vivero, id_zona, fecha_inicio),
    CONSTRAINT fk_ez_empleado FOREIGN KEY (dni_empleado)
        REFERENCES empleado(dni_empleado) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ez_zona FOREIGN KEY (id_vivero, id_zona)
        REFERENCES zona(id_vivero, id_zona) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_ez_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE TABLE empleado_puesto (
    dni_empleado VARCHAR(15) NOT NULL,
    id_puesto    INTEGER NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin    DATE,
    CONSTRAINT pk_empleado_puesto
        PRIMARY KEY (dni_empleado, id_puesto, fecha_inicio),
    CONSTRAINT fk_ep_empleado FOREIGN KEY (dni_empleado)
        REFERENCES empleado(dni_empleado) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ep_puesto FOREIGN KEY (id_puesto)
        REFERENCES puesto(id_puesto) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_ep_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE TABLE pedido (
    id_pedido    INTEGER PRIMARY KEY CHECK (id_pedido > 0),
    dni_cliente  VARCHAR(15) NOT NULL,
    dni_empleado VARCHAR(15) NOT NULL,
    fecha        DATE NOT NULL,
    importe      NUMERIC(12,2) NOT NULL CHECK (importe >= 0),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (dni_cliente)
        REFERENCES cliente(dni_cliente) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_empleado FOREIGN KEY (dni_empleado)
        REFERENCES empleado(dni_empleado) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- =========================
-- REGLA TEMPORAL ENTRE DESTINO Y TRABAJO EN ZONA
-- El periodo de trabajo debe quedar cubierto por un destino del mismo vivero.
-- =========================

CREATE OR REPLACE FUNCTION comprobar_destino_empleado_zona()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    trabajo_fin DATE;
BEGIN
    trabajo_fin := COALESCE(NEW.fecha_fin, 'infinity'::date);

    IF NOT EXISTS (
        SELECT 1
        FROM empleado_vivero ev
        WHERE ev.dni_empleado = NEW.dni_empleado
          AND ev.id_vivero = NEW.id_vivero
          AND ev.fecha_inicio <= NEW.fecha_inicio
          AND COALESCE(ev.fecha_fin, 'infinity'::date) >= trabajo_fin
    ) THEN
        RAISE EXCEPTION
            'El periodo de trabajo de % en la zona % del vivero % debe estar cubierto por un destino en ese vivero',
            NEW.dni_empleado, NEW.id_zona, NEW.id_vivero;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_comprobar_destino_empleado_zona
BEFORE INSERT OR UPDATE ON empleado_zona
FOR EACH ROW EXECUTE FUNCTION comprobar_destino_empleado_zona();

-- ==============================================================================
-- 3. INSERCIÓN DE DATOS (Mínimo 5 filas por tabla)
-- ==============================================================================

INSERT INTO vivero VALUES
(1, 'Vivero La Laguna', 28.48740, -16.31590),
(2, 'Vivero Santa Cruz', 28.46360, -16.25180),
(3, 'Vivero La Orotava', 28.39020, -16.52300),
(4, 'Vivero Adeje', 28.12270, -16.72600),
(5, 'Vivero Tacoronte', 28.47690, -16.41020);

INSERT INTO zona VALUES
(1, 1, 'Exterior', 'Venta', 28.48750, -16.31580),
(1, 2, 'Invernadero', 'Cultivo', 28.48760, -16.31570),
(2, 1, 'Almacén', 'Almacenamiento', 28.46370, -16.25170),
(3, 1, 'Semilleros', 'Cultivo', 28.39030, -16.52290),
(4, 1, 'Decoración', 'Venta', 28.12280, -16.72590),
(5, 1, 'Frutales', 'Cultivo', 28.47700, -16.41010);

INSERT INTO producto VALUES
(1, 'Planta de tomate', 4.50, 'Hortaliza'),
(2, 'Maceta de barro', 8.90, 'Decoración'),
(3, 'Saco de sustrato', 6.25, 'Jardinería'),
(4, 'Pino canario', 19.95, 'Árbol'),
(5, 'Regadera metálica', 12.50, 'Herramienta');

INSERT INTO empleado VALUES
('DNI001', 'Ana Pérez'),
('DNI002', 'Luis Martín'),
('DNI003', 'Marta Díaz'),
('DNI004', 'Carlos León'),
('DNI005', 'Sara González');

INSERT INTO puesto VALUES
(1, 'Vendedor'),
(2, 'Encargado de almacén'),
(3, 'Jardinero'),
(4, 'Responsable de vivero'),
(5, 'Atención al cliente');

INSERT INTO cliente VALUES
('CLI001', 'María García', '600123456'),
('CLI002', 'Pedro Rodríguez', '611223344'),
('CLI003', 'Lucía Hernández', '622334455'),
('CLI004', 'David González', '633445566'),
('CLI005', 'Elena Martín', '644556677'),
('CLI006', 'Pablo Díaz', '655667788'),
('CLI007', 'Noelia Castro', '666778899');

INSERT INTO cliente_plus VALUES
('CLI001', DATE '2026-01-15'),
('CLI002', DATE '2026-02-01'),
('CLI003', DATE '2026-03-10'),
('CLI004', DATE '2026-04-05'),
('CLI005', DATE '2026-05-20');

INSERT INTO registro_productividad VALUES
(1, 1, DATE '2026-10-01', 75.50),
(1, 1, DATE '2026-10-02', 79.00),
(1, 2, DATE '2026-10-01', 82.25),
(2, 1, DATE '2026-10-01', 68.00),
(3, 1, DATE '2026-10-01', 91.75);

INSERT INTO stock_zona VALUES
(1, 1, 1, 50),
(1, 1, 2, 20),
(1, 2, 3, 35),
(2, 1, 4, 12),
(3, 1, 5, 18),
(4, 1, 2, 40);

-- Cada empleado tiene al menos un destino. DNI001 tiene dos destinos históricos
-- no solapados; DNI005 tiene un destino abierto (actual).
INSERT INTO empleado_vivero VALUES
(1, 'DNI001', DATE '2025-01-01', DATE '2025-06-30'),
(2, 'DNI001', DATE '2025-07-01', NULL),
(1, 'DNI002', DATE '2025-01-01', NULL),
(2, 'DNI003', DATE '2025-02-01', NULL),
(3, 'DNI004', DATE '2025-03-01', NULL),
(5, 'DNI005', DATE '2025-04-01', NULL);

-- Cada periodo de trabajo está cubierto por el destino correspondiente.
INSERT INTO empleado_zona VALUES
('DNI001', 1, 1, DATE '2025-01-10', DATE '2025-06-20', 'Atención de zona exterior', 80.00),
('DNI001', 2, 1, DATE '2025-07-10', NULL, 'Venta y reposición', 88.50),
('DNI002', 1, 2, DATE '2025-02-01', NULL, 'Cultivo y riego', 76.25),
('DNI003', 2, 1, DATE '2025-03-01', NULL, 'Control de almacén', 84.00),
('DNI004', 3, 1, DATE '2025-04-01', NULL, 'Cuidado de semilleros', 92.00),
('DNI005', 5, 1, DATE '2025-05-01', NULL, 'Cuidado de frutales', 79.50);

INSERT INTO empleado_puesto VALUES
('DNI001', 1, DATE '2025-01-01', DATE '2025-06-30'),
('DNI001', 4, DATE '2025-07-01', NULL),
('DNI002', 3, DATE '2025-01-01', NULL),
('DNI003', 2, DATE '2025-02-01', NULL),
('DNI004', 4, DATE '2025-03-01', NULL),
('DNI005', 5, DATE '2025-04-01', NULL);

INSERT INTO pedido VALUES
(1001, 'CLI001', 'DNI001', DATE '2026-06-10', 125.75),
(1002, 'CLI002', 'DNI002', DATE '2026-06-12', 48.90),
(1003, 'CLI003', 'DNI003', DATE '2026-07-02', 215.00),
(1004, 'CLI006', 'DNI001', DATE '2026-07-05', 32.50),
(1005, 'CLI004', 'DNI004', DATE '2026-08-14', 89.99),
(1006, 'CLI005', 'DNI005', DATE '2026-09-01', 150.00);

-- =========================
-- 4. CONSULTAS DE COMPROBACIÓN
-- =========================

-- Comprobar que todas las tablas tienen al menos cinco filas.
SELECT 'vivero' AS tabla, count(*) AS filas FROM vivero
UNION ALL SELECT 'zona', count(*) FROM zona
UNION ALL SELECT 'producto', count(*) FROM producto
UNION ALL SELECT 'empleado', count(*) FROM empleado
UNION ALL SELECT 'puesto', count(*) FROM puesto
UNION ALL SELECT 'cliente', count(*) FROM cliente
UNION ALL SELECT 'cliente_plus', count(*) FROM cliente_plus
UNION ALL SELECT 'registro_productividad', count(*) FROM registro_productividad
UNION ALL SELECT 'stock_zona', count(*) FROM stock_zona
UNION ALL SELECT 'empleado_vivero', count(*) FROM empleado_vivero
UNION ALL SELECT 'empleado_zona', count(*) FROM empleado_zona
UNION ALL SELECT 'empleado_puesto', count(*) FROM empleado_puesto
UNION ALL SELECT 'pedido', count(*) FROM pedido
ORDER BY tabla;

-- Ejemplo de atributo calculado mediante consulta: volumen de compras mensual
-- de clientes Plus.
SELECT cp.dni_cliente,
       date_trunc('month', p.fecha)::date AS mes,
       COALESCE(SUM(p.importe), 0)::NUMERIC(12,2) AS volumen_compras
FROM cliente_plus cp
LEFT JOIN pedido p
       ON p.dni_cliente = cp.dni_cliente
      AND p.fecha >= cp.fecha_alta
GROUP BY cp.dni_cliente, date_trunc('month', p.fecha)
ORDER BY cp.dni_cliente, mes;

-- =========================
-- 5. EJEMPLOS DE DELETE
-- Se ejecutan dentro de una transacción y se deshacen con ROLLBACK,
-- para que los datos de prueba sigan intactos.
-- =========================

BEGIN;

-- 1. Borrar una fila de stock concreta (no afecta a otras tablas).
DELETE FROM stock_zona
WHERE id_vivero = 1 AND id_zona = 1 AND id_producto = 2;

-- 2 Intentar borrar un cliente que tiene pedidos.
-- La operación debe fallar por la restricción RESTRICT de pedidos,
-- en el caso de que borraramos por un casual los pedidos relacionados con este,
-- al eliminar cliente eliminaria su entrada en cliente_plus tambien.
DELETE FROM cliente
WHERE dni_cliente = 'CLI002';

-- 3. Borrar una zona: CASCADE elimina su stock y sus registros de productividad.
DELETE FROM zona WHERE id_vivero = 1 AND id_zona = 2;

ROLLBACK;
