/* =====================================================================
   RETRO GAMES - Etapa V: Optimización de consultas a través de índices
   SQL Server / Transact-SQL (requiere SQL Server 2016 SP1 o superior)
   Requisito: haber ejecutado crear_bd.sql (y, para el índice de
   auditoría, el script de triggers de la carpeta triggers_auditoria,
   que crea dbo.auditoria_producto).

   Contenido:
     Partes 1 a 8: experimento de rendimiento sobre una tabla con
       1.000.000 de filas (dbo.venta_historica), que replica la
       estructura de venta_cabecera: sin índices -> índice agrupado ->
       índice con cobertura. Se mide con STATISTICS TIME / IO y con el
       plan de ejecución.
     Parte 9: índices permanentes para las tablas reales de RetroGames,
       elegidos según las consultas del sistema (ventas, catálogo,
       auditoría).
     Parte 10: verificación y limpieza.

   POR QUÉ UNA TABLA APARTE: cargar un millón de ventas simuladas en
   venta_cabecera contaminaría los datos reales (exigiría usuarios y
   direcciones ficticios, y alteraría ventas y reportes). La tabla de
   prueba se crea sin claves foráneas y se puede borrar al final.

   ANTES DE EJECUTAR LAS PARTES 3, 4 Y 6 EN SSMS:
     - Activar "Incluir plan de ejecución real" (Ctrl + M).
     - Mirar la pestaña "Mensajes": ahí aparecen el tiempo de CPU, el
       tiempo total y las lecturas lógicas.
     - Los valores varían según el hardware; lo importante es la
       comparación entre escenarios.
   ===================================================================== */

USE RetroGames;
GO

/* ---------------------------------------------------------------------
   PARTE 1. CREACIÓN DE LA TABLA DE PRUEBAS
   Se crea como "heap" (sin clave primaria ni índice agrupado) a
   propósito: si tuviera un PK agrupado, no se podría crear después un
   índice agrupado sobre la fecha (solo existe uno por tabla).
   Estructura análoga a dbo.venta_cabecera (fecha, total, usuario).
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.venta_historica;
GO

CREATE TABLE dbo.venta_historica
(
    id_venta    BIGINT IDENTITY(1,1) NOT NULL,
    fecha_venta DATE                 NOT NULL,
    importe     DECIMAL(12,2)        NOT NULL,
    id_usuario  INT                  NOT NULL
);
GO

/* ---------------------------------------------------------------------
   PARTE 2. CARGA MASIVA DE DATOS (1.000.000 de filas)
   Ventas simuladas entre 2020-01-01 y 2024-12-30, con importes entre
   1,00 y ~10.000,00 y usuarios del 1 al 50 (simulados, sin FK).
   Se usa sys.all_objects para garantizar filas suficientes en el
   producto cartesiano. Puede tardar unos segundos.
   --------------------------------------------------------------------- */
SET NOCOUNT ON;
GO

