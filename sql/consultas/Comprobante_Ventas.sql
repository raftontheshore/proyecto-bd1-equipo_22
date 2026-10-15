/* =====================================================================
   RETRO GAMES - Comprobante de Venta

   Necesidad de negocio:
   Emitir el comprobante de una venta consolidando encabezado
   (venta_cabecera, usuario, direccion, pago, metodo_pago) y detalle
   (venta_detalle, productos), con subtotal por renglon, total acumulado
   renglon a renglon y total de la venta.

   Criterios:
   - Solo se emiten comprobantes de ventas "realizadas"
     (PAGADA, ENVIADA, ENTREGADA), igual que consulta_avanzada.sql.
     CARRITO, PENDIENTE y CANCELADA no generan comprobante.
   - El subtotal por renglon se CALCULA en la consulta
     (cantidad * precio_unitario). Coincide con venta_detalle.subtotal
     porque el CHECK de la tabla garantiza esa igualdad.
   - venta_cabecera.total y pago.monto son datos independientes de la
     suma de los detalles: se incluyen columnas de control que deben
     dar 0.
   - Direccion armada con CONCAT para tolerar campos NULL.

   Contenido:
   1. Formato comprobante estilo ticket (total una sola vez al pie)
   2. Vista  dbo.vw_comprobante_venta
   3. Procedimiento dbo.sp_comprobante_venta
   ===================================================================== */

USE RetroGames;
GO

/* ---------------------------------------------------------------------
   1. CONSULTA DIRECTA
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   Encabezado una sola vez, luego los renglones y, al pie, SUBTOTAL y
   TOTAL una sola vez. Como el modelo no tiene impuestos ni descuentos
   globales, SUBTOTAL (suma de renglones) y TOTAL (venta_cabecera.total)
   deben coincidir; si no, hay una inconsistencia en los datos.
   --------------------------------------------------------------------- */
DECLARE @id_venta_ticket INT = 7;   -- cambiar por el id de la venta a imprimir

-- Resultado 1: ENCABEZADO (una fila)
SELECT
    vc.id_venta_cabecera                              AS nro_comprobante,
    vc.fecha_venta,
    u.nombre                                          AS cliente,
    CONCAT(dir.calle, ', ', dir.ciudad, ', ', dir.provincia,
           CASE WHEN dir.codpostal IS NOT NULL
                THEN CONCAT(' (CP ', dir.codpostal, ')') END)
                                                      AS direccion_entrega,
    mp.nombre                                         AS metodo_pago
FROM dbo.venta_cabecera vc
JOIN      dbo.usuario     u   ON u.id_usuario     = vc.id_usuario
JOIN      dbo.direccion   dir ON dir.id_direccion = vc.id_direccion
LEFT JOIN dbo.pago        pg  ON pg.id_venta_cabecera = vc.id_venta_cabecera
LEFT JOIN dbo.metodo_pago mp  ON mp.id_metodo_pago    = pg.id_metodo_pago
WHERE vc.id_venta_cabecera = @id_venta_ticket
  AND vc.estado IN ('PAGADA', 'ENVIADA', 'ENTREGADA');

