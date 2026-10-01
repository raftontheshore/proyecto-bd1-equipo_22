# Restricciones de Integridad - Base de Datos RetroGames

Este documento detalla las reglas de integridad implementadas físicamente en la base de datos `RetroGames`, asegurando la consistencia y validez de los datos según las reglas de negocio.

## 1. Integridad de Entidad (Claves Primarias)
Todas las tablas utilizan un campo de identificación única auto-incremental (`IDENTITY(1,1)`) como clave primaria (Primary Key):
*   **categoria**: `id_categoria`
*   **direccion**: `id_direccion`
*   **metodo_pago**: `id_metodo_pago`
*   **productos**: `id_productos`
*   **usuario**: `id_usuario`
*   **venta_cabecera**: `id_venta_cabecera`
*   **venta_detalle**: `id_venta_detalle`
*   **pago**: `id_pago`

## 2. Integridad Referencial (Claves Foráneas y Acciones)
Las relaciones entre tablas definen el comportamiento ante actualizaciones o eliminaciones:
*   **productos -> categoria**: No se permite borrar una categoría si tiene productos asociados (`ON DELETE NO ACTION`). Se declara `ON UPDATE CASCADE`, pero como `id_categoria` es `IDENTITY` SQL Server no permite modificarla, por lo que esa cascada **nunca se dispara en la práctica**.
*   **usuario -> direccion**: Si se elimina una dirección, el registro del usuario conserva sus datos pero el campo de dirección queda nulo (`ON DELETE SET NULL`). No hay acción en actualización (`ON UPDATE NO ACTION`). Esto solo ocurre si la dirección **nunca fue destino de una venta**: si lo fue, `FK_venta_cabecera_direccion` (`NO ACTION`) rechaza el borrado. Si varios usuarios comparten la dirección, todos quedan con `NULL`.
*   **venta_cabecera -> usuario / direccion**: No se permite eliminar usuarios ni direcciones vinculadas a una venta para conservar el historial (`ON DELETE NO ACTION`, `ON UPDATE NO ACTION`).
*   **venta_detalle -> productos**: No se permite borrar un producto que ya forma parte de una venta (`ON DELETE NO ACTION`, `ON UPDATE NO ACTION`).
*   **venta_detalle -> venta_cabecera**: Si se elimina una venta cabecera, se eliminan automáticamente sus detalles (`ON DELETE CASCADE`). Se declara también `ON UPDATE CASCADE`, que al igual que en `productos -> categoria` nunca se dispara porque la PK es `IDENTITY`. Una venta con pago asociado no puede eliminarse (ver `pago`).
*   **pago -> venta_cabecera / metodo_pago**: Al ser registros contables, no se permite borrar pagos en cascada al eliminar ventas o métodos de pago (`ON DELETE NO ACTION`, `ON UPDATE NO ACTION`).

## 3. Integridad de Dominio (Validaciones, Valores por Defecto y Unicidad)
Se aplican restricciones específicas a nivel de columna para asegurar que los datos ingresados sean válidos.

**Tabla `categoria` y `metodo_pago`:**
*   El campo `nombre` no permite valores nulos y debe ser único para evitar duplicados (`UNIQUE`).
*   En métodos de pago, el estado `activo` no permite nulos y por defecto es `0` (deshabilitado): un método nuevo debe ser autorizado explícitamente por la administración antes de poder usarse (RN-10).

**Tabla `productos`:**
*   **Precios:** El `precio` es obligatorio y debe ser estrictamente mayor a 0. El `precio_original` (si se provee) debe ser mayor a 0.
*   **Descuentos:** El `porcentaje_descuento` (si se provee) debe estar entre 0 y 100.
*   **Stock:** El `stock` (si se provee) debe ser mayor o igual a 0, con un valor por defecto de 0. El `stock_minimo` es obligatorio, asume el valor por defecto de 5, y debe ser mayor o igual a 0. El indicador de `stock_bajo` asume el valor por defecto de 0; es un campo derivado (`stock < stock_minimo`) que el esquema no recalcula, por lo que un producto creado con los valores por defecto queda con `stock_bajo = 0` aunque `stock (0) < stock_minimo (5)`.
*   **Conservación:** El campo `estado_conservacion` es obligatorio y solo admite los valores: `'NUEVO'`, `'USADO'` o `'EN_CAJA'`.
*   **Categoría:** El campo `id_categoria` es obligatorio: todo producto pertenece a una categoría.
*   **Estado:** El campo `activo` asume el valor por defecto de 1.

**Tabla `usuario`:**
*   **Email:** Es obligatorio, debe ser único (`UNIQUE`) y debe contener una estructura válida incluyendo un `@` y un punto (`LIKE '%_@_%._%'`).
*   **Rol:** Es obligatorio, por defecto es `'CLIENTE'`, y solo admite los valores `'ADMIN'` o `'CLIENTE'`.
*   **Estado:** El campo `activo` asume el valor por defecto de 1.

**Tabla `venta_cabecera`:**
*   **Fecha:** Si no se envía fecha, por defecto se registra el momento exacto de la inserción (`GETDATE()`) y no admite nulos.
*   **Estado:** Es obligatorio, su valor por defecto es `'PENDIENTE'`, y solo admite los estados: `'PENDIENTE'`, `'PAGADA'`, `'ENVIADA'`, `'ENTREGADA'`, `'CANCELADA'` o `'CARRITO'`. `ENVIADA` y `ENTREGADA` son estados administrativos de la venta; el sistema no gestiona logística ni seguimiento de pedidos.
*   **Total:** Es obligatorio y debe ser mayor a 0.
*   **Usuario y dirección:** `id_usuario` e `id_direccion` son obligatorios (no se admiten ventas anónimas ni sin dirección de entrega).
*   **Carrito:** como `total > 0` y `id_direccion` es obligatoria, una venta en estado `CARRITO` debe crearse con al menos un ítem y con dirección de entrega.

**Tabla `venta_detalle`:**
*   La `cantidad` y el `precio_unitario` son obligatorios y deben ser mayores a 0.
*   El `subtotal` es obligatorio, debe ser mayor a 0, y el sistema valida matemáticamente que sea exactamente el resultado de multiplicar la `cantidad` por el `precio_unitario` (`subtotal = cantidad * precio_unitario`).
*   `id_productos` e `id_venta_cabecera` son obligatorias.

**Tabla `pago`:**
*   **Unicidad:** La columna `id_venta_cabecera` es `UNIQUE`, garantizando como máximo un pago por venta (cardinalidad 0..1: las ventas `PENDIENTE` o `CARRITO` todavía no tienen pago).
*   **Fecha y Monto:** La `fecha_pago` asume por defecto la fecha actual (`GETDATE()`) y el `monto` debe ser mayor a 0. Ninguno admite valores nulos.
*   `id_venta_cabecera` e `id_metodo_pago` son obligatorias.

## 4. Índices
Además de los índices implícitos de las claves primarias y las restricciones `UNIQUE`, se crearon índices no agrupados sobre las claves foráneas: `IX_productos_categoria`, `IX_usuario_direccion`, `IX_venta_cabecera_usuario`, `IX_venta_cabecera_direccion`, `IX_venta_detalle_productos`, `IX_venta_detalle_cabecera` e `IX_pago_metodo_pago`.
