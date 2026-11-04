# Investigación: Manejo de Transacciones y Transacciones Anidadas

## 1. Definición y objetivo
Una transacción es un conjunto de operaciones SQL que se ejecutan como una única unidad lógica de trabajo: o se confirman todas (`COMMIT`) o se deshacen todas (`ROLLBACK`). Garantiza las propiedades **ACID**: Atomicidad (todo o nada), Consistencia (la base pasa de un estado válido a otro válido), Aislamiento (las transacciones concurrentes no se interfieren) y Durabilidad (lo confirmado permanece). El objetivo principal es evitar que una operación de negocio que afecta varias tablas quede a medias, dejando información incompleta o inconsistente.

## 2. Ventajas y aplicaciones
* **Atomicidad:** una venta involucra varias tablas (`venta_cabecera`, `venta_detalle`, `pago` y `productos`); si una falla, no debe quedar ninguna huella de las anteriores.
* **Consistencia del inventario:** el stock solo se descuenta si la venta se registró completa, evitando diferencias entre lo vendido y lo existente.
* **Control de concurrencia:** al bloquear la fila del producto durante la venta, dos compras simultáneas no pueden vender la misma última unidad.
* **Manejo de errores:** combinadas con `TRY...CATCH`, permiten deshacer todo ante cualquier fallo (stock insuficiente, método de pago inválido, caída de conexión) y avisar el motivo al cliente.
* **Indicadores de inventario al día:** al descontar el stock dentro de la misma transacción, también se actualiza la bandera `stock_bajo`, de modo que el aviso de reposición nunca queda desfasado respecto del stock real.
* **Integración con la auditoría:** los registros que generan los triggers de auditoría de `productos` (`trg_productos_auditoria_update` y `trg_productos_auditoria_delete`) se escriben dentro de la misma transacción; si la venta se deshace, la auditoría del cambio de stock también.
* **Composición de procesos:** gracias a las transacciones anidadas, un procedimiento con su propia transacción puede ser invocado desde otro proceso mayor sin perder la garantía de "todo o nada".

## 3. Implementación en SQL Server Express
SQL Server Express soporta transacciones explícitas con las siguientes sentencias y recursos:
* **`BEGIN TRANSACTION`:** inicia la transacción.
* **`COMMIT TRANSACTION`:** confirma de forma definitiva todos los cambios.
* **`ROLLBACK TRANSACTION`:** deshace todos los cambios realizados desde el inicio.
* **`BEGIN TRY ... BEGIN CATCH`:** captura los errores; en el `CATCH` se hace el `ROLLBACK` y se relanza el error con `THROW`.
* **`SET XACT_ABORT ON`:** ante un error en tiempo de ejecución, el motor cancela y revierte la transacción automáticamente, evitando transacciones abiertas por accidente.
* **`@@TRANCOUNT`:** indica cuántas transacciones hay abiertas; se consulta antes de hacer `ROLLBACK` para no provocar un error si ya fue revertida.
* **`SAVE TRANSACTION`:** crea un punto de guardado dentro de una transacción, para poder revertir solo una parte (ver sección 3.1).
* **Sugerencias de bloqueo (`UPDLOCK`, `ROWLOCK`):** al leer el stock con `UPDLOCK` se reserva la fila hasta el final de la transacción, evitando condiciones de carrera.
* **`CREATE OR ALTER`:** permite volver a ejecutar el script sin errores (requiere SQL Server 2016 SP1 o superior).

Esquema utilizado:

```sql
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
        -- 1. Validar stock (con bloqueo de la fila)
        -- 2. Registrar venta (cabecera)
        -- 3. Registrar detalle
        -- 4. Registrar pago
        -- 5. Descontar stock
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

A diferencia del esquema conceptual `IF stock < cantidad ... ROLLBACK ELSE COMMIT`, esta versión valida el stock **antes** de escribir y usa `TRY...CATCH`, de modo que cualquier error, no solo la falta de stock, deshace la operación.

### 3.1 Transacciones anidadas
Una transacción anidada ocurre cuando se ejecuta un `BEGIN TRANSACTION` estando ya dentro de otra transacción; por ejemplo, cuando un proceso con su propia transacción llama a un procedimiento que también abre una. En SQL Server, la anidación funciona con un **contador** y no con transacciones independientes:

* Cada `BEGIN TRANSACTION` suma 1 a `@@TRANCOUNT`.
* Un `COMMIT` interno **no confirma nada**: solo resta 1 al contador. Los datos se confirman de forma definitiva únicamente cuando el contador llega a 0, es decir, con el `COMMIT` de la transacción más externa.
* Un `ROLLBACK` deshace **todo**, incluso lo que parecía confirmado en la transacción interna, y deja `@@TRANCOUNT` en 0. Por eso un fallo en el procedimiento interno revierte también los cambios que había hecho la transacción externa.
* `SAVE TRANSACTION nombre` permite definir un punto de guardado; un `ROLLBACK TRANSACTION nombre` deshace solo lo realizado desde ese punto, sin cancelar la transacción completa. Es la única forma de revertir una parte sin perder el resto.

Consecuencia para el diseño: el procedimiento `sp_RegistrarVentaTransaccional` abre su propia transacción, y por lo tanto puede ejecutarse tanto de forma independiente como dentro de una transacción mayor. En el primer caso su `COMMIT` confirma los datos; en el segundo, los datos quedan confirmados recién cuando termina la transacción externa.

## 4. Caso concreto aplicado al sistema de Retro Games
**Escenario:** un cliente compra unidades de un producto del catálogo. La operación debe: (1) crear la venta, (2) crear el detalle con el precio congelado, (3) registrar el pago y (4) descontar el stock. Si no hay stock suficiente, o si cualquier paso falla:
* No se registra la venta.
* No se registra el detalle ni el pago.
* No se modifica el stock (ni se genera auditoría).

Se implementa en:
* **Procedimiento `sp_RegistrarVentaTransaccional`:** evoluciona al `sp_RegistrarVentaCompleta` de la etapa anterior, que ejecutaba sus inserciones sin transacción: si fallaba un paso intermedio (por ejemplo, el pago), quedaban la cabecera y el detalle guardados sin stock descontado. La nueva versión envuelve todo en una transacción, lee el stock con `UPDLOCK`, valida que el producto exista y esté activo, que el método de pago esté autorizado (RN-10), y devuelve el id de la venta generada.

**Mantenimiento de la bandera `stock_bajo` (RN-07):** el procedimiento de venta es el responsable de mantener la columna `productos.stock_bajo`. Al descontar el stock, en la misma sentencia `UPDATE` y dentro de la misma transacción, se recalcula la bandera: queda en `1` cuando el stock resultante es menor a `stock_minimo` (umbral de reposición) y en `0` en caso contrario. Como forma parte de la transacción, el stock y la bandera siempre cambian juntos: si la venta se revierte, ninguno de los dos se modifica. Este mantenimiento se hace desde el procedimiento y no desde un trigger, por lo que otras vías de modificación del stock (por ejemplo, una reposición manual) deberán recalcular la bandera por su cuenta.

**Uso anidado:** las pruebas 5 y 6 ejecutan el procedimiento dentro de una transacción externa. En la prueba 5 (caso exitoso) el `COMMIT` interno solo baja el contador y el `ROLLBACK` externo deshace todo. En la prueba 6 (caso con fallo) el `ROLLBACK` del procedimiento revierte también el cambio previo realizado por la transacción externa.

## 5. Script de demostración y pruebas
El código físico para la creación del procedimiento, junto con sus casos de prueba, se encuentra en el archivo `scripts.sql` adjunto en este directorio. Requiere haber ejecutado previamente `crear_bd.sql` y `datos_prueba.sql` (y, opcionalmente, el script de triggers para ver la auditoría). Se realizan seis pruebas:

| Prueba | Operación | Resultado esperado |
| :--- | :--- | :--- |
| 1 | Venta con stock suficiente | `COMMIT`: +1 cabecera, +1 detalle, +1 pago y stock descontado |
| 2 | Venta con stock insuficiente | `ROLLBACK`: ninguna tabla cambia |
| 3 | Fallo a mitad de la operación (método de pago inexistente) | `ROLLBACK`: se deshacen cabecera y detalle ya insertados; el stock no cambia |
| 4 | Transacción manual con `ROLLBACK` explícito | El stock vuelve al valor original y la auditoría no conserva el cambio |
| 5 | Venta que alcanza el umbral de reposición (stock 3, mínimo 3, se vende 1), dentro de una transacción externa | `stock_bajo` pasa de 0 a 1 junto con el descuento de stock; el `COMMIT` interno no persiste nada y el `ROLLBACK` externo revierte todo |
| 6 | Transacción anidada con fallo interno (la externa suma stock y el procedimiento falla por método de pago inexistente) | `ROLLBACK` total: no hay cabecera nueva y el stock vuelve al original, incluido el cambio de la transacción externa |

En cada prueba se comparan las cantidades de filas y el stock antes y después, demostrando que las operaciones son atómicas: o se registra la venta completa o no queda rastro de ella.

Los resultados visuales de la ejecución de estas pruebas en SQL Server Management Studio se documentan a través de capturas de pantalla (una por prueba), las cuales están alojadas dentro de la subcarpeta `evidencias/`.