WITH Numeros AS
(
    SELECT TOP (1000000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.venta_historica (fecha_venta, importe, id_usuario)
SELECT
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1826, '2020-01-01'),
    CAST(1 + (ABS(CHECKSUM(NEWID())) % 999900) / 100.0 AS DECIMAL(12,2)),
    1 + ABS(CHECKSUM(NEWID())) % 50
FROM Numeros;
GO

-- Verificar la cantidad de registros (debe ser 1.000.000)
SELECT COUNT(*) AS CantidadRegistros
FROM dbo.venta_historica;
GO

/* ---------------------------------------------------------------------
   PARTE 3. CONSULTA SIN ÍNDICES  (escenario 1)
   Consulta típica del negocio: ventas de un período.
   Se limpia la caché para medir lecturas reales de disco
   (CHECKPOINT y DBCC DROPCLEANBUFFERS requieren permisos de
   administrador; usar solo en un servidor de pruebas).
   Esperado en el plan: Table Scan (la tabla es un heap).
   --------------------------------------------------------------------- */
PRINT '--- PARTE 3: SIN ÍNDICES ---';
CHECKPOINT;
DBCC DROPCLEANBUFFERS;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT id_venta, fecha_venta, importe
FROM dbo.venta_historica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

/* Registrar (Mensajes + plan de ejecución):
   Tiempo de CPU: ____ ms | Tiempo total: ____ ms
   Lecturas lógicas: ____ | Operación principal: Table Scan  */

/* ---------------------------------------------------------------------
   PARTE 4. ÍNDICE AGRUPADO SOBRE LA FECHA  (escenario 2)
   El índice agrupado ordena físicamente la tabla por fecha_venta, de
   modo que un rango de fechas se lee como un bloque contiguo.
   Esperado en el plan: Clustered Index Seek.
   --------------------------------------------------------------------- */
PRINT '--- PARTE 4: ÍNDICE AGRUPADO SOBRE LA FECHA ---';
CREATE CLUSTERED INDEX IX_venta_historica_fecha
ON dbo.venta_historica (fecha_venta);
GO

CHECKPOINT;
DBCC DROPCLEANBUFFERS;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT id_venta, fecha_venta, importe
FROM dbo.venta_historica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

/* Registrar: CPU ____ ms | Total ____ ms | Lecturas lógicas ____
   Operación principal: Clustered Index Seek  */

/* ---------------------------------------------------------------------
   PARTE 5. ELIMINAR EL ÍNDICE AGRUPADO
   Se elimina para probar el siguiente escenario en igualdad de
   condiciones (la tabla vuelve a ser un heap).
   --------------------------------------------------------------------- */
DROP INDEX IF EXISTS IX_venta_historica_fecha
ON dbo.venta_historica;
GO

/* ---------------------------------------------------------------------
   PARTE 6. ÍNDICE NO AGRUPADO QUE CUBRE LA CONSULTA  (escenario 3)
   Contiene la columna de filtro (fecha_venta) y, como columna
   incluida, la que se devuelve (importe): el motor resuelve la consulta
   leyendo solo el índice, sin tocar la tabla. Por eso esta consulta no
   pide id_venta: al no estar en el índice, obligaría a un Lookup a la
   tabla por cada fila.
   Esperado en el plan: Index Seek (sin Key/RID Lookup).
   --------------------------------------------------------------------- */
PRINT '--- PARTE 6: ÍNDICE CON COBERTURA ---';
CREATE NONCLUSTERED INDEX IX_venta_historica_fecha_cobertura
ON dbo.venta_historica (fecha_venta)
INCLUDE (importe);
GO

CHECKPOINT;
DBCC DROPCLEANBUFFERS;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT fecha_venta, importe
FROM dbo.venta_historica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

/* Registrar: CPU ____ ms | Total ____ ms | Lecturas lógicas ____
   Operación principal: Index Seek  */

/* ---------------------------------------------------------------------
   PARTE 7. COSTO DE MANTENER UN ÍNDICE (impacto en INSERT)
   Los índices aceleran las lecturas, pero cada INSERT, UPDATE o DELETE
   también debe actualizarlos. Se insertan 100.000 filas con el índice
   de cobertura presente y luego sin él. Ambas inserciones se
   revierten con ROLLBACK para no alterar la cantidad de filas; al
   terminar, el índice se vuelve a crear.
   --------------------------------------------------------------------- */
PRINT '--- PARTE 7: COSTO DE MANTENIMIENTO DEL ÍNDICE ---';
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- 7.a) INSERT de 100.000 filas CON el índice de cobertura
PRINT '7.a) Inserción CON índice';
BEGIN TRANSACTION;
    INSERT INTO dbo.venta_historica (fecha_venta, importe, id_usuario)
    SELECT TOP (100000)
           DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1826, '2020-01-01'),
           CAST(1 + (ABS(CHECKSUM(NEWID())) % 999900) / 100.0 AS DECIMAL(12,2)),
           1 + ABS(CHECKSUM(NEWID())) % 50
    FROM sys.all_objects a CROSS JOIN sys.all_objects b;
ROLLBACK TRANSACTION;
GO

DROP INDEX IF EXISTS IX_venta_historica_fecha_cobertura
ON dbo.venta_historica;
GO

-- 7.b) INSERT de 100.000 filas SIN índices
PRINT '7.b) Inserción SIN índice';
BEGIN TRANSACTION;
    INSERT INTO dbo.venta_historica (fecha_venta, importe, id_usuario)
    SELECT TOP (100000)
           DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1826, '2020-01-01'),
           CAST(1 + (ABS(CHECKSUM(NEWID())) % 999900) / 100.0 AS DECIMAL(12,2)),
           1 + ABS(CHECKSUM(NEWID())) % 50
    FROM sys.all_objects a CROSS JOIN sys.all_objects b;
ROLLBACK TRANSACTION;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- Se restablece el índice de cobertura
CREATE NONCLUSTERED INDEX IX_venta_historica_fecha_cobertura
ON dbo.venta_historica (fecha_venta)
INCLUDE (importe);
GO

/* Registrar: la inserción con índice debería usar más lecturas/escrituras
   lógicas y más tiempo que sin índice. Ese es el precio de la mejora en
   consultas. */

/* ---------------------------------------------------------------------
   PARTE 8. ESPACIO OCUPADO Y TABLA COMPARATIVA
   Los índices también consumen espacio en disco.
   --------------------------------------------------------------------- */
