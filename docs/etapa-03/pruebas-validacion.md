# Pruebas de Validación - Base de Datos RetroGames (Etapa III)

## 1. Objetivo y alcance

Este documento demuestra que los mecanismos de integridad definidos en `crear_bd.sql` (PK, FK, CHECK, UNIQUE, NOT NULL y DEFAULT) funcionan correctamente. Las pruebas se derivan de las reglas descriptas en `restricciones-integridad.md`, del modelo de `modelo-relacional.md` y se ejecutan sobre los datos cargados por `datos_prueba.sql`.

Cada tabla incluye:

* **Pruebas de camino feliz (Happy Path):** operaciones válidas que deben ejecutarse con éxito.
* **Pruebas negativas (Negative Testing):** operaciones que violan una restricción a propósito y **deben fallar**.
* **Hallazgos (⚠️):** casos donde el esquema actual *acepta* un dato que, por reglas de negocio, quizá no debería aceptar. Se documentan con honestidad en la sección 13.

## 2. Entorno y convenciones de ejecución

* **Motor:** SQL Server / Transact-SQL. **Base:** `RetroGames`, con `datos_prueba.sql` ya ejecutado.
* **Ejecución:** cada prueba se corre como un lote independiente en SSMS o Azure Data Studio.
* **Preservación de datos:** las pruebas que modifican datos válidos usan `BEGIN TRAN ... ROLLBACK`, de modo que la base queda igual que después de cargar los datos de prueba. Las sentencias que fallan no dejan cambios (cada sentencia es atómica).
* **Identity:** como las PK son `IDENTITY(1,1)`, las pruebas de PK duplicada usan `SET IDENTITY_INSERT ... ON`. Un `ROLLBACK` puede dejar "huecos" en la secuencia, lo cual es normal en SQL Server.
* **Fechas:** `datos_prueba.sql` fija `SET DATEFORMAT ymd` y usa literales ISO 8601 (`YYYY-MM-DDThh:mm:ss`), que no dependen del idioma del servidor. Las pruebas que escriben fechas usan el mismo formato (o `YYYYMMDD`, como la Prueba 12 de `venta_cabecera`).
* **Reinicio de datos:** `datos_prueba.sql` es re-ejecutable (borra y vuelve a cargar), por lo que ante cualquier duda se puede restaurar el estado inicial volviendo a correrlo.

### Códigos de error de SQL Server esperados

| Código | Significado |
| :--- | :--- |
| **2627** | Violación de PRIMARY KEY o UNIQUE |
| **547** | Conflicto con FOREIGN KEY (INSERT/UPDATE/DELETE) o con CHECK |
| **515** | Se intentó insertar NULL en una columna NOT NULL |
| **544** | Valor explícito en columna IDENTITY con `IDENTITY_INSERT OFF` |
| **8102** | Intento de modificar una columna IDENTITY |
| **241 / 242** | Error de conversión de fecha (valor inválido o fuera de rango) |

---

## 3. Verificación previa: carga de datos

**Prueba 0: Conteo de registros tras ejecutar `datos_prueba.sql` (Happy Path)**

* **Descripción:** confirma que el poblado inicial se realizó completo y que ninguna restricción rechazó filas.
* **Sentencia SQL:**

```sql
SELECT 'categoria'      AS tabla, COUNT(*) AS filas FROM dbo.categoria      UNION ALL
SELECT 'direccion',               COUNT(*)          FROM dbo.direccion      UNION ALL
SELECT 'metodo_pago',             COUNT(*)          FROM dbo.metodo_pago    UNION ALL
SELECT 'productos',               COUNT(*)          FROM dbo.productos      UNION ALL
SELECT 'usuario',                 COUNT(*)          FROM dbo.usuario        UNION ALL
SELECT 'venta_cabecera',          COUNT(*)          FROM dbo.venta_cabecera UNION ALL
SELECT 'venta_detalle',           COUNT(*)          FROM dbo.venta_detalle  UNION ALL
SELECT 'pago',                    COUNT(*)          FROM dbo.pago;
```

* **Resultado Esperado:** categoria = 8, direccion = 8, metodo_pago = 8, productos = 8, usuario = 8, venta_cabecera = 10, venta_detalle = 11, pago = 8.

---

## 4. Tabla `categoria`

**Prueba 1: Inserción exitosa de una categoría (Happy Path)**

* **Descripción:** se inserta una categoría con nombre único y descripción opcional.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.categoria (nombre, descripcion)
VALUES ('Categoría QA', 'Categoría creada para pruebas de validación.');
SELECT * FROM dbo.categoria WHERE nombre = 'Categoría QA';
ROLLBACK TRAN;
```

* **Resultado Esperado:** `(1 row affected)`; el SELECT devuelve la fila con un `id_categoria` autogenerado.

**Prueba 2: Violación de Clave Primaria (PK) - ID duplicado**

* **Descripción:** se fuerza un `id_categoria = 1`, que ya existe (`Videojuegos`).
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.categoria ON;
INSERT INTO dbo.categoria (id_categoria, nombre) VALUES (1, 'Categoría con PK repetida');
SET IDENTITY_INSERT dbo.categoria OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_categoria'. Cannot insert duplicate key...*

**Prueba 3: Violación de UNIQUE - nombre duplicado**

* **Descripción:** se intenta registrar otra categoría llamada `Videojuegos`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.categoria (nombre, descripcion)
VALUES ('Videojuegos', 'Intento de duplicar el nombre');
```

* **Resultado Esperado:** Error 2627: *Violation of UNIQUE KEY constraint 'UQ_categoria_nombre'.*

**Prueba 4: Violación de NOT NULL - nombre vacío**

* **Descripción:** `nombre` es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.categoria (nombre, descripcion) VALUES (NULL, 'Sin nombre');
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'nombre', table 'RetroGames.dbo.categoria'; column does not allow nulls.*

**Prueba 5: Integridad referencial - borrar categoría con productos (ON DELETE NO ACTION)**

* **Descripción:** la categoría 1 tiene productos asociados (Super Mario World, Sonic), por lo que no puede eliminarse.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.categoria WHERE id_categoria = 1;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_productos_categoria'.*

**Prueba 6: Borrado exitoso de una categoría sin productos (Happy Path)**

* **Descripción:** una categoría recién creada y sin productos sí puede eliminarse.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.categoria (nombre) VALUES ('Categoría Temporal');
DELETE FROM dbo.categoria WHERE nombre = 'Categoría Temporal';
SELECT COUNT(*) AS restantes FROM dbo.categoria WHERE nombre = 'Categoría Temporal';
ROLLBACK TRAN;
```

* **Resultado Esperado:** INSERT y DELETE con 1 fila afectada; `restantes = 0`.

**Prueba 7: ON UPDATE CASCADE sobre columna IDENTITY**

* **Descripción:** `FK_productos_categoria` declara `ON UPDATE CASCADE`, pero la PK de `categoria` es `IDENTITY`, y SQL Server no permite actualizar columnas identity. Esta prueba documenta esa limitación.
* **Sentencia SQL:**

```sql
UPDATE dbo.categoria SET id_categoria = 99 WHERE id_categoria = 8;
```

* **Resultado Esperado:** Error 8102: *Cannot update identity column 'id_categoria'.* La cascada de actualización existe en el esquema pero, en la práctica, nunca se dispara.

---

## 5. Tabla `direccion`

**Prueba 1: Inserción exitosa de una dirección (Happy Path)**

* **Descripción:** alta de una dirección completa.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.direccion (codpostal, calle, provincia, ciudad)
VALUES ('3400', 'Calle QA 123', 'Corrientes', 'Corrientes');
SELECT TOP 1 * FROM dbo.direccion ORDER BY id_direccion DESC;
ROLLBACK TRAN;
```

* **Resultado Esperado:** `(1 row affected)` con ID autogenerado.

**Prueba 2: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_direccion = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.direccion ON;
INSERT INTO dbo.direccion (id_direccion, codpostal, calle, provincia, ciudad)
VALUES (1, '0000', 'Calle Duplicada', 'Chaco', 'Resistencia');
SET IDENTITY_INSERT dbo.direccion OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_direccion'.*

**Prueba 3: Valor explícito en columna IDENTITY sin habilitar IDENTITY_INSERT**

* **Descripción:** verifica que el ID autoincremental no puede imponerse manualmente en uso normal.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.direccion (id_direccion, calle) VALUES (500, 'Calle con ID manual');
```

* **Resultado Esperado:** Error 544: *Cannot insert explicit value for identity column in table 'direccion' when IDENTITY_INSERT is set to OFF.*

**Prueba 4: Borrar dirección vinculada a una venta (ON DELETE NO ACTION)**

* **Descripción:** la dirección 1 es destino de las ventas 1 y 7; no puede borrarse para conservar el historial.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.direccion WHERE id_direccion = 1;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_venta_cabecera_direccion'.*

**Prueba 5: Borrar dirección usada solo por un usuario (ON DELETE SET NULL)**

* **Descripción:** la dirección 5 (Rosario) pertenece únicamente al usuario 6 y no tiene ventas. Al borrarla, el usuario debe conservarse con `id_direccion = NULL`. El `SET NULL` solo opera cuando la dirección nunca se usó en una venta; si se usó, el borrado se rechaza (ver Prueba 7 y H-13).
* **Sentencia SQL:**

```sql
BEGIN TRAN;
DELETE FROM dbo.direccion WHERE id_direccion = 5;
SELECT id_usuario, nombre, id_direccion FROM dbo.usuario WHERE id_usuario = 6;
ROLLBACK TRAN;
```

* **Resultado Esperado:** DELETE con 1 fila afectada; el SELECT devuelve al usuario 6 con `id_direccion = NULL`.

**Prueba 6: ⚠️ Dirección sin ningún dato (todas las columnas son NULL)**

* **Descripción:** en el DDL, `codpostal`, `calle`, `provincia` y `ciudad` admiten NULL, tal como lo indica el modelo relacional. Se comprueba que el esquema acepta una dirección vacía.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.direccion DEFAULT VALUES;
SELECT TOP 1 * FROM dbo.direccion ORDER BY id_direccion DESC;
ROLLBACK TRAN;
```

* **Resultado Esperado:** inserción **exitosa** (1 fila con todos los campos NULL). Ver hallazgo H-1.

**Prueba 7: ⚠️ Borrar la dirección propia de un usuario que ya compró (`SET NULL` bloqueado por `NO ACTION`)**

* **Descripción:** la dirección 3 es la dirección del usuario 4 y el destino de sus ventas 3 y 9. `FK_usuario_direccion` declara `ON DELETE SET NULL`, pero `FK_venta_cabecera_direccion` es `NO ACTION` y prevalece: el borrado se rechaza y el usuario conserva su dirección.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.direccion WHERE id_direccion = 3;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_venta_cabecera_direccion'.* Ver hallazgo H-13.

---

## 6. Tabla `metodo_pago`

**Prueba 1: Inserción exitosa con valor DEFAULT en `activo` (Happy Path)**

* **Descripción:** se omite `activo`; debe asumir el valor por defecto `0`: un método de pago nuevo nace deshabilitado hasta que la administración lo autorice de forma explícita (RN-10).
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.metodo_pago (nombre, descripcion) VALUES ('Método QA', 'Prueba de DEFAULT');
SELECT nombre, activo FROM dbo.metodo_pago WHERE nombre = 'Método QA';
ROLLBACK TRAN;
```

* **Resultado Esperado:** 1 fila afectada; `activo = 0`.

**Prueba 2: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_metodo_pago = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.metodo_pago ON;
INSERT INTO dbo.metodo_pago (id_metodo_pago, nombre, activo) VALUES (1, 'Otro Método', 1);
SET IDENTITY_INSERT dbo.metodo_pago OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_metodo_pago'.*

**Prueba 3: Violación de UNIQUE - nombre duplicado**

* **Descripción:** ya existe el método `Efectivo`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.metodo_pago (nombre, activo) VALUES ('Efectivo', 1);
```

* **Resultado Esperado:** Error 2627: *Violation of UNIQUE KEY constraint 'UQ_metodo_pago_nombre'.*

**Prueba 4: Violación de NOT NULL - nombre vacío**

* **Descripción:** `nombre` es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.metodo_pago (nombre, activo) VALUES (NULL, 1);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'nombre'...*

