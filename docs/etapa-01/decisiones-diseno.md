# Decisiones de Diseño — Etapa 1

## Introducción
Este documento expone los fundamentos detrás de las decisiones tomadas al definir el caso de negocio de Retro Games durante la Etapa 1. 

## 1. Delimitación del negocio a un único rubro

**Decisión:** definir el caso sobre un comercio de nicho (videojuegos retro, consolas y accesorios de colección) en lugar de un comercio genérico.

**Justificación:** un rubro específico permite establecer un dominio acotado y reconocible, con reglas propias (condición de conservación, carácter de colección) que enriquecen el modelo sin ambigüedad respecto a qué se vende y cómo.

## 2. Inclusión de un canal de venta online dentro del alcance

**Decisión:** incorporar la tienda en línea completa (exploración de catálogo, carrito y checkout) como parte del sistema, y no limitarlo a un backoffice interno de gestión.

**Justificación:** el proyecto está concebido como plataforma digital desde su descripción del caso, por lo que restringirlo a un panel administrativo dejaría fuera la función principal del negocio: la venta directa al cliente final.

## 3. Exclusión de proveedores, pagos externos y logística de envíos

**Decisión:** delimitar explícitamente el alcance dejando fuera la gestión de proveedores, la integración con pasarelas de pago reales y el seguimiento logístico de pedidos.

**Justificación:** estas funciones no son necesarias para cumplir el objetivo del proyecto (modelado de datos orientado a catálogo, stock y ventas) y su inclusión implicaría sobreingeniería fuera del foco de la materia.

## 4. Adopción de un modelo de roles simple

**Decisión:** contemplar únicamente dos perfiles de usuario, cliente y personal administrativo, sin niveles de permisos granulares.

**Justificación:** el negocio descripto no requiere jerarquías complejas de autorización; un esquema simple es suficiente para cubrir las operaciones definidas en el alcance (RN-05).

## 5. Condición de conservación como dato obligatorio del producto

**Decisión:** exigir que todo producto registre un estado de conservación válido (Nuevo, Usado, En Caja).

**Justificación:** al tratarse de artículos de colección, la condición física es un atributo determinante en la decisión de compra, a diferencia de un comercio de productos nuevos estándar (RN-04).

## 6. Registro de usuario obligatorio para concretar una venta

**Decisión:** exigir que toda venta esté asociada a un usuario registrado, sin permitir compras como invitado.

**Justificación:** garantiza trazabilidad del historial de compras y sustenta el requisito de contar con datos de contacto y dirección de envío para completar el checkout (RN-06, RN-08).

## 7. Definición de un umbral de stock mínimo por producto

**Decisión:** establecer que cada producto debe tener parametrizado un nivel de stock mínimo.

**Justificación:** dado el carácter limitado y no siempre reponible de los artículos retro/de colección, anticipar niveles críticos de inventario es clave para la gestión operativa (RN-07).

## 8. Congelamiento del precio al momento de la venta

**Decisión:** establecer como regla que el precio unitario registrado en cada venta no se vea afectado por cambios posteriores del catálogo.

**Justificación:** preserva la integridad histórica de los reportes de ventas y evita inconsistencias contables si el precio de un producto se actualiza luego de una operación ya concretada (RN-09).

## 9. Restricción a un único punto de venta

**Decisión:** limitar el alcance a la operatoria de un solo local/sucursal, sin contemplar gestión multi-sede.

**Justificación:** simplifica el caso de negocio a la realidad actual de la organización descripta, evitando complejidad adicional no solicitada por el proyecto.

## 10. Formalización de los métodos de pago habilitados

**Decisión:** exigir que toda venta utilice únicamente un método de pago previamente autorizado y parametrizado por la administración, en lugar de aceptar cualquier forma de pago libremente.

**Justificación:** da consistencia y control administrativo sobre las formas de cobro sin necesidad de integrar pasarelas externas, alineado con la exclusión definida en el punto 3 (RN-10).

---

## Resumen de Decisiones

| # | Decisión | Fundamento |
| :-- | :--- | :--- |
| 1 | Negocio de nicho (retro gaming) | Acotar el dominio del caso |
| 2 | Incluir tienda online en el alcance | Fidelidad al objetivo del negocio |
| 3 | Excluir proveedores, pagos y envíos | Delimitación del alcance |
| 4 | Roles simples (cliente/admin) | Alcance acotado del sistema |
| 5 | Condición de conservación obligatoria | Particularidad del rubro de colección |
| 6 | Venta asociada a usuario registrado | Trazabilidad e historial |
| 7 | Umbral de stock mínimo | Gestión proactiva de inventario |
| 8 | Precio congelado por venta | Integridad histórica |
| 9 | Único punto de venta | Simplicidad del caso |
| 10 | Métodos de pago autorizados | Control administrativo |
