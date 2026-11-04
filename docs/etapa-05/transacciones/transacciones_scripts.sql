/* =====================================================================
   RETRO GAMES - Etapa V: Manejo de Transacciones
   SQL Server / Transact-SQL (requiere SQL Server 2016 SP1 o superior)
   Requisito: haber ejecutado crear_bd.sql y datos_prueba.sql
   (opcional: el script de triggers, para ver la auditoría del stock)

   Qué se resuelve: el registro de una venta involucra varias tablas
   (venta_cabecera, venta_detalle, pago y productos). Se ejecuta como
   una única transacción: o se guarda todo o no se guarda nada.

   ATENCIÓN: las pruebas de la sección 2 modifican datos de prueba;
   para restaurarlos, volver a ejecutar datos_prueba.sql.
   ===================================================================== */

USE RetroGames;
GO

/* ---------------------------------------------------------------------
   1. PROCEDIMIENTO: dbo.sp_RegistrarVentaTransaccional
   Registra una venta de un producto dentro de una transacción:
     A. Valida producto y stock (bloqueando la fila con UPDLOCK).
     B. Inserta cabecera de venta.
     C. Inserta detalle congelando el precio vigente.
     D. Registra el pago.
     E. Descuenta el stock y mantiene la bandera stock_bajo (RN-07).
   Si cualquier paso falla se hace ROLLBACK de todo y se relanza el error.
   Devuelve el id de la venta generada en @id_venta (OUTPUT).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarVentaTransaccional
    @id_usuario     INT,
    @id_direccion   INT,
    @id_metodo_pago INT,
    @id_producto    INT,
    @cantidad       INT,
    @id_venta       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- ante un error de ejecución, el motor revierte la transacción

    DECLARE @stock_actual    INT;
    DECLARE @precio_vigente  DECIMAL(10,2);
    DECLARE @activo          BIT;
    DECLARE @subtotal        DECIMAL(12,2);

    BEGIN TRY
        IF @cantidad IS NULL OR @cantidad <= 0
            THROW 50002, 'Error: la cantidad debe ser mayor a cero.', 1;

        BEGIN TRANSACTION;

            -- A. Leer producto bloqueando la fila hasta el final de la transacción
            --    (evita que dos ventas simultáneas vendan la misma última unidad)
            SELECT @stock_actual   = stock,
                   @precio_vigente = precio,
                   @activo         = activo
            FROM dbo.productos WITH (UPDLOCK, ROWLOCK)
            WHERE id_productos = @id_producto;

            IF @stock_actual IS NULL
                THROW 50003, 'Error: el producto no existe.', 1;

            IF @activo = 0
                THROW 50004, 'Error: el producto está dado de baja.', 1;

            IF @stock_actual < @cantidad
                THROW 50001, 'Error: Stock insuficiente para completar la venta.', 1;

            -- RN-10: solo se aceptan métodos de pago autorizados (activo = 1).
            -- Un método inexistente lo rechaza la clave foránea de pago (prueba 3).
            IF EXISTS (SELECT 1 FROM dbo.metodo_pago
                       WHERE id_metodo_pago = @id_metodo_pago AND activo = 0)
                THROW 50005, 'Error: el método de pago no está autorizado.', 1;

            SET @subtotal = @precio_vigente * @cantidad;

            -- B. Encabezado de venta
            INSERT INTO dbo.venta_cabecera (fecha_venta, estado, total, id_usuario, id_direccion)
            VALUES (GETDATE(), 'PAGADA', @subtotal, @id_usuario, @id_direccion);

            SET @id_venta = SCOPE_IDENTITY();

            -- C. Detalle con el precio congelado
            INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
            VALUES (@cantidad, @precio_vigente, @subtotal, @id_producto, @id_venta);

            -- D. Pago
            INSERT INTO dbo.pago (fecha_pago, monto, id_venta_cabecera, id_metodo_pago)
            VALUES (GETDATE(), @subtotal, @id_venta, @id_metodo_pago);

            -- E. Descuento de stock y mantenimiento de la bandera stock_bajo (RN-07)
            --    stock_bajo = 1 cuando el stock resultante queda por debajo del
            --    umbral de reposición (stock < stock_minimo); 0 en caso contrario.
            --    En un UPDATE, el lado derecho usa los valores previos a la
            --    modificación, por eso se calcula con (stock - @cantidad).
            UPDATE dbo.productos
            SET stock      = stock - @cantidad,
                stock_bajo = CASE WHEN stock - @cantidad < stock_minimo THEN 1 ELSE 0 END
            WHERE id_productos = @id_producto;

        COMMIT TRANSACTION;

        PRINT 'Venta ' + CAST(@id_venta AS VARCHAR(10)) + ' confirmada (COMMIT). Stock actualizado.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 --deshacer ante error
            ROLLBACK TRANSACTION;

        SET @id_venta = NULL;
        PRINT 'Transacción revertida (ROLLBACK).';
        THROW;   -- relanza el error original al cliente
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------
   2. DEMOSTRACIÓN Y PRUEBAS
   --------------------------------------------------------------------- */
   