**Prueba 5: Violación de NOT NULL - `activo` explícitamente NULL**

* **Descripción:** aunque `activo` tiene DEFAULT, enviar NULL de forma explícita debe ser rechazado porque la columna es NOT NULL.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.metodo_pago (nombre, activo) VALUES ('Método Sin Estado', NULL);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'activo'...*

**Prueba 6: Borrar un método de pago utilizado en pagos (ON DELETE NO ACTION)**

* **Descripción:** `Tarjeta de Crédito` (id 2) figura en los pagos 1 y 5.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.metodo_pago WHERE id_metodo_pago = 2;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_pago_metodo_pago'.*

---

## 7. Tabla `productos`

**Prueba 1: Inserción exitosa con valores DEFAULT (Happy Path)**

* **Descripción:** se insertan solo los campos obligatorios (`nombre`, `precio`, `estado_conservacion`, `id_categoria`). Deben aplicarse los DEFAULT: `stock = 0`, `stock_minimo = 5`, `stock_bajo = 0`, `activo = 1`.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto QA', 1500.00, 'NUEVO', 1);
SELECT nombre, stock, stock_minimo, stock_bajo, activo
FROM dbo.productos WHERE nombre = 'Producto QA';
ROLLBACK TRAN;
```

* **Resultado Esperado:** 1 fila afectada; `stock = 0`, `stock_minimo = 5`, `stock_bajo = 0`, `activo = 1`. ⚠️ Con esos DEFAULT el producto nace con `stock (0) < stock_minimo (5)` pero con `stock_bajo = 0`, es decir, incoherente (V-5 lo detectaría si no se hiciera `ROLLBACK`). Ver hallazgo H-11.

**Prueba 2: Valores límite válidos en descuento y estados de conservación (Happy Path)**

* **Descripción:** `porcentaje_descuento` en los extremos permitidos (0 y 100) y los tres estados de conservación válidos.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.productos (nombre, precio, porcentaje_descuento, estado_conservacion, id_categoria) VALUES
('QA Límite 0',   100.00,   0.00, 'NUEVO',   1),
('QA Límite 100', 100.00, 100.00, 'USADO',   1),
('QA En Caja',    100.00,  50.00, 'EN_CAJA', 1);
ROLLBACK TRAN;
```

* **Resultado Esperado:** `(3 rows affected)`.

**Prueba 3: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_productos = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.productos ON;
INSERT INTO dbo.productos (id_productos, nombre, precio, estado_conservacion, id_categoria)
VALUES (1, 'Producto PK Duplicada', 1000.00, 'NUEVO', 1);
SET IDENTITY_INSERT dbo.productos OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_productos'.*

**Prueba 4: Violación de Clave Foránea (FK) - categoría inexistente**

* **Descripción:** `id_categoria = 999` no existe en `categoria`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto Huérfano', 1000.00, 'NUEVO', 999);
```

* **Resultado Esperado:** Error 547: *The INSERT statement conflicted with the FOREIGN KEY constraint 'FK_productos_categoria'.*

**Prueba 5: Violación de NOT NULL - `nombre`**

* **Descripción:** el nombre del producto es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES (NULL, 1000.00, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'nombre'...*

**Prueba 6: Violación de NOT NULL - `precio`**

* **Descripción:** el precio es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto Sin Precio', NULL, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'precio'...*

**Prueba 7: Violación de NOT NULL - `estado_conservacion` (RN-04)**

* **Descripción:** el estado de conservación es obligatorio y no tiene DEFAULT.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, id_categoria)
VALUES ('Producto Sin Estado', 1000.00, 1);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'estado_conservacion'...*

**Prueba 8: Violación de NOT NULL - `id_categoria`**

* **Descripción:** todo producto debe pertenecer a una categoría.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto Sin Categoría', 1000.00, 'NUEVO', NULL);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'id_categoria'...*

**Prueba 9: Violación de CHECK - precio igual a cero**

* **Descripción:** `CK_productos_precio` exige `precio > 0` (estrictamente).
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto Gratis', 0.00, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *The INSERT statement conflicted with the CHECK constraint 'CK_productos_precio'.*

**Prueba 10: Violación de CHECK - precio negativo**

* **Descripción:** se intenta registrar un precio menor a cero.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto Precio Negativo', -500.00, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_precio'.*

**Prueba 11: Violación de CHECK - `precio_original` no positivo**

* **Descripción:** si se informa `precio_original`, debe ser mayor a 0.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio_original, precio, estado_conservacion, id_categoria)
VALUES ('Producto Precio Original Inválido', -10.00, 1000.00, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_precio_original'.*

**Prueba 12: Violación de CHECK - descuento mayor a 100**

* **Descripción:** `porcentaje_descuento` debe estar entre 0 y 100.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, porcentaje_descuento, estado_conservacion, id_categoria)
VALUES ('Producto Descuento 150', 1000.00, 150.00, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_descuento'.*

**Prueba 13: Violación de CHECK - descuento negativo**

* **Descripción:** descuento por debajo del límite inferior.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, porcentaje_descuento, estado_conservacion, id_categoria)
VALUES ('Producto Descuento Negativo', 1000.00, -5.00, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_descuento'.*

**Prueba 14: Violación de CHECK - stock negativo**

* **Descripción:** `stock` debe ser mayor o igual a 0.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, stock, estado_conservacion, id_categoria)
VALUES ('Producto Stock Negativo', 1000.00, -1, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_stock'.*

**Prueba 15: Violación de CHECK - stock mínimo negativo (RN-07)**

* **Descripción:** `stock_minimo` debe ser mayor o igual a 0.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, stock_minimo, estado_conservacion, id_categoria)
VALUES ('Producto Stock Mínimo Negativo', 1000.00, -3, 'NUEVO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_stock_minimo'.*

**Prueba 16: Violación de CHECK - estado de conservación inexistente**

* **Descripción:** solo se admite `'NUEVO'`, `'USADO'` o `'EN_CAJA'`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.productos (nombre, precio, estado_conservacion, id_categoria)
VALUES ('Producto Roto', 1000.00, 'ROTO', 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_productos_conservacion'.*

**Prueba 17: Violación de CHECK por UPDATE - precio negativo sobre un producto existente**

* **Descripción:** los CHECK también protegen las modificaciones, no solo las altas.
* **Sentencia SQL:**

```sql
UPDATE dbo.productos SET precio = -1 WHERE id_productos = 1;
```

* **Resultado Esperado:** Error 547: *The UPDATE statement conflicted with the CHECK constraint 'CK_productos_precio'.* El precio del producto 1 permanece en 40000.00.

**Prueba 18: Borrar un producto que ya fue vendido (ON DELETE NO ACTION)**

* **Descripción:** el producto 1 (Super Mario World) figura en `venta_detalle`.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.productos WHERE id_productos = 1;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_venta_detalle_productos'.*

---

## 8. Tabla `usuario`

**Prueba 1: Inserción exitosa con valores DEFAULT (Happy Path)**

* **Descripción:** se omiten `rol` y `activo`; deben asumir `'CLIENTE'` y `1`. La dirección es opcional.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES ('Usuario QA', 'qa.test@retrogames.com', '$2y$10$HashDePruebaQA');
SELECT nombre, rol, activo, id_direccion FROM dbo.usuario WHERE email = 'qa.test@retrogames.com';
ROLLBACK TRAN;
```

