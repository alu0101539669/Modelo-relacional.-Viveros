-- ==============================================================================
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ==============================================================================
-- NOTA: Ejecuta esta instrucción y luego conéctate a la base de datos 'viveros' 
-- antes de ejecutar el resto del script (en psql usa: \c viveros).
-- CREATE DATABASE viveros;

-- ==============================================================================
-- 2. CREACIÓN DE TABLAS Y RESTRICCIONES
-- ==============================================================================

CREATE TABLE vivero (
    id_vivero SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    latitud NUMERIC(9,6) NOT NULL,
    longitud NUMERIC(9,6) NOT NULL
);

CREATE TABLE zona (
    id_zona SERIAL PRIMARY KEY,
    id_vivero INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('Invernadero', 'Exterior', 'Almacén', 'Semillero')),
    latitud NUMERIC(9,6),
    longitud NUMERIC(9,6),
    CONSTRAINT fk_zona_vivero FOREIGN KEY (id_vivero) REFERENCES vivero(id_vivero) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE registro_productividad (
    id_registro SERIAL PRIMARY KEY,
    id_zona INT NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    unidades_producidas INT NOT NULL CHECK (unidades_producidas >= 0),
    horas_trabajadas NUMERIC(5,2) NOT NULL CHECK (horas_trabajadas > 0),
    CONSTRAINT fk_registro_zona FOREIGN KEY (id_zona) REFERENCES zona(id_zona) ON DELETE CASCADE
);

CREATE TABLE producto (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    precio NUMERIC(10,2) NOT NULL CHECK (precio > 0)
);

CREATE TABLE stock_zona (
    id_zona INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    PRIMARY KEY (id_zona, id_producto),
    CONSTRAINT fk_stock_zona FOREIGN KEY (id_zona) REFERENCES zona(id_zona) ON DELETE CASCADE,
    CONSTRAINT fk_stock_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
);

CREATE TABLE empleado (
    id_empleado VARCHAR(20) PRIMARY KEY, -- DNI u otro documento
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    email VARCHAR(100) UNIQUE
);

CREATE TABLE puesto (
    id_puesto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE empleado_puesto (
    id_empleado VARCHAR(20) NOT NULL,
    id_puesto INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    PRIMARY KEY (id_empleado, id_puesto, fecha_inicio),
    CONSTRAINT chk_fechas_puesto CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT fk_ep_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado) ON DELETE CASCADE,
    CONSTRAINT fk_ep_puesto FOREIGN KEY (id_puesto) REFERENCES puesto(id_puesto) ON DELETE RESTRICT
);

CREATE TABLE empleado_zona (
    id_empleado VARCHAR(20) NOT NULL,
    id_zona INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    tarea VARCHAR(200) NOT NULL,
    PRIMARY KEY (id_empleado, id_zona, fecha_inicio),
    CONSTRAINT chk_fechas_zona CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT fk_ez_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado) ON DELETE CASCADE,
    CONSTRAINT fk_ez_zona FOREIGN KEY (id_zona) REFERENCES zona(id_zona) ON DELETE CASCADE
);

CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    email VARCHAR(100) UNIQUE NOT NULL
);

-- Especialización de cliente (Herencia 1:1)
CREATE TABLE cliente_plus (
    id_cliente INT PRIMARY KEY,
    fecha_alta DATE NOT NULL DEFAULT CURRENT_DATE,
    descuento_aplicable NUMERIC(4,2) DEFAULT 0.10 CHECK (descuento_aplicable >= 0 AND descuento_aplicable <= 1),
    CONSTRAINT fk_cliente_plus FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE
);

CREATE TABLE pedido (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_empleado VARCHAR(20), -- Empleado que gestiona el pedido (puede ser nulo si es online)
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado) ON DELETE SET NULL
);

CREATE TABLE detalle_pedido (
    id_pedido INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    -- ATRIBUTO DERIVADO (Calculado automáticamente por PostgreSQL)
    importe_linea NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
);

-- ==============================================================================
-- 3. INSERCIÓN DE DATOS (Mínimo 5 filas por tabla)
-- ==============================================================================

INSERT INTO vivero (nombre, latitud, longitud) VALUES
('Viveros El Sol', 40.416775, -3.703790),
('Viveros La Luna', 41.385063, 2.173404),
('Natura Garden', 39.469907, -0.376288),
('Plantas del Sur', 37.389092, -5.984459),
('Vivero Norte', 43.362343, -5.844759);

INSERT INTO zona (id_vivero, nombre, tipo, latitud, longitud) VALUES
(1, 'Invernadero Principal', 'Invernadero', 40.416800, -3.703800),
(1, 'Exposición Rosales', 'Exterior', 40.416900, -3.703900),
(2, 'Almacén Central', 'Almacén', 41.385100, 2.173500),
(3, 'Semilleros 1', 'Semillero', 39.470000, -0.376300),
(4, 'Patio de Frutales', 'Exterior', 37.389100, -5.984500);

INSERT INTO registro_productividad (id_zona, fecha, unidades_producidas, horas_trabajadas) VALUES
(1, '2023-10-01', 500, 8),
(1, '2023-10-02', 450, 7.5),
(3, '2023-10-01', 120, 4),
(4, '2023-10-03', 1000, 16),
(5, '2023-10-04', 50, 8);

