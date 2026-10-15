# Consulta de Negocio Avanzada

**Etapa IV — Consultas y Casos de Uso**
**Script:** `sql/consultas/consulta_avanzada.sql`

---

## 1. Necesidad de información

Identificar a los **clientes de alto valor**: aquellos cuyo gasto total en ventas efectivamente realizadas supera el gasto promedio por cliente.

Esta información permite al personal administrativo:

- Priorizar el seguimiento comercial de los mejores clientes.
- Ofrecer anticipadamente artículos de colección de stock limitado.
- Detectar el comportamiento de compra (variedad de categorías y métodos de pago usados).

## 2. Criterios aplicados

| Criterio | Detalle |
| :--- | :--- |
| Ventas consideradas | Estados `PAGADA`, `ENVIADA` y `ENTREGADA` |
| Ventas excluidas | `CARRITO` y `PENDIENTE` (sin pago registrado, RN-13) y `CANCELADA` (no concretadas) |
| Métrica de valor | Suma de `venta_detalle.subtotal` por cliente |
| Umbral | Promedio del gasto por cliente, calculado con una subconsulta |

## 3. Requisitos de la consigna

| Requisito | Cómo se cumple |
| :--- | :--- |
| JOIN de al menos 3 tablas | Se combinan **7 tablas**: `usuario`, `venta_cabecera`, `venta_detalle`, `productos`, `categoria`, `pago` y `metodo_pago` |
| Filtro condicional | Cláusula `HAVING` sobre el gasto total agregado |
| Subconsulta | Subconsulta anidada que calcula el gasto promedio por cliente |

## 4. Consulta SQL

```sql
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
```

## 5. Explicación paso a paso

1. **`FROM` + `JOIN`:** se recorre la cadena completa `usuario → venta_cabecera → venta_detalle → productos → categoria`, y en paralelo `venta_cabecera → pago → metodo_pago`. Los `JOIN` internos descartan ventas sin pago, lo que es coherente con el filtro de estados.
2. **`WHERE`:** deja solo las ventas realizadas, antes de agrupar.
3. **`GROUP BY`:** una fila por cliente.
4. **Agregaciones:** `COUNT(DISTINCT ...)` evita contar de más cuando una venta tiene varios ítems; `SUM(subtotal)` calcula el gasto total.
5. **Subconsulta interna:** calcula el gasto total de cada cliente con ventas realizadas.
6. **Subconsulta externa:** `AVG` sobre esos totales da el gasto promedio por cliente.
7. **`HAVING`:** conserva solo los clientes cuyo gasto supera ese promedio. Se usa `HAVING` y no `WHERE` porque la condición se aplica sobre un valor agregado.

## 6. Resultado con los datos de prueba

Gasto por cliente en ventas realizadas:

| Cliente | Gasto total |
| :--- | ---: |
| Juan Pérez | 210.000,00 |
| Micaela Pawlizki | 98.000,00 |
| Sofía Martínez | 98.000,00 |
| Mauricio Aguirre | 30.000,00 |
| María Gómez | 25.000,00 |

**Promedio por cliente:** 461.000 / 5 = **92.200,00**

Resultado de la consulta (clientes por encima del promedio):

| cliente | compras | categorias_distintas | metodos_pago_usados | gasto_total |
| :--- | :---: | :---: | :---: | ---: |
| Juan Pérez | 2 | 2 | 2 | 210.000,00 |
| Micaela Pawlizki | 2 | 3 | 2 | 98.000,00 |
| Sofía Martínez | 2 | 2 | 2 | 98.000,00 |

Lucía Fernández no figura porque su única venta está `PENDIENTE` (sin pago), y Esteban Quito no tiene compras.

## 7. Interpretación

Tres de los cinco clientes con compras concretadas superan el promedio. Juan Pérez es el cliente de mayor valor: gasta más del doble que el promedio. Micaela es la que compra en más categorías distintas (3), lo que la hace buena candidata para ofertas cruzadas entre rubros.
