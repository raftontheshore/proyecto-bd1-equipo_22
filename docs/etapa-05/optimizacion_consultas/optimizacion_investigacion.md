# Investigación: Optimización de Consultas a través de Índices

## 1. Definición y objetivo
Un índice es una estructura que SQL Server mantiene junto a una tabla para localizar información de forma eficiente. Funciona como el índice de un libro: en lugar de recorrer todas las páginas para encontrar un tema, el motor consulta una estructura ordenada que le indica directamente dónde está el dato. Sin índices adecuados, una consulta que filtra por una columna obliga al motor a leer toda la tabla (*Table Scan*), y el tiempo de respuesta crece a medida que crece la cantidad de registros. El objetivo de esta etapa es medir el efecto de distintos tipos de índices sobre una consulta real del negocio (ventas de un período) y definir un conjunto de índices permanentes para las tablas de Retro Games.

### Conceptos y tipos de índices en SQL Server
* **Heap:** tabla sin índice agrupado; sus filas no tienen un orden físico. Cualquier búsqueda por una columna sin índice termina en un *Table Scan*.
* **Índice agrupado (*clustered*):** define el orden físico de la tabla, por lo que solo puede haber uno por tabla. Un rango de valores se lee como un bloque contiguo. Por defecto lo crea la clave primaria.
* **Índice no agrupado (*nonclustered*):** estructura separada, con su propio orden, que apunta a las filas de la tabla. Puede haber varios por tabla.
* **Índice con cobertura (columnas `INCLUDE`):** índice no agrupado que además guarda en sus hojas las columnas que la consulta devuelve. Si contiene todo lo que la consulta necesita, el motor la resuelve sin acceder a la tabla.
* **Operadores del plan de ejecución:**
  * *Scan:* recorre todo el índice o la tabla.
  * *Seek:* salta directamente al rango buscado.
  * *Lookup (Key/RID):* vuelve a la tabla por cada fila para traer una columna que el índice no contiene; es costoso si son muchas filas.

## 2. Ventajas y aplicaciones
* **Menor tiempo de respuesta:** las consultas de búsqueda leen una fracción de los datos.
* **Menos lecturas lógicas:** el motor analiza menos páginas, lo que reduce el uso de CPU y de disco.
* **Optimización de filtros y uniones:** aceleran los filtros por fechas, clientes o productos y los `JOIN` entre tablas relacionadas.
* **Escalabilidad:** el sistema sigue respondiendo bien aunque el volumen de datos crezca.

También tienen un costo que conviene conocer:
* **Espacio en disco:** cada índice es una copia parcial de los datos.
* **Escrituras más lentas:** cada `INSERT`, `UPDATE` o `DELETE` debe actualizar también los índices de la tabla.
* **Sin beneficio con pocos datos:** en tablas chicas el optimizador puede preferir un escaneo, porque leer todo es igual de barato.

Por eso no se indexa todo: se eligen las columnas que realmente se usan para filtrar, ordenar o unir tablas.

## 3. Implementación en SQL Server Express
Los índices se crean con `CREATE [CLUSTERED | NONCLUSTERED] INDEX` y se eliminan con `DROP INDEX`. Para medir el efecto se utilizan las siguientes herramientas de SQL Server Management Studio:
* **`SET STATISTICS TIME ON`:** informa el tiempo de CPU y el tiempo total de cada consulta.
* **`SET STATISTICS IO ON`:** informa las lecturas lógicas (páginas leídas), la métrica más estable para comparar, porque no depende tanto del hardware.
* **Plan de ejecución real (Ctrl + M):** muestra qué operadores eligió el motor (*Table Scan*, *Index Seek*, etc.) y el costo relativo de cada uno.
* **`CHECKPOINT` y `DBCC DROPCLEANBUFFERS`:** vacían la caché antes de cada medición para comparar lecturas reales de disco (solo en un servidor de pruebas).