INSERT INTO producto (nombre, categoria, precio) VALUES
('Rosal Rojo', 'Flores', 12.50),
('Limonero 1.5m', 'Árboles Frutales', 45.00),
('Saco Tierra 50L', 'Sustratos', 8.99),
('Semillas Tomate', 'Semillas', 2.50),
('Maceta Cerámica 20cm', 'Accesorios', 15.00);

INSERT INTO stock_zona (id_zona, id_producto, cantidad) VALUES
(1, 1, 150),
(2, 1, 50),
(3, 3, 200),
(4, 4, 500),
(5, 2, 30);

INSERT INTO empleado (id_empleado, nombre, apellidos, telefono, email) VALUES
('12345678A', 'Ana', 'García Pérez', '600123456', 'ana.gp@viveros.com'),
('87654321B', 'Carlos', 'Ruiz', '600654321', 'carlos.r@viveros.com'),
('11223344C', 'Marta', 'López', '611223344', 'marta.l@viveros.com'),
('44332211D', 'Pedro', 'Sánchez', '622334455', 'pedro.s@viveros.com'),
('99887766E', 'Lucía', 'Gómez', '633445566', 'lucia.g@viveros.com');

INSERT INTO puesto (nombre) VALUES
('Gerente'),
('Operario de Invernadero'),
('Mozo de Almacén'),
('Dependiente'),
('Técnico Agrícola');

INSERT INTO empleado_puesto (id_empleado, id_puesto, fecha_inicio, fecha_fin) VALUES
('12345678A', 1, '2020-01-01', NULL),
('87654321B', 2, '2021-03-15', NULL),
('11223344C', 3, '2022-06-01', '2023-01-01'),
('11223344C', 4, '2023-01-02', NULL),
('44332211D', 5, '2019-11-10', NULL);

INSERT INTO empleado_zona (id_empleado, id_zona, fecha_inicio, fecha_fin, tarea) VALUES
('87654321B', 1, '2021-03-15', NULL, 'Riego y poda'),
('87654321B', 2, '2021-03-15', '2022-03-15', 'Mantenimiento exterior'),
('11223344C', 3, '2022-06-01', '2023-01-01', 'Recepción de sustratos'),
('44332211D', 4, '2019-11-10', NULL, 'Gestión de semilleros'),
('99887766E', 5, '2023-02-01', NULL, 'Cuidado de frutales');

INSERT INTO cliente (nombre, telefono, email) VALUES
('Juan Pérez', '655112233', 'juan.p@mail.com'),
('María Rodríguez', '655998877', 'maria.r@mail.com'),
('Empresa Jardines SL', '912345678', 'contacto@jardinessl.com'),
('Luis Martínez', '600000001', 'luis.m@mail.com'),
('Ayuntamiento Madrid', '910000000', 'parques@madrid.es');

INSERT INTO cliente_plus (id_cliente, fecha_alta, descuento_aplicable) VALUES
(2, '2022-05-10', 0.10),
(3, '2021-01-15', 0.15),
(5, '2020-10-20', 0.20),
(1, '2023-09-01', 0.05),
(4, '2023-10-01', 0.10);

INSERT INTO pedido (id_cliente, id_empleado, fecha) VALUES
(1, '11223344C', '2023-10-05 10:30:00'),
(3, '12345678A', '2023-10-06 12:15:00'),
(2, NULL, '2023-10-07 09:00:00'), -- Pedido online sin empleado
(5, '12345678A', '2023-10-08 08:30:00'),
(4, '11223344C', '2023-10-09 17:45:00');

INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
(1, 1, 2, 12.50), -- importe_linea generado: 25.00
(1, 3, 1, 8.99),  -- importe_linea generado: 8.99
(2, 2, 10, 42.00), -- Precio negociado diferente al catalogo
(3, 4, 5, 2.50),
(4, 1, 100, 10.00);

-- ==============================================================================
-- 4. EJEMPLOS REPRESENTATIVOS DE OPERACIONES DELETE
-- ==============================================================================

-- a) DELETE con SET NULL:
-- Si borramos a un empleado que tramitó un pedido, el empleado se elimina 
-- pero el pedido se conserva (el id_empleado del pedido pasará a NULL).
DELETE FROM empleado WHERE id_empleado = '12345678A';

-- b) DELETE con CASCADE:
-- Si borramos un Vivero, se borran automáticamente sus Zonas, 
-- el Stock de esas zonas, los Registros de productividad y las asignaciones 
-- de Empleados a esas zonas.
DELETE FROM vivero WHERE id_vivero = 1;

-- c) DELETE con RESTRICT (Lanzará ERROR en PostgreSQL):
-- Intentar borrar un producto que está en un detalle de pedido será bloqueado
-- por la base de datos para no romper la consistencia contable del historial de compras.
-- DELETE FROM producto WHERE id_producto = 2; 

-- d) Borrado limpio de un detalle puntual:
-- Simplemente borra la línea del pedido específico.
DELETE FROM detalle_pedido WHERE id_pedido = 1 AND id_producto = 3;