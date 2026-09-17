# 1. Primera Forma Normal (1FN)

## Regla Teórica
Una tabla se encuentra en Primera Forma Normal si y solo si:
* **Todos los atributos son atómicos** (es decir, no contienen grupos repetitivos, listas ni colecciones de valores).
* Contiene una **clave primaria única** y ningún atributo componente de la clave es nulo.
* Existe **independencia** en el orden de las filas y columnas.

## Análisis y Evolución
En nuestro sistema, observamos que por cada venta realizada se registran múltiples productos. Esto genera una estructura multivaluada (varios ítems y precios dentro de un mismo comprobante), lo que viola el principio de atomicidad de la 1FN.

## Solución Aplicada
Para eliminar los grupos repetitivos, se descompone la estructura inicial en dos tablas independientes vinculadas relacionalmente:

* **`venta_cabecera`**: Aloja los datos generales e irrepetibles de la transacción (fecha, estado, total, datos del usuario y dirección).
* **`venta_detalle`**: Aloja los datos de los productos comprados. Como una venta puede tener muchos productos, la clave primaria de esta tabla pasa a ser compuesta o se gestiona mediante la combinación de identificadores.

---

### Esquema Relacional Resultante (Diagrama)

A partir del análisis, la estructura de datos se divide de la siguiente manera:

#### Tabla: `venta_cabecera`
| Campo | Detalles / Restricciones |
| :--- | :--- |
| **`id_venta_cabecera`** | **Primary Key (PK)** |
| `fecha_venta` | |
| `estado` | |
| `total` | |
| `nombre_usuario` | |
| `email_usuario` | |
| `telefono_usuario` | |
| `direccion` | |

#### Tabla: `venta_detalle`
| Campo | Detalles / Restricciones |
| :--- | :--- |
| **`id_venta_detalle`** | **Primary Key (PK)** |
| `productos` | |
| `descripcion_producto` | |
| `precio` | |
| `cantidad` | |
| `categoria` | |
| `id_venta_cabecera` | **Foreign Key (FK)** -> referencia a `venta_cabecera` |

*(La relación indica que una `venta_cabecera` puede tener múltiples registros asociados en `venta_detalle`, conectados a través de la Foreign Key).*

# 2. Segunda Forma Normal (2FN)

## Regla Teórica
Una tabla se encuentra en Segunda Forma Normal si y solo si:
* Se encuentra en **Primera Forma Normal (1FN)**.
* Todos los atributos que no son clave **dependen por completo de toda la clave primaria**.
* Esta regla aplica fundamentalmente a aquellas tablas que poseen claves compuestas.

## Análisis y Evolución
Analizamos la tabla `venta_detalle`, la cual posee una clave compuesta o relación cruzada entre la venta y los productos. Observamos que atributos descriptivos, tales como el nombre, la descripción, el precio y la categoría, no dependen de toda la venta, sino exclusivamente del producto en sí (`id_productos`). 
Si dejábamos esto así, se generarían fuertes redundancias cada vez que un mismo producto fuera vendido a diferentes clientes.

## Solución Aplicada
Se extraen todos los atributos descriptivos hacia una nueva entidad independiente denominada `productos`, dotándola de su propia clave primaria (`id_productos`).
La tabla `venta_detalle` queda limpia y optimizada, conservando únicamente los atributos que pertenecen estrictamente a la transacción del producto (como la cantidad, el precio_unitario, el subtotal) y las claves foráneas correspondientes.

---

### Esquema Relacional Resultante (Diagrama)

A partir de la aplicación de la 2FN, se actualiza incorporando la nueva tabla de productos:

#### Tabla: `venta_cabecera`
| Campo | Detalles / Restricciones |
| :--- | :--- |
| **`id_venta_cabera`** | **Primary Key (PK)** |
| `fecha_venta` | |
| `estado` | |
| `total` | |
| `nombre_usuario` | |
| `email_usuario` | |
| `telefono_usuario` | |
| `direccion` | |

#### Tabla: `venta_detalle`
| Campo | Detalles / Restricciones |
| :--- | :--- |
| **`id_venta_detalle`** | **Primary Key (PK)** |
| `cantidad` | |
| `precio_unitario` | |
| `subtotal` | |
| `id_venta_cabera` | **Foreign Key (FK)** -> referencia a `venta_cabecera` |
| `id_productos` | **Foreign Key (FK)** -> referencia a `productos` |

#### Tabla: `productos`
| Campo | Detalles / Restricciones |
| :--- | :--- |
| **`id_productos`** | **Primary Key (PK)** |
| `nombre` | |
| `descripcion` | |
| `precio_original` | |
| `precio` | |
| `porcentaje_descuento`| |
| `stock` | |
| `stock_bajo` | |
| `marca` | |
| `consola` | |
| `tipo_producto` | |
| `activo` | |
| `categoria` | |

*(Las relaciones indican que un registro en `venta_detalle` asocia una `venta_cabecera` específica con un `producto` específico a través de sus respectivas Foreign Keys).*

# 3. Tercera Forma Normal (3FN)

## Regla Teórica
Una relación se halla en Tercera Forma Normal si y solo si:
* Se encuentra en **Segunda Forma Normal (2FN)**.
* **No existe ninguna dependencia transitiva** entre los atributos que no son clave. 
* Es decir, un atributo que no forma parte de la clave primaria no puede depender funcionalmente de otro atributo que tampoco sea clave primaria.

## Análisis y Evolución
Al revisar el modelo obtenido en 2FN, detectamos dos dependencias transitivas críticas: 
1. En la tabla `venta_cabecera`, los datos del cliente (`nombre_usuario`, `email_usuario`, `telefono_usuario`) y la dirección (`direccion`, `ciudad`, etc.) dependían del `id_usuario` y del `id_direccion`, campos que no eran claves primarias de la factura, sino atributos dependientes de otro valor no clave.
2. En la tabla `productos`, el atributo de la categoría dependía de un código o nombre de categoría que no constituía la clave principal del producto.

## Solución Aplicada
Se independizan las entidades relacionales creando tablas específicas: `usuario`, `direccion` y `categoria`.
Se reemplazan los campos redundantes por claves foráneas (FK), logrando que cada atributo no clave dependa única, directa y exclusivamente de la clave primaria de su respectiva tabla.

---

### Esquema Relacional Resultante (Diagrama Completo en 3FN)

A partir de la aplicación de la 3FN, el esquema se expande creando entidades independientes conectadas por relaciones 1 a N, conformando el modelo relacional final:

#### Tabla: `categoria`
| Campo | Detalles / Restricciones | Cardinalidad |
| :--- | :--- | :--- |
| **`id_categoria`** | **Primary Key (PK)** | **1** (Una categoría...) |
| `nombre` | | |
| `descripcion` | | |

#### Tabla: `productos`
| Campo | Detalles / Restricciones | Cardinalidad |
| :--- | :--- | :--- |
| **`id_productos`** | **Primary Key (PK)** | **1** (Un producto...) |
| `nombre` | | |
| `precio` | | |
| `stock` | | |
| `id_categoria` | **Foreign Key (FK)** -> `categoria` | **N..1** (...pertenece a 1 categoría) |

*(Nota: Se han omitido algunos campos descriptivos por brevedad, pero la estructura de claves se mantiene).*

#### Tabla: `direccion`
| Campo | Detalles / Restricciones | Cardinalidad |
| :--- | :--- | :--- |
| **`id_direccion`** | **Primary Key (PK)** | **1** (Una dirección...) |
| `codpostal` | | |
| `calle` | | |
| `ciudad` | | |

#### Tabla: `usuario`
| Campo | Detalles / Restricciones | Cardinalidad |
| :--- | :--- | :--- |
| **`id_usuario`** | **Primary Key (PK)** | **1** (Un usuario...) |
| `nombre` | | |
| `email` | | |
| `id_direccion` | **Foreign Key (FK)** -> `direccion` | **1..1** (...tiene 1 dirección) |

#### Tabla: `venta_cabecera`
| Campo | Detalles / Restricciones | Cardinalidad |
| :--- | :--- | :--- |
| **`id_venta_cabecera`** | **Primary Key (PK)** | **1** (Una venta...) |
| `fecha_venta` | | |
| `total` | | |
| `id_usuario` | **Foreign Key (FK)** -> `usuario` | **N..1** (...pertenece a 1 usuario) |
| `id_direccion` | **Foreign Key (FK)** -> `direccion` | **N..1** (...se envía a 1 dirección) |

#### Tabla: `venta_detalle`
| Campo | Detalles / Restricciones | Cardinalidad |
| :--- | :--- | :--- |
| **`id_venta_detalle`** | **Primary Key (PK)** | - |
| `cantidad` | | |
| `subtotal` | | |
| `id_productos` | **Foreign Key (FK)** -> `productos` | **N..1** (Muchos detalles tienen 1 producto) |
| `id_venta_cabecera` | **Foreign Key (FK)** -> `venta_cabecera`| **N..1** (Muchos detalles son de 1 venta) |

*(Nota de relaciones: El modelo refleja cardinalidades claras, como 1..N entre Categoría y Productos, 1..N entre Usuario y Venta, y N..1 entre Venta Detalle hacia Productos y Cabecera de Venta).*
