/* =====================================================================
   RETRO GAMES - Etapa IV: Reporte Agregado por Categoría
   SQL Server / Transact-SQL
   Archivo: sql/consultas/informe_ventas.sql
   Requisito: haber ejecutado crear_bd.sql y el script DML de datos de prueba.

   Necesidad de negocio:
   Obtener el total de ventas realizadas agrupadas por cada categoría
   de producto dentro de un rango de fechas específico, permitiendo
   analizar el volumen de unidades comercializadas, la cantidad de
   transacciones y la recaudación total por rubro.

   Técnicas aplicadas:
   - Uso de funciones de agregación: SUM, COUNT, AVG
   - Agrupamiento con GROUP BY
   - Filtrado temporal y por estados de venta válidos
   - Ordenamiento del resultado de mayor a menor recaudación
   ===================================================================== */

USE RetroGames;
GO

-- Definición de rango de fechas para el reporte (configurable mediante variables)
DECLARE @fecha_inicio DATETIME = '2026-09-01 00:00:00';
DECLARE @fecha_fin    DATETIME = '2026-09-30 23:59:59';

SELECT
    c.id_categoria,
    c.nombre                                   AS categoria,
    COUNT(DISTINCT vc.id_venta_cabecera)       AS total_operaciones,
    SUM(vd.cantidad)                           AS unidades_vendidas,
    SUM(vd.subtotal)                           AS recaudacion_total,
    AVG(vd.precio_unitario)                    AS precio_promedio
FROM dbo.categoria c
JOIN dbo.productos      pr ON pr.id_categoria      = c.id_categoria
JOIN dbo.venta_detalle  vd ON vd.id_productos      = pr.id_productos
JOIN dbo.venta_cabecera vc ON vc.id_venta_cabecera = vd.id_venta_cabecera
WHERE vc.estado IN ('PAGADA', 'ENVIADA', 'ENTREGADA')
  AND vc.fecha_venta BETWEEN @fecha_inicio AND @fecha_fin
GROUP BY c.id_categoria, c.nombre
ORDER BY recaudacion_total DESC;
GO