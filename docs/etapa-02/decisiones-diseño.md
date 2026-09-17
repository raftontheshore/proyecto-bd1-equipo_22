# Decisiones de Diseño

## Introducción
Este documento expone los fundamentos que sustentan el diseño del modelo de datos de Retro Games. Las decisiones tomadas surgen de un análisis de las necesidades y el contexto del proyecto, con el fin de asegurar el correcto funcionamiento del sistema. Asimismo, estas se respaldan y documentan a través de los siguientes archivos: la definición del caso y su alcance (descripcion-caso.md, alcance.md), el proceso de refinamiento de datos (normalizacion.md) y los modelos resultantes (der/der.png y modelo-relacional.md).

## 1. Separación de `venta_cabecera` y `venta_detalle`

**Decisión:** dividir la venta en dos entidades en lugar de una sola tabla `venta`.

**Justificación:** una venta puede incluir múltiples productos, lo que generaría atributos repetidos (grupos multivaluados) si se modelara en una única tabla, violando la 1FN. Al separar los datos generales de la transacción (`venta_cabecera`) de los ítems comprados (`venta_detalle`), se logra una estructura atómica, se evita la redundancia y se permite registrar cualquier cantidad de productos por venta sin modificar el esquema.

## 2. Entidad `productos` independiente de `venta_detalle`

**Decisión:** extraer los atributos descriptivos del producto (`nombre`, `descripcion`, `marca`, `consola`, etc.) hacia una tabla `productos` propia, en lugar de repetirlos en cada detalle de venta.

**Justificación:** estos atributos dependen únicamente del producto y no de la venta en la que participan (dependencia parcial resuelta en 2FN). Mantenerlos en `venta_detalle` generaría alta redundancia cada vez que un mismo producto se vendiera más de una vez, además de riesgo de inconsistencias si el precio o nombre de un producto cambiara.

## 3. Manejo del precio: `precio_original`, `precio` y `porcentaje_descuento`

**Decisión:** incluir tres campos relacionados al precio en `productos`, en lugar de un único campo `precio`.

**Justificación:** el alcance contempla ofertas/descuentos sobre el catálogo. Guardar el precio original y el porcentaje de descuento permite calcular y mostrar el precio final sin perder el dato histórico del valor de lista, útil tanto para la vista de catálogo (mostrar "antes/ahora") como para reportes estadísticos de ventas.

## 4. `stock_bajo` como campo booleano

**Decisión:** agregar un campo `stock_bajo` en `productos` en lugar de calcularlo siempre dinámicamente contra un umbral.

**Justificación:** permite marcar y filtrar rápidamente productos con inventario crítico desde el panel administrativo (parte del alcance: "control de stock e inventario") sin recalcular sobre toda la tabla en cada consulta, priorizando la velocidad de lectura en el catálogo y en las alertas del panel.

## 5. Campo `activo` en `productos` y `usuario` (baja lógica)

**Decisión:** utilizar un atributo `activo` (booleano) en lugar de eliminar físicamente registros de productos o usuarios.

**Justificación:** un producto o usuario dado de baja puede estar referenciado por ventas históricas (`venta_detalle`, `venta_cabecera`). Eliminarlo físicamente rompería la integridad referencial y el historial de ventas. La baja lógica preserva la trazabilidad de la información sin afectar los reportes ni las FK existentes.

## 6. Entidad `categoria` separada de `productos`

**Decisión:** crear una tabla `categoria` independiente y referenciarla desde `productos` mediante `id_categoria` (FK).

**Justificación:** en el modelo inicial la categoría era un atributo de texto libre repetido en cada producto, generando una dependencia transitiva (3FN) y redundancia. Separarla permite estandarizar nombres de categoría, evitar inconsistencias de tipeo y administrar el catálogo de categorías desde el panel administrativo de forma centralizada.

## 7. Entidad `direccion` independiente, compartida por `usuario` y `venta_cabecera`

**Decisión:** modelar `direccion` como entidad propia en lugar de campos de dirección embebidos directamente en `usuario` y en `venta_cabecera`.

**Justificación:** la dirección es utilizada en dos contextos distintos: como dato del cliente (`usuario` → `direccion`, relación **1..1** opcional) y como destino de envío de una venta puntual (`venta_cabecera` → `direccion`, relación **N..1**). Separarla evita duplicar los campos de dirección en ambas tablas y permite que una venta se envíe a una dirección distinta a la registrada por defecto en el perfil del usuario.

## 8. Relación `usuario`–`direccion` como 1..1 opcional

**Decisión:** la FK `id_direccion` en `usuario` puede ser nula (opcional), a diferencia de la FK del mismo nombre en `venta_cabecera`, que es obligatoria.

**Justificación:** un usuario puede registrarse y navegar el catálogo sin haber cargado aún una dirección (por ejemplo, antes de su primera compra), pero toda venta concretada sí necesita una dirección de entrega definida para poder completarse, conforme al proceso de checkout descripto en el alcance.

## 9. `id_venta_detalle` como clave primaria simple (no compuesta)

**Decisión:** en lugar de usar una clave primaria compuesta (`id_venta_cabecera` + `id_productos`), se define un identificador propio `id_venta_detalle`.

**Justificación:** una clave compuesta impediría que un mismo producto apareciera más de una vez en distintas líneas de una misma venta (por ejemplo, si se agregan cantidades en momentos distintos del carrito) y complicaría las referencias desde otras posibles funcionalidades (reportes, devoluciones). Un identificador simple simplifica las relaciones y consultas, manteniendo igualmente ambas FK para preservar la trazabilidad hacia `productos` y `venta_cabecera`.

## 10. `rol` como atributo de `usuario` y no como entidad aparte

**Decisión:** representar el rol del usuario (cliente / administrador) como un campo `rol` dentro de la propia tabla `usuario`, sin crear una tabla `roles` independiente.

**Justificación:** el alcance define un modelo simple de dos perfiles (cliente y personal administrativo) sin permisos granulares ni jerarquías de roles. Crear una entidad adicional agregaría complejidad innecesaria para el nivel de control requerido por el sistema.

## 11. No inclusión de entidades de proveedores, pagos ni envíos

**Decisión:** el modelo no contempla tablas para proveedores, medios de pago externos ni logística/seguimiento de pedidos.

**Justificación:** estas funcionalidades están explícitamente excluidas del alcance del sistema (`alcance.md`), por lo que incorporarlas incumpliría el principio de diseñar el modelo estrictamente en función de los requerimientos definidos, evitando sobreingeniería.

## 12. Cardinalidades N..1 desde `productos` y `venta_cabecera` hacia sus entidades padre

**Decisión:** todas las relaciones del modelo son de tipo **1 a N** (nunca N a N), resolviendo cualquier relación de muchos a muchos mediante tablas intermedias.

**Justificación:** la relación conceptual "muchos productos por muchas ventas" se resuelve mediante `venta_detalle`, que actúa como tabla asociativa entre `productos` y `venta_cabecera`, transformando una relación N a N en dos relaciones 1 a N. Esto es coherente con el modelo relacional estándar, que no admite relaciones N a N directas entre tablas.

---

## Resumen de Decisiones

| # | Decisión | Principio aplicado |
| :-- | :--- | :--- |
| 1 | Separar `venta_cabecera` y `venta_detalle` | 1FN – Atomicidad |
| 2 | Extraer `productos` de `venta_detalle` | 2FN – Dependencia total de la clave |
| 3 | `precio_original` + `porcentaje_descuento` | Regla de negocio (ofertas) |
| 4 | `stock_bajo` booleano | Rendimiento / regla de negocio |
| 5 | `activo` en `productos` y `usuario` | Integridad referencial / historial |
| 6 | `categoria` como entidad propia | 3FN – Dependencia transitiva |
| 7 | `direccion` como entidad propia | 3FN – Reutilización de datos |
| 8 | FK opcional `usuario` → `direccion` | Regla de negocio (registro sin dirección) |
| 9 | PK simple en `venta_detalle` | Simplicidad y flexibilidad del modelo |
| 10 | `rol` como atributo simple | Alcance acotado del sistema |
| 11 | Exclusión de proveedores/pagos/envíos | Delimitación del alcance |
| 12 | Resolución de N a N vía tabla asociativa | Modelo relacional estándar |