* **Resultado Esperado:** 1 fila afectada; `rol = 'CLIENTE'`, `activo = 1`, `id_direccion = NULL`.

**Prueba 2: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_usuario = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.usuario ON;
INSERT INTO dbo.usuario (id_usuario, nombre, email, [password])
VALUES (1, 'Usuario PK Duplicada', 'pk.dup@retrogames.com', 'hash');
SET IDENTITY_INSERT dbo.usuario OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_usuario'.*

**Prueba 3: Violación de UNIQUE - email duplicado**

* **Descripción:** `admin@retrogames.com` ya está registrado.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES ('Otro Admin', 'admin@retrogames.com', 'hash');
```

* **Resultado Esperado:** Error 2627: *Violation of UNIQUE KEY constraint 'UQ_usuario_email'.*

**Prueba 4: Violación de UNIQUE - email duplicado con distinta capitalización**

* **Descripción:** con la collation por defecto de SQL Server (insensible a mayúsculas), `ADMIN@RETROGAMES.COM` equivale a `admin@retrogames.com`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES ('Admin Mayúsculas', 'ADMIN@RETROGAMES.COM', 'hash');
```

* **Resultado Esperado:** Error 2627 (*UQ_usuario_email*). Si la base usara una collation sensible a mayúsculas (`_CS_`), la inserción tendría éxito.

**Prueba 5: Violación de FK - dirección inexistente**

* **Descripción:** `id_direccion = 999` no existe.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password], id_direccion)
VALUES ('Usuario Dirección Falsa', 'fk.dir@retrogames.com', 'hash', 999);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_usuario_direccion'.*

**Prueba 6: Violación de NOT NULL - `nombre`**

* **Descripción:** el nombre es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES (NULL, 'sin.nombre@retrogames.com', 'hash');
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'nombre'...*

**Prueba 7: Violación de NOT NULL - `email`**

* **Descripción:** el email es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password]) VALUES ('Sin Email', NULL, 'hash');
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'email'...*

**Prueba 8: Violación de NOT NULL - `password`**

* **Descripción:** la contraseña (hash) es obligatoria.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES ('Sin Password', 'sin.pass@retrogames.com', NULL);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'password'...*

**Prueba 9: Violación de NOT NULL - `rol` explícitamente NULL**

* **Descripción:** aunque `rol` tiene DEFAULT, un NULL explícito debe rechazarse.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password], rol)
VALUES ('Sin Rol', 'sin.rol@retrogames.com', 'hash', NULL);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'rol'...*

**Prueba 10: Violación de CHECK - email sin arroba**

* **Descripción:** `CK_usuario_email` (`LIKE '%_@_%._%'`) exige un `@`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES ('Email Inválido 1', 'correo-sin-arroba.com', 'hash');
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_usuario_email'.*

**Prueba 11: Violación de CHECK - email sin punto en el dominio**

* **Descripción:** el email debe contener un punto después del `@`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password])
VALUES ('Email Inválido 2', 'usuario@dominio', 'hash');
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_usuario_email'.*

**Prueba 12: Violación de CHECK - rol inexistente**

* **Descripción:** solo se admiten los roles `'ADMIN'` y `'CLIENTE'`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.usuario (nombre, email, [password], rol)
VALUES ('Rol Inválido', 'rol.invalido@retrogames.com', 'hash', 'SUPERADMIN');
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_usuario_rol'.*

**Prueba 13: Borrar un usuario con ventas registradas (ON DELETE NO ACTION)**

* **Descripción:** el usuario 2 (Micaela) tiene las ventas 1 y 7; el historial debe conservarse.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.usuario WHERE id_usuario = 2;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_venta_cabecera_usuario'.*

**Prueba 14: Borrar un usuario sin ventas (Happy Path)**

* **Descripción:** el usuario 6 (Esteban Quito, inactivo) no tiene ventas y puede eliminarse.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
DELETE FROM dbo.usuario WHERE id_usuario = 6;
ROLLBACK TRAN;
```

* **Resultado Esperado:** `(1 row affected)`.

**Prueba 15: ⚠️ Dos usuarios con la misma dirección**

* **Descripción:** el modelo relacional documenta `usuario → direccion` como **1..1**, pero el DDL no define UNIQUE en `usuario.id_direccion`. Los propios datos de prueba lo evidencian (usuarios 1 y 2 comparten la dirección 1).
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.usuario (nombre, email, [password], id_direccion)
VALUES ('Usuario Misma Dirección', 'misma.dir@retrogames.com', 'hash', 1);
ROLLBACK TRAN;
```

* **Resultado Esperado:** inserción **exitosa**. Ver hallazgo H-2.

---

## 9. Tabla `venta_cabecera`

**Prueba 1: Inserción exitosa con valores DEFAULT (Happy Path)**

