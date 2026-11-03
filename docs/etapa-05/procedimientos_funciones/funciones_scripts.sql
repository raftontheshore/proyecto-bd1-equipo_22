/* =====================================================================
   RETRO GAMES - Etapa V: Procedimientos y Funciones Almacenadas
   Archivo: procedimientos_funciones/scripts.sql
   ===================================================================== */

USE RetroGames;
GO

/* ---------------------------------------------------------------------
   1. CREACIÓN DE FUNCIONES ALMACENADAS
   --------------------------------------------------------------------- */

-- Función 1: fn_StockDisponible
-- Propósito: Retornar el stock actual de un producto para facilitar validaciones.
CREATE OR ALTER FUNCTION dbo.fn_StockDisponible (@id_producto INT)
RETURNS INT
AS 
BEGIN
    DECLARE @stock_actual INT;
    
    SELECT @stock_actual = stock
    FROM dbo.productos
    WHERE id_productos = @id_producto;
    
    RETURN ISNULL(@stock_actual, 0);
END;
GO


-- Función 2: fn_CalcularSubtotal
-- Propósito: Retornar el subtotal calculado.
CREATE OR ALTER FUNCTION dbo.fn_CalcularSubtotal (@cantidad INT, @precio_unitario DECIMAL(10,2))
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN @cantidad * @precio_unitario;
END;
GO

/* ---------------------------------------------------------------------
   2. CREACIÓN DE PROCEDIMIENTOS CRUD (Catálogo)
   --------------------------------------------------------------------- */

-- A. Procedimiento para Insertar
CREATE OR ALTER PROCEDURE dbo.sp_InsertarProducto
    @nombre VARCHAR(150),
    @precio DECIMAL(10,2),
    @stock INT,
    @stock_minimo INT,
    @estado_conservacion VARCHAR(20),
    @id_categoria INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.productos (nombre, precio, stock, stock_minimo, estado_conservacion, id_categoria)
    VALUES (@nombre, @precio, @stock, @stock_minimo, @estado_conservacion, @id_categoria);
END;
GO

-- B. Procedimiento para Modificar
CREATE OR ALTER PROCEDURE dbo.sp_ActualizarPrecioProducto
    @id_producto INT,
    @nuevo_precio DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.productos
    SET precio = @nuevo_precio
    WHERE id_productos = @id_producto;
END;
GO

-- C. Procedimiento para Borrar (Baja lógica)
CREATE OR ALTER PROCEDURE dbo.sp_EliminarProductoLogico
    @id_producto INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.productos
    SET activo = 0
    WHERE id_productos = @id_producto;
END;
GO

/* ---------------------------------------------------------------------
   3. CREACIÓN DE PROCEDIMIENTO DE NEGOCIO (Ventas)
   Propósito: Agrega un ítem al detalle de una venta, valida cantidades
   y stock mediante funciones, y actualiza el total de la cabecera.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_AgregarDetalleVenta
    @id_venta_cabecera INT,
    @id_producto INT,
    @cantidad INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables para cálculos
    DECLARE @precio_vigente DECIMAL(10,2);
    DECLARE @subtotal DECIMAL(12,2);

    -- RN-01: Validar que la cantidad sea positiva
    IF @cantidad <= 0
    BEGIN
        ;THROW 50001, 'Error: La cantidad del ítem debe ser mayor a cero.', 1;
    END

    -- Validar existencias mediante la función
    IF dbo.fn_StockDisponible(@id_producto) < @cantidad
    BEGIN
        ;THROW 50002, 'Error: Stock insuficiente para agregar el producto.', 1;
    END

    -- RN-09: Obtener el precio vigente actual del producto
    SELECT @precio_vigente = precio 
    FROM dbo.productos 
    WHERE id_productos = @id_producto;

    -- Calcular el subtotal usando la función
    SET @subtotal = dbo.fn_CalcularSubtotal(@cantidad, @precio_vigente);

    -- Insertar el detalle de venta
    INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
    VALUES (@cantidad, @precio_vigente, @subtotal, @id_producto, @id_venta_cabecera);

    -- RN-01: Actualizar el total de la cabecera (suma de subtotales)
    UPDATE dbo.venta_cabecera
    SET total = total + @subtotal
    WHERE id_venta_cabecera = @id_venta_cabecera;
    
    PRINT 'Ítem agregado con éxito al detalle de la venta.';
END;
GO

/* ---------------------------------------------------------------------
   4. PRUEBAS Y DEMOSTRACIÓN
   --------------------------------------------------------------------- */

-- ==========================================
-- BLOQUE A: Pruebas CRUD de Catálogo
-- ==========================================

PRINT '--- PRUEBA A1: Lote de inserción directa ---';

SELECT id_productos, nombre, precio, stock FROM dbo.productos;
GO

