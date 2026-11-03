/* =====================================================================
   RETRO GAMES - Etapa V: Triggers (auditoría y control de operaciones)
   SQL Server / Transact-SQL (requiere SQL Server 2016 SP1 o superior)
   Requisito: haber ejecutado crear_bd.sql y datos_prueba.sql

   Qué implementa este script:
   1) Auditoría de UPDATE y DELETE sobre dbo.productos: antes de cada
      modificación o borrado se guarda en dbo.auditoria_producto el
      registro completo con sus valores ANTERIORES, más la fecha, la
      hora y el usuario de la base de datos que hizo la operación.
        - trg_productos_auditoria_update  (AFTER UPDATE)
        - trg_productos_auditoria_delete  (AFTER DELETE)
   2) Bloqueo de DELETE sobre dbo.pago: los pagos son registros
      contables y no pueden eliminarse. El trigger
      trg_pago_bloquear_delete (INSTEAD OF DELETE) emite un mensaje de
      error y no permite la operación.

   ATENCIÓN:
   - La sección 1 recrea la tabla de auditoría (borra su contenido).
   - Las pruebas modifican datos; para restaurarlos, ejecutar
     crear_bd.sql y luego datos_prueba.sql.
   - Con el bloqueo instalado, datos_prueba.sql por sí solo falla en su
     primer DELETE FROM dbo.pago. Para recargar datos sin recrear las
     tablas: DISABLE TRIGGER dbo.trg_pago_bloquear_delete ON dbo.pago;
     y después ENABLE TRIGGER dbo.trg_pago_bloquear_delete ON dbo.pago;
   ===================================================================== */

USE RetroGames;
GO

/* ---------------------------------------------------------------------
   1. TABLA DE AUDITORÍA: dbo.auditoria_producto
   Copia todas las columnas de dbo.productos con los valores que tenía
   el registro ANTES del cambio. Sin FK hacia productos a propósito: así
   el historial de un producto eliminado se conserva.
   --------------------------------------------------------------------- */
DROP TRIGGER IF EXISTS dbo.trg_productos_auditoria;           -- versión anterior
DROP TRIGGER IF EXISTS dbo.trg_productos_auditoria_update;
DROP TRIGGER IF EXISTS dbo.trg_productos_auditoria_delete;
DROP TRIGGER IF EXISTS dbo.trg_pago_bloquear_delete;
DROP TABLE IF EXISTS dbo.auditoria_producto;
GO

CREATE TABLE dbo.auditoria_producto (
    id_auditoria          INT IDENTITY(1,1) NOT NULL,
    operacion             VARCHAR(10)       NOT NULL,   -- UPDATE / DELETE
    fecha_hora            DATETIME          NOT NULL    -- fecha y hora de la operación
        CONSTRAINT DF_auditoria_producto_fecha DEFAULT GETDATE(),
    usuario_login         SYSNAME           NOT NULL    -- login de SQL Server
        CONSTRAINT DF_auditoria_producto_login DEFAULT SUSER_SNAME(),
    usuario_bd            SYSNAME           NOT NULL    -- usuario de la base de datos
        CONSTRAINT DF_auditoria_producto_usuario DEFAULT USER_NAME(),

    -- Valores del registro ANTES de la modificación o el borrado
    id_productos          INT               NOT NULL,
    nombre                VARCHAR(150)      NOT NULL,
    descripcion           VARCHAR(500)      NULL,
    precio_original       DECIMAL(10,2)     NULL,
    precio                DECIMAL(10,2)     NOT NULL,
    porcentaje_descuento  DECIMAL(5,2)      NULL,
    stock                 INT               NULL,
    stock_minimo          INT               NOT NULL,
    stock_bajo            BIT               NULL,
    marca                 VARCHAR(100)      NULL,
    consola               VARCHAR(100)      NULL,
    tipo_producto         VARCHAR(100)      NULL,
    estado_conservacion   VARCHAR(20)       NOT NULL,
    activo                BIT               NULL,
    id_categoria          INT               NOT NULL,

    CONSTRAINT PK_auditoria_producto PRIMARY KEY (id_auditoria),
    CONSTRAINT CK_auditoria_producto_operacion
        CHECK (operacion IN ('UPDATE', 'DELETE'))
);
GO

