# Documento de Implementación y Decisiones Técnicas (RetroGames).

Este documento justifica las decisiones técnicas tomadas durante la fase de implementación física (Modelo Relacional a SQL Server). El objetivo de este diseño DDL es delegar la mayor cantidad de validaciones de reglas de negocio directamente al motor de la base de datos, garantizando la consistencia y seguridad de la información sin depender exclusivamente de la lógica del backend o frontend.

## 1. Integridad de Dominio y Validaciones de Negocio (CHECK)

Se implementaron restricciones `CHECK` para materializar reglas de negocio (RN) directamente en la estructura de las tablas:

* **Regla de Negocio:** Un producto debe tener un estado de conservación válido y obligatorio (RN-04).


* **Implementación:** `CONSTRAINT CK_productos_conservacion CHECK (estado_conservacion IN ('NUEVO', 'USADO', 'EN_CAJA'))`.


* **Justificación:** Limita el dominio de la columna a valores estandarizados, evitando errores de tipeo y asegurando que los filtros de búsqueda en la aplicación funcionen correctamente.


* **Regla de Negocio:** El subtotal de un ítem vendido debe ser matemáticamente consistente.


* **Implementación:** `CONSTRAINT CK_venta_detalle_subtotal CHECK (subtotal > 0 AND subtotal = cantidad * precio_unitario)`.


* **Justificación:** Se agrega una validación aritmética a nivel de motor. Esto impide de forma absoluta anomalías de datos (por ejemplo, registrar 2 productos a $100 y que el subtotal diga $50).




* **Regla de Negocio:** Todo usuario debe registrar un correo electrónico válido.


* **Implementación:** `CONSTRAINT CK_usuario_email CHECK (email LIKE '%_@_%._%')`.


* **Justificación:** Actúa como una primera barrera de seguridad estructural. Si la aplicación intenta guardar un formato erróneo, el motor aborta la transacción inmediatamente.



## 2. Tipos de Datos Sensibles (Estructura y Precisión)

* **Regla de Negocio:** Los valores monetarios deben ser exactos para contabilidad.


* **Implementación:** Uso de `DECIMAL(10,2)` y `DECIMAL(12,2)` para los campos de precio, subtotal y total.


* **Justificación:** Se descartan los tipos de coma flotante (`FLOAT` o `REAL`) porque pueden generar errores de redondeo impredecibles en operaciones financieras.


* **Regla de Negocio:** Contraseñas seguras.


* **Implementación:** `[password] VARCHAR(255) NOT NULL`.


* **Justificación:** Se previó un almacenamiento amplio (255 caracteres) para soportar métodos robustos de hashing (ej. bcrypt, Argon2) que requieren longitudes variables mayores a un string estándar.





## 3. Automatización y Estados por Defecto (DEFAULT)

Para agilizar los procesos de inserción (`INSERT`) y asegurar el cumplimiento de valores por defecto en la lógica de negocio, se utilizaron restricciones `DEFAULT`:

* **Regla de Negocio:** El umbral de reposición (RN-07) y los métodos de pago autorizados (RN-10) deben autoconfigurarse.


* **Implementación:** `DF_productos_stock_minimo DEFAULT 5` y `DF_metodo_pago_activo DEFAULT 1`.


* **Justificación:** Permite que la capa de aplicación omita estos campos en la inserción si se trata de un flujo estándar. El motor asume la responsabilidad de establecer el stock mínimo en 5 y habilitar el método de pago por defecto.



## 4. Gestión del Historial y Comportamientos de Eliminación (FOREIGN KEY)

El diseño de las restricciones de integridad referencial contempla la protección de los datos históricos financieros del negocio:

* **Regla de Negocio:** Resguardo de auditoría en el flujo de caja e historial de compras.


* **Implementación:** Relaciones de venta (`venta_cabecera`) y pagos (`pago`) utilizan `ON DELETE NO ACTION`.


* **Justificación:** Como son registros contables, está estrictamente prohibido eliminarlos en cascada. Si se intenta borrar un usuario con historial de compras, el motor arrojará una excepción referencial.




* **Regla de Negocio:** Eliminación limpia de datos prescindibles.


* **Implementación:** La relación de `usuario -> direccion` utiliza `ON DELETE SET NULL`, y la relación `venta_detalle -> venta_cabecera` utiliza `ON DELETE CASCADE`.


* **Justificación:** Si un usuario elimina una de sus direcciones, su cuenta se mantiene intacta pero el puntero de dirección pasa a estar vacío de forma automática (`SET NULL`). Por otro lado, si se cancela y purga un carrito/venta, sus ítems en detalle se destruyen en cascada, evitando dejar registros huérfanos (`CASCADE`).





## 5. Representación Física de Cardinalidades (UNIQUE)

* **Regla de Negocio:** Una operación de venta debe contar con un solo pago (Relación 1 a 1).


* **Implementación:** `CONSTRAINT UQ_pago_venta UNIQUE (id_venta_cabecera)` en la tabla `pago`.


* **Justificación:** Al aplicar unicidad sobre la clave foránea en la tabla secundaria, el motor impide físicamente que se ingresen múltiples registros de pago vinculados a una misma cabecera de venta, asegurando a nivel de esquema la cardinalidad 1..1 planificada en el diseño conceptual.