* **Descripción:** se omiten `fecha_venta` y `estado`; deben asumir `GETDATE()` y `'PENDIENTE'`.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (15000.00, 2, 1);
SELECT TOP 1 id_venta_cabecera, fecha_venta, estado, total
FROM dbo.venta_cabecera ORDER BY id_venta_cabecera DESC;
ROLLBACK TRAN;
```

* **Resultado Esperado:** 1 fila afectada; `estado = 'PENDIENTE'` y `fecha_venta` con la fecha y hora actuales.

**Prueba 2: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_venta_cabecera = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.venta_cabecera ON;
INSERT INTO dbo.venta_cabecera (id_venta_cabecera, total, id_usuario, id_direccion)
VALUES (1, 1000.00, 2, 1);
SET IDENTITY_INSERT dbo.venta_cabecera OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_venta_cabecera'.*

**Prueba 3: Violación de FK - usuario inexistente**

* **Descripción:** la venta referencia a `id_usuario = 999`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (1000.00, 999, 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_venta_cabecera_usuario'.*

**Prueba 4: Violación de FK - dirección inexistente**

* **Descripción:** la venta referencia a `id_direccion = 999`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (1000.00, 2, 999);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_venta_cabecera_direccion'.*

**Prueba 5: Violación de NOT NULL - `total`**

* **Descripción:** el total es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (NULL, 2, 1);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'total'...*

**Prueba 6: Violación de NOT NULL - `id_usuario`**

* **Descripción:** toda venta debe tener un cliente.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (1000.00, NULL, 1);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'id_usuario'...*

**Prueba 7: Violación de NOT NULL - `id_direccion`**

* **Descripción:** toda venta debe tener dirección de entrega.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (1000.00, 2, NULL);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'id_direccion'...*

**Prueba 8: Violación de NOT NULL - `fecha_venta` y `estado` explícitamente NULL**

* **Descripción:** ambos tienen DEFAULT, pero un NULL explícito debe ser rechazado.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (fecha_venta, total, id_usuario, id_direccion)
VALUES (NULL, 1000.00, 2, 1);

INSERT INTO dbo.venta_cabecera (estado, total, id_usuario, id_direccion)
VALUES (NULL, 1000.00, 2, 1);
```

* **Resultado Esperado:** dos errores 515: uno por `fecha_venta` y otro por `estado`.

**Prueba 9: Violación de CHECK - total igual a cero**

* **Descripción:** `CK_venta_cabecera_total` exige `total > 0`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (0.00, 2, 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_venta_cabecera_total'.*

**Prueba 10: Violación de CHECK - total negativo**

* **Descripción:** no se admiten ventas con importe negativo.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (-2500.00, 2, 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_venta_cabecera_total'.*

**Prueba 11: Violación de CHECK - estado inexistente**

* **Descripción:** solo se admiten `PENDIENTE`, `PAGADA`, `ENVIADA`, `ENTREGADA`, `CANCELADA` y `CARRITO`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (estado, total, id_usuario, id_direccion)
VALUES ('DEVUELTA', 1000.00, 2, 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_venta_cabecera_estado'.*

**Prueba 12: Violación de tipo de dato - fecha inválida**

* **Descripción:** el 30 de febrero no existe; el tipo `DATETIME` rechaza la fecha incoherente.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (fecha_venta, total, id_usuario, id_direccion)
VALUES ('20260230 10:00:00', 1000.00, 2, 1);
```

* **Resultado Esperado:** Error 242 (o 241 según el formato): *The conversion of a varchar data type to a datetime data type resulted in an out-of-range value.*

**Prueba 13: ⚠️ Fechas incoherentes pero sintácticamente válidas**

* **Descripción:** el DDL no tiene CHECK sobre `fecha_venta`. Una venta fechada en el año 2099 o en 1900 se acepta, aunque sea lógicamente incoherente.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.venta_cabecera (fecha_venta, total, id_usuario, id_direccion) VALUES
('2099-12-31T23:59:00', 1000.00, 2, 1),
('1900-01-01T00:00:00', 1000.00, 2, 1);
ROLLBACK TRAN;
```

* **Resultado Esperado:** inserción **exitosa** (2 filas). Ver hallazgo H-3.

**Prueba 14: Borrar una venta con pago asociado (ON DELETE NO ACTION en `pago`)**

* **Descripción:** la venta 1 tiene un pago registrado; al ser un registro contable, bloquea el borrado de la venta.
* **Sentencia SQL:**

```sql
DELETE FROM dbo.venta_cabecera WHERE id_venta_cabecera = 1;
```

* **Resultado Esperado:** Error 547: *The DELETE statement conflicted with the REFERENCE constraint 'FK_pago_venta_cabecera'.*

**Prueba 15: Borrado en cascada de detalles (ON DELETE CASCADE)**

* **Descripción:** la venta 8 (`CARRITO`) tiene un detalle y ningún pago. Al eliminarla, su detalle debe desaparecer automáticamente.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
SELECT COUNT(*) AS detalles_antes FROM dbo.venta_detalle WHERE id_venta_cabecera = 8;
DELETE FROM dbo.venta_cabecera WHERE id_venta_cabecera = 8;
SELECT COUNT(*) AS detalles_despues FROM dbo.venta_detalle WHERE id_venta_cabecera = 8;
ROLLBACK TRAN;
```

* **Resultado Esperado:** `detalles_antes = 1`, DELETE con 1 fila afectada y `detalles_despues = 0`.

**Prueba 16: ⚠️ No puede existir un carrito vacío ni sin dirección**

* **Descripción:** el carrito se modela como una `venta_cabecera` en estado `CARRITO`, y la tabla exige `total > 0` e `id_direccion` obligatoria. Un carrito sin ítems (total 0) o de un usuario sin dirección cargada no puede crearse.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_cabecera (estado, total, id_usuario, id_direccion) VALUES ('CARRITO', 0.00, 2, 1);
INSERT INTO dbo.venta_cabecera (estado, total, id_usuario, id_direccion) VALUES ('CARRITO', 1000.00, 2, NULL);
```

* **Resultado Esperado:** dos errores: Error 547 por `CK_venta_cabecera_total` y Error 515 por `id_direccion`. Ver hallazgo H-10.

**Prueba 17: ⚠️ Venta sin ningún ítem de detalle**

* **Descripción:** el esquema no exige que una cabecera tenga al menos un detalle. La consulta con `LEFT JOIN` muestra la venta recién creada sin ítems.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.venta_cabecera (total, id_usuario, id_direccion) VALUES (15000.00, 2, 1);
SELECT c.id_venta_cabecera, c.total
FROM dbo.venta_cabecera c
LEFT JOIN dbo.venta_detalle d ON d.id_venta_cabecera = c.id_venta_cabecera
WHERE d.id_venta_detalle IS NULL;
ROLLBACK TRAN;
```

* **Resultado Esperado:** inserción **exitosa**; el SELECT devuelve 1 fila (la venta nueva, sin detalle). Ver hallazgo H-12.

---

## 10. Tabla `venta_detalle`

**Prueba 1: Inserción exitosa de un ítem (Happy Path)**

* **Descripción:** se agrega a la venta 8 un ítem coherente: `subtotal = cantidad × precio_unitario`.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (2, 30000.00, 60000.00, 2, 8);
ROLLBACK TRAN;
```

* **Resultado Esperado:** `(1 row affected)`.

**Prueba 2: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_venta_detalle = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.venta_detalle ON;
INSERT INTO dbo.venta_detalle (id_venta_detalle, cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1, 8000.00, 8000.00, 7, 8);
SET IDENTITY_INSERT dbo.venta_detalle OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_venta_detalle'.*

**Prueba 3: Violación de FK - producto inexistente**

* **Descripción:** el ítem referencia a `id_productos = 999`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1000.00, 1000.00, 999, 8);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_venta_detalle_productos'.*

**Prueba 4: Violación de FK - venta inexistente**

* **Descripción:** un detalle huérfano que apunta a `id_venta_cabecera = 999`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1000.00, 1000.00, 1, 999);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_venta_detalle_cabecera'.*

**Prueba 5: Violación de NOT NULL - `cantidad`, `precio_unitario` y `subtotal`**

* **Descripción:** los tres campos numéricos son obligatorios; se prueba cada uno por separado.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (NULL, 1000.00, 1000.00, 1, 8);

INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, NULL, 1000.00, 1, 8);

INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1000.00, NULL, 1, 8);
```

* **Resultado Esperado:** tres errores 515, uno por `cantidad`, otro por `precio_unitario` y otro por `subtotal`.

**Prueba 6: Violación de NOT NULL - claves foráneas**

* **Descripción:** `id_productos` e `id_venta_cabecera` son obligatorias.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1000.00, 1000.00, NULL, 8);

INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1000.00, 1000.00, 1, NULL);
```

* **Resultado Esperado:** dos errores 515 (`id_productos` e `id_venta_cabecera`).

**Prueba 7: Violación de CHECK - cantidad cero**

* **Descripción:** `CK_venta_detalle_cantidad` exige `cantidad > 0`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (0, 1000.00, 1000.00, 1, 8);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_venta_detalle_cantidad'.*

**Prueba 8: Violación de CHECK - cantidad negativa**

* **Descripción:** no se admiten cantidades negativas.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (-2, 1000.00, -2000.00, 1, 8);
```

* **Resultado Esperado:** Error 547 (CHECK). SQL Server puede reportar `CK_venta_detalle_cantidad` o `CK_venta_detalle_subtotal`, ya que ambas se violan.

**Prueba 9: Violación de CHECK - precio unitario no positivo**

* **Descripción:** `CK_venta_detalle_precio` exige `precio_unitario > 0`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, -1000.00, 1000.00, 1, 8);
```

* **Resultado Esperado:** Error 547 (CHECK). El valor viola a la vez `CK_venta_detalle_precio` y `CK_venta_detalle_subtotal` (1 × -1000 ≠ 1000), y SQL Server informa solo uno de los dos. No es posible aislar `precio_unitario <= 0`: con `cantidad > 0` siempre hace fallar también `subtotal > 0`.

**Prueba 10: Violación de CHECK - subtotal inconsistente (cantidad × precio)**

* **Descripción:** 2 × 30000 = 60000, pero se informa un subtotal de 50000. El CHECK valida la aritmética.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (2, 30000.00, 50000.00, 2, 8);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_venta_detalle_subtotal'.*

**Prueba 11: Violación de CHECK - subtotal igual a cero**

* **Descripción:** el subtotal debe ser estrictamente mayor a 0.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 1000.00, 0.00, 1, 8);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_venta_detalle_subtotal'.*

**Prueba 12: ⚠️ Detalle que deja inconsistente el total de la cabecera**

* **Descripción:** el total de la venta 8 es 50000 (un único ítem). Se agrega otro ítem válido y se comprueba que `total` no se recalcula ni se valida contra la suma de los detalles.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.venta_detalle (cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera)
VALUES (1, 8000.00, 8000.00, 7, 8);

SELECT c.total AS total_cabecera, SUM(d.subtotal) AS suma_detalles
FROM dbo.venta_cabecera c
JOIN dbo.venta_detalle d ON d.id_venta_cabecera = c.id_venta_cabecera
WHERE c.id_venta_cabecera = 8
GROUP BY c.total;
ROLLBACK TRAN;
```

* **Resultado Esperado:** inserción **exitosa**; `total_cabecera = 50000.00` y `suma_detalles = 58000.00`. Ver hallazgo H-4.

---

## 11. Tabla `pago`

**Prueba 1: Inserción exitosa de un pago (Happy Path)**

* **Descripción:** se registra el pago de la venta 5 (`PENDIENTE`, total 90000) con Tarjeta de Crédito.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (90000.00, 5, 2);
SELECT TOP 1 * FROM dbo.pago ORDER BY id_pago DESC;
ROLLBACK TRAN;
```

* **Resultado Esperado:** 1 fila afectada; `fecha_pago` toma `GETDATE()` por DEFAULT.

**Prueba 2: Violación de Clave Primaria (PK)**

* **Descripción:** se reutiliza `id_pago = 1`.
* **Sentencia SQL:**

```sql
SET IDENTITY_INSERT dbo.pago ON;
INSERT INTO dbo.pago (id_pago, monto, id_venta_cabecera, id_metodo_pago) VALUES (1, 90000.00, 5, 2);
SET IDENTITY_INSERT dbo.pago OFF;
```

* **Resultado Esperado:** Error 2627: *Violation of PRIMARY KEY constraint 'PK_pago'.*