/* ---------------------------------------------------------------------
   2. TRIGGER DE AUDITORÍA PARA UPDATE
   Se ejecuta después de cada UPDATE sobre dbo.productos. La tabla
   virtual "deleted" contiene las filas con sus valores anteriores a la
   modificación. Funciona por conjuntos: una sentencia que modifica
   varios productos genera una fila de auditoría por cada uno.
   Audita cualquier modificación, sin importar qué columna cambió.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_productos_auditoria_update
ON dbo.productos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.auditoria_producto
        (operacion, id_productos, nombre, descripcion, precio_original, precio,
         porcentaje_descuento, stock, stock_minimo, stock_bajo, marca, consola,
         tipo_producto, estado_conservacion, activo, id_categoria)
    SELECT
        'UPDATE', d.id_productos, d.nombre, d.descripcion, d.precio_original, d.precio,
        d.porcentaje_descuento, d.stock, d.stock_minimo, d.stock_bajo, d.marca, d.consola,
        d.tipo_producto, d.estado_conservacion, d.activo, d.id_categoria
    FROM deleted AS d;
END;
GO

/* ---------------------------------------------------------------------
   3. TRIGGER DE AUDITORÍA PARA DELETE
   Se ejecuta después de cada DELETE sobre dbo.productos y guarda el
   registro eliminado completo. Solo se dispara si el borrado se
   concreta: si lo rechaza una FK (producto con ventas), no hay registro.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_productos_auditoria_delete
ON dbo.productos
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.auditoria_producto
        (operacion, id_productos, nombre, descripcion, precio_original, precio,
         porcentaje_descuento, stock, stock_minimo, stock_bajo, marca, consola,
         tipo_producto, estado_conservacion, activo, id_categoria)
    SELECT
        'DELETE', d.id_productos, d.nombre, d.descripcion, d.precio_original, d.precio,
        d.porcentaje_descuento, d.stock, d.stock_minimo, d.stock_bajo, d.marca, d.consola,
        d.tipo_producto, d.estado_conservacion, d.activo, d.id_categoria
    FROM deleted AS d;
END;
GO

/* ---------------------------------------------------------------------
   4. TRIGGER QUE BLOQUEA EL DELETE SOBRE dbo.pago
   Los pagos son registros contables. Ninguna FK impide borrar una fila
   de pago (pago es la tabla hija), por eso se bloquea con un trigger.
   INSTEAD OF DELETE reemplaza la operación: el borrado nunca se ejecuta
   y THROW emite el mensaje de error. Si el DELETE no alcanza ninguna
   fila, no se dispara el mensaje.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_pago_bloquear_delete
ON dbo.pago
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50010, 'Operación no permitida: los pagos son registros contables y no pueden eliminarse.', 1;
END;
GO

/* ---------------------------------------------------------------------
   5. DEMOSTRACIÓN Y PRUEBAS
   --------------------------------------------------------------------- */

-- PRUEBA 0: los 3 triggers están instalados y habilitados
PRINT '--- PRUEBA 0: VERIFICAR INSTALACIÓN ---';
SELECT t.name AS trigger_nombre,
       OBJECT_NAME(t.parent_id) AS tabla,
       t.is_instead_of_trigger  AS instead_of,
       t.is_disabled            AS deshabilitado
FROM sys.triggers AS t
WHERE t.parent_id IN (OBJECT_ID('dbo.productos'), OBJECT_ID('dbo.pago'))
ORDER BY tabla, trigger_nombre;

SELECT COUNT(*) AS filas_de_auditoria FROM dbo.auditoria_producto;
GO

/* ===================== A. AUDITORÍA DE UPDATE ===================== */

-- PRUEBA 1: modificación de precio
-- Producto 4 (Control Inalámbrico Retro): 25.000 -> 28.000
-- Se actualiza también precio_original para mantener coherente el descuento (0%).
-- La auditoría debe guardar los valores ANTERIORES (precio 25.000, stock 20, etc.).
PRINT '--- PRUEBA 1: UPDATE DE PRECIO ---';
UPDATE dbo.productos
SET precio = 28000.00,
    precio_original = 28000.00
WHERE id_productos = 4;

SELECT id_auditoria, operacion, fecha_hora, usuario_login, usuario_bd,
       id_productos, nombre, precio_original, precio, stock, activo
FROM dbo.auditoria_producto
WHERE id_productos = 4;
GO

-- PRUEBA 2: modificación de otro dato (reposición de stock)
-- Producto 3 (Sega Dreamcast): stock 3 -> 5. La auditoría guarda el stock anterior (3).
PRINT '--- PRUEBA 2: UPDATE DE STOCK ---';
UPDATE dbo.productos
SET stock = stock + 2
WHERE id_productos = 3;

SELECT id_auditoria, operacion, fecha_hora, usuario_login, usuario_bd,
       id_productos, nombre, precio, stock, stock_minimo
FROM dbo.auditoria_producto
WHERE id_productos = 3;
GO

-- PRUEBA 3: modificación masiva (una sentencia, varias filas)
-- Aumento del 10% a la categoría 1 (Videojuegos: productos 1 y 2).
-- Debe registrarse una fila de auditoría por cada producto afectado.
PRINT '--- PRUEBA 3: UPDATE MASIVO (+10% CATEGORÍA 1) ---';
UPDATE dbo.productos
SET precio = ROUND(precio * 1.10, 2),
    precio_original = ROUND(precio_original * 1.10, 2)
WHERE id_categoria = 1;

SELECT id_auditoria, operacion, id_productos, nombre, precio_original, precio
FROM dbo.auditoria_producto
WHERE id_productos IN (1, 2)
ORDER BY id_auditoria;
GO

-- PRUEBA 4: cualquier dato se audita (aquí, solo la descripción)
-- La cantidad de filas de auditoría debe aumentar en 1.
PRINT '--- PRUEBA 4: UPDATE DE UNA COLUMNA CUALQUIERA (DESCRIPCIÓN) ---';
DECLARE @antes INT = (SELECT COUNT(*) FROM dbo.auditoria_producto);

UPDATE dbo.productos
SET descripcion = 'Cartucho original SNES en excelente estado (revisado).'
WHERE id_productos = 1;

SELECT @antes AS auditoria_antes,
       (SELECT COUNT(*) FROM dbo.auditoria_producto) AS auditoria_despues;

-- La fila nueva conserva la descripción anterior y el precio previo a este cambio
SELECT TOP (1) id_auditoria, operacion, id_productos, descripcion, precio
FROM dbo.auditoria_producto
WHERE id_productos = 1
ORDER BY id_auditoria DESC;
GO

/* ===================== B. AUDITORÍA DE DELETE ===================== */

-- PRUEBA 5: eliminación de un producto sin ventas
-- Se crea un producto temporal (el INSERT no se audita) y se elimina.
-- La auditoría debe guardar el registro completo que fue eliminado.
PRINT '--- PRUEBA 5: DELETE DE UN PRODUCTO SIN VENTAS ---';
DECLARE @antes INT = (SELECT COUNT(*) FROM dbo.auditoria_producto);

INSERT INTO dbo.productos
    (nombre, descripcion, precio_original, precio, porcentaje_descuento,
     stock, stock_minimo, stock_bajo, marca, consola, tipo_producto,
     estado_conservacion, activo, id_categoria)
VALUES
    ('PRUEBA - Producto temporal', 'Producto creado solo para probar la auditoría.',
     120000.00, 120000.00, 0.00, 5, 2, 0, 'Nintendo', 'SNES', 'Consola',
     'NUEVO', 1, 2);

SELECT @antes AS auditoria_antes_del_insert,
       (SELECT COUNT(*) FROM dbo.auditoria_producto) AS auditoria_despues_del_insert;  -- igual: el INSERT no se audita

DELETE FROM dbo.productos
WHERE nombre = 'PRUEBA - Producto temporal';

SELECT id_auditoria, operacion, fecha_hora, usuario_login, usuario_bd,
       id_productos, nombre, precio, stock, marca, consola, id_categoria
FROM dbo.auditoria_producto
WHERE nombre = 'PRUEBA - Producto temporal';
GO

-- PRUEBA 6: eliminación rechazada por integridad referencial
-- El producto 1 tiene ventas (FK_venta_detalle_productos, NO ACTION):
-- el borrado falla y la auditoría no registra nada.
PRINT '--- PRUEBA 6: DELETE RECHAZADO (PRODUCTO CON VENTAS) ---';
DECLARE @antes INT = (SELECT COUNT(*) FROM dbo.auditoria_producto);