## 4. Caso concreto aplicado al sistema de Retro Games
El negocio necesita analizar las ventas de determinados períodos. Cargar un millón de ventas simuladas en `venta_cabecera` contaminaría los datos reales (exigiría usuarios y direcciones ficticios y alteraría los reportes), por lo que el experimento se realiza sobre una tabla aparte, `venta_historica`, sin claves foráneas y con estructura análoga a la cabecera de ventas (fecha, importe y usuario). Se crea como *heap* a propósito: si tuviera una clave primaria agrupada, no podría crearse después un índice agrupado sobre la fecha.

El experimento compara tres escenarios con la misma consulta (ventas del primer trimestre de 2023):
1. **Sin índice:** se espera un *Table Scan* de toda la tabla.
2. **Índice agrupado sobre `fecha_venta`:** se espera un *Clustered Index Seek*.
3. **Índice no agrupado con cobertura** (`fecha_venta` con `importe` incluida): se espera un *Index Seek* sin acceso a la tabla. En este escenario la consulta no pide `id_venta`, porque al no estar en el índice obligaría a un *Lookup* por cada fila.

Además se mide el **costo de mantener el índice**, insertando 100.000 filas con y sin índice (ambas inserciones se revierten con `ROLLBACK`), y el **espacio** que ocupan la tabla y sus índices.

Finalmente, se definen los **índices permanentes** de las tablas reales. SQL Server no crea índices automáticamente sobre las claves foráneas, y cada FK sin índice vuelve lentos los `JOIN` y las verificaciones de integridad (por ejemplo, el borrado rechazado de un producto con ventas). Se crean 9 índices, sin duplicar los que ya existen por claves primarias y restricciones `UNIQUE`:

| Tabla | Índice | Columnas (y `INCLUDE`) | Consulta que optimiza |
| :--- | :--- | :--- | :--- |
| `venta_cabecera` | `IX_venta_cabecera_fecha` | `fecha_venta` + estado, total, id_usuario | Reportes de ventas por período |
| `venta_cabecera` | `IX_venta_cabecera_usuario` | `id_usuario, fecha_venta` + estado, total | Historial de compras de un cliente |
| `venta_cabecera` | `IX_venta_cabecera_direccion` | `id_direccion` | FK a dirección |
| `venta_detalle` | `IX_venta_detalle_cabecera` | `id_venta_cabecera` + producto, cantidad, precio, subtotal | Ítems de una venta |
| `venta_detalle` | `IX_venta_detalle_productos` | `id_productos` + cantidad, subtotal | Ventas por producto; FK a productos |
| `pago` | `IX_pago_metodo_pago` | `id_metodo_pago` + fecha, monto | Recaudación por método de pago |
| `productos` | `IX_productos_categoria` | `id_categoria` + nombre, precio, stock, activo | Catálogo por categoría |
| `productos` | `IX_productos_nombre` | `nombre` | Búsqueda por nombre (`LIKE 'texto%'`) |
| `usuario` | `IX_usuario_direccion` | `id_direccion` | FK a dirección |

Criterios aplicados: se evitan índices sobre columnas de poca selectividad (como las de tipo `BIT`: `activo`, `stock_bajo`) y se limita la cantidad de índices y de columnas incluidas, porque cada venta inserta en tres tablas y actualiza `productos`, por lo que cada índice adicional encarece la escritura.

## 5. Script de demostración y resultados obtenidos
El código físico del experimento y de los índices permanentes se encuentra en el archivo `optimizacion_scripts.sql` adjunto en este directorio. Requiere haber ejecutado previamente `crear_bd.sql`. El script se organiza en 10 partes:

| Parte | Contenido |
| :--- | :--- |
| 1 y 2 | Creación de `venta_historica` y carga de 1.000.000 de filas simuladas |
| 3 | Consulta sin índices (escenario 1) |
| 4 | Índice agrupado sobre la fecha (escenario 2) |
| 5 | Eliminación del índice agrupado |
| 6 | Índice con cobertura (escenario 3) |
| 7 | Costo de mantener un índice: inserción de 100.000 filas con y sin índice |
| 8 | Espacio ocupado por la tabla y sus índices |
| 9 | Índices permanentes de las tablas reales de Retro Games |
| 10 | Verificación de los índices creados y limpieza |

