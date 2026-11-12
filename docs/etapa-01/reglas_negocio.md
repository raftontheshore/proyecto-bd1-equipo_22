# Reglas de Negocio

## Introducción
Este documento expone los fundamentos detrás de las decisiones tomadas al definir el caso de negocio de Retro Games durante la Etapa 1\.

## Integridad de datos y conservación del historial

**RN-01: Validez de valores e importes**
Los precios, el precio unitario, la cantidad, el subtotal, el total y el monto del pago deben ser mayores a cero; el stock no puede ser negativo y el porcentaje de descuento debe estar entre 0 y 100. El total de una venta es la suma de los subtotales de sus ítems, y toda venta tiene al menos un ítem.

**RN-02: Protección del historial comercial**
Los registros que sustentan el historial del negocio no pueden eliminarse: usuarios con compras, direcciones usadas en ventas, productos ya vendidos, métodos de pago usados y ventas con pago. Solo puede eliminarse una venta sin pago (por ejemplo, un carrito), junto con sus ítems.

## Inventario y catálogo

**RN-03: Clasificación obligatoria de artículos**
Todo artículo del catálogo debe pertenecer a una y solo una categoría principal del negocio. No puede eliminarse una categoría que tenga productos asociados.

**RN-04: Registro de condición de conservación**
Todo producto registrado debe especificar un estado de conservación, que solo puede ser **Nuevo**, **Usado** o **En Caja**.

**RN-07: Definición de umbral de stock mínimo**
Todo producto del inventario debe tener definido un stock mínimo (5 unidades por defecto, ajustable por producto). Cuando el stock queda por debajo de ese umbral, el producto se considera en situación de stock bajo y requiere reposición.

## Usuarios y clientes

**RN-05: Asignación exclusiva de roles administrativos**
Existen únicamente dos roles: Cliente y Personal Administrativo. Solo los usuarios con rol de Personal Administrativo pueden modificar el catálogo, gestionar el stock y generar reportes.

**RN-06: Obligatoriedad de cuenta para operaciones de compra**
Toda venta debe estar asociada a un usuario registrado en el sistema; no se admiten compras como invitado.

**RN-08: Registro de datos obligatorios de clientes**
Todo cliente se registra con nombre, correo electrónico y contraseña. Para concretar una compra debe contar además con un número de contacto y una dirección de envío; toda venta se registra con una dirección de entrega.

**RN-11: Identificación única de usuarios**
Cada usuario se identifica por un correo electrónico válido (con `@` y dominio con punto) que no puede repetirse entre usuarios.

## Ventas, precios y pagos

**RN-09: Inmutabilidad histórica del precio unitario**
Cada detalle de venta debe conservar el precio unitario vigente al momento de la operación, sin verse afectado por cambios posteriores en el catálogo. El subtotal de cada ítem es siempre igual a la cantidad por el precio unitario registrado.

**RN-10: Validación de métodos de pago habilitados**
Toda venta debe registrarse utilizando únicamente un método de pago previamente autorizado por la administración. Un método de pago nuevo nace deshabilitado y solo puede usarse una vez que la administración lo habilita.

**RN-12: Estados de la venta**
Toda venta se encuentra en uno de estos estados: Carrito, Pendiente, Pagada, Enviada, Entregada o Cancelada. Una venta nueva nace en estado Pendiente. Enviada y Entregada son estados administrativos que registra el personal; el sistema no gestiona logística ni seguimiento de pedidos.

**RN-13: Un pago por venta**
Una venta admite como máximo un pago, cuyo monto debe ser igual al total de la venta. Las ventas en estado Carrito o Pendiente todavía no tienen pago registrado, y no puede registrarse un pago sobre un carrito.

## Resumen de Reglas de Negocio

| \#    | Regla                                                               | Fundamento                                     |
| :---- | :------------------------------------------------------------------ | :--------------------------------------------- |
| RN-01 | Importes positivos, total = suma de subtotales                      | Integridad de los valores monetarios           |
| RN-02 | No se elimina el historial comercial                                | Auditoría y trazabilidad                       |
| RN-03 | Una y solo una categoría por producto                               | Clasificación del catálogo                     |
| RN-04 | Estado de conservación obligatorio (Nuevo, Usado, En Caja)          | Particularidad del rubro de colección          |
| RN-05 | Solo el personal administrativo gestiona catálogo, stock y reportes | Control de accesos por rol                     |
| RN-06 | Toda venta asociada a un usuario registrado                         | Trazabilidad e historial                       |
| RN-07 | Stock mínimo definido por producto                                  | Gestión proactiva de reposición                |
| RN-08 | Cliente con nombre, contacto y dirección de envío para comprar      | Datos necesarios para el checkout              |
| RN-09 | Precio unitario congelado en el detalle de venta                    | Integridad histórica, sin cambios retroactivos |
| RN-10 | Solo métodos de pago autorizados por la administración              | Control administrativo de cobros               |
| RN-11 | Email válido y único por usuario                                    | Identificación inequívoca                      |
| RN-12 | Estados de venta definidos (sin logística)                          | Ciclo de vida administrativo de la venta       |
| RN-13 | Un solo pago por venta, igual al total                              | Consistencia contable                          |
