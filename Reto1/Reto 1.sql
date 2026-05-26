CREATE DATABASE dulceRincon;
USE dulceRincon;

-- ------------------------------------------------------------
-- 1. PROVEEDORES
-- ------------------------------------------------------------
CREATE TABLE proveedores (
  idProveedor INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  nombreEmpresa VARCHAR(120) NOT NULL,
  personaContacto  VARCHAR(100),
  telefono VARCHAR(20),
  email VARCHAR(100)
);


-- ------------------------------------------------------------
-- 2. GOLOSINAS
-- ------------------------------------------------------------
CREATE TABLE golosinas(
  idGolosina INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(120) NOT NULL,
  descripcion VARCHAR(120),
  precioVenta DECIMAL(8,2) NOT NULL,
  stockActual INT NOT NULL DEFAULT 0,
  fechaCaducidad DATE,
  idProveedor INT NOT NULL,
  FOREIGN KEY (idProveedor) REFERENCES proveedores (idProveedor)
  ON UPDATE CASCADE ON DELETE RESTRICT -- En caso de actualizar el ID del proveedor o eliminarlo.--
);

-- ------------------------------------------------------------
-- 3. DEPARTAMENTOS
-- ------------------------------------------------------------

CREATE TABLE departamentos (
  codigoDepartamento INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(80) NOT NULL
);

-- ------------------------------------------------------------
-- 4. CARGOS
-- ------------------------------------------------------------
CREATE TABLE cargos (
  codigoCargo INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  nombreCargo VARCHAR(80) NOT NULL,
  descripcionFunciones VARCHAR(150),
  salarioBase DECIMAL(10,2) NOT NULL DEFAULT 0.00
);

