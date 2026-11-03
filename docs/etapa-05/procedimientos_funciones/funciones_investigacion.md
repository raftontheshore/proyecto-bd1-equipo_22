# Investigación: Procedimientos y Funciones Almacenadas

## 1. Definición y objetivo

Los procedimientos almacenados (Stored Procedures) son programas SQL alojados directamente dentro de la base de datos que tienen la capacidad de ejecutar múltiples operaciones secuenciales como una única llamada. Por otro lado, las funciones definidas por el usuario (Functions) son rutinas que reciben parámetros de entrada, procesan cálculos específicos y devuelven un valor único o un conjunto de datos en forma de tabla. El objetivo principal de ambos mecanismos es abstraer operaciones complejas del sistema y consolidarlas en la capa de la base de datos.

## 2. Ventajas y aplicaciones

La implementación de estos objetos en el motor de base de datos aporta múltiples beneficios arquitectónicos:

* **Reutilización y Mantenibilidad:** Reducen la repetición de código y simplifican el mantenimiento, ya que la lógica se programa una sola vez.

* **Centralización:** Permiten que las reglas comerciales (como cálculos de descuentos o validaciones de inventario) residan en un único componente.

* **Rendimiento:** Al ser conjuntos de instrucciones precompiladas, el motor SQL las ejecuta de manera más eficiente.

* **Seguridad:** Facilitan el control de acceso, permitiendo que los usuarios ejecuten acciones sobre los datos sin otorgarles permisos directos sobre las tablas subyacentes.

## 3. Implementación en SQL Server Express

En SQL Server Express, la sintaxis estándar utiliza `CREATE PROCEDURE` para los procedimientos y `CREATE FUNCTION` para las funciones. Las funciones suelen emplearse dentro de sentencias `SELECT`, `WHERE` o asignaciones para calcular valores al vuelo, mientras que los procedimientos se invocan mediante el comando `EXEC`, permitiendo realizar modificaciones de estado (`INSERT`, `UPDATE`, `DELETE`) en múltiples tablas simultáneamente.

## 4. Caso concreto aplicado al sistema de Retro Games

Para resolver las necesidades del negocio y cumplir con los requisitos técnicos, se aplicarán estos mecanismos tanto a la gestión del catálogo como al armado de ventas:

* **Procedimientos de Catálogo (CRUD):** Se implementarán los procedimientos `sp_InsertarProducto`, `sp_ActualizarPrecioProducto` y `sp_EliminarProductoLogico` sobre la tabla `productos` para manejar el inventario de forma segura e invocable.

* **Procedimiento Comercial (`sp_AgregarDetalleVenta`):** Un procedimiento diseñado para agregar ítems a una venta en estado "Pendiente" (RN-12). Este SP se encarga de: validar que la cantidad requerida sea mayor a cero (RN-01), validar la disponibilidad de inventario utilizando la función creada, congelar el precio vigente e insertar el detalle (RN-09), y finalmente actualizar el total de la cabecera sumando el nuevo subtotal.

* **Funciones Almacenadas:**

  1. **`fn_StockDisponible`:** Una función que, dado un identificador de producto, retorna la cantidad actual en inventario. Esto abstrae la lectura del stock y facilita su validación antes de cualquier transacción comercial.

  2. **`fn_CalcularSubtotal`:** Retorna el subtotal calculado (cantidad \* precio_unitario) de forma estandarizada.

## 5. Script de demostración y resultados obtenidos

El código físico para la creación de las funciones y los procedimientos, junto con sus respectivos casos de prueba (lotes de inserción directa vs. procedimientos, éxito al agregar un ítem válido, y error al intentar ingresar cantidades inválidas o sin stock), se encuentran en el archivo `scripts.sql` adjunto en este directorio.

Los resultados visuales de la ejecución de estas pruebas en SQL Server Management Studio se documentan a través de capturas de pantalla, las cuales están alojadas dentro de la subcarpeta `evidencias/`.