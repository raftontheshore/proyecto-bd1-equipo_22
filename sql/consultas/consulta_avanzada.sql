/* =====================================================================
   RETRO GAMES - Etapa IV: Consulta de Negocio Avanzada
   SQL Server / Transact-SQL
   Archivo: sql/consultas/consulta_avanzada.sql
   Requisito: haber ejecutado crear_bd.sql y datos_prueba.sql

   Necesidad de negocio:
   Identificar a los "clientes de prioritarios": aquellos cuyo gasto total
   en ventas efectivamente realizadas supera el gasto promedio por
   cliente. Sirve para campañas, ofertas de reposición de productos de
   colección y seguimiento comercial.

   Técnicas aplicadas:
   - JOIN de 7 tablas (requisito: al menos 3)
   - Filtro condicional con HAVING
   - Subconsulta anidada para calcular el promedio de referencia
   - Ventas "realizadas" = PAGADA, ENVIADA, ENTREGADA
     (se excluyen CARRITO, PENDIENTE y CANCELADA, que no tienen pago
     o no se concretaron)
   ===================================================================== */

USE RetroGames;
GO

SELECT
    u.id_usuario,
    u.nombre                                   AS cliente,
    u.email,
    COUNT(DISTINCT vc.id_venta_cabecera)       AS compras,
    COUNT(DISTINCT c.id_categoria)             AS categorias_distintas,
    COUNT(DISTINCT mp.id_metodo_pago)          AS metodos_pago_usados,
    SUM(vd.subtotal)                           AS gasto_total
FROM dbo.usuario u
JOIN dbo.venta_cabecera vc ON vc.id_usuario        = u.id_usuario
JOIN dbo.venta_detalle  vd ON vd.id_venta_cabecera = vc.id_venta_cabecera
JOIN dbo.productos      pr ON pr.id_productos      = vd.id_productos
JOIN dbo.categoria      c  ON c.id_categoria       = pr.id_categoria
JOIN dbo.pago           pg ON pg.id_venta_cabecera = vc.id_venta_cabecera
JOIN dbo.metodo_pago    mp ON mp.id_metodo_pago    = pg.id_metodo_pago
WHERE vc.estado IN ('PAGADA', 'ENVIADA', 'ENTREGADA')
GROUP BY u.id_usuario, u.nombre, u.email
HAVING SUM(vd.subtotal) > (
        -- Subconsulta: gasto promedio por cliente (ventas realizadas)
        SELECT AVG(t.gasto_cliente)
        FROM (
            SELECT SUM(vd2.subtotal) AS gasto_cliente
            FROM dbo.venta_cabecera vc2
            JOIN dbo.venta_detalle vd2
                 ON vd2.id_venta_cabecera = vc2.id_venta_cabecera
            WHERE vc2.estado IN ('PAGADA', 'ENVIADA', 'ENTREGADA')
            GROUP BY vc2.id_usuario
        ) t
)
ORDER BY gasto_total DESC;
GO

/* ---------------------------------------------------------------------
   Resultado esperado con datos_prueba.sql
   (gasto promedio por cliente = 92.200,00):

   Juan Pérez       2 compras   gasto_total 210.000
   Micaela Pawlizki 2 compras   gasto_total  98.000
   Sofía Martínez   2 compras   gasto_total  98.000
   --------------------------------------------------------------------- */