**Prueba 3: Violación de UNIQUE - segundo pago para la misma venta (máximo un pago por venta)**

* **Descripción:** la venta 1 ya tiene su pago; `UQ_pago_venta` impide registrar otro.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (40000.00, 1, 3);
```

* **Resultado Esperado:** Error 2627: *Violation of UNIQUE KEY constraint 'UQ_pago_venta'.*

**Prueba 4: Violación de FK - venta inexistente**

* **Descripción:** pago que apunta a `id_venta_cabecera = 999`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (1000.00, 999, 1);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_pago_venta_cabecera'.*

**Prueba 5: Violación de FK - método de pago inexistente**

* **Descripción:** pago con `id_metodo_pago = 999`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (90000.00, 5, 999);
```

* **Resultado Esperado:** Error 547: *conflicted with the FOREIGN KEY constraint 'FK_pago_metodo_pago'.*

**Prueba 6: Violación de NOT NULL - `monto`**

* **Descripción:** el monto es obligatorio.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (NULL, 5, 2);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'monto'...*

**Prueba 7: Violación de NOT NULL - `id_venta_cabecera` e `id_metodo_pago`**

* **Descripción:** un pago debe estar ligado a una venta y a un método.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (1000.00, NULL, 2);
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (1000.00, 5, NULL);
```

* **Resultado Esperado:** dos errores 515 (uno por cada columna).

**Prueba 8: Violación de NOT NULL - `fecha_pago` explícitamente NULL**

* **Descripción:** aunque tiene DEFAULT, un NULL explícito debe ser rechazado.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (fecha_pago, monto, id_venta_cabecera, id_metodo_pago) VALUES (NULL, 90000.00, 5, 2);
```

* **Resultado Esperado:** Error 515: *Cannot insert the value NULL into column 'fecha_pago'...*

**Prueba 9: Violación de CHECK - monto igual a cero**

* **Descripción:** `CK_pago_monto` exige `monto > 0`.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (0.00, 5, 2);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_pago_monto'.*

**Prueba 10: Violación de CHECK - monto negativo**

* **Descripción:** no se admiten pagos con importe negativo.
* **Sentencia SQL:**

```sql
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (-90000.00, 5, 2);
```

* **Resultado Esperado:** Error 547: *conflicted with the CHECK constraint 'CK_pago_monto'.*

**Prueba 11: ⚠️ Pago con un método de pago desactivado (RN-10)**

* **Descripción:** `Criptomonedas` (id 7) está marcado `activo = 0`, es decir, no autorizado. El esquema no impide usarlo.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (90000.00, 5, 7);
ROLLBACK TRAN;
```

* **Resultado Esperado:** inserción **exitosa**. Ver hallazgo H-5.

**Prueba 12: ⚠️ Pago cuyo monto no coincide con el total de la venta, o de una venta en `CARRITO`**

* **Descripción:** no existe restricción que relacione `pago.monto` con `venta_cabecera.total` ni con el estado de la venta.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (1.00, 5, 2);   -- monto distinto del total (90000)
INSERT INTO dbo.pago (monto, id_venta_cabecera, id_metodo_pago) VALUES (50000.00, 8, 2); -- venta en estado CARRITO
ROLLBACK TRAN;
```

* **Resultado Esperado:** ambas inserciones **exitosas** (2 filas). Ver hallazgo H-6.

**Prueba 13: Eliminar un pago (registro hoja, sin dependientes)**

* **Descripción:** ninguna tabla referencia a `pago`; se puede borrar un pago sin errores referenciales.
* **Sentencia SQL:**

```sql
BEGIN TRAN;
DELETE FROM dbo.pago WHERE id_pago = 6;
ROLLBACK TRAN;
```

* **Resultado Esperado:** `(1 row affected)`.

---

## 12. Consultas de verificación de integridad sobre los datos cargados

Estas consultas confirman que los datos de prueba son coherentes. Todas deben devolver **0 filas** (salvo indicación).

**V-1: Detalles huérfanos (sin cabecera o sin producto)**

```sql
SELECT d.* FROM dbo.venta_detalle d
LEFT JOIN dbo.venta_cabecera c ON c.id_venta_cabecera = d.id_venta_cabecera
LEFT JOIN dbo.productos p ON p.id_productos = d.id_productos
WHERE c.id_venta_cabecera IS NULL OR p.id_productos IS NULL;
```

**V-2: Ventas cuyo total no coincide con la suma de sus detalles (incluye ventas sin detalle)**

```sql
SELECT c.id_venta_cabecera, c.total, ISNULL(SUM(d.subtotal), 0) AS suma_detalles
FROM dbo.venta_cabecera c
LEFT JOIN dbo.venta_detalle d ON d.id_venta_cabecera = c.id_venta_cabecera
GROUP BY c.id_venta_cabecera, c.total
HAVING c.total <> ISNULL(SUM(d.subtotal), 0);
```

**V-3: Pagos cuyo monto no coincide con el total de la venta**

```sql
SELECT p.id_pago, p.monto, c.total
FROM dbo.pago p JOIN dbo.venta_cabecera c ON c.id_venta_cabecera = p.id_venta_cabecera
WHERE p.monto <> c.total;
```

**V-4: Ventas sin pago y su estado (debe mostrar solo `PENDIENTE` y `CARRITO`)**

```sql
SELECT c.id_venta_cabecera, c.estado
FROM dbo.venta_cabecera c
LEFT JOIN dbo.pago p ON p.id_venta_cabecera = c.id_venta_cabecera
WHERE p.id_pago IS NULL;
```

*Resultado esperado:* 2 filas (ventas 5 y 8).

**V-5: Productos con `stock_bajo` mal calculado respecto a `stock < stock_minimo`**

```sql
SELECT id_productos, nombre, stock, stock_minimo, stock_bajo
FROM dbo.productos
WHERE stock_bajo <> CASE WHEN stock < stock_minimo THEN 1 ELSE 0 END;
```

**V-6: Pagos realizados con métodos de pago inactivos**

```sql
SELECT p.id_pago, m.nombre
FROM dbo.pago p JOIN dbo.metodo_pago m ON m.id_metodo_pago = p.id_metodo_pago
WHERE m.activo = 0;
```

