# Investigación: Seguridad y Manejo de Permisos

## 1. Definición y objetivo

La seguridad en una base de datos permite controlar de forma granular qué usuarios pueden acceder a la información y qué operaciones específicas pueden realizar. SQL Server administra estos accesos otorgando permisos de manera individual (a usuarios) o agrupándolos mediante roles. El objetivo principal es aplicar el principio de mínimo privilegio, asegurando que cada identidad tenga solo los permisos estrictamente necesarios para cumplir su función.

## 2. Ventajas y aplicaciones

Implementar un esquema de seguridad robusto aporta los siguientes beneficios:

* **Protección de datos:** Protege la información sensible del sistema frente a accesos malintencionados.

* **Prevención de errores:** Evita modificaciones accidentales o no autorizadas limitando las operaciones DML (`INSERT`, `UPDATE`, `DELETE`).

* **Asignación de responsabilidades:** Permite perfilar los accesos según el rol operativo del usuario en la organización.

* **Mantenibilidad:** Simplifica la administración de accesos mediante el uso de roles reutilizables, evitando la asignación repetitiva de permisos uno a uno.

## 3. Implementación en SQL Server Express

Para implementar este modelo en SQL Server Express, primero se debe verificar que el motor esté configurado en "modo mixto" (autenticación integrada de Windows y autenticación por usuario de SQL Server). A nivel de sintaxis, la implementación requiere:

* Creación de credenciales a nivel de servidor (`CREATE LOGIN`).

* Creación de usuarios en la base de datos específica (`CREATE USER`).

* Creación de roles personalizados (`CREATE ROLE`) y asignación de miembros (`ALTER ROLE ... ADD MEMBER`).

* Otorgamiento de permisos mediante la cláusula `GRANT` (`SELECT`, `EXECUTE`, etc.) o denegación mediante `DENY`.

## 4. Caso concreto aplicado al sistema de Retro Games

Para nuestro dominio de ventas de videojuegos retro, se implementan dos escenarios prácticos orientados a hacer cumplir nuestras reglas de negocio, específicamente la **RN-05** (Solo el personal administrativo gestiona catálogo, stock y reportes):

* **Permisos a nivel de usuarios (Control del Catálogo - RN-05):** Se crean dos usuarios: un administrador (`retro_admin`) y un vendedor (`retro_vendedor`). Al administrador se le asigna el rol `db_owner`, otorgándole control total. Para cumplir estrictamente con la RN-05, al vendedor *solo* se le otorga permiso de lectura (`SELECT`) sobre el catálogo. De esta forma, el motor de base de datos bloqueará automáticamente cualquier intento del vendedor por hacer un `INSERT` directo o por ejecutar el procedimiento almacenado `sp_InsertarProducto`, garantizando que la restricción comercial sea inviolable a nivel de datos.

* **Permisos a nivel de roles (Visibilidad del Catálogo):** Se define un rol personalizado llamado `rol_consulta_catalogo` que posee permisos de lectura (`SELECT`) exclusivamente sobre la tabla `productos`. Se crean dos usuarios clientes, pero solo uno se asocia al rol, demostrando cómo se aísla la información para el usuario sin los privilegios correctos.

## 5. Script de demostración y resultados obtenidos

El código físico para la creación de logins, usuarios, roles y la asignación de permisos, junto con las pruebas de éxito y denegación de acceso, se encuentran en el archivo `scripts.sql` adjunto en este directorio.

Las evidencias visuales de la ejecución de estas pruebas se documentan a través de capturas de pantalla, las cuales están alojadas dentro de la subcarpeta `evidencias/`.