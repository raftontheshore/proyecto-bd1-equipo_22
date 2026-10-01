/* =====================================================================
   RETRO GAMES - Etapa III: Implementación Física
   Script DDL (SQL Server / Transact-SQL)
   Origen: modelo-relacional.md (8 tablas, 3FN)
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 0. Base de datos
-- ---------------------------------------------------------------------
IF DB_ID('RetroGames') IS NULL
    CREATE DATABASE RetroGames;
GO

USE RetroGames;
GO

-- ---------------------------------------------------------------------
-- 1. categoria
-- ---------------------------------------------------------------------
CREATE TABLE dbo.categoria (
    id_categoria  INT IDENTITY(1,1) NOT NULL,
    nombre        VARCHAR(100)      NOT NULL,
    descripcion   VARCHAR(255)      NULL,

    CONSTRAINT PK_categoria PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_categoria_nombre UNIQUE (nombre)
);
GO

-- ---------------------------------------------------------------------
-- 2. direccion
-- ---------------------------------------------------------------------
CREATE TABLE dbo.direccion (
    id_direccion  INT IDENTITY(1,1) NOT NULL,
    codpostal     VARCHAR(10)       NULL,
    calle         VARCHAR(150)      NULL,
    provincia     VARCHAR(100)      NULL,
    ciudad        VARCHAR(100)      NULL,

    CONSTRAINT PK_direccion PRIMARY KEY (id_direccion)
);
GO

-- ---------------------------------------------------------------------
-- 3. metodo_pago  (RN-10: solo métodos autorizados por la administración)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.metodo_pago (
    id_metodo_pago  INT IDENTITY(1,1) NOT NULL,
    nombre          VARCHAR(50)       NOT NULL,
    descripcion     VARCHAR(255)      NULL,
    activo          BIT               NOT NULL      -- 1 = habilitado / autorizado
        CONSTRAINT DF_metodo_pago_activo DEFAULT 1,

    CONSTRAINT PK_metodo_pago PRIMARY KEY (id_metodo_pago),
    CONSTRAINT UQ_metodo_pago_nombre UNIQUE (nombre)
);
GO

-- ---------------------------------------------------------------------
-- 4. productos
-- ---------------------------------------------------------------------
CREATE TABLE dbo.productos (
    id_productos          INT IDENTITY(1,1) NOT NULL,
    nombre                VARCHAR(150)      NOT NULL,
    descripcion           VARCHAR(500)      NULL,
    precio_original       DECIMAL(10,2)     NULL,
    precio                DECIMAL(10,2)     NOT NULL,
    porcentaje_descuento  DECIMAL(5,2)      NULL,
    stock                 INT               NULL
        CONSTRAINT DF_productos_stock DEFAULT 0,
    stock_minimo          INT               NOT NULL   -- RN-07: umbral de reposición
        CONSTRAINT DF_productos_stock_minimo DEFAULT 5,
    stock_bajo            BIT               NULL
        CONSTRAINT DF_productos_stock_bajo DEFAULT 0,
    marca                 VARCHAR(100)      NULL,
    consola               VARCHAR(100)      NULL,
    tipo_producto         VARCHAR(100)      NULL,
    estado_conservacion   VARCHAR(20)       NOT NULL,  -- RN-04: obligatorio
    activo                BIT               NULL
        CONSTRAINT DF_productos_activo DEFAULT 1,
    id_categoria          INT               NOT NULL,

    CONSTRAINT PK_productos PRIMARY KEY (id_productos),

    CONSTRAINT FK_productos_categoria
        FOREIGN KEY (id_categoria) REFERENCES dbo.categoria (id_categoria)
        ON DELETE NO ACTION     -- no se puede borrar una categoría con productos
        ON UPDATE CASCADE,

    CONSTRAINT CK_productos_precio           CHECK (precio > 0),
    CONSTRAINT CK_productos_precio_original  CHECK (precio_original IS NULL OR precio_original > 0),
    CONSTRAINT CK_productos_descuento        CHECK (porcentaje_descuento IS NULL
                                                    OR porcentaje_descuento BETWEEN 0 AND 100),
    CONSTRAINT CK_productos_stock            CHECK (stock IS NULL OR stock >= 0),
    CONSTRAINT CK_productos_stock_minimo     CHECK (stock_minimo >= 0),
    CONSTRAINT CK_productos_conservacion     CHECK (estado_conservacion IN
        ('NUEVO', 'USADO', 'EN_CAJA'))
);
GO

-- ---------------------------------------------------------------------
-- 5. usuario
-- ---------------------------------------------------------------------
CREATE TABLE dbo.usuario (
    id_usuario    INT IDENTITY(1,1) NOT NULL,
    nombre        VARCHAR(100)      NOT NULL,
    email         VARCHAR(150)      NOT NULL,
    [password]    VARCHAR(255)      NOT NULL,   -- 255 para hash (bcrypt, etc.)
    rol           VARCHAR(20)       NOT NULL
        CONSTRAINT DF_usuario_rol DEFAULT 'CLIENTE',
    activo        BIT               NULL
        CONSTRAINT DF_usuario_activo DEFAULT 1,
    telefono      VARCHAR(30)       NULL,
    id_direccion  INT               NULL,       -- opcional

    CONSTRAINT PK_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_usuario_email UNIQUE (email),

    CONSTRAINT FK_usuario_direccion
        FOREIGN KEY (id_direccion) REFERENCES dbo.direccion (id_direccion)
        ON DELETE SET NULL      -- si se borra la dirección, el usuario queda sin dirección
        ON UPDATE NO ACTION,

    CONSTRAINT CK_usuario_email CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT CK_usuario_rol   CHECK (rol IN ('ADMIN', 'CLIENTE'))
);
GO

-- ---------------------------------------------------------------------
-- 6. venta_cabecera
-- ---------------------------------------------------------------------
CREATE TABLE dbo.venta_cabecera (
    id_venta_cabecera  INT IDENTITY(1,1) NOT NULL,
    fecha_venta        DATETIME          NOT NULL
        CONSTRAINT DF_venta_cabecera_fecha DEFAULT GETDATE(),
    estado             VARCHAR(20)       NOT NULL
        CONSTRAINT DF_venta_cabecera_estado DEFAULT 'PENDIENTE',
    total              DECIMAL(12,2)     NOT NULL,
    id_usuario         INT               NOT NULL,
    id_direccion       INT               NOT NULL,

    CONSTRAINT PK_venta_cabecera PRIMARY KEY (id_venta_cabecera),

    CONSTRAINT FK_venta_cabecera_usuario
        FOREIGN KEY (id_usuario) REFERENCES dbo.usuario (id_usuario)
        ON DELETE NO ACTION     -- se conserva el historial de ventas
        ON UPDATE NO ACTION,

    CONSTRAINT FK_venta_cabecera_direccion
        FOREIGN KEY (id_direccion) REFERENCES dbo.direccion (id_direccion)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,

    CONSTRAINT CK_venta_cabecera_total  CHECK (total >= 0),
    CONSTRAINT CK_venta_cabecera_estado CHECK (estado IN
        ('PENDIENTE', 'PAGADA', 'ENVIADA', 'ENTREGADA', 'CANCELADA', 'CARRITO'))
);
GO

-- ---------------------------------------------------------------------
-- 7. venta_detalle
-- ---------------------------------------------------------------------
CREATE TABLE dbo.venta_detalle (
    id_venta_detalle   INT IDENTITY(1,1) NOT NULL,
    cantidad           INT               NOT NULL,
    precio_unitario    DECIMAL(10,2)     NOT NULL,
    subtotal           DECIMAL(12,2)     NOT NULL,
    id_productos       INT               NOT NULL,
    id_venta_cabecera  INT               NOT NULL,

    CONSTRAINT PK_venta_detalle PRIMARY KEY (id_venta_detalle),

    CONSTRAINT FK_venta_detalle_productos
        FOREIGN KEY (id_productos) REFERENCES dbo.productos (id_productos)
        ON DELETE NO ACTION     -- no se borra un producto que ya se vendió
        ON UPDATE NO ACTION,

    CONSTRAINT FK_venta_detalle_cabecera
        FOREIGN KEY (id_venta_cabecera) REFERENCES dbo.venta_cabecera (id_venta_cabecera)
        ON DELETE CASCADE       -- al borrar la venta se borran sus ítems
        ON UPDATE CASCADE,

    CONSTRAINT CK_venta_detalle_cantidad  CHECK (cantidad > 0),
    CONSTRAINT CK_venta_detalle_precio    CHECK (precio_unitario > 0),
    CONSTRAINT CK_venta_detalle_subtotal  CHECK (subtotal > 0 AND subtotal = cantidad * precio_unitario)
);
GO

-- ---------------------------------------------------------------------
-- 8. pago  (venta_cabecera 1..1 pago | metodo_pago 1..N pago)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.pago (
    id_pago            INT IDENTITY(1,1) NOT NULL,
    fecha_pago         DATETIME          NOT NULL
        CONSTRAINT DF_pago_fecha DEFAULT GETDATE(),
    monto              DECIMAL(12,2)     NOT NULL,
    id_venta_cabecera  INT               NOT NULL,
    id_metodo_pago     INT               NOT NULL,

    CONSTRAINT PK_pago PRIMARY KEY (id_pago),
    CONSTRAINT UQ_pago_venta UNIQUE (id_venta_cabecera),   -- una venta, un pago

    CONSTRAINT FK_pago_venta_cabecera
        FOREIGN KEY (id_venta_cabecera) REFERENCES dbo.venta_cabecera (id_venta_cabecera)
        ON DELETE NO ACTION     -- el pago es registro contable, no se borra en cascada
        ON UPDATE NO ACTION,

    CONSTRAINT FK_pago_metodo_pago
        FOREIGN KEY (id_metodo_pago) REFERENCES dbo.metodo_pago (id_metodo_pago)
        ON DELETE NO ACTION     -- no se borra un método usado en pagos
        ON UPDATE NO ACTION,

    CONSTRAINT CK_pago_monto CHECK (monto > 0)
);
GO