-- PRUEBA 1: venta exitosa (stock suficiente) -> COMMIT
PRINT '--- PRUEBA 1: VENTA EXITOSA ---';
DECLARE @id_venta INT;
DECLARE @cab_antes INT = (SELECT COUNT(*) FROM dbo.venta_cabecera);
DECLARE @det_antes INT = (SELECT COUNT(*) FROM dbo.venta_detalle);
DECLARE @pag_antes INT = (SELECT COUNT(*) FROM dbo.pago);
DECLARE @stock_antes INT = (SELECT stock FROM dbo.productos WHERE id_productos = 1);

EXEC dbo.sp_RegistrarVentaTransaccional
    @id_usuario = 1, @id_direccion = 1, @id_metodo_pago = 1,
    @id_producto = 1, @cantidad = 1, @id_venta = @id_venta OUTPUT;

SELECT @id_venta AS id_venta_generada,
       @cab_antes AS cabeceras_antes, (SELECT COUNT(*) FROM dbo.venta_cabecera) AS cabeceras_despues,
       @det_antes AS detalles_antes,  (SELECT COUNT(*) FROM dbo.venta_detalle)  AS detalles_despues,
       @pag_antes AS pagos_antes,     (SELECT COUNT(*) FROM dbo.pago)           AS pagos_despues,
       @stock_antes AS stock_antes,   (SELECT stock FROM dbo.productos WHERE id_productos = 1) AS stock_despues;
GO

-- PRUEBA 2: stock insuficiente -> ROLLBACK, no cambia nada 
PRINT '--- PRUEBA 2: STOCK INSUFICIENTE ---';
DECLARE @id_venta INT;
DECLARE @cab_antes INT = (SELECT COUNT(*) FROM dbo.venta_cabecera);
DECLARE @det_antes INT = (SELECT COUNT(*) FROM dbo.venta_detalle);
DECLARE @pag_antes INT = (SELECT COUNT(*) FROM dbo.pago);
DECLARE @stock_antes INT = (SELECT stock FROM dbo.productos WHERE id_productos = 1);

BEGIN TRY
    EXEC dbo.sp_RegistrarVentaTransaccional
        @id_usuario = 1, @id_direccion = 1, @id_metodo_pago = 1,
        @id_producto = 1, @cantidad = 99999, @id_venta = @id_venta OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;

SELECT @cab_antes AS cabeceras_antes, (SELECT COUNT(*) FROM dbo.venta_cabecera) AS cabeceras_despues,
       @det_antes AS detalles_antes,  (SELECT COUNT(*) FROM dbo.venta_detalle)  AS detalles_despues,
       @pag_antes AS pagos_antes,     (SELECT COUNT(*) FROM dbo.pago)           AS pagos_despues,
       @stock_antes AS stock_antes,   (SELECT stock FROM dbo.productos WHERE id_productos = 1) AS stock_despues;
GO

-- PRUEBA 3: fallo a mitad de la operación -> ROLLBACK de lo ya insertado
-- El método de pago 9999 no existe: la cabecera y el detalle ya se habían
-- insertado cuando falla el pago (violación de clave foránea). La
-- transacción los deshace; el stock tampoco se descuenta.
PRINT '--- PRUEBA 3: FALLO A MITAD DE LA TRANSACCIÓN (MÉTODO DE PAGO INEXISTENTE) ---';
DECLARE @id_venta INT;
DECLARE @cab_antes INT = (SELECT COUNT(*) FROM dbo.venta_cabecera);
DECLARE @det_antes INT = (SELECT COUNT(*) FROM dbo.venta_detalle);
DECLARE @pag_antes INT = (SELECT COUNT(*) FROM dbo.pago);
DECLARE @stock_antes INT = (SELECT stock FROM dbo.productos WHERE id_productos = 1);

BEGIN TRY
    EXEC dbo.sp_RegistrarVentaTransaccional
        @id_usuario = 1, @id_direccion = 1, @id_metodo_pago = 9999,
        @id_producto = 1, @cantidad = 1, @id_venta = @id_venta OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;

SELECT @cab_antes AS cabeceras_antes, (SELECT COUNT(*) FROM dbo.venta_cabecera) AS cabeceras_despues,
       @det_antes AS detalles_antes,  (SELECT COUNT(*) FROM dbo.venta_detalle)  AS detalles_despues,
       @pag_antes AS pagos_antes,     (SELECT COUNT(*) FROM dbo.pago)           AS pagos_despues,
       @stock_antes AS stock_antes,   (SELECT stock FROM dbo.productos WHERE id_productos = 1) AS stock_despues;
GO

-- PRUEBA 4: transacción manual con ROLLBACK explícito
-- Se modifica el stock dentro de una transacción, se verifica el cambio
-- DENTRO de ella y luego se deshace: el stock vuelve al valor original.
PRINT '--- PRUEBA 4: ROLLBACK EXPLÍCITO ---';
DECLARE @stock_original INT = (SELECT stock FROM dbo.productos WHERE id_productos = 2);
DECLARE @stock_en_transaccion INT;

BEGIN TRANSACTION;
    UPDATE dbo.productos SET stock = stock + 1 WHERE id_productos = 2;
    SET @stock_en_transaccion = (SELECT stock FROM dbo.productos WHERE id_productos = 2);
ROLLBACK TRANSACTION;

SELECT @stock_original AS stock_original,
       @stock_en_transaccion AS stock_dentro_de_la_transaccion,
       (SELECT stock FROM dbo.productos WHERE id_productos = 2) AS stock_despues_del_rollback;
GO

-- PRUEBA 5: la venta mantiene la bandera stock_bajo (RN-07)
-- Se prepara el producto 2 con stock 3 y umbral 3, y se vende 1 unidad:
-- el stock resultante (2) queda por debajo del umbral, por lo que stock_bajo
-- pasa de 0 a 1. ...
    UPDATE dbo.productos
    SET stock = 3, stock_minimo = 3, stock_bajo = 0
    WHERE id_productos = 2;

BEGIN TRANSACTION;
    UPDATE dbo.productos
    SET stock = 3, stock_minimo = 2, stock_bajo = 0
    WHERE id_productos = 2;

    SELECT 'Antes de la venta' AS momento, stock, stock_minimo, stock_bajo
    FROM dbo.productos WHERE id_productos = 2;

    EXEC dbo.sp_RegistrarVentaTransaccional
        @id_usuario = 1, @id_direccion = 1, @id_metodo_pago = 1,
        @id_producto = 2, @cantidad = 1, @id_venta = @id_venta OUTPUT;

    SELECT 'Después de la venta' AS momento, stock, stock_minimo, stock_bajo
    FROM dbo.productos WHERE id_productos = 2;
ROLLBACK TRANSACTION;   -- se descarta la preparación y la venta de prueba
GO

-- PRUEBA 6: transacción anidada con fallo interno
-- La transacción externa modifica el stock y luego llama al procedimiento
-- (transacción interna) con un método de pago inexistente. El ROLLBACK del
-- procedimiento deshace TAMBIÉN el cambio de la externa.
PRINT '--- PRUEBA 6: TRANSACCIÓN ANIDADA CON FALLO INTERNO ---';
DECLARE @id_venta INT;
DECLARE @cab_antes INT = (SELECT COUNT(*) FROM dbo.venta_cabecera);
DECLARE @stock_antes INT = (SELECT stock FROM dbo.productos WHERE id_productos = 2);

BEGIN TRY
    BEGIN TRANSACTION;   -- externa
        PRINT '@@TRANCOUNT en la externa: ' + CAST(@@TRANCOUNT AS VARCHAR(5));

        UPDATE dbo.productos SET stock = stock + 10 WHERE id_productos = 2;

        EXEC dbo.sp_RegistrarVentaTransaccional
            @id_usuario = 1, @id_direccion = 1, @id_metodo_pago = 9999,
            @id_producto = 2, @cantidad = 1, @id_venta = @id_venta OUTPUT;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
    PRINT '@@TRANCOUNT en el CATCH: ' + CAST(@@TRANCOUNT AS VARCHAR(5));
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;

SELECT @cab_antes AS cabeceras_antes, (SELECT COUNT(*) FROM dbo.venta_cabecera) AS cabeceras_despues,
       @stock_antes AS stock_antes, (SELECT stock FROM dbo.productos WHERE id_productos = 2) AS stock_despues;
GO
/* ---------------------------------------------------------------------
   3. CONSULTA DE VERIFICACIÓN
   --------------------------------------------------------------------- */
-- Últimas ventas registradas con su detalle y pago
PRINT '--- ÚLTIMAS VENTAS REGISTRADAS ---';
SELECT TOP 5 vc.id_venta_cabecera, vc.fecha_venta, vc.estado, vc.total,
       vd.id_productos, vd.cantidad, vd.precio_unitario,
       p.monto AS monto_pagado, p.id_metodo_pago
FROM dbo.venta_cabecera AS vc
JOIN dbo.venta_detalle  AS vd ON vd.id_venta_cabecera = vc.id_venta_cabecera
JOIN dbo.pago           AS p  ON p.id_venta_cabecera  = vc.id_venta_cabecera
ORDER BY vc.id_venta_cabecera DESC;
GO

/* ---------------------------------------------------------------------
   Resultado esperado (partiendo de datos_prueba.sql recién cargado)
   Prueba 1: +1 cabecera, +1 detalle, +1 pago; stock del producto 1 baja en 1.
   Prueba 2: error 'Stock insuficiente'; todos los contadores iguales.
   Prueba 3: error de clave foránea en pago; todos los contadores iguales
             y stock sin cambios (se deshizo la cabecera y el detalle).
  Prueba 4: stock_dentro_de_la_transaccion = stock_original + 1;
             stock_despues_del_rollback = stock_original.
  Prueba 5: antes stock 3 / stock_bajo 0; después stock 2 / stock_bajo 1
             (queda por debajo del umbral 3). Luego se revierte todo.
    Prueba 6: cabeceras y stock sin cambios.
                El +10 de la transacción externa también se pierde,
                porque el ROLLBACK interno deshizo todo. Eso demuestra que un rollback
                interno afecta a la externa.
   --------------------------------------------------------------------- */
