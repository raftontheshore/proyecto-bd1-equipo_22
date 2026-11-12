# Modelo Relacional (DER)

## Descripción General

El siguiente modelo relacional representa la estructura final de la base de datos del sistema de **Retro Games**, resultado del proceso de normalización (1FN, 2FN y 3FN) detallado en `normalizacion.md`. Está compuesto por **ocho entidades** relacionadas entre sí mediante claves foráneas (FK), que permiten gestionar el catálogo de productos, las categorías, los usuarios, las direcciones, el registro de ventas y los pagos con sus métodos.

> **Atributos derivados:** `precio_final` (productos), `subtotal` (venta_detalle) y `total` (venta_cabecera) figuran en el DER como atributos derivados (línea punteada). Se calculan a partir de otros campos y **no se almacenan** como columnas.
>
> - `precio_final = precio_original - (precio_original * porcentaje_descuento / 100)`
> - `subtotal = cantidad * precio_unitario`
> - `total = SUM(subtotal)` de los detalles de la venta

---

## Entidades y Atributos

### Tabla: `categoria`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_categoria`** | INT | **Primary Key (PK)** |
| `nombre` | VARCHAR | NOT NULL |
| `descripcion` | VARCHAR | |

### Tabla: `productos`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_productos`** | INT | **Primary Key (PK)** |
| `nombre` | VARCHAR | NOT NULL |
| `descripcion` | VARCHAR | |
| `precio_original` | DECIMAL | NOT NULL |
| `porcentaje_descuento` | DECIMAL | |
| `stock` | INT | |
| `stock_bajo` | BOOLEAN | |
| `marca` | VARCHAR | |
| `consola` | VARCHAR | |
| `tipo_producto` | VARCHAR | |
| `activo` | BOOLEAN | |
| `id_categoria` | INT | **Foreign Key (FK)** -> referencia a `categoria` |

### Tabla: `direccion`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_direccion`** | INT | **Primary Key (PK)** |
| `cod_postal` | VARCHAR | |
| `calle` | VARCHAR | |
| `provincia` | VARCHAR | |
| `ciudad` | VARCHAR | |

### Tabla: `usuario`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_usuario`** | INT | **Primary Key (PK)** |
| `nombre` | VARCHAR | NOT NULL |
| `email` | VARCHAR | NOT NULL, UNIQUE |
| `password` | VARCHAR | NOT NULL |
| `rol` | VARCHAR | NOT NULL |
| `activo` | BOOLEAN | |
| `telefono` | VARCHAR | |
| `id_direccion` | INT | **Foreign Key (FK)** -> referencia a `direccion` (opcional) |

### Tabla: `venta_cabecera`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_venta`** | INT | **Primary Key (PK)** |
| `fecha_venta` | DATETIME | NOT NULL |
| `estado` | VARCHAR | NOT NULL |
| `id_usuario` | INT | **Foreign Key (FK)** -> referencia a `usuario`, NOT NULL |
| `id_direccion` | INT | **Foreign Key (FK)** -> referencia a `direccion` |

### Tabla: `venta_detalle`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_venta_detalle`** | INT | **Primary Key (PK)** |
| `cantidad` | INT | NOT NULL |
| `precio_unitario` | DECIMAL | NOT NULL |
| `id_productos` | INT | **Foreign Key (FK)** -> referencia a `productos`, NOT NULL |
| `id_venta` | INT | **Foreign Key (FK)** -> referencia a `venta_cabecera`, NOT NULL |

### Tabla: `pago`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_pago`** | INT | **Primary Key (PK)** |
| `fecha_pago` | DATETIME | NOT NULL |
| `monto` | DECIMAL | NOT NULL |
| `id_venta` | INT | **Foreign Key (FK)** -> referencia a `venta_cabecera`, NOT NULL, UNIQUE |
| `id_metodo_pago` | INT | **Foreign Key (FK)** -> referencia a `metodo_pago`, NOT NULL |

### Tabla: `metodo_pago`

| Campo | Tipo de Dato | Restricciones |
| :--- | :--- | :--- |
| **`id_metodo_pago`** | INT | **Primary Key (PK)** |
| `nombre` | VARCHAR | NOT NULL |
| `descripcion` | VARCHAR | |

---

## Relaciones y Cardinalidades

| Relación | Cardinalidad | Descripción |
| :--- | :--- | :--- |
| `categoria` → `productos` | **1..N** | Una categoría puede agrupar muchos productos; cada producto pertenece a una única categoría. |
| `productos` → `venta_detalle` | **1..N** | Un producto puede aparecer en muchos detalles de venta; cada detalle referencia a un único producto. |
| `venta_cabecera` → `venta_detalle` | **1..N** | Una venta (cabecera) puede tener muchos ítems de detalle; cada detalle pertenece a una única venta. |
| `usuario` → `venta_cabecera` | **1..N** | Un usuario puede realizar muchas ventas; cada venta es realizada por un único usuario. |
| `direccion` → `venta_cabecera` | **1..N** | Una dirección puede usarse como destino de muchas ventas; cada venta tiene una única dirección de entrega. |
| `direccion` → `usuario` | **1..N** (opcional) | Una dirección puede estar asociada a varios usuarios; un usuario tiene como máximo una dirección propia. |
| `venta_cabecera` → `pago` | **1..1** | Cada venta posee un único pago; cada pago corresponde a una única venta. |
| `metodo_pago` → `pago` | **1..N** | Un método de pago puede utilizarse en muchos pagos; cada pago utiliza un único método. |

---

## Diagrama Entidad-Relación

```mermaid
erDiagram
    CATEGORIA ||--o{ PRODUCTOS : clasifica
    PRODUCTOS ||--o{ VENTA_DETALLE : incluye
    VENTA_CABECERA ||--|{ VENTA_DETALLE : contiene
    USUARIO ||--o{ VENTA_CABECERA : realiza
    DIRECCION ||--o{ VENTA_CABECERA : "es destino de"
    DIRECCION |o--o{ USUARIO : reside_en
    VENTA_CABECERA ||--|| PAGO : posee
    METODO_PAGO ||--o{ PAGO : utiliza

    CATEGORIA {
        int id_categoria PK
        string nombre
        string descripcion
    }

    PRODUCTOS {
        int id_productos PK
        string nombre
        string descripcion
        decimal precio_original
        decimal porcentaje_descuento
        int stock
        boolean stock_bajo
        string marca
        string consola
        string tipo_producto
        boolean activo
        int id_categoria FK
    }

    DIRECCION {
        int id_direccion PK
        string cod_postal
        string calle
        string provincia
        string ciudad
    }

    USUARIO {
        int id_usuario PK
        string nombre
        string email
        string password
        string rol
        boolean activo
        string telefono
        int id_direccion FK
    }

    VENTA_CABECERA {
        int id_venta PK
        datetime fecha_venta
        string estado
        int id_usuario FK
        int id_direccion FK
    }

    VENTA_DETALLE {
        int id_venta_detalle PK
        int cantidad
        decimal precio_unitario
        int id_productos FK
        int id_venta FK
    }

    PAGO {
        int id_pago PK
        datetime fecha_pago
        decimal monto
        int id_venta FK
        int id_metodo_pago FK
    }

    METODO_PAGO {
        int id_metodo_pago PK
        string nombre
        string descripcion
    }
```