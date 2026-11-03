# Investigación: Triggers (Auditoría y Control de Operaciones)

## 1. Definición y objetivo
Los triggers (disparadores) son procedimientos especiales que se almacenan en la base de datos y se ejecutan de forma automática cuando ocurre un evento sobre una tabla: un `INSERT`, un `UPDATE` o un `DELETE`. A diferencia de un procedimiento almacenado, no se invocan manualmente con `EXEC`: es el propio motor quien los dispara, sin importar desde qué aplicación o usuario se realizó la operación. Se utilizan con frecuencia para auditoría y trazabilidad (registrar quién cambió qué y cuándo) y para controlar operaciones (impedir o validar cambios). El objetivo de esta etapa es aplicarlos de ambas formas sobre el sistema de Retro Games: registrar los valores previos de los productos ante cada modificación o borrado, y bloquear el borrado de registros que no deben eliminarse.

### Tipos de triggers en SQL Server
* **Según el momento de ejecución (triggers DML):**
  * **`AFTER` (o `FOR`):** se ejecutan *después* de que la operación se realizó. Sirven para registrar lo ocurrido (auditoría) o validar el resultado; si el trigger falla, la operación se deshace. Solo pueden definirse sobre tablas.
  * **`INSTEAD OF`:** se ejecutan *en lugar de* la operación original, que no se realiza salvo que el propio trigger la haga. Sirven para bloquear operaciones, reemplazarlas o hacer modificables ciertas vistas.
* **Según el evento:** de `INSERT`, de `UPDATE`, de `DELETE`, o combinados en un mismo trigger.
* **Otras categorías:** los triggers **DDL** responden a cambios de estructura (`CREATE`, `ALTER`, `DROP`) y los triggers de **logon** responden a inicios de sesión. En este trabajo se utilizan únicamente triggers DML.

## 2. Ventajas y aplicaciones
La implementación de triggers en el motor de base de datos aporta los siguientes beneficios:
* **Trazabilidad:** permiten responder preguntas como ¿quién modificó un precio?, ¿cuándo se eliminó un producto? o ¿qué valor tenía antes del cambio?
* **Automatización:** el registro se genera solo, sin código adicional en la aplicación cliente ni intervención del usuario.
* **Cobertura total:** al residir en la tabla, controlan cualquier cambio, incluso los hechos directamente desde SQL Server Management Studio o por scripts, que una auditoría programada en la aplicación no vería.
* **Integridad y seguridad:** pueden impedir operaciones que no deben ocurrir (por ejemplo, borrar registros contables) aunque el usuario tenga permisos sobre la tabla.
* **Respaldo de reglas de negocio:** complementan la protección del historial comercial definida en RN-02.

También tienen contras que conviene conocer: agregan trabajo a cada operación sobre la tabla, su ejecución es "invisible" para quien programa la aplicación y, si se abusa de ellos, vuelven difícil seguir el flujo de la lógica. Por eso se aplican a casos puntuales como los de este trabajo.

## 3. Implementación en SQL Server Express
SQL Server Express soporta triggers `AFTER` e `INSTEAD OF` mediante la sentencia `CREATE TRIGGER`. Dentro del trigger el motor expone dos tablas lógicas temporales:
* **`inserted`:** contiene las filas nuevas (en un `INSERT`) o los valores nuevos (en un `UPDATE`).
* **`deleted`:** contiene las filas eliminadas (en un `DELETE`) o los valores anteriores (en un `UPDATE`).

Otros recursos utilizados en la implementación:
* **Procesamiento por conjuntos:** el trigger se ejecuta una sola vez por sentencia, no una vez por fila, por lo que se programa para registrar una fila de auditoría por cada producto afectado (`INSERT ... SELECT` desde `deleted`).
* **`SUSER_SNAME()` y `USER_NAME()`:** devuelven el login de SQL Server y el usuario de la base de datos que realizó la operación; se usan como valores por defecto (`DEFAULT`) de la tabla de auditoría.
* **`THROW`:** emite un mensaje de error personalizado. Dentro de un trigger, además, cancela la sentencia y deshace la transacción.
* **`CREATE OR ALTER` y `DROP ... IF EXISTS`:** permiten volver a ejecutar el script sin errores (requiere SQL Server 2016 SP1 o superior).

## 4. Caso concreto aplicado al sistema de Retro Games
El catálogo es el activo más sensible del negocio: un cambio de precio o de stock no registrado genera errores en el inventario y en los reportes de ventas, que es justamente parte de la problemática que el sistema busca resolver. Por otro lado, los pagos son registros contables que, según la regla RN-02, no deben eliminarse. Se implementan tres triggers:

* **Tabla `auditoria_producto`:** copia todas las columnas de `productos` y guarda los valores que tenía el registro *antes* del cambio, junto con el tipo de operación, la fecha y hora, el login de SQL Server y el usuario de la base de datos. No tiene clave foránea hacia `productos` a propósito, para que el historial de un producto eliminado se conserve.
* **`trg_productos_auditoria_update` (`AFTER UPDATE` sobre `productos`):** ante cualquier modificación, sin importar qué columna cambió, guarda en la auditoría el registro con sus valores anteriores. Una sentencia que modifica varios productos genera una fila por cada uno.
* **`trg_productos_auditoria_delete` (`AFTER DELETE` sobre `productos`):** guarda el registro completo del producto eliminado. Solo se dispara si el borrado se concreta: si lo rechaza una clave foránea (producto con ventas), no deja registro.
* **`trg_pago_bloquear_delete` (`INSTEAD OF DELETE` sobre `pago`):** ante un intento de borrar un pago, emite un mensaje de error y no realiza la operación. Se eligió la tabla `pago` porque ninguna clave foránea impide borrar sus filas (es tabla hija), de modo que solo un trigger puede proteger ese dato.

## 5. Script de demostración y resultados obtenidos
El código físico para la creación de la tabla de auditoría y de los triggers, junto con sus casos de prueba y consultas de auditoría, se encuentra en el archivo `scripts.sql` adjunto en este directorio. Requiere haber ejecutado previamente `crear_bd.sql` y `datos_prueba.sql`. Se realizan nueve pruebas (0 a 8):

| Prueba | Operación | Resultado |
| :--- | :--- | :--- |
| 0 | Verificación de instalación | Los 3 triggers aparecen habilitados y la auditoría está vacía |
| 1 | `UPDATE` de precio (producto 4: 25.000 → 28.000) | Se registra 1 fila con el precio, precio original y stock anteriores |
| 2 | `UPDATE` de stock (producto 3: 3 → 5) | Se registra 1 fila con el stock anterior (3) |
| 3 | `UPDATE` masivo: +10% a la categoría 1 | Una sola sentencia genera 2 filas, una por producto afectado |
| 4 | `UPDATE` de la descripción (producto 1) | Se registra 1 fila: cualquier columna se audita |
| 5 | `DELETE` de un producto sin ventas | El `INSERT` previo no se audita; el `DELETE` guarda el registro completo |
| 6 | `DELETE` de un producto con ventas | Lo rechaza la clave foránea y no se registra nada |
| 7 | `DELETE` de un pago puntual | El trigger emite el mensaje y el pago sigue existiendo |
| 8 | `DELETE` de toda la tabla `pago` | El trigger lo bloquea y la cantidad de pagos no cambia |

Partiendo de `datos_prueba.sql` recién cargado, la auditoría termina con 6 filas (5 `UPDATE` y 1 `DELETE`). Las consultas finales permiten ver el historial completo, los valores anteriores de los productos modificados con su responsable, y los productos eliminados.

**Nota sobre la recarga de datos:** con el trigger de bloqueo instalado, `datos_prueba.sql` falla en su primer `DELETE FROM dbo.pago`. Para recargar los datos sin recrear las tablas hay que deshabilitar temporalmente el trigger (`DISABLE TRIGGER`) y volver a habilitarlo después (`ENABLE TRIGGER`).

Los resultados visuales de la ejecución de estas pruebas en SQL Server Management Studio se documentan a través de capturas de pantalla, las cuales están alojadas dentro de la subcarpeta `evidencias/`.

## 6. Conclusiones
* **Funcionalidad:** los triggers de auditoría registraron automáticamente cada modificación y cada borrado de productos, incluida una actualización masiva (una fila por producto) y el cambio de una columna secundaria como la descripción. El trigger de bloqueo impidió eliminar pagos, tanto de forma puntual como masiva, y emitió el mensaje definido.
* **Trazabilidad:** la tabla `auditoria_producto` permite saber qué valor tenía un producto antes del cambio, cuándo ocurrió y qué login y usuario de la base lo realizó. Al no tener clave foránea, el historial de un producto eliminado se conserva con todos sus datos, por lo que incluso un borrado puede reconstruirse.
* **Integridad de los datos:** el trigger `INSTEAD OF DELETE` protege la información contable que ninguna clave foránea cubre, reforzando RN-02. La prueba del producto con ventas muestra además que ambos mecanismos se complementan: la clave foránea protege los productos vendidos y el trigger protege los pagos. Cuando el borrado se rechaza, la auditoría no registra nada, por lo que no quedan datos inconsistentes.
* **Seguridad:** al ejecutarse dentro del motor, la auditoría y el bloqueo valen para cualquier acceso a la base, sea desde la aplicación, desde SSMS o desde un script, y no dependen de que cada programa los implemente.
* **Limitaciones y mejoras posibles:** la auditoría guarda solo los valores anteriores (el valor nuevo se deduce de la fila siguiente o del estado actual), no registra los `INSERT` y toda modificación genera una fila aunque los valores no cambien. Además, el bloqueo de `pago` obliga a deshabilitar el trigger para recargar datos de prueba. Como mejoras se podrían guardar también los valores nuevos y extender la auditoría a otras tablas como `usuario` o `venta_cabecera`.