PRINT '--- PARTE 8: ESPACIO OCUPADO POR LA TABLA Y SUS ÍNDICES ---';
SELECT ISNULL(i.name, '(tabla sin índice agrupado - heap)') AS estructura,
       i.type_desc                                         AS tipo,
       CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(10,2)) AS espacio_mb
FROM sys.indexes AS i
JOIN sys.dm_db_partition_stats AS ps
     ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.object_id = OBJECT_ID('dbo.venta_historica')
GROUP BY i.name, i.type_desc
ORDER BY i.type_desc;
GO

/* Tabla comparativa (completar con los valores medidos):

   | Escenario           | CPU (ms) | Tiempo total (ms) | Lecturas lógicas | Operación principal   |
   | ------------------- | -------- | ----------------- | ---------------- | --------------------- |
   | Sin índice          |    XX    |        XX         |        XX        | Table Scan            |
   | Índice agrupado     |    XX    |        XX         |        XX        | Clustered Index Seek  |
   | Índice con cobertura|    XX    |        XX         |        XX        | Index Seek            |

   Resultado esperado: sin índice se recorre toda la tabla; el índice
   sobre la fecha reduce el trabajo de forma significativa; el índice con
   cobertura reduce aún más las lecturas porque no accede a la tabla; el
   plan pasa de un escaneo completo a búsquedas eficientes. */

/* ---------------------------------------------------------------------
   PARTE 9. ÍNDICES PERMANENTES PARA LAS TABLAS REALES DE RETROGAMES
   Criterios aplicados:
   - SQL Server NO crea índices automáticamente sobre las claves
     foráneas. Cada FK sin índice vuelve lentos los JOIN y las
     verificaciones de integridad (por ejemplo, el borrado rechazado de
     un producto con ventas o el DELETE en cascada del detalle).
   - Ya existen índices por las claves primarias y por las restricciones
     UNIQUE (categoria.nombre, metodo_pago.nombre, usuario.email,
     pago.id_venta_cabecera), por lo que no se duplican.
   - Se usan columnas INCLUDE para cubrir las consultas más frecuentes,
     evitando lecturas a la tabla.
   - Se evitan índices sobre columnas de poca selectividad (BIT como
     activo o stock_bajo) y filtrados, que exigen opciones SET
     específicas en cada sesión que ejecute DML.
   - Costo de escritura: cada venta (sp_RegistrarVentaTransaccional)
     inserta en 3 tablas y actualiza productos. Se limitó la cantidad de
     índices y de columnas incluidas a las necesarias. La Parte 7 permite
     medir el costo de escritura de un índice.
   El script es repetible: elimina cada índice si existe antes de crearlo.
   --------------------------------------------------------------------- */
PRINT '--- PARTE 9: ÍNDICES PERMANENTES ---';

-- 9.1 venta_cabecera ---------------------------------------------------
-- Reportes de ventas por período (el caso del experimento) y tableros.
DROP INDEX IF EXISTS IX_venta_cabecera_fecha ON dbo.venta_cabecera;
CREATE NONCLUSTERED INDEX IX_venta_cabecera_fecha
ON dbo.venta_cabecera (fecha_venta)
INCLUDE (estado, total, id_usuario);

-- Historial de compras de un cliente (FK a usuario).
DROP INDEX IF EXISTS IX_venta_cabecera_usuario ON dbo.venta_cabecera;
CREATE NONCLUSTERED INDEX IX_venta_cabecera_usuario
ON dbo.venta_cabecera (id_usuario, fecha_venta)
INCLUDE (estado, total);

-- FK a direccion: verificaciones de integridad y búsquedas por dirección.
DROP INDEX IF EXISTS IX_venta_cabecera_direccion ON dbo.venta_cabecera;
CREATE NONCLUSTERED INDEX IX_venta_cabecera_direccion
ON dbo.venta_cabecera (id_direccion);

-- 9.2 venta_detalle ----------------------------------------------------
-- Ítems de una venta (JOIN con cabecera) y DELETE en cascada.
DROP INDEX IF EXISTS IX_venta_detalle_cabecera ON dbo.venta_detalle;
CREATE NONCLUSTERED INDEX IX_venta_detalle_cabecera
ON dbo.venta_detalle (id_venta_cabecera)
INCLUDE (id_productos, cantidad, precio_unitario, subtotal);

-- Ventas por producto y control del borrado de productos vendidos (FK).
DROP INDEX IF EXISTS IX_venta_detalle_productos ON dbo.venta_detalle;
CREATE NONCLUSTERED INDEX IX_venta_detalle_productos
ON dbo.venta_detalle (id_productos)
INCLUDE (cantidad, subtotal);