INSERT INTO dbo.productos (nombre, precio, stock, stock_minimo, estado_conservacion, id_categoria)
VALUES ('Nintendo 64 Usada', 120000.00, 12, 2, 'USADO', 1);

INSERT INTO dbo.productos (nombre, precio, stock, stock_minimo, estado_conservacion, id_categoria)
VALUES ('Super Mario 64', 45000.00, 21, 3, 'USADO', 2);
GO

SELECT id_productos, nombre, precio, stock FROM dbo.productos;
GO

PRINT '--- PRUEBA A2: Lote invocando procedimientos creados ---';

SELECT id_productos, nombre, precio, stock FROM dbo.productos;
GO

EXEC dbo.sp_InsertarProducto @nombre = 'Sega Genesis Boxed', @precio = 180000.00, @stock = 10, @stock_minimo = 1, @estado_conservacion = 'EN_CAJA', @id_categoria = 1;
EXEC dbo.sp_InsertarProducto @nombre = 'Sonic The Hedgehog', @precio = 30000.00, @stock = 15, @stock_minimo = 5, @estado_conservacion = 'USADO', @id_categoria = 2;
GO

SELECT id_productos, nombre, precio, stock FROM dbo.productos;
GO

PRINT '--- PRUEBA A3: Actualizar y Eliminar (Baja Lógica) ---';

SELECT id_productos, nombre, precio, activo FROM dbo.productos;
GO

DECLARE @id_genesis INT = (SELECT TOP 1 id_productos FROM dbo.productos
                           WHERE nombre = 'Sega Genesis Boxed' ORDER BY id_productos DESC);
DECLARE @id_sonic   INT = (SELECT TOP 1 id_productos FROM dbo.productos
                           WHERE nombre = 'Sonic The Hedgehog' ORDER BY id_productos DESC);

EXEC dbo.sp_ActualizarPrecioProducto @id_producto = @id_genesis, @nuevo_precio = 185000.00;
EXEC dbo.sp_EliminarProductoLogico   @id_producto = @id_sonic;

-- Verificación
SELECT id_productos, nombre, precio, activo
FROM dbo.productos
WHERE id_productos IN (@id_genesis, @id_sonic);
GO

-- ==========================================
-- BLOQUE B: Pruebas del Procedimiento de Negocio
-- ==========================================

PRINT '--- PREPARACIÓN: Creando Venta Pendiente ---';
-- Se crea una venta en estado PENDIENTE (RN-12)
INSERT INTO dbo.venta_cabecera (fecha_venta, estado, total, id_usuario, id_direccion)
VALUES (GETDATE(), 'PENDIENTE', 0.00, 1, 1);

DECLARE @id_venta_prueba INT = SCOPE_IDENTITY();

-- CASO DE PRUEBA B1: Ejecución exitosa
PRINT '--- INICIANDO PRUEBA B1: AGREGAR ÍTEM VÁLIDO ---';
EXEC dbo.sp_AgregarDetalleVenta 
    @id_venta_cabecera = @id_venta_prueba, 
    @id_producto = 1, 
    @cantidad = 2;
GO

-- CASO DE PRUEBA B2: Ejecución fallida (RN-01)
PRINT '--- INICIANDO PRUEBA B2: CANTIDAD CERO O NEGATIVA ---';
DECLARE @id_venta_prueba INT = (SELECT TOP 1 id_venta_cabecera FROM dbo.venta_cabecera ORDER BY id_venta_cabecera DESC);
BEGIN TRY
    EXEC dbo.sp_AgregarDetalleVenta 
        @id_venta_cabecera = @id_venta_prueba, 
        @id_producto = 2, 
        @cantidad = -1;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;
GO

-- CASO DE PRUEBA B3: Ejecución fallida (Stock insuficiente)
PRINT '--- INICIANDO PRUEBA B3: STOCK INSUFICIENTE ---';
DECLARE @id_venta_prueba INT = (SELECT TOP 1 id_venta_cabecera FROM dbo.venta_cabecera ORDER BY id_venta_cabecera DESC);
BEGIN TRY
    EXEC dbo.sp_AgregarDetalleVenta 
        @id_venta_cabecera = @id_venta_prueba, 
        @id_producto = 1, 
        @cantidad = 99999;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;

-- Verificando el resultado final en la base de datos
PRINT '--- VERIFICACIÓN FINAL ---';
SELECT vc.id_venta_cabecera, vc.estado, vc.total, p.nombre, vd.cantidad, vd.subtotal
FROM dbo.venta_cabecera vc
LEFT JOIN dbo.venta_detalle vd ON vc.id_venta_cabecera = vd.id_venta_cabecera
LEFT JOIN dbo.productos p ON vd.id_productos = p.id_productos
WHERE vc.id_venta_cabecera = @id_venta_prueba;
GO