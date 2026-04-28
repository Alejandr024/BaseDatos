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
  salarioNeto DECIMAL(10,2) GENERATED ALWAYS AS (totalDevengos - totalDeducciones),
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
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE vTotal DECIMAL(10,2);
  SELECT COALESCE(SUM(dnc.importeCalculado), 0)
    INTO vTotal
    FROM detalleNominaConceptos dnc
    JOIN tiposConceptoNomina tcn ON tcn.idConcepto = dnc.idConcepto
   WHERE dnc.idNomina = pIdNomina
     AND tcn.tipoMovimiento  = 'Devengo';
  RETURN vTotal;
END$$

-- ============================================================
--  PROCEDIMIENTO: calcular_nomina
--  Recalcula total_devengos, total_deducciones y salario_neto
--  para la nómina indicada y actualiza la fila.
-- ============================================================
CREATE PROCEDURE calcularNomina(IN pIdNomina INT)
BEGIN
  DECLARE vDevengos DECIMAL(10,2);
  DECLARE vDeducciones DECIMAL(10,2);

  SELECT COALESCE(SUM(CASE WHEN tcn.tipoMovimiento = 'Devengo'   THEN dnc.importeCalculado ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN tcn.tipoMovimiento = 'Deduccion' THEN dnc.importeCalculado ELSE 0 END), 0)
    INTO vDevengos, vDeducciones
    FROM detalleNominaConceptos dnc
    JOIN tiposConceptoNomina tcn ON tcn.idConcepto = dnc.idConcepto
   WHERE dnc.idNomina = pIdNomina;

  UPDATE nominas
     SET totalDevengos = vDevengos,
         totalDeducciones = vDeducciones,
         salarioNeto = vDevengos - vDeducciones
   WHERE idNomina = pIdNomina;
END$$

DELIMITER ;

-- ============================================================
--  DATOS DE EJEMPLO
-- ============================================================

-- Proveedores
INSERT INTO proveedores (nombreEmpresa, personaContacto, telefono, email)
VALUES
  ('Chucherías del Norte S.L.', 'Ana López',   '912345678', 'ana@chuches.es'),
  ('Dulces Mediterráneo S.A.',  'Pedro Ruiz',  '934567890', 'pedro@dulcesmed.es');

-- Golosinas
INSERT INTO golosinas (nombre, descripcion, precioVenta, stockActual, fechaCaducidad, idProveedor)
VALUES
  ('Gominola de fresa',  'Gominola con sabor a fresa natural', 0.10,  500, '2025-12-31', 1),
  ('Chocolatina con leche', 'Chocolate con leche en tableta pequeña', 0.50, 200, '2025-09-30', 2);

-- Departamentos
INSERT INTO departamentos (nombre) VALUES ('Ventas'), ('RRHH'), ('Almacén');

-- Cargos
INSERT INTO cargos (nombreCargo, descripcionFunciones, salarioBase)
VALUES
  ('Vendedor',            'Atención al cliente y cobro en caja', 1200.00),
  ('Responsable de RRHH', 'Gestión de personal y nóminas',       1800.00),
  ('Reponedor',           'Reposición y control de stock',       1100.00);

-- Empleados
INSERT INTO empleados (dni, nombre, apellidos, fechaNacimiento, direccion, telefono, email, fechaContratacion, codigoDepartamento, codigoCargo)
VALUES
  ('12345678A', 'María',   'García Torres',  '1990-04-15', 'Calle Mayor 1, Madrid', '600111222', 'maria@dulcerincon.es', '2020-01-10', 1, 1),
  ('87654321B', 'Carlos',  'Martín Díaz',    '1985-08-22', 'Avenida Sol 5, Madrid',  '600333444', 'carlos@dulcerincon.es','2018-06-01', 2, 2);

-- Tipos de concepto de nómina
INSERT INTO tiposConceptoNomina (nombreConcepto, tipoMovimiento, esPorcentaje, porcentajeAplicable)
VALUES
  ('Salario base',                          'Devengo',   FALSE, NULL),
  ('Horas extra al 50%',                    'Devengo',   TRUE,  0.50),
  ('Complemento de antigüedad (trienio)',   'Devengo',   FALSE, NULL),
  ('Bonificación productividad',            'Devengo',   FALSE, NULL),
  ('SS Contingencias comunes (trabajador)', 'Deduccion', TRUE,  0.47),
  ('SS Desempleo (trabajador)',             'Deduccion', TRUE,  0.15),
  ('SS Formación profesional',              'Deduccion', TRUE,  0.10),
  ('Retención IRPF',                        'Deduccion', TRUE,  0.15);

-- Venta de ejemplo
INSERT INTO ventas (fechaHora, idEmpleado)
VALUES ('2024-05-10 10:30:00', '12345678A');

INSERT INTO detalleVenta (idVenta, idGolosina, cantidad, precioUnitarioVenta)
VALUES (1, 1, 10, 0.10), (1, 2, 2, 0.50);

-- Nómina de ejemplo (mayo 2024, María García)
INSERT INTO nominas (idEmpleado, mes, yearCorrespondiente, fechaEmision, fechaPago, totalDevengos, totalDeducciones, salarioNeto)
VALUES ('12345678A', 5, 2024, '2023-12-02', '2024-06-05', 3333.33, 1234.55, 2098.78);

CREATE TABLE nominas (
  idNomina INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  idEmpleado VARCHAR(9) NOT NULL,
  mes VARCHAR(30) NOT NULL,
  yearCorrespondiente YEAR NOT NULL,
  fechaEmision DATE NOT NULL,
  fechaPago DATE,
  totalDevengos DECIMAL(10,2),
  totalDeducciones DECIMAL(10,2) DEFAULT 0.00,
  salarioNeto DECIMAL(10,2) GENERATED ALWAYS AS (totalDevengos - totalDeducciones),
  FOREIGN KEY (idEmpleado) REFERENCES empleados (dni) ON UPDATE CASCADE ON DELETE RESTRICT
);


INSERT INTO detalle_nomina_conceptos (id_nomina, id_concepto, base_calculo, cantidad, precio_unitario, importe_calculado)
VALUES
  (1, 1, NULL,    NULL, NULL,  1200.00),   -- Salario base
  (1, 3, NULL,    1,    60.00, 60.00),     -- 1 trienio = 60 €
  (1, 5, 1260.00, NULL, NULL,  59.22),     -- SS Contingencias 4.70%
  (1, 6, 1260.00, NULL, NULL,  19.53),     -- SS Desempleo 1.55%
  (1, 7, 1260.00, NULL, NULL,  1.26),      -- SS Formación 0.10%
  (1, 8, 1260.00, NULL, NULL,  189.00);    -- IRPF 15%

-- Recalcular totales de la nómina
CALL calcular_nomina(1);

-- ============================================================
--  CONSULTAS ÚTILES DE EJEMPLO
-- ============================================================

-- Resumen de una nómina
SELECT n.id_nomina, CONCAT(e.nombre,' ',e.apellidos) AS empleado,
       n.mes, n.anio, n.total_devengos, n.total_deducciones, n.salario_neto
  FROM nominas n
  JOIN empleados e ON e.dni = n.id_empleado;

-- Desglose de conceptos de una nómina
SELECT tcn.nombre_concepto, tcn.tipo_movimiento, dnc.importe_calculado
  FROM detalle_nomina_conceptos dnc
  JOIN tipos_concepto_nomina    tcn ON tcn.id_concepto = dnc.id_concepto
 WHERE dnc.id_nomina = 1
 ORDER BY tcn.tipo_movimiento, dnc.importe_calculado DESC;

-- Total de ventas por empleado
SELECT CONCAT(e.nombre,' ',e.apellidos) AS empleado,
       COUNT(v.id_venta)               AS num_ventas,
       SUM(dv.cantidad * dv.precio_unitario_venta) AS total_facturado
  FROM ventas v
  JOIN empleados    e  ON e.dni         = v.id_empleado
  JOIN detalle_venta dv ON dv.id_venta  = v.id_venta
 GROUP BY e.dni;