-- 9.3 pago -------------------------------------------------------------
-- Pagos por método (FK a metodo_pago) y reportes de recaudación.
DROP INDEX IF EXISTS IX_pago_metodo_pago ON dbo.pago;
CREATE NONCLUSTERED INDEX IX_pago_metodo_pago
ON dbo.pago (id_metodo_pago)
INCLUDE (fecha_pago, monto);

-- 9.4 productos --------------------------------------------------------
-- Catálogo por categoría (FK a categoria): listados de la tienda.
DROP INDEX IF EXISTS IX_productos_categoria ON dbo.productos;
CREATE NONCLUSTERED INDEX IX_productos_categoria
ON dbo.productos (id_categoria)
INCLUDE (nombre, precio, stock, activo);

-- Búsqueda de productos por nombre (LIKE 'texto%' usa el índice;
-- LIKE '%texto%' no, porque no conoce el comienzo).
DROP INDEX IF EXISTS IX_productos_nombre ON dbo.productos;
CREATE NONCLUSTERED INDEX IX_productos_nombre
ON dbo.productos (nombre);

-- 9.5 usuario ----------------------------------------------------------
-- FK a direccion (el email ya tiene índice por su restricción UNIQUE).
DROP INDEX IF EXISTS IX_usuario_direccion ON dbo.usuario;
CREATE NONCLUSTERED INDEX IX_usuario_direccion
ON dbo.usuario (id_direccion);

-- 9.6 auditoria_producto (solo si se instaló el script de triggers) ----
-- Consultas de auditoría: historial de un producto ordenado por fecha.
-- La tabla guarda los valores ANTERIORES del registro (columnas precio,
-- stock, etc.) y la fecha en fecha_hora, según el script de triggers.
-- Se usa SQL dinámico porque la tabla puede no existir.
-- Nota: el script de triggers recrea la tabla (DROP TABLE), lo que elimina
-- este índice; si se vuelve a ejecutar, repetir esta sección 9.6.
IF OBJECT_ID('dbo.auditoria_producto', 'U') IS NOT NULL
BEGIN
    EXEC (N'DROP INDEX IF EXISTS IX_auditoria_producto_producto ON dbo.auditoria_producto;');
    EXEC (N'CREATE NONCLUSTERED INDEX IX_auditoria_producto_producto
            ON dbo.auditoria_producto (id_productos, fecha_hora)
            INCLUDE (operacion, precio, stock);');
END
ELSE
    PRINT 'Aviso: dbo.auditoria_producto no existe; se omite su índice (ejecutar antes el script de triggers).';
GO

/* ---------------------------------------------------------------------
   PARTE 10. VERIFICACIÓN Y LIMPIEZA
   --------------------------------------------------------------------- */

-- 10.1 Índices creados y espacio que ocupan
PRINT '--- ÍNDICES PERMANENTES CREADOS ---';
SELECT OBJECT_NAME(i.object_id) AS tabla,
       i.name                   AS indice,
       i.type_desc              AS tipo,
       CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(10,3)) AS espacio_mb
FROM sys.indexes AS i
JOIN sys.dm_db_partition_stats AS ps
     ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.name LIKE 'IX[_]%'
  AND OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND OBJECT_NAME(i.object_id) <> 'venta_historica'
GROUP BY i.object_id, i.name, i.type_desc
ORDER BY tabla, indice;

-- 10.2 Prueba rápida de las tablas reales (con pocos datos el optimizador
--      puede preferir un escaneo: el beneficio crece con el volumen).
--      Verlo con el plan de ejecución (Ctrl + M).
PRINT '--- VENTAS DE UN CLIENTE EN UN PERÍODO ---';
SELECT vc.id_venta_cabecera, vc.fecha_venta, vc.estado, vc.total
FROM dbo.venta_cabecera AS vc
WHERE vc.id_usuario = 1
  AND vc.fecha_venta >= '2020-01-01';
GO

-- 10.3 Limpieza: elimina la tabla de pruebas de 1.000.000 de filas.
--      Se deja comentada para poder conservar las capturas y repetir
--      el experimento. Descomentar para liberar el espacio.
-- DROP TABLE IF EXISTS dbo.venta_historica;
-- GO

/* ---------------------------------------------------------------------
   Resultado esperado
   - Parte 3: Table Scan, lecturas lógicas altas (toda la tabla).
   - Parte 4: Clustered Index Seek, lecturas muy inferiores.
   - Parte 6: Index Seek sobre IX_venta_historica_fecha_cobertura, sin
              acceso a la tabla; las lecturas lógicas más bajas de las tres.
   - Parte 7: la inserción con índice cuesta más que sin índice.
   - Parte 8: el índice con cobertura ocupa espacio adicional respecto
              de la tabla sola.
   - Parte 9: se crean 9 índices en las tablas reales (10 si existe
              dbo.auditoria_producto).
   --------------------------------------------------------------------- */
