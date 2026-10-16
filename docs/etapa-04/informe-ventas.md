# Reporte Agregado de Ventas por Categoría

**Etapa IV — Consultas y Casos de Uso**
**Script:** `sql/consultas/informe_ventas.sql`

---

## 1. Necesidad de información

Obtener un consolidado del **total de ventas realizadas agrupadas por categoría de producto** en un rango de fechas determinado.

Esta información permite al personal administrativo:

- Identificar cuáles son las categorías de mayor rentabilidad y volumen de ventas (ej. Videojuegos vs. Consolas de Sobremesa).
- Tomar decisiones estratégicas sobre la reposición y compra de stock de colección.
- Evaluar el rendimiento comercial por rubro para orientar campañas de marketing y promociones.

## 2. Criterios aplicados

| Criterio | Detalle |
| :--- | :--- |
| Rango temporal | Filtrado mediante variables de fecha declaradas al inicio (`@fecha_inicio` y `@fecha_fin`) |
| Ventas consideradas | Estados `PAGADA`, `ENVIADA` y `ENTREGADA` (ventas efectivamente concretadas) |
| Ventas excluidas | `CARRITO`, `PENDIENTE` y `CANCELADA` |
| Métricas calculadas | Cantidad de operaciones, unidades vendidas, recaudación total y precio promedio por rubro |


## 3. Requisitos de la consigna

| Requisito | Cómo se cumple |
| :--- | :--- |
| Reporte Agregado | Uso de funciones de grupo (`SUM`, `COUNT`, `AVG`) combinadas con `GROUP BY` |
| Rango de fechas | Filtro explícito en la cláusula `WHERE` mediante el operador `BETWEEN` sobre la fecha de venta |

## 4. Consulta SQL


```sql
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
```

## 5. Explicación paso a paso

1. **Selección de base de datos (`USE`):** Garantiza que la consulta se ejecute sobre el esquema correcto (`RetroGames`).
2. **Variables de fecha (`DECLARE`):** Permiten parametrizar el periodo de análisis de forma limpia sin modificar la estructura interna de la consulta.
3. **`FROM` + `JOIN`:** Relaciona las tablas `categoria` (`c`), `productos` (`pr`), `venta_detalle` (`vd`) y `venta_cabecera` (`vc`) mediante sus respectivas claves foráneas para vincular cada ítem vendido con su categoría.
4. **`WHERE`:** Filtra únicamente las transacciones concretadas (`PAGADA`, `ENVIADA`, `ENTREGADA`) y acota los registros al rango temporal establecido por las variables.
5. **`GROUP BY`:** Agrupa los resultados por identificador y nombre de la categoría para consolidar los cálculos por rubro.
6. **Agregaciones (`SUM`, `COUNT`, `AVG`):**
   - `COUNT(DISTINCT vc.id_venta_cabecera)` cuenta las operaciones de venta distintas por categoría (evitando duplicados si un ticket tiene varios ítems del mismo rubro).
   - `SUM(vd.cantidad)` totaliza las unidades físicas comercializadas.
   - `SUM(vd.subtotal)` calcula la recaudación total generada por la categoría.
   - `AVG(vd.precio_unitario)` obtiene el precio promedio de los productos vendidos en ese rubro.
7. **`ORDER BY`:** Ordena las categorías de mayor a menor según la recaudación total obtenida (`DESC`).

## 6. Resultado esperado con los datos de prueba

Con los datos cargados en el script DML para el mes de septiembre de 2026:

| categoria | total_operaciones | unidades_vendidas | recaudacion_total | precio_promedio |
| :--- | :---: | :---: | ---: | ---: |
| Consolas de Sobremesa | 1 | 1 | 160.000,00 | 160.000,00 |
| Ediciones de Colección | 2 | 2 | 118.000,00 | 59.000,00 |
| Consolas Portátiles | 1 | 1 | 90.000,00 | 90.000,00 |
| Videojuegos | 2 | 2 | 70.000,00 | 35.000,00 |
| Accesorios | 2 | 2 | 33.000,00 | 16.500,00 |

## 7. Interpretación

El rubro **Consolas de Sobremesa** lidera la recaudación total a pesar de registrar una sola operación, debido al alto valor unitario del producto. Por otro lado, la categoría **Ediciones de Colección** demuestra un excelente rendimiento tanto en volumen como en ingresos, consolidándose como uno de los pilares comerciales del negocio de videojuegos.
























