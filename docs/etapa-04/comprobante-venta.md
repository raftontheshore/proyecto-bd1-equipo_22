# Comprobante de Venta

**Etapa IV — Consultas y Casos de Uso**
**Script:** `sql/consultas/Comprobante_Ventas.sql`

---

## 1. Necesidad de información

Emitir el **comprobante de una venta**, consolidando el encabezado (venta, cliente, dirección de entrega y método de pago) y el detalle (productos vendidos), con el subtotal de cada renglón, el total acumulado renglón a renglón y el total de la venta.

Esta información permite al personal administrativo:

- Entregar al cliente un comprobante completo de su compra, en formato ticket.
- Verificar que el total de la venta coincide con la suma de sus renglones.
- Verificar que el monto cobrado coincide con el total vendido (mediante la vista y el procedimiento, que incluyen columnas de control).

## 2. Criterios aplicados

| Criterio | Detalle |
| :--- | :--- |
| Ventas con comprobante | Estados `PAGADA`, `ENVIADA` y `ENTREGADA`, el mismo criterio que `consulta_avanzada.sql` |
| Ventas sin comprobante | `CARRITO` y `PENDIENTE` (sin pago registrado, RN-13) y `CANCELADA` (no concretadas) |
| Número de renglón | No existe en el esquema: se genera con `ROW_NUMBER()` ordenado por `id_venta_detalle` |
| Subtotal por renglón | Se **calcula** en la consulta como `cantidad * precio_unitario`. Coincide con `venta_detalle.subtotal` porque el `CHECK` de la tabla garantiza esa igualdad |
| Total acumulado | Suma corrida de los subtotales, renglón a renglón |
| SUBTOTAL y TOTAL | Se muestran **una sola vez al pie**. SUBTOTAL es la suma de los renglones y TOTAL es `venta_cabecera.total`. Como el modelo no tiene impuestos ni descuentos globales, deben coincidir; si no, hay una inconsistencia en los datos |
| Controles | `venta_cabecera.total` y `pago.monto` son datos independientes de la suma de los detalles. La vista y el procedimiento incluyen columnas de control que deben dar 0 |
| Datos de pago | `LEFT JOIN`, porque el pago es opcional (relación 0..1 con la venta) |
| Dirección | Se arma con `CONCAT`, que tolera campos `NULL` (todos los campos de `direccion` son opcionales) |

## 3. Requisitos de la consigna

| Requisito | Cómo se cumple |
| :--- | :--- |
| Consolidar encabezado y detalle de una venta | Se combinan **7 tablas**: `venta_cabecera`, `usuario`, `direccion`, `pago`, `metodo_pago` (encabezado) y `venta_detalle`, `productos` (detalle), filtrando una venta con `@id_venta_ticket` |
| Sub-totales por renglón | Columna `subtotal_renglon` = `cantidad * precio_unitario`, más la fila `SUBTOTAL` al pie |
| Total acumulado | Columna `total_acumulado` (suma corrida con función de ventana) y fila `TOTAL` al pie con el total de la venta |

## 4. Consulta SQL (formato ticket)

La consulta devuelve **dos resultados**: el encabezado (una fila) y el detalle, que termina con las filas `SUBTOTAL` y `TOTAL`.

```sql
USE RetroGames;
GO

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
```

## 5. Explicación paso a paso

**Resultado 1: encabezado**

1. **`FROM` + `JOIN`:** se parte de `venta_cabecera` y se une con `usuario` y `direccion`. Estos `JOIN` internos son seguros: todas las claves foráneas son obligatorias.
2. **`LEFT JOIN` a `pago` y `metodo_pago`:** el pago es 0..1 por venta (`UNIQUE` sobre `id_venta_cabecera`), por lo que no multiplica filas. Se usa `LEFT JOIN` para no perder la venta si el pago no existiera.
3. **`WHERE`:** filtra una sola venta y exige que esté en un estado realizado. Si no lo está, no devuelve filas.
4. **`CONCAT` para la dirección:** a diferencia del operador `+`, ignora los valores `NULL` y evita que toda la dirección quede vacía si falta un dato.

**Resultado 2: detalle, subtotal y total**

5. **CTE `detalle`:** une `venta_cabecera`, `venta_detalle` y `productos` para la venta indicada. Genera el número de renglón con `ROW_NUMBER()` y calcula `subtotal_renglon` como `cantidad * precio_unitario`.
6. **CTE `filas`:** arma tres grupos con `UNION ALL`:
   - **Grupo 1, renglones:** incluye el `total_acumulado`, calculado con `SUM(...) OVER (ORDER BY renglon ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`. Se usa `ROWS` en lugar del `RANGE` por defecto porque es más eficiente y no depende de empates en el orden.
   - **Grupo 2, `SUBTOTAL`:** suma de los subtotales de todos los renglones.
   - **Grupo 3, `TOTAL`:** total registrado en la cabecera (`MAX(total_cabecera)`; el valor es el mismo en todas las filas).