BEGIN TRY
    DELETE FROM dbo.productos WHERE id_productos = 1;
    PRINT 'ERROR: el borrado no debería haberse permitido.';
END TRY
BEGIN CATCH
    PRINT 'Borrado rechazado: ' + ERROR_MESSAGE();
END CATCH;

SELECT @antes AS auditoria_antes,
       (SELECT COUNT(*) FROM dbo.auditoria_producto) AS auditoria_despues;
GO

/* ============== C. BLOQUEO DE DELETE SOBRE dbo.pago ============== */

-- PRUEBA 7: intento de eliminar un pago puntual
-- Debe emitir el mensaje del trigger y el pago debe seguir existiendo.
PRINT '--- PRUEBA 7: DELETE DE UN PAGO ---';
BEGIN TRY
    DELETE FROM dbo.pago WHERE id_pago = 1;
    PRINT 'ERROR: el borrado no debería haberse permitido.';
END TRY
BEGIN CATCH
    PRINT 'Operación rechazada por el trigger: ' + ERROR_MESSAGE();
END CATCH;

SELECT COUNT(*) AS pagos_registrados,                 -- debe seguir en 8
       (SELECT COUNT(*) FROM dbo.pago WHERE id_pago = 1) AS pago_1_existe
FROM dbo.pago;
GO

-- PRUEBA 8: intento de vaciar la tabla (DELETE sin WHERE)
PRINT '--- PRUEBA 8: DELETE MASIVO SOBRE PAGO ---';
BEGIN TRY
    DELETE FROM dbo.pago;
    PRINT 'ERROR: el borrado no debería haberse permitido.';
END TRY
BEGIN CATCH
    PRINT 'Operación rechazada por el trigger: ' + ERROR_MESSAGE();
END CATCH;

SELECT COUNT(*) AS pagos_registrados FROM dbo.pago;   -- debe seguir en 8
GO

/* ---------------------------------------------------------------------
   6. CONSULTAS DE AUDITORÍA
   --------------------------------------------------------------------- */

-- 6.1 Historial completo de auditoría (valores anteriores)
PRINT '--- HISTORIAL COMPLETO DE AUDITORÍA ---';
SELECT id_auditoria, operacion, fecha_hora, usuario_login, usuario_bd,
       id_productos, nombre, precio_original, precio, stock, activo
FROM dbo.auditoria_producto
ORDER BY id_auditoria;

-- 6.2 ¿Qué valor tenía antes cada producto modificado y quién lo modificó?
PRINT '--- VALORES ANTERIORES DE LOS PRODUCTOS MODIFICADOS ---';
SELECT id_productos, nombre, precio AS precio_anterior, stock AS stock_anterior,
       fecha_hora, usuario_login, usuario_bd
FROM dbo.auditoria_producto
WHERE operacion = 'UPDATE'
ORDER BY id_productos, fecha_hora, id_auditoria;

-- 6.3 ¿Cuándo se eliminó un producto y con qué datos?
PRINT '--- PRODUCTOS ELIMINADOS ---';
SELECT id_productos, nombre, precio, stock, fecha_hora, usuario_login, usuario_bd
FROM dbo.auditoria_producto
WHERE operacion = 'DELETE';
GO

/* ---------------------------------------------------------------------
   Resultado esperado (partiendo de datos_prueba.sql recién cargado)
   Auditoría total: 6 filas, con los valores ANTERIORES al cambio
     UPDATE  producto 4   precio 25000,00, precio_original 25000,00, stock 20
     UPDATE  producto 3   stock 3 (precio 160000,00)
     UPDATE  producto 1   precio 40000,00, precio_original 45000,00   (prueba 3)
     UPDATE  producto 2   precio 30000,00, precio_original 30000,00   (prueba 3)
     UPDATE  producto 1   precio 44000,00, descripción anterior       (prueba 4)
     DELETE  producto temporal   precio 120000,00, stock 5            (prueba 5)
   El INSERT del producto temporal (prueba 5) y el DELETE rechazado por
   la FK (prueba 6) no agregan filas.
   Pruebas 7 y 8: el mensaje "Operación no permitida: los pagos son
   registros contables y no pueden eliminarse." y pagos_registrados = 8.
   --------------------------------------------------------------------- */