### Resultados de la comparación
Los valores se obtienen de la pestaña Messages (`STATISTICS TIME` e `IO`) y del plan de ejecución real. Varían según el hardware; lo importante es la comparación entre escenarios.

| Escenario | CPU (ms) | Tiempo total (ms) | Lecturas lógicas | Operación principal |
| :--- | :--- | :--- | :--- | :--- |
| Sin índice | 94 | 676 | 4082 | Table Scan |
| Índice agrupado sobre la fecha | 15 | 407 | 256 | Clustered Index Seek |
| Índice con cobertura | 15 | 512 | 164 | Index Seek |

Reducción respecto al escenario sin índice: con el índice agrupado, la CPU baja un 84 %, el tiempo total un 40 % y las lecturas lógicas un 94 %; con el índice con cobertura, la CPU baja un 84 %, el tiempo total un 24 % y las lecturas lógicas un 96 %.

### Costo de escritura y espacio

| Medición | Valor |
| :--- | :--- |
| Inserción de 100.000 filas **con** índice (CPU / tiempo total / lecturas) | 812 ms / 1657 ms / 440.872 lecturas lógicas |
| Inserción de 100.000 filas **sin** índice (CPU / tiempo total / lecturas) | 547 ms / 1016 ms / 100.408 lecturas lógicas |
| Espacio de la tabla (heap) | 35,20 MB |
| Espacio del índice con cobertura | 25,25 MB |

Los resultados visuales de la ejecución de estas pruebas en SQL Server Management Studio (mensajes de estadísticas y planes de ejecución) se documentan a través de capturas de pantalla, las cuales están alojadas dentro de la subcarpeta `evidencias/`.

## 6. Conclusiones
* **Sin índice:** la consulta recorre las 1.000.000 de filas (*Table Scan*) para devolver solo las de un trimestre; el trabajo es proporcional al tamaño de la tabla, no al de la respuesta. Se midieron 4082 lecturas lógicas, 94 ms de CPU y 676 ms de tiempo total.
* **Índice agrupado:** al ordenar físicamente la tabla por fecha, el motor salta al rango buscado y lee un bloque contiguo (*Clustered Index Seek*), con una reducción significativa de las lecturas lógicas: de 4082 a 256 (−94 %), con 15 ms de CPU y 407 ms de tiempo total.
* **Índice con cobertura:** al contener la columna de filtro y la devuelta, la consulta se resuelve solo con el índice y requiere aún menos lecturas (164, un 96 % menos que sin índice), porque no accede a la tabla. Su tiempo total (512 ms) resultó algo mayor que el del índice agrupado (407 ms) pese a leer menos páginas: con la caché vacía influyen las lecturas físicas y la variación entre ejecuciones, por eso la métrica más confiable para comparar es la de lecturas lógicas.
* **El costo existe:** la inserción de 100.000 filas con índice requirió 440.872 lecturas lógicas, 812 ms de CPU y 1657 ms, frente a 100.408 lecturas, 547 ms y 1016 ms sin índice (unas 4,4 veces más lecturas y un 63 % más de tiempo). Además, el índice con cobertura ocupa 25,25 MB, cerca del 72 % de los 35,20 MB de la tabla. Por eso en las tablas reales se indexan solo las claves foráneas y las columnas de filtro de las consultas frecuentes, y no se indexan columnas de poca selectividad.
* **Dependencia del volumen:** con los pocos datos de prueba de las tablas reales, el optimizador puede preferir un escaneo; el beneficio de los índices permanentes se manifiesta cuando crece la cantidad de ventas. En la verificación (Parte 10) se confirmó la creación de los 9 índices, de 0,016 MB cada uno, y la consulta de prueba sobre `venta_cabecera` devolvió solo 2 filas.
* **Diseño dirigido por las consultas:** un índice solo ayuda a las consultas que lo usan. La consulta del escenario 3 no pide `id_venta` justamente para poder ser cubierta por el índice; si la pidiera, el motor tendría que hacer un *Lookup* por cada fila.