7. **`HAVING COUNT(*) > 0`:** un agregado sin `GROUP BY` devolvería siempre una fila, incluso sin datos. Con este filtro, si la venta no existe o no está en un estado realizado, no aparecen filas `SUBTOTAL` ni `TOTAL` vacías.
8. **`SELECT` final:** convierte todo a texto con `ISNULL`, `CAST` y `CONVERT` para que las filas de renglón y las de pie compartan columnas del mismo tipo y las celdas sin dato queden vacías en lugar de `NULL`. Ordena por `grupo, n` para dejar los renglones primero, luego `SUBTOTAL` y por último `TOTAL`.

## 6. Resultado con los datos de prueba

Ejemplo con la venta 7 (`@id_venta_ticket = 7`), la única con dos renglones.

**Resultado 1: encabezado**

| Campo | Valor |
| :--- | :--- |
| nro_comprobante | 7 |
| fecha_venta | 2026-09-20 12:00 |
| cliente | Micaela Pawlizki |
| direccion_entrega | Av. 3 de Abril 1150, Corrientes, Corrientes (CP 3400) |
| metodo_pago | Mercado Pago |

**Resultado 2: detalle**

| renglon | producto | cantidad | precio_unitario | subtotal_renglon | total_acumulado |
| :---: | :--- | :---: | ---: | ---: | ---: |
| 1 | Pac-Man Arcade Mini | 1 | 50000.00 | 50000.00 | 50000.00 |
| 2 | Cable AV RCA para PlayStation | 1 | 8000.00 | 8000.00 | 58000.00 |
| SUBTOTAL | | | | 58000.00 | |
| TOTAL | | | | 58000.00 | |

Los importes salen como texto (`CONVERT(VARCHAR)`), por lo que se muestran sin separador de miles y con punto decimal.

### Otras ventas del juego de datos

| Venta | Estado | Resultado |
| :---: | :--- | :--- |
| 1, 2, 3, 4, 6, 10 | `ENTREGADA`, `ENVIADA` o `PAGADA` | Comprobante con un renglón |
| 7 | `PAGADA` | Comprobante con dos renglones |
| 9 | `ENTREGADA` | Un renglón con cantidad 2: 2 × 25000.00 = 50000.00 |
| 5 | `PENDIENTE` | Sin filas: no genera comprobante |
| 8 | `CARRITO` | Sin filas: no genera comprobante |

## 7. Interpretación

El total acumulado del último renglón, el `SUBTOTAL` y el `TOTAL` coinciden (58000.00 en la venta 7), lo que confirma que el cálculo es correcto y que la cabecera es consistente con el detalle. Con los datos de prueba, los controles de la vista dan 0 en todas las ventas con comprobante, por lo que cabecera, detalle y pago son consistentes.

El modelo no tiene campos de impuestos ni descuentos globales, por lo que el comprobante muestra únicamente subtotales y total.

## 8. Variantes incluidas en el script

El archivo `Comprobante_Ventas.sql` incluye además dos objetos que reutilizan la lógica de la consulta pero devuelven **una fila por renglón**, con más columnas que el ticket.

### Vista `dbo.vw_comprobante_venta`

No filtra por venta: se consulta con `WHERE nro_comprobante = X`. Los acumulados usan `PARTITION BY id_venta_cabecera`, por lo que el resultado es correcto aunque se filtre una sola venta o varias a la vez. Solo incluye ventas `PAGADA`, `ENVIADA` o `ENTREGADA`.

Además de las columnas del ticket, agrega:

| Grupo | Columnas |
| :--- | :--- |
| Encabezado | `estado`, `id_usuario`, `email`, `telefono`, `fecha_pago` |
| Detalle | `id_venta_detalle`, `consola`, `estado_conservacion` |
| Totales | `total_calculado` (suma de los renglones, repetida en cada fila), `total_cabecera`, `monto_pagado` |
| Controles (deben dar 0) | `diferencia_control` = `total_cabecera` − `total_calculado`; `diferencia_pago` = `monto_pagado` − `total_cabecera` |

Los controles son necesarios porque el esquema no valida estas igualdades.

```sql
SELECT * FROM dbo.vw_comprobante_venta
WHERE nro_comprobante = 7
ORDER BY renglon;
```

### Procedimiento `dbo.sp_comprobante_venta`

Recibe `@id_venta` y devuelve las filas de la vista para esa venta, ordenadas por renglón. Antes verifica que la venta exista en la vista; si no existe o no está en estado `PAGADA`, `ENVIADA` o `ENTREGADA`, lanza el error 50001 con `THROW`.

```sql
EXEC dbo.sp_comprobante_venta @id_venta = 7;
```