-- ------------------------------------------------------------
-- 5. EMPLEADOS
-- ------------------------------------------------------------
CREATE TABLE empleados (
  dni VARCHAR(9) PRIMARY KEY NOT NULL,
  nombre VARCHAR(80) NOT NULL,
  apellidos VARCHAR(120) NOT NULL,
  fechaNacimiento DATE NOT NULL,
  direccion VARCHAR(255),
  telefono VARCHAR(20),
  email VARCHAR(100),
  fechaContratacion DATE NOT NULL,
  codigoDepartamento INT NOT NULL,
  codigoCargo INT NOT NULL, 
  FOREIGN KEY (codigoDepartamento) REFERENCES departamentos (codigoDepartamento) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (codigoCargo) REFERENCES cargos (codigoCargo) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 6. VENTAS
-- ------------------------------------------------------------
CREATE TABLE ventas (
  idVenta INT  PRIMARY KEY NOT NULL AUTO_INCREMENT,
  fechaHora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  idEmpleado VARCHAR(9) NOT NULL,
  FOREIGN KEY (idEmpleado) REFERENCES empleados (dni) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 7. DETALLE_VENTA
-- ------------------------------------------------------------
CREATE TABLE detalleVenta (
  idDetalle INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  idVenta INT NOT NULL,
  idGolosina INT NOT NULL,
  cantidad INT NOT NULL,
  precioUnitarioVenta DECIMAL(8,2) NOT NULL,   -- precio histórico en el momento de la venta
  FOREIGN KEY (idVenta) REFERENCES ventas (idVenta) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (idGolosina) REFERENCES golosinas (idGolosina) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 8. TIPOS_CONCEPTO_NOMINA
-- ------------------------------------------------------------
CREATE TABLE tiposConceptoNomina (
  idConcepto INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  nombreConcepto VARCHAR(120) NOT NULL,
  tipoMovimiento ENUM('Devengo','Deduccion') NOT NULL,
  esPorcentaje BOOLEAN NOT NULL DEFAULT FALSE,
  porcentajeAplicable DECIMAL(6,2)
);

-- ------------------------------------------------------------
-- 9. NOMINAS
-- ------------------------------------------------------------
CREATE TABLE nominas (
  idNomina INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  idEmpleado VARCHAR(9) NOT NULL,
  mes VARCHAR(30) NOT NULL,
  yearCorrespondiente YEAR NOT NULL,
  fechaEmision DATE NOT NULL,
  fechaPago DATE,
  totalDevengos DECIMAL(10,2),
  totalDeducciones DECIMAL(10,2) DEFAULT 0.00,
  salarioNeto DECIMAL(10,2) GENERATED ALWAYS AS (totalDevengos - totalDeducciones) ,
  FOREIGN KEY (idEmpleado) REFERENCES empleados (dni) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 10. DETALLE_NOMINA_CONCEPTOS
-- ------------------------------------------------------------
CREATE TABLE detalleNominaConceptos (
  idDetalleNomina INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  idNomina INT NOT NULL,
  idConcepto INT NOT NULL,
  baseCalculo DECIMAL(10,2),   -- base sobre la que aplica el % (opcional)
  cantidad DECIMAL(8,2),    -- ej: nº de horas extra, nº de trienios
  precioUnitario DECIMAL(8,2),    -- ej: precio/hora extra
  importeCalculado DECIMAL(10,2) NOT NULL,   -- valor final del concepto
  FOREIGN KEY (idNomina) REFERENCES nominas (idNomina) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (idConcepto) REFERENCES tiposConceptoNomina (idConcepto) ON UPDATE CASCADE ON DELETE RESTRICT
);



-- ============================================================
--  FUNCIÓN: calcularTotalDevengos
--  Devuelve la suma de importe_calculado para los conceptos
--  de tipo 'Devengo' de una nómina dada.
-- ============================================================
DELIMITER $$
CREATE FUNCTION calcularTotalDevengos(pIdNomina INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC -- los mismos 
READS SQL DATA
BEGIN
  DECLARE vTotal DECIMAL(10,2);
  SELECT SUM(dnc.importeCalculado)
    INTO vTotal
    FROM detalleNominaConceptos dnc
    JOIN tiposConceptoNomina tcn ON tcn.idConcepto = dnc.idConcepto
   WHERE dnc.idNomina = pIdNomina
     AND tcn.tipoMovimiento  = 'Devengo';
  RETURN IFNULL(vTotal,0.00); -- si no encuentra filas, el sum devuelve null, para evitar esto, hacemos que devuelvo 0 con ifnull().
END$$

-- La funcion calcularTotalDevengos trata de calcular el total de ingresos de un empleado, y para ello se pide, como parametro, el idNomina del empleado.
-- Con el idNomina, buscamos los importes calculados, cuyo movimiento sea 'Devengos' y que ademas la nomima este presente en la tabla de detalleNominaConcepto.
-- Para llevar a cabo dicha funcion, utilizamos tres tablas para encontrar todos los devengos disponibles de la nomina: detalleNominaConcepto, tiposConceptoNomina y nomima.
-- COn la tabla nomina se concecta con la tabla detalleNonimaConcepto, y la tabla tipoConceptoNomina se conecta tambien con la tabla detalleNominaConceptos mediante el JOIN, para captuar todos los devengos existentes.
-- 

-- ============================================================
--  PROCEDIMIENTO: calcular_nomina
--  Recalcula total_devengos, total_deducciones y salario_neto
--  para la nómina indicada y actualiza la fila.
-- ============================================================
CREATE PROCEDURE calcularNomina(IN pIdNomina INT)
BEGIN
	DECLARE v_total DECIMAL(10,2);

  SELECT SUM(dnc.importeCalculado)
    INTO v_total
    FROM detalleNominaConceptos dnc
    JOIN tiposConceptoNomina tcn ON tcn.idConcepto = dnc.idConcepto
   WHERE dnc.idNomina = pIdNomina
   AND tcn.tipoMovimiento= "Deduccion";

  UPDATE nominas
     SET totalDevengos = vDevengos,
         totalDeducciones = vDeducciones,
         salarioNeto = vDevengos - vDeducciones
   WHERE idNomina = pIdNomina;
END$$

DELIMITER ;

-- ============================================================
--  DATOS
-- ============================================================

-- Proveedores
INSERT INTO proveedores (idProveedor, nombreEmpresa, personaContacto, telefono, email)
VALUES
(1,'ChocoDelicias S.A.', 'Carlos Rivera', '912345678', 'pedidos@chocodelicias.es'),
(2,'Gominolas Fantasía Ltda.', 'Laura Méndez', '934567890', 'laura.mendez@gominolasfantasia.com'),
(3,'Snacks Internacionales S.L.', 'Pedro Jiménez', '600112233','ventas@snacksinternacionales.com'),
(4, 'Dulces Tradicionales El Artesano', 'Ana Torres', '987654321', 'info@dulcesartesano.es'),
(5, 'Importadora de Caramelos del Mundo', 'Sofía Castro', '650987654','scastro@caramelosmundo.com');

-- Golosinas
INSERT INTO golosinas (nombre, descripcion, precioVenta, stockActual, fechaCaducidad, idProveedor)
VALUES
(1, 'Ositos de Goma Ácidos', 'Gominolas con forma de osito y pica-pica ácido, saboressurtidos.', 1.50, 120, 2, '2026-03-15'),
(2, 'Tableta Chocolate Negro 70%', 'Chocolate negro intenso con 70% de cacao puro.', 2.20,75, 1, '2026-07-30'),
(3, 'Chicle Menta Fresca (Paquete)', 'Paquete de chicles sin azúcar sabor menta fresca.',0.80, 200, 3, '2025-12-01'),
(4, 'Caramelos de Violeta Artesanos', 'Auténticos caramelos de violeta, receta tradicional.',2.50, 50, 4, '2026-01-20'),
(5, 'Nubes de Fresa Gigantes', 'Nubes de azúcar esponjosas con sabor a fresa, tamaño XL.',1.00, 90, 5, '2025-11-10'),
(6, 'Piruleta Corazón Fresa', 'Piruleta clásica con forma de corazón y sabor a fresa intensa.',0.60, 150, 2, '2026-05-22'),
(7, 'Bombones Surtidos Caja Pequeña', 'Caja con selección de 6 bombones de chocolate con leche, negro y blanco.', 3.00, 40, 1, '2025-10-15'),
(8, 'Patatas Fritas Onduladas (Bolsa)', 'Bolsa de patatas fritas con corte ondulado y sal.',1.20, 110, 3, '2025-09-01'),
(9, 'Regaliz Rojo Relleno (Tira)', 'Tira de regaliz rojo con relleno cremoso sabor nata.', 0.75,130, 5, '2026-02-28'),
(10, 'Pastillas de Menta y Eucalipto', 'Caramelos balsámicos para refrescar el aliento y la garganta.', 1.80, 60, 4, '2026-08-10');

-- Departamentos
INSERT INTO departamentos (codigoDepartamento, nombre) 
VALUES 
(10, 'Ventas'),
(20, 'Recursos Humanos'),
(30, 'Almacén');

-- Cargos
INSERT INTO cargos (nombreCargo, descripcionFunciones, salarioBase)
VALUES
(101, 'Vendedor/a', 'Atención al cliente, venta de productos, reposición en tienda.', 1250.75),
(102, 'Cajero/a', 'Cobro de productos, arqueo de caja, atención al cliente.', 1200.50),
(103, 'Responsable de RRHH', 'Gestión de personal, nóminas, contratación, formación.', 2300.00),
(104, 'Reponedor/a Almacén', 'Recepción de mercancía, organización de almacén, preparación de pedidos para tienda.', 1150.20),
(105, 'Jefe/a de Tienda', 'Supervisión del equipo de ventas, gestión de stock en tienda, objetivos de venta.', 1950.00);

-- Empleados
INSERT INTO empleados (dni, nombre, apellidos, fechaNacimiento, direccion, telefono, email, fechaContratacion, codigoDepartamento, codigoCargo)
VALUES
('12345678A', 'Ana', 'García Pérez', '1990-05-15', 'Calle Mayor 1, 28001 Madrid','600111222', 'ana.garcia@dulcerincon.es', '2020-03-01', 10, 105),
('23456789B', 'Luis', 'Martínez Sánchez', '1995-08-20', 'Avenida del Sol 5, 28002 Madrid','600222333', 'luis.martinez@dulcerincon.es', '2022-01-10', 10, 101),
('34567890C', 'Sofía', 'López Fernández', '1998-11-02', 'Plaza Nueva 3, 28003 Madrid','600333444', 'sofia.lopez@dulcerincon.es', '2023-06-15', 10, 102),
('45678901D', 'Carlos', 'Ruiz Gómez', '1985-02-10', 'Calle Luna 7, 28004 Madrid','600444555', 'carlos.ruiz@dulcerincon.es', '2018-09-01', 20, 103),
('56789012E', 'Elena', 'Vázquez Torres', '1992-07-25', 'Paseo de la Castellana 100, 28005Madrid', '600555666', 'elena.vazquez@dulcerincon.es', '2021-05-20', 30, 104),
('67890123F', 'Javier', 'Romero Díaz', '1999-01-30', 'Calle Gran Vía 20, 28006 Madrid','600666777', 'javier.romero@dulcerincon.es', '2024-02-01', 10, 101),
('78901234G', 'Laura', 'Jiménez Moreno', '1996-04-12', 'Calle Alcalá 150, 28007 Madrid','600777888', 'laura.jimenez@dulcerincon.es', '2023-01-05', 10, 102),
('89012345H', 'David', 'Álvarez Alonso', '2000-09-05', 'Avenida de América 2, 28008 Madrid','600888999', 'david.alvarez@dulcerincon.es', '2024-05-01', 30, 104),
('90123456I', 'Marta', 'Gutiérrez Navarro', '1993-12-18', 'Calle Serrano 50, 28009 Madrid','600999000', 'marta.gutierrez@dulcerincon.es', '2022-11-10', 10, 101),
('01234567J', 'Pablo', 'Iglesias Ramos', '1997-06-22', 'Ronda de Valencia 8, 28010 Madrid','600000111', 'pablo.iglesias@dulcerincon.es', '2023-08-20', 10, 101);

-- Ventas
INSERT INTO ventas (fechaHora, idEmpleado)
VALUES (1, '2025-05-27 10:15:30', '23456789B'),
(2, '2025-05-27 11:05:00', '34567890C'),
(3, '2025-05-27 12:30:15', '67890123F'),
(4, '2025-05-27 16:45:50', '78901234G'),
(5, '2025-05-27 18:00:00', '90123456I'),
(6, '2025-05-26 10:30:00', '01234567J'),
(7, '2025-05-26 11:20:10', '12345678A'),
(8, '2025-05-26 14:00:45', '23456789B'),
(9, '2025-05-26 17:15:20', '34567890C'),
(10, '2025-05-26 19:05:30', '67890123F'),
(11, '2025-05-25 10:05:00', '78901234G'),
(12, '2025-05-25 11:45:15', '90123456I'),
(13, '2025-05-25 13:50:00', '01234567J'),
(14, '2025-05-24 16:30:25', '12345678A'),
(15, '2025-05-24 18:55:40', '23456789B'),
(16, '2025-04-20 10:10:10', '34567890C'),
(17, '2025-04-20 12:00:00', '67890123F'),
(18, '2025-04-21 17:05:00', '78901234G'),
(19, '2025-04-22 11:33:00', '90123456I'),
(20, '2025-04-23 18:22:00', '01234567J'),
(21, '2025-03-15 10:40:00', '12345678A'),
(22, '2025-03-15 16:15:00', '23456789B'),
(23, '2025-03-16 11:55:00', '34567890C'),
(24, '2025-02-28 17:50:00', '67890123F'),
(25, '2025-02-28 19:10:00', '78901234G');

-- Detalles de venta
INSERT INTO detalleVenta (idVenta, idGolosina, cantidad, precioUnitarioVenta)
VALUES (1, 1, 10, 0.10), (1, 2, 2, 0.50);

-- Calcular el dinero en total de una venta
SELECT SUM(cantidad * precioUnitarioVenta) AS totalVenta
FROM detalleVenta
WHERE idVenta = 1;