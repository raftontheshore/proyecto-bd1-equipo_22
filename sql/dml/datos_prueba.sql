/* =====================================================================
   RETRO GAMES - Etapa III: Implementación Física
   Script DML (Data Manipulation Language - SQL Server / Transact-SQL)
   Poblado inicial de datos de prueba (mínimo 8 registros por tabla;
   venta_cabecera = 10, venta_detalle = 11 por haber ventas de varios ítems)

   Requisito: haber ejecutado antes crear_bd.sql.
   Re-ejecutable: el bloque de limpieza inicial borra los datos existentes.
   ===================================================================== */

USE RetroGames;
GO

-- Las fechas se escriben en formato ISO 8601 (YYYY-MM-DDThh:mm:ss), que no
-- depende del idioma del servidor. Además se fija el orden año-mes-día para
-- la sesión, por si se agregan fechas con otro formato.
SET DATEFORMAT ymd;
GO

-- ---------------------------------------------------------------------
-- 0. Limpieza previa (ATENCIÓN: borra todos los datos de las 8 tablas)
-- ---------------------------------------------------------------------
DELETE FROM dbo.pago;
DELETE FROM dbo.venta_detalle;
DELETE FROM dbo.venta_cabecera;
DELETE FROM dbo.usuario;
DELETE FROM dbo.productos;
DELETE FROM dbo.metodo_pago;
DELETE FROM dbo.direccion;
DELETE FROM dbo.categoria;
GO

DBCC CHECKIDENT ('dbo.pago',            RESEED, 0);
DBCC CHECKIDENT ('dbo.venta_detalle',   RESEED, 0);
DBCC CHECKIDENT ('dbo.venta_cabecera',  RESEED, 0);
DBCC CHECKIDENT ('dbo.usuario',         RESEED, 0);
DBCC CHECKIDENT ('dbo.productos',       RESEED, 0);
DBCC CHECKIDENT ('dbo.metodo_pago',     RESEED, 0);
DBCC CHECKIDENT ('dbo.direccion',       RESEED, 0);
DBCC CHECKIDENT ('dbo.categoria',       RESEED, 0);
GO

-- Se inserta respetando estrictamente el orden jerárquico de las FK.

-- ---------------------------------------------------------------------
-- 1. Tabla: categoria (Independiente)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.categoria ON;
INSERT INTO dbo.categoria (id_categoria, nombre, descripcion) VALUES
(1, 'Videojuegos', 'Juegos clásicos en cartucho, disco o tarjeta para sistemas retro.'),
(2, 'Consolas de Sobremesa', 'Sistemas clásicos de entretenimiento para conectar a televisores o monitores.'),
(3, 'Consolas Portátiles', 'Dispositivos de videojuegos portátiles clásicos con pantalla integrada.'),
(4, 'Accesorios', 'Controles, cables de video, fuentes de alimentación y periféricos originales.'),
(5, 'Ediciones de Colección', 'Artículos retro de edición limitada, cajas originales y piezas de exhibición.'),
(6, 'Merchandising', 'Posters, manuales originales, guías de estrategia y artículos de colección.'),
(7, 'Juegos Arcade', 'Placas, repuestos y elementos para gabinetes y máquinas recreativas.'),
(8, 'Repuestos y Componentes', 'Piezas de hardware internas, joysticks de repuesto y carcasas de recambio.');
SET IDENTITY_INSERT dbo.categoria OFF;
GO

-- ---------------------------------------------------------------------
-- 2. Tabla: direccion (Independiente)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.direccion ON;
INSERT INTO dbo.direccion (id_direccion, codpostal, calle, provincia, ciudad) VALUES
(1, '3400', 'Av. 3 de Abril 1150', 'Corrientes', 'Corrientes'),
(2, '3500', 'Av. Alberdi 240', 'Chaco', 'Resistencia'),
(3, '1010', 'Av. Corrientes 1200', 'Buenos Aires', 'CABA'),
(4, '5000', 'Av. Vélez Sársfield 450', 'Córdoba', 'Córdoba'),
(5, '2000', 'Bv. Oroño 800', 'Santa Fe', 'Rosario'),
(6, '4400', 'Mitre 550', 'Salta', 'Salta'),
(7, '5500', 'San Martín 1200', 'Mendoza', 'Mendoza'),
(8, '9100', '9 de Julio 300', 'Chubut', 'Trelew');
SET IDENTITY_INSERT dbo.direccion OFF;
GO

-- ---------------------------------------------------------------------
-- 3. Tabla: metodo_pago (Independiente - RN-10)
--    activo se informa de forma explícita: el DEFAULT es 0 (un método nuevo
--    nace deshabilitado hasta que la administración lo autorice).
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.metodo_pago ON;
INSERT INTO dbo.metodo_pago (id_metodo_pago, nombre, descripcion, activo) VALUES
(1, 'Efectivo', 'Pago en efectivo al retirar por sucursal o contra entrega.', 1),
(2, 'Tarjeta de Crédito', 'Pago en cuotas mediante tarjeta de crédito habilitada.', 1),
(3, 'Tarjeta de Débito', 'Pago inmediato con tarjeta de débito bancaria.', 1),
(4, 'Transferencia Bancaria', 'Transferencia directa a cuenta CBU oficial del comercio.', 1),
(5, 'Mercado Pago', 'Billetera virtual y pagos con códigos QR.', 1),
(6, 'PayPal', 'Pagos internacionales seguros online.', 1),
(7, 'Criptomonedas', 'Pago descentralizado mediante USDT o BTC.', 0), -- Deshabilitado de prueba
(8, 'Cuenta Corriente', 'Crédito interno exclusivo para clientes corporativos.', 1);
SET IDENTITY_INSERT dbo.metodo_pago OFF;
GO

-- ---------------------------------------------------------------------
-- 4. Tabla: productos (Depende de categoria)
-- Estado de conservación permitido: 'NUEVO', 'USADO', 'EN_CAJA'
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.productos ON;
INSERT INTO dbo.productos (id_productos, nombre, descripcion, precio_original, precio, porcentaje_descuento, stock, stock_minimo, stock_bajo, marca, consola, tipo_producto, estado_conservacion, activo, id_categoria) VALUES
(1, 'Super Mario World', 'Cartucho original SNES en excelente estado.', 45000.00, 40000.00, 11.11, 12, 3, 0, 'Nintendo', 'SNES', 'Juego Físico', 'EN_CAJA', 1, 1),
(2, 'Sonic the Hedgehog', 'Cartucho Sega Genesis clásico suelto.', 30000.00, 30000.00, 0.00, 8, 2, 0, 'Sega', 'Genesis', 'Juego Físico', 'USADO', 1, 1),
(3, 'Consola Sega Dreamcast', 'Consola chipeada con accesorios y cables originales.', 180000.00, 160000.00, 11.11, 3, 2, 0, 'Sega', 'Dreamcast', 'Consola', 'EN_CAJA', 1, 2),
(4, 'Control Inalámbrico Retro', 'Gamepad USB compatible con múltiples sistemas.', 25000.00, 25000.00, 0.00, 20, 5, 0, '8BitDo', 'Universal', 'Accesorio', 'NUEVO', 1, 4),
(5, 'Game Boy Color (Teal)', 'Consola portátil color turquesa con tapa de pilas.', 95000.00, 90000.00, 5.26, 4, 2, 0, 'Nintendo', 'Game Boy Color', 'Consola', 'USADO', 1, 3),
(6, 'The Legend of Zelda: Ocarina of Time', 'Cartucho edición de colección Nintendo 64.', 75000.00, 68000.00, 9.33, 2, 3, 1, 'Nintendo', 'Nintendo 64', 'Juego Físico', 'EN_CAJA', 1, 5),
(7, 'Cable AV RCA para PlayStation', 'Cable de video componente universal PS1 / PS2.', 8000.00, 8000.00, 0.00, 25, 5, 0, 'Sony', 'PlayStation', 'Accesorio', 'NUEVO', 1, 4),
(8, 'Pac-Man Arcade Mini', 'Réplica miniatura de gabinete arcade clásico coleccionable.', 55000.00, 50000.00, 9.09, 6, 2, 0, 'Bandai Namco', 'Arcade', 'Merchandising', 'NUEVO', 1, 6);
SET IDENTITY_INSERT dbo.productos OFF;
GO

-- ---------------------------------------------------------------------
-- 5. Tabla: usuario (Depende de direccion)
-- Roles permitidos: 'ADMIN', 'CLIENTE'
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.usuario ON;
INSERT INTO dbo.usuario (id_usuario, nombre, email, [password], rol, activo, telefono, id_direccion) VALUES
(1, 'Carlos Administrador', 'admin@retrogames.com', '$2y$10$EjemploHashPasswordAdmin123', 'ADMIN', 1, '3794112233', 1),
(2, 'Micaela Pawlizki', 'micaela.p@gmail.com', '$2y$10$EjemploHashPasswordClient1', 'CLIENTE', 1, '3794556677', 1),
(3, 'Mauricio Aguirre', 'mauricio.a@gmail.com', '$2y$10$EjemploHashPasswordClient2', 'CLIENTE', 1, '3624889900', 2),
(4, 'Juan Pérez', 'juan.perez@hotmail.com', '$2y$10$EjemploHashPasswordClient3', 'CLIENTE', 1, '1144332211', 3),
(5, 'María Gómez', 'maria.gomez@yahoo.com', '$2y$10$EjemploHashPasswordClient4', 'CLIENTE', 1, '3516778899', 4),
(6, 'Esteban Quito', 'esteban.q@gmail.com', '$2y$10$EjemploHashPasswordClient5', 'CLIENTE', 0, '3413221144', 5),
(7, 'Lucía Fernández', 'lucia.f@gmail.com', '$2y$10$EjemploHashPasswordClient6', 'CLIENTE', 1, '3874551122', 6),
(8, 'Sofía Martínez', 'sofia.m@gmail.com', '$2y$10$EjemploHashPasswordClient7', 'CLIENTE', 1, '2615998877', 7);
SET IDENTITY_INSERT dbo.usuario OFF;
GO

-- ---------------------------------------------------------------------
-- 6. Tabla: venta_cabecera (Depende de usuario y direccion)
-- Estados permitidos: 'PENDIENTE', 'PAGADA', 'ENVIADA', 'ENTREGADA', 'CANCELADA', 'CARRITO'
-- (ENVIADA / ENTREGADA son estados administrativos, no seguimiento logístico)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.venta_cabecera ON;
INSERT INTO dbo.venta_cabecera (id_venta_cabecera, fecha_venta, estado, total, id_usuario, id_direccion) VALUES
(1, '2026-09-01T10:30:00', 'ENTREGADA', 40000.00, 2, 1),
(2, '2026-09-03T14:15:00', 'ENTREGADA', 30000.00, 3, 2),
(3, '2026-09-05T18:00:00', 'ENVIADA', 160000.00, 4, 3),
(4, '2026-09-10T11:20:00', 'PAGADA', 25000.00, 5, 4),
(5, '2026-09-15T09:45:00', 'PENDIENTE', 90000.00, 7, 6),
(6, '2026-09-18T16:30:00', 'ENTREGADA', 68000.00, 8, 7),
(7, '2026-09-20T12:00:00', 'PAGADA', 58000.00, 2, 1),    -- (Ej: producto 8 + producto 7)
(8, '2026-09-22T20:10:00', 'CARRITO', 50000.00, 3, 2),
(9, '2026-09-24T15:00:00', 'ENTREGADA', 50000.00, 4, 3), -- (Ej: 2 x producto 4)
(10, '2026-09-27T10:15:00', 'PAGADA', 30000.00, 8, 7);
SET IDENTITY_INSERT dbo.venta_cabecera OFF;
GO

-- ---------------------------------------------------------------------
-- 7. Tabla: venta_detalle (Depende de productos y venta_cabecera)
-- Se valida estrictamente: subtotal = cantidad * precio_unitario
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.venta_detalle ON;
INSERT INTO dbo.venta_detalle (id_venta_detalle, cantidad, precio_unitario, subtotal, id_productos, id_venta_cabecera) VALUES
(1, 1, 40000.00, 40000.00, 1, 1),   -- Venta 1: Super Mario World (1 x 40000)
(2, 1, 30000.00, 30000.00, 2, 2),   -- Venta 2: Sonic the Hedgehog (1 x 30000)
(3, 1, 160000.00, 160000.00, 3, 3), -- Venta 3: Sega Dreamcast (1 x 160000)
(4, 1, 25000.00, 25000.00, 4, 4),   -- Venta 4: Control Inalámbrico (1 x 25000)
(5, 1, 90000.00, 90000.00, 5, 5),   -- Venta 5: Game Boy Color (1 x 90000)
(6, 1, 68000.00, 68000.00, 6, 6),   -- Venta 6: Zelda N64 (1 x 68000)
(7, 1, 50000.00, 50000.00, 8, 7),   -- Venta 7 (Parte 1): Pac-Man Arcade (1 x 50000)
(8, 1, 8000.00, 8000.00, 7, 7),     -- Venta 7 (Parte 2): Cable AV (1 x 8000) -> Total venta 7 = 58000
(9, 1, 50000.00, 50000.00, 8, 8),   -- Venta 8: Pac-Man Arcade (1 x 50000)
(10, 2, 25000.00, 50000.00, 4, 9),  -- Venta 9: Control Inalámbrico (2 x 25000 = 50000)
(11, 1, 30000.00, 30000.00, 2, 10); -- Venta 10: Sonic the Hedgehog (1 x 30000)
SET IDENTITY_INSERT dbo.venta_detalle OFF;
GO

-- ---------------------------------------------------------------------
-- 8. Tabla: pago (Depende de venta_cabecera y metodo_pago)
-- Una venta tiene como máximo un pago (relación 0..1 con venta_cabecera)
-- ---------------------------------------------------------------------
SET IDENTITY_INSERT dbo.pago ON;
INSERT INTO dbo.pago (id_pago, fecha_pago, monto, id_venta_cabecera, id_metodo_pago) VALUES
(1, '2026-09-01T10:35:00', 40000.00, 1, 2),  -- Pago con Tarjeta de Crédito
(2, '2026-09-03T14:20:00', 30000.00, 2, 5),  -- Pago con Mercado Pago
(3, '2026-09-05T18:05:00', 160000.00, 3, 4), -- Pago por Transferencia Bancaria
(4, '2026-09-10T11:25:00', 25000.00, 4, 3),  -- Pago con Tarjeta de Débito
(5, '2026-09-18T16:35:00', 68000.00, 6, 2),  -- Pago con Tarjeta de Crédito
(6, '2026-09-20T12:05:00', 58000.00, 7, 5),  -- Pago con Mercado Pago
(7, '2026-09-24T15:05:00', 50000.00, 9, 3),  -- Pago con Tarjeta de Débito
(8, '2026-09-27T10:20:00', 30000.00, 10, 4); -- Pago por Transferencia Bancaria
-- Nota: las ventas 5 y 8 no tienen registro en pago porque están en estado 'PENDIENTE' y 'CARRITO' respectivamente.
SET IDENTITY_INSERT dbo.pago OFF;
GO