**V-7: Comprobación formal de todas las restricciones del esquema**

```sql
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
```

*Resultado esperado:* sin filas, lo que indica que no hay datos que violen ninguna FK o CHECK.

---

## 13. Hallazgos y recomendaciones

Las pruebas marcadas con ⚠️ muestran reglas de negocio o del modelo que **no están garantizadas por el esquema físico**. No son errores de ejecución, pero conviene documentarlas y decidir si se refuerzan.

| ID | Hallazgo | Origen | Recomendación |
| :--- | :--- | :--- | :--- |
| **H-1** | Se acepta una dirección con todos sus campos NULL. | `direccion` no define NOT NULL en `calle`, `ciudad` ni `provincia` (coincide con el modelo). | Evaluar `NOT NULL` en `calle` y `ciudad`, o un CHECK que exija al menos un dato. |
| **H-2** | El modelo indica `usuario → direccion` como 1..1, pero varios usuarios pueden compartir una dirección (los usuarios 1 y 2 ya lo hacen). | No hay UNIQUE en `usuario.id_direccion`. | Decidir: o se corrige el modelo a 1..N, o se agrega un índice UNIQUE filtrado (`WHERE id_direccion IS NOT NULL`) y se ajustan los datos de prueba. |
| **H-3** | Se aceptan fechas de venta futuras o muy antiguas. | No hay CHECK sobre `fecha_venta` ni `fecha_pago`. | Agregar `CHECK (fecha_venta <= GETDATE())`, o validarlo en la capa de aplicación. |
| **H-4** | `venta_cabecera.total` no se valida contra la suma de `venta_detalle.subtotal`. | Dependencia entre tablas que un CHECK no puede expresar. | Resolverlo con un trigger, un procedimiento almacenado transaccional o validación en la aplicación. |
| **H-5** | Se puede registrar un pago con un método de pago inactivo (RN-10). | El campo `activo` es solo informativo; no hay restricción que lo cruce con `pago`. | Trigger `AFTER INSERT` sobre `pago` o validación en la capa de servicio. |
| **H-6** | El monto del pago puede no coincidir con el total de la venta, y se puede pagar una venta en `CARRITO`. | No hay restricción entre `pago` y `venta_cabecera`. | Trigger o procedimiento almacenado que valide monto y estado. |
| **H-7** | La cascada `ON UPDATE CASCADE` declarada en `FK_productos_categoria` y `FK_venta_detalle_cabecera` nunca se ejecuta en la práctica. | Las PK son `IDENTITY` y SQL Server no permite actualizarlas (error 8102). | Mantenerlo es inofensivo; puede documentarse como protección teórica. |
| **H-8** | La unicidad del email y las validaciones de texto (`'NUEVO'`, `'ADMIN'`) no distinguen mayúsculas de minúsculas. | Depende de la collation de la base (por defecto `_CI_`). | Si se quiere sensibilidad a mayúsculas, definir `COLLATE` en esas columnas. |
| **H-9** | `stock_bajo` es un campo derivado (`stock < stock_minimo`) almacenado, por lo que puede quedar desactualizado. | Dato redundante en `productos`. | Convertirlo en columna calculada o mantenerlo con un trigger. |
| **H-10** | El carrito es una `venta_cabecera` en estado `CARRITO`, por lo que exige `total > 0` e `id_direccion`: no existe un carrito vacío ni de un usuario sin dirección cargada (Prueba 16). | `CK_venta_cabecera_total` e `id_direccion NOT NULL`. | Documentar la limitación. Alternativas: `id_direccion` nulable mientras el estado sea `CARRITO`, o manejar el carrito fuera de la base (sesión). |
| **H-11** | Un producto insertado con los DEFAULT queda con `stock = 0 < stock_minimo = 5` y `stock_bajo = 0`: nace incoherente (Prueba 1 de `productos`, V-5). | DEFAULT independientes sobre un campo derivado. | Columna calculada, trigger, o que la aplicación informe `stock_bajo`. |
| **H-12** | Se acepta una venta sin ningún ítem de detalle (Prueba 17). | Ninguna restricción declarativa puede exigir al menos un detalle por cabecera. | Trigger o procedimiento almacenado transaccional, o validación en la aplicación. V-2 (con `LEFT JOIN`) la detecta. |
| **H-13** | La dirección de un usuario que ya compró no puede eliminarse y, si varios usuarios la comparten, el `SET NULL` los afecta a todos (Prueba 7 de `direccion`). | `FK_venta_cabecera_direccion` (`NO ACTION`) prevalece sobre `FK_usuario_direccion` (`SET NULL`). | Documentar. Alternativa: baja lógica de direcciones. |

## 14. Resumen de cobertura

| Tipo de restricción | Tablas cubiertas por pruebas negativas |
| :--- | :--- |
| **PRIMARY KEY** | categoria, direccion, metodo_pago, productos, usuario, venta_cabecera, venta_detalle, pago |
| **FOREIGN KEY (INSERT)** | productos, usuario, venta_cabecera, venta_detalle, pago |
| **FOREIGN KEY (DELETE: NO ACTION / SET NULL / CASCADE)** | categoria, direccion, metodo_pago, productos, usuario, venta_cabecera |
| **UNIQUE** | categoria (nombre), metodo_pago (nombre), usuario (email), pago (id_venta_cabecera) |
| **NOT NULL** | Todas las tablas salvo `direccion` (no tiene columnas obligatorias) |
| **CHECK** | productos, usuario, venta_cabecera, venta_detalle, pago |
| **DEFAULT** | productos, usuario, metodo_pago, venta_cabecera, pago |
| **Tipo de dato** | venta_cabecera (fecha inválida) |

**Conclusión:** el esquema físico garantiza correctamente la integridad de entidad, la integridad referencial, la integridad de dominio y la unicidad definidas en `restricciones-integridad.md`. Las reglas que involucran **más de una tabla o columnas derivadas** (H-4, H-5, H-6, H-9, H-11, H-12) quedan fuera del alcance de las restricciones declarativas y requieren triggers, procedimientos almacenados o validación en la aplicación. Los hallazgos H-10 y H-13 son limitaciones del modelo (carrito como venta y direcciones referenciadas por ventas) que se documentan como decisiones de diseño.
