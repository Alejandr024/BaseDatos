CREATE DATABASE practica_subconsultas;
USE practica_subconsultas;

CREATE TABLE MASCOTAS (
    id_mascota INT PRIMARY KEY AUTO_INCREMENT,
    especie VARCHAR(1),
    sexo VARCHAR(1),
    ubicacion VARCHAR(3),
    estado VARCHAR(1)
);

DROP TABLE MASCOTAS;

CREATE TABLE EMPLEADOS (
    id_empleado INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50),
    fecha_nacimiento DATE,
    salario DECIMAL(10,2)
);

CREATE TABLE PROFESORES (
    id_profesor INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50),
    especialidad VARCHAR(50)
);

CREATE TABLE CURSOS (
    id_curso INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50),
    id_profesor INT,
    FOREIGN KEY (id_profesor) REFERENCES PROFESORES(id_profesor)
);
CREATE TABLE ALUMNOS (
    id_alumno INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50),
    fecha_nacimiento DATE
);
CREATE TABLE ALUMNOS_CURSOS (
    id_alumno INT,
    id_curso INT,
    PRIMARY KEY (id_alumno, id_curso),
    FOREIGN KEY (id_alumno) REFERENCES ALUMNOS(id_alumno),
    FOREIGN KEY (id_curso) REFERENCES CURSOS(id_curso)
);

CREATE TABLE ARTICULOS (
    id_articulo INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(50),
    precio DECIMAL(10,2)
);

CREATE TABLE FACTURAS (
    id_factura INT PRIMARY KEY AUTO_INCREMENT,
    fecha DATE
);

CREATE TABLE LINEAS_FACTURA (
    id_linea INT PRIMARY KEY AUTO_INCREMENT,
    id_factura INT,
    id_articulo INT,
    precio DECIMAL(10,2),
    cantidad INT,
    FOREIGN KEY (id_factura) REFERENCES FACTURAS(id_factura),
    FOREIGN KEY (id_articulo) REFERENCES ARTICULOS(id_articulo)
);

INSERT INTO MASCOTAS (id_mascota, especie, sexo, ubicacion, estado) VALUES
(1,'P','M','E05','B'),
(2,'P','M','E02','B'),
(3,'P','H','E02','A'),
(4,'P','M','E03','A'),
(5,'G','H','E01','A'),
(6,'P','H','E05','A'),
(7,'G','M','E01','A'),
(8,'G','H','E01','B'),
(9,'P','M','E02','A'),
(10,'G','H','E04','A'),
(11,'G','M','E04','B'),
(12,'P','H','E02','A'),
(13,'P','H','E05','A'),
(14,'G','M','E04','A'),
(15,'G','M','E04','A'),
(16,'P','M','E02','A');

SELECT m.ubicacion, m.especie, COUNT(*) *100 / totales.total AS porcentaje 
FROM MASCOTAS m, (SELECT m2.especie, COUNT(*) AS total FROM MASCOTAS m2 WHERE estado='A' GROUP BY m2.especie) as totales 
WHERE m.estado='A'
AND m.especie= totales.especie
GROUP BY m.ubicacion, m.especie;