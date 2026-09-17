# Reglas de Negocio

**RN-01: Validación de disponibilidad de inventario**
La cantidad de unidades solicitadas en un detalle de venta no puede superar el stock físico disponible del producto.

**RN-02: Consistencia del stock por transacción**
Toda venta concretada debe reducir el stock del producto asociado en una cantidad exactamente igual a las unidades vendidas.

**RN-03: Clasificación obligatoria de artículos**
Todo artículo del catálogo debe pertenecer a una y solo una categoría principal del negocio.

**RN-04: Registro de condición de conservación**
Todo producto registrado debe especificar un estado de conservación válido (ej. Nuevo, Usado, En Caja).

**RN-05: Asignación exclusiva de roles administrativos**
Solo los usuarios con rol de Personal Administrativo pueden modificar el catálogo, gestionar el stock y generar reportes.

**RN-06: Obligatoriedad de cuenta para operaciones de compra**
Toda venta debe estar asociada a un usuario registrado en el sistema.

**RN-07: Definición de umbral de stock mínimo**
Todo producto del inventario debe tener definido un stock mínimo que indique cuándo requiere reposición.

**RN-08: Registro de datos obligatorios de clientes**
Todo cliente registrado debe contar con nombre, número de contacto y dirección de envío.

**RN-09: Inmutabilidad histórica del precio unitario**
Cada detalle de venta debe conservar el precio unitario vigente al momento de la operación, sin verse afectado por cambios posteriores en el catálogo.

**RN-10: Validación de métodos de pago habilitados**
Toda venta debe registrarse utilizando únicamente un método de pago previamente autorizado por la administración.