-- Resultado 2: DETALLE + SUBTOTAL + TOTAL al pie
WITH detalle AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY vd.id_venta_detalle)  AS renglon,
        p.nombre                                          AS producto,
        vd.cantidad,
        vd.precio_unitario,
        vd.cantidad * vd.precio_unitario                  AS subtotal_renglon,
        vc.total                                          AS total_cabecera
    FROM dbo.venta_cabecera vc
    JOIN dbo.venta_detalle vd ON vd.id_venta_cabecera = vc.id_venta_cabecera
    JOIN dbo.productos     p  ON p.id_productos       = vd.id_productos
    WHERE vc.id_venta_cabecera = @id_venta_ticket
      AND vc.estado IN ('PAGADA', 'ENVIADA', 'ENTREGADA')
),
filas AS (
    -- Renglones
    SELECT 1 AS grupo, renglon AS n,
           CAST(renglon AS VARCHAR(10))                   AS renglon,
           producto, cantidad, precio_unitario, subtotal_renglon,
           SUM(subtotal_renglon) OVER (ORDER BY renglon
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                          AS total_acumulado
    FROM detalle
    UNION ALL
    -- Subtotal (suma de los renglones)
    SELECT 2, 0, 'SUBTOTAL', NULL, NULL, NULL, SUM(subtotal_renglon), NULL
    FROM detalle
    HAVING COUNT(*) > 0
    UNION ALL
    -- Total de la venta (el registrado en la cabecera)
    SELECT 3, 0, 'TOTAL', NULL, NULL, NULL, MAX(total_cabecera), NULL
    FROM detalle
    HAVING COUNT(*) > 0
)
SELECT
    renglon,
    ISNULL(producto, '')                               AS producto,
    ISNULL(CAST(cantidad AS VARCHAR(10)), '')          AS cantidad,
    ISNULL(CONVERT(VARCHAR(20), precio_unitario), '')  AS precio_unitario,
    ISNULL(CONVERT(VARCHAR(20), subtotal_renglon), '') AS subtotal_renglon,
    ISNULL(CONVERT(VARCHAR(20), total_acumulado), '')  AS total_acumulado
FROM filas
ORDER BY grupo, n;
GO

/* ---------------------------------------------------------------------
   2. VISTA
   Sin filtro por venta: se consulta con WHERE nro_comprobante = X.
   Los acumulados particionan por venta, por lo que el resultado es
   correcto aun filtrando una sola venta o varias a la vez.
   --------------------------------------------------------------------- */
DROP VIEW IF EXISTS dbo.vw_comprobante_venta;
GO

CREATE VIEW dbo.vw_comprobante_venta
AS
SELECT
    vc.id_venta_cabecera                              AS nro_comprobante,
    vc.fecha_venta,
    vc.estado,
    u.id_usuario,
    u.nombre                                          AS cliente,
    u.email,
    u.telefono,
    CONCAT(dir.calle, ', ', dir.ciudad, ', ', dir.provincia,
           CASE WHEN dir.codpostal IS NOT NULL
                THEN CONCAT(' (CP ', dir.codpostal, ')') END)
                                                      AS direccion_entrega,
    mp.nombre                                         AS metodo_pago,
    pg.fecha_pago,
    vd.id_venta_detalle,
    ROW_NUMBER() OVER (PARTITION BY vc.id_venta_cabecera
                       ORDER BY vd.id_venta_detalle)  AS renglon,
    p.nombre                                          AS producto,
    p.consola,
    p.estado_conservacion,
    vd.cantidad,
    vd.precio_unitario,
    vd.cantidad * vd.precio_unitario                  AS subtotal_renglon,
    SUM(vd.cantidad * vd.precio_unitario) OVER (PARTITION BY vc.id_venta_cabecera
                           ORDER BY vd.id_venta_detalle
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                      AS total_acumulado,
    SUM(vd.cantidad * vd.precio_unitario) OVER (PARTITION BY vc.id_venta_cabecera)
                                                      AS total_calculado,
    vc.total                                          AS total_cabecera,
    pg.monto                                          AS monto_pagado,
    vc.total - SUM(vd.cantidad * vd.precio_unitario) OVER (PARTITION BY vc.id_venta_cabecera)
                                                      AS diferencia_control,
    pg.monto - vc.total                               AS diferencia_pago
FROM dbo.venta_cabecera vc
JOIN      dbo.usuario       u   ON u.id_usuario         = vc.id_usuario
JOIN      dbo.direccion     dir ON dir.id_direccion     = vc.id_direccion
JOIN      dbo.venta_detalle vd  ON vd.id_venta_cabecera = vc.id_venta_cabecera
JOIN      dbo.productos     p   ON p.id_productos       = vd.id_productos
LEFT JOIN dbo.pago          pg  ON pg.id_venta_cabecera = vc.id_venta_cabecera
LEFT JOIN dbo.metodo_pago   mp  ON mp.id_metodo_pago    = pg.id_metodo_pago
WHERE vc.estado IN ('PAGADA', 'ENVIADA', 'ENTREGADA');
GO

/* Uso:
   SELECT * FROM dbo.vw_comprobante_venta
   WHERE nro_comprobante = 1
   ORDER BY renglon;
*/

/* ---------------------------------------------------------------------
   3. PROCEDIMIENTO ALMACENADO
   Devuelve el comprobante de una venta. Si la venta no existe o no
   esta en estado PAGADA / ENVIADA / ENTREGADA, informa el error.
   --------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.sp_comprobante_venta;
GO

CREATE PROCEDURE dbo.sp_comprobante_venta
    @id_venta INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1
                   FROM dbo.vw_comprobante_venta
                   WHERE nro_comprobante = @id_venta)
    BEGIN
        THROW 50001,
              'La venta no existe o no esta en estado PAGADA, ENVIADA o ENTREGADA: no genera comprobante.',
              1;
    END;

    SELECT *
    FROM dbo.vw_comprobante_venta
    WHERE nro_comprobante = @id_venta
    ORDER BY renglon;
END;
GO

/* Uso:
   EXEC dbo.sp_comprobante_venta @id_venta = 1;
*/