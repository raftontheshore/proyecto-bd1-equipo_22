/* =====================================================================
   RETRO GAMES - Etapa V: Seguridad (Usuarios y Roles)
   Archivo: seguridad/scripts.sql
   Requisito: haber ejecutado crear_bd.sql, datos_prueba.sql y el script de
   procedimientos y funciones, que crea dbo.sp_InsertarProducto.
   ===================================================================== */

-- 1. CREACIÓN DE INICIOS DE SESIÓN (Nivel Servidor)
USE master;
GO

-- Logins para Prueba de Usuarios
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'retro_admin')
    CREATE LOGIN retro_admin WITH PASSWORD = 'AdminRetro123*';
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'retro_vendedor')
    CREATE LOGIN retro_vendedor WITH PASSWORD = 'VendedorRetro123*';

-- Logins para Prueba de Roles
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'retro_cliente1')
    CREATE LOGIN retro_cliente1 WITH PASSWORD = 'ClienteUno123*';
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'retro_cliente2')
    CREATE LOGIN retro_cliente2 WITH PASSWORD = 'ClienteDos123*';
GO

-- 2. CREACIÓN DE USUARIOS Y ASIGNACIÓN DE PERMISOS (Nivel Base de Datos)
USE RetroGames;
GO

-- Creación de usuarios vinculados a los logins
IF DATABASE_PRINCIPAL_ID('retro_admin') IS NULL
    CREATE USER retro_admin FOR LOGIN retro_admin;
IF DATABASE_PRINCIPAL_ID('retro_vendedor') IS NULL
    CREATE USER retro_vendedor FOR LOGIN retro_vendedor;
IF DATABASE_PRINCIPAL_ID('retro_cliente1') IS NULL
    CREATE USER retro_cliente1 FOR LOGIN retro_cliente1;
IF DATABASE_PRINCIPAL_ID('retro_cliente2') IS NULL
    CREATE USER retro_cliente2 FOR LOGIN retro_cliente2;
GO

/* ---------------------------------------------------------------------
   PARTE 1: PERMISOS A NIVEL DE USUARIOS
   RN-05: Solo el personal administrativo gestiona catálogo y stock.
   --------------------------------------------------------------------- */

-- A. Asignar rol de administrador total a retro_admin
ALTER ROLE db_owner ADD MEMBER retro_admin;
GO

-- B. Asignar permisos restringidos a retro_vendedor
-- Solo puede leer productos, no modificarlos, cumpliendo la RN-05
GRANT SELECT ON dbo.productos TO retro_vendedor;
GO

/* ---------------------------------------------------------------------
   PARTE 2: PERMISOS A NIVEL DE ROLES
   --------------------------------------------------------------------- */

-- A. Crear un rol personalizado para lectura del catálogo
IF DATABASE_PRINCIPAL_ID('rol_consulta_catalogo') IS NULL
    CREATE ROLE rol_consulta_catalogo;
GO

-- B. Asignar permisos al rol
GRANT SELECT ON dbo.productos TO rol_consulta_catalogo;
GO

-- C. Incorporar solo a un usuario al rol
ALTER ROLE rol_consulta_catalogo ADD MEMBER retro_cliente1;
GO


/* =====================================================================
   DEMOSTRACIÓN Y PRUEBAS 
   ===================================================================== */

-- ==========================================
-- PRUEBAS PARTE 1 
-- ==========================================

-- Prueba 1.1: Administrador usando el Procedimiento (Ejecución valida)
EXECUTE AS USER = 'retro_admin';
PRINT '--- PRUEBA 1.1: Admin insertando mediante SP ---';
EXEC dbo.sp_InsertarProducto 
    @nombre = 'Consola Admin SP', 
    @precio = 150000.00,
    @stock = 14,
    @stock_minimo = 2, 
    @estado_conservacion = 'NUEVO', 
    @id_categoria = 1;
PRINT 'Inserción por Admin exitosa.';
REVERT;
GO

-- Prueba 1.2: Vendedor haciendo un INSERT directo (Ejecución fallida)
EXECUTE AS USER = 'retro_vendedor';
PRINT '--- PRUEBA 1.2: Vendedor insertando directo (Se espera error - RN-05) ---';
BEGIN TRY
    INSERT INTO dbo.productos (nombre, precio, stock_minimo, estado_conservacion, id_categoria)
    VALUES ('Consola Vendedor Directa', 50000.00, 1, 'USADO', 1);
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

-- Prueba 1.3: Vendedor intentando usar el Procedimiento (Ejecución fallida)
EXECUTE AS USER = 'retro_vendedor';
PRINT '--- PRUEBA 1.3: Vendedor insertando mediante SP (Se espera error - RN-05) ---';
BEGIN TRY
    EXEC dbo.sp_InsertarProducto 
        @nombre = 'Juego Vendedor SP', 
        @precio = 25000.00, 
        @stock = 12,
        @stock_minimo = 5, 
        @estado_conservacion = 'NUEVO', 
        @id_categoria = 2;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO


-- ==========================================
-- PRUEBAS PARTE 2 (Roles y Lectura)
-- ==========================================

-- Prueba 2.1: Usuario CON rol consultando la tabla (Ejecución valida)
EXECUTE AS USER = 'retro_cliente1';
PRINT '--- PRUEBA 2.1: Cliente CON rol consultando catálogo ---';
SELECT TOP 3 id_productos, nombre, precio FROM dbo.productos;
REVERT;
GO

-- Prueba 2.2: Usuario SIN rol consultando la tabla (Ejecución fallida)
EXECUTE AS USER = 'retro_cliente2';
PRINT '--- PRUEBA 2.2: Cliente SIN rol consultando catálogo ---';
BEGIN TRY
    SELECT TOP 3 id_productos, nombre, precio FROM dbo.productos;
END TRY
BEGIN CATCH
    PRINT 'Error capturado: ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO