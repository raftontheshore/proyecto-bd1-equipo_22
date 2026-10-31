# proyecto-bd1-equipo_22

![Cátedra](https://img.shields.io/badge/C%C3%A1tedra-Base_de_Datos_I-555555?style=flat-square)
![Motor](https://img.shields.io/badge/SQL_Server-T--SQL-CC2927?style=flat-square&logo=microsoftsqlserver&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Etapas_01_a_05_completas-22C55E?style=flat-square)

**Retro Games** es un sistema de gestión para una tienda de videojuegos retro, consolas y accesorios de colección. Este repositorio reúne la documentación y los scripts SQL desarrollados para la cátedra Base de Datos I.

<p align="center">
  <a href="docs/etapa-01/"><img alt="Etapa 01" src="https://img.shields.io/badge/ETAPA_01-REQUERIMIENTOS-3B82F6?style=for-the-badge"></a>
  <a href="docs/etapa-02/"><img alt="Etapa 02" src="https://img.shields.io/badge/ETAPA_02-MODELADO-8B5CF6?style=for-the-badge"></a>
  <a href="docs/etapa-03/"><img alt="Etapa 03" src="https://img.shields.io/badge/ETAPA_03-IMPLEMENTACI%C3%93N-22C55E?style=for-the-badge"></a>
  <a href="docs/etapa-04/"><img alt="Etapa 04" src="https://img.shields.io/badge/ETAPA_04-CONSULTAS-0EA5E9?style=for-the-badge"></a>
  <a href="docs/etapa-05/"><img alt="Etapa 05" src="https://img.shields.io/badge/ETAPA_05-TEMAS_T%C3%89CNICOS-EC4899?style=for-the-badge"></a>
</p>

| Etapa | Tema | Estado |
| :---: | :--- | :---: |
| [01](docs/etapa-01/) | Requerimientos y dominio del negocio | ✅ Completa |
| [02](docs/etapa-02/) | Modelado conceptual y lógico | ✅ Completa |
| [03](docs/etapa-03/) | Implementación física y validación | ✅ Completa |
| [04](docs/etapa-04/) | Consultas y casos de uso | ✅ Completa |
| [05](docs/etapa-05/) | Temas técnicos: procedimientos, transacciones, triggers, seguridad y optimización | ✅ Completa |

---

## ![01](https://img.shields.io/badge/01-555555?style=flat-square)![PRESENTACI%C3%93N Y CONTEXTO](https://img.shields.io/badge/PRESENTACI%C3%93N_Y_CONTEXTO-3B82F6?style=flat-square) Presentación y contexto

**Retro Games** es una tienda especializada en la comercialización de **videojuegos retro, consolas y accesorios vintage y de colección**. Opera como plataforma digital que centraliza el catálogo, atendiendo tanto al público general interesado en cultura retro como al personal administrativo encargado de la gestión comercial.

El sistema permite registrar y relacionar **productos, categorías, usuarios, direcciones, ventas, pagos y métodos de pago**, con una estructura centralizada para gestionar el catálogo, el stock y las ventas.

---

## ![02](https://img.shields.io/badge/02-555555?style=flat-square)![PROBLEM%C3%81TICA](https://img.shields.io/badge/PROBLEM%C3%81TICA-EF4444?style=flat-square) Problemática

La gestión del catálogo, el stock y las ventas se realiza de forma **manual y desorganizada**. Esto dificulta mantener actualizada la disponibilidad de productos, genera **errores en el control de inventario** y limita la posibilidad de ofrecer a los clientes un canal de compra en línea ágil y confiable.

---

## ![03](https://img.shields.io/badge/03-555555?style=flat-square)![ALCANCE](https://img.shields.io/badge/ALCANCE-22C55E?style=flat-square) Alcance

**Incluye**

- Gestión de productos y categorías del catálogo.
- Panel administrativo para el personal del negocio.
- Exploración y filtrado del catálogo, carrito de compras y checkout.
- Registro y control de ventas, stock e inventario.
- Reportes estadísticos de ventas.

**No incluye**

- Gestión de proveedores.
- Integración con pasarelas de pago reales.
- Logística de envíos ni seguimiento de pedidos.
- Más de un local o sucursal.
- Programa de fidelización o puntos.

El detalle completo está en [`alcance.md`](docs/etapa-01/alcance.md).

---

## ![04](https://img.shields.io/badge/04-555555?style=flat-square)![MODELO DE DATOS](https://img.shields.io/badge/MODELO_DE_DATOS-8B5CF6?style=flat-square) Modelo de datos

La base de datos `RetroGames` (SQL Server) está normalizada hasta 3FN y se compone de 8 tablas.

![Diagrama Entidad-Relación](docs/etapa-02/der/der.png)

| Tabla | Descripción |
| :--- | :--- |
| `categoria` | Categorías del catálogo. |
| `productos` | Videojuegos, consolas y accesorios, con precio, stock y estado de conservación. |
| `direccion` | Direcciones de usuarios y destinos de venta. |
| `usuario` | Clientes y personal administrativo (rol `CLIENTE` / `ADMIN`). |
| `metodo_pago` | Métodos de pago habilitados por la administración. |
| `venta_cabecera` | Datos generales de cada venta: fecha, estado, total, usuario y dirección. |
| `venta_detalle` | Ítems de cada venta, con el precio unitario vigente al momento de la compra. |
| `pago` | Pago asociado a una venta (como máximo uno por venta). |

Más detalle en [`modelo-relacional.md`](docs/etapa-02/modelo-relacional.md) y [`normalizacion.md`](docs/etapa-02/normalizacion.md).

---

## ![05](https://img.shields.io/badge/05-555555?style=flat-square)![REGLAS DE NEGOCIO](https://img.shields.io/badge/REGLAS_DE_NEGOCIO-F59E0B?style=flat-square) Reglas de negocio principales

- **Control de stock:** no se puede vender más unidades que el stock disponible, y cada venta concretada descuenta el stock.
- **Historial e inmutabilidad de precios:** cada detalle de venta conserva el precio unitario vigente al momento de la operación.
- **Registro de clientes:** toda venta está asociada a un usuario registrado; para comprar necesita contacto y dirección de envío.
- **Métodos de pago:** solo se usan métodos autorizados por la administración; un método nuevo nace deshabilitado.
- **Clasificación y conservación:** cada producto pertenece a una única categoría y declara su estado (Nuevo, Usado, En Caja).
- **Stock mínimo:** todo producto define un umbral de reposición.
- **Roles:** solo el personal administrativo modifica el catálogo, gestiona el stock y genera reportes.
- **Estados de la venta:** Carrito, Pendiente, Pagada, Enviada, Entregada o Cancelada (estados administrativos, sin logística).
- **Un pago por venta:** el monto del pago coincide con el total de la venta.
- **Protección del historial:** no se eliminan ventas con pago, ni usuarios, direcciones o productos con ventas asociadas.
- **Validez de importes:** precios y cantidades positivos; el total es la suma de los subtotales.

La definición completa se encuentra en [`reglas-negocio.md`](docs/etapa-01/reglas-negocio.md).

---

## ![06](https://img.shields.io/badge/06-555555?style=flat-square)![DOCUMENTACI%C3%93N](https://img.shields.io/badge/DOCUMENTACI%C3%93N-0EA5E9?style=flat-square) Documentación

La documentación está organizada en la carpeta [`docs/`](docs/), separada por etapas del proyecto.

### Etapa 01 — Requerimientos y dominio del negocio

[![Ir a la Etapa 01](https://img.shields.io/badge/Ir_a_la_carpeta-docs%2Fetapa--01-3B82F6?style=flat-square)](docs/etapa-01/)

| Documento | Descripción |
| :--- | :--- |
| [`descripcion-caso.md`](docs/etapa-01/descripcion-caso.md) | Organización, problemática y alcance funcional resumido. |
| [`alcance.md`](docs/etapa-01/alcance.md) | Funciones incluidas y excluidas del sistema. |
| [`reglas-negocio.md`](docs/etapa-01/reglas-negocio.md) | Reglas que rigen el funcionamiento del sistema. |
| [`decisiones-diseno.md`](docs/etapa-01/decisiones-diseno.md) | Decisiones y justificaciones del caso de negocio. |

### Etapa 02 — Modelado conceptual y lógico

[![Ir a la Etapa 02](https://img.shields.io/badge/Ir_a_la_carpeta-docs%2Fetapa--02-8B5CF6?style=flat-square)](docs/etapa-02/)

| Documento | Descripción |
| :--- | :--- |
| [`der.png`](docs/etapa-02/der/der.png) | Diagrama Entidad-Relación. |
| [`modelo-relacional.md`](docs/etapa-02/modelo-relacional.md) | Entidades, atributos, claves y cardinalidades del modelo relacional. |
| [`normalizacion.md`](docs/etapa-02/normalizacion.md) | Proceso de normalización hasta 3FN. |
| [`decisiones-diseno.md`](docs/etapa-02/decisiones-diseno.md) | Decisiones tomadas durante el diseño del modelo. |

### Etapa 03 — Implementación física y validación

[![Ir a la Etapa 03](https://img.shields.io/badge/Ir_a_la_carpeta-docs%2Fetapa--03-22C55E?style=flat-square)](docs/etapa-03/)

| Documento | Descripción |
| :--- | :--- |
| [`implementacion.md`](docs/etapa-03/implementacion.md) | Decisiones técnicas de la implementación en SQL Server. |
| [`restricciones-integridad.md`](docs/etapa-03/restricciones-integridad.md) | Restricciones y mecanismos de integridad de la base de datos. |
| [`pruebas-validacion.md`](docs/etapa-03/pruebas-validacion.md) | Pruebas y validaciones realizadas sobre la implementación. |
| [`crear_bd.sql`](sql/ddl/crear_bd.sql) | Script DDL: crea la base de datos, las tablas, restricciones e índices. |
| [`datos_prueba.sql`](sql/dml/datos_prueba.sql) | Script DML: carga de datos de prueba. |

### Etapa 04 — Consultas y casos de uso

[![Ir a la Etapa 04](https://img.shields.io/badge/Ir_a_la_carpeta-docs%2Fetapa--04-0EA5E9?style=flat-square)](docs/etapa-04/)

| Documento | Descripción |
| :--- | :--- |
| [`casos-uso.md`](docs/etapa-04/casos-uso.md) | Casos de uso que dan origen a las consultas. |
| [`comprobante-venta.md`](docs/etapa-04/comprobante-venta.md) | Comprobante de una venta: encabezado y detalle, con subtotales por renglón y total. Script: [`comprobante_venta.sql`](sql/consultas/comprobante_venta.sql). |
| [`informe-ventas.md`](docs/etapa-04/informe-ventas.md) | Informe agregado de ventas con `GROUP BY`, `SUM` y `COUNT`. Script: [`informe_ventas.sql`](sql/consultas/informe_ventas.sql). |
| [`consulta-avanzada.md`](docs/etapa-04/consulta-avanzada.md) | Clientes de alto valor: gasto superior al promedio, con `JOIN` de 7 tablas, `HAVING` y subconsulta. Script: [`consulta_avanzada.sql`](sql/consultas/consulta_avanzada.sql). |

### Etapa 05 — Temas técnicos

[![Ir a la Etapa 05](https://img.shields.io/badge/Ir_a_la_carpeta-docs%2Fetapa--05-EC4899?style=flat-square)](docs/etapa-05/)

Cada tema tiene su carpeta con la investigación, el script de demostración y las capturas de la ejecución (`evidencias/`).

| Tema | Qué se implementa | Investigación | Scripts | Evidencias |
| :--- | :--- | :--- | :--- | :--- |
| Procedimientos y funciones | Funciones y procedimientos de catálogo y de registro de ventas. | [`funciones_investigacion.md`](docs/etapa-05/procedimientos_funciones/funciones_investigacion.md) | [`funciones_scripts.sql`](docs/etapa-05/procedimientos_funciones/funciones_scripts.sql) | [`evidencias/`](docs/etapa-05/procedimientos_funciones/evidencias/) |
| Transacciones | Registro de venta atómico (`COMMIT` / `ROLLBACK`) y transacciones anidadas. | [`transacciones_investigacion.md`](docs/etapa-05/transacciones/transacciones_investigacion.md) | [`transacciones_scripts.sql`](docs/etapa-05/transacciones/transacciones_scripts.sql) | [`evidencias/`](docs/etapa-05/transacciones/evidencias/) |
| Triggers de auditoría | Auditoría de `UPDATE` y `DELETE` sobre `productos` y bloqueo de `DELETE` sobre `pago`. | [`triggers_investigacion.md`](docs/etapa-05/triggers_auditoria/triggers_investigacion.md) | [`triggers_scripts.sql`](docs/etapa-05/triggers_auditoria/triggers_scripts.sql) | [`evidencias/`](docs/etapa-05/triggers_auditoria/evidencias/) |
| Seguridad | Logins, usuarios y roles con permisos mínimos. | [`seguridad_investigacion.md`](docs/etapa-05/seguridad/seguridad_investigacion.md) | [`seguridad_scripts.sql`](docs/etapa-05/seguridad/seguridad_scripts.sql) | [`evidencias/`](docs/etapa-05/seguridad/evidencias/) |
| Optimización | Experimento de índices con 1.000.000 de filas e índices permanentes del esquema. | [`optimizacion_investigacion.md`](docs/etapa-05/optimizacion/optimizacion_investigacion.md) | [`optimizacion_scripts.sql`](docs/etapa-05/optimizacion/optimizacion_scripts.sql) | [`evidencias/`](docs/etapa-05/optimizacion/evidencias/) |

---

## ![07](https://img.shields.io/badge/07-555555?style=flat-square)![ESTRUCTURA DEL REPOSITORIO](https://img.shields.io/badge/ESTRUCTURA_DEL_REPOSITORIO-6B7280?style=flat-square) Estructura del repositorio

```text
proyecto-bd1-equipo_22/
│
├── docs/
│   │
│   ├── etapa-01/
│   │   ├── descripcion-caso.md
│   │   ├── alcance.md
│   │   ├── reglas-negocio.md
│   │   └── decisiones-diseno.md
│   │
│   ├── etapa-02/
│   │   ├── der/
│   │   │   └── der.png
│   │   ├── modelo-relacional.md
│   │   ├── normalizacion.md
│   │   └── decisiones-diseno.md
│   │
│   ├── etapa-03/
│   │   ├── implementacion.md
│   │   ├── restricciones-integridad.md
│   │   └── pruebas-validacion.md
│   │
│   ├── etapa-04/
│   │   ├── casos-uso.md
│   │   ├── comprobante-venta.md
│   │   ├── informe-ventas.md
│   │   └── consulta-avanzada.md
│   │
│   └── etapa-05/
│       ├── procedimientos_funciones/
│       │   ├── funciones_investigacion.md
│       │   ├── funciones_scripts.sql
│       │   └── evidencias/
│       ├── transacciones/
│       │   ├── transacciones_investigacion.md
│       │   ├── transacciones_scripts.sql
│       │   └── evidencias/
│       ├── triggers_auditoria/
│       │   ├── triggers_investigacion.md
│       │   ├── triggers_scripts.sql
│       │   └── evidencias/
│       ├── seguridad/
│       │   ├── seguridad_investigacion.md
│       │   ├── seguridad_scripts.sql
│       │   └── evidencias/
│       └── optimizacion/
│           ├── optimizacion_investigacion.md
│           ├── optimizacion_scripts.sql
│           └── evidencias/
│
├── sql/
│   │
│   ├── ddl/
│   │   └── crear_bd.sql
│   │
│   ├── dml/
│   │   └── datos_prueba.sql
│   │
│   └── consultas/
│       ├── comprobante_venta.sql
│       ├── informe_ventas.sql
│       └── consulta_avanzada.sql
│
└── README.md
```

---

## ![08](https://img.shields.io/badge/08-555555?style=flat-square)![EJECUCI%C3%93N](https://img.shields.io/badge/EJECUCI%C3%93N-14B8A6?style=flat-square) Orden de ejecución de los scripts

Requiere **SQL Server 2016 SP1 o superior** (por `CREATE OR ALTER` y `DROP ... IF EXISTS`). Ejecutar en este orden sobre una base de pruebas:

| Orden | Script | Nota |
| :---: | :--- | :--- |
| 1 | [`sql/ddl/crear_bd.sql`](sql/ddl/crear_bd.sql) | Crea la base `RetroGames` con sus 8 tablas, restricciones e índices. |
| 2 | [`sql/dml/datos_prueba.sql`](sql/dml/datos_prueba.sql) | Carga los datos de prueba. |
| 3 | [`sql/consultas/`](sql/consultas/) | Consultas de la Etapa 04 (comprobante, informe y consulta avanzada). |
| 4 | [`triggers_scripts.sql`](docs/etapa-05/triggers_auditoria/triggers_scripts.sql) | Crea la tabla de auditoría y los triggers. Conviene ejecutarlo sobre los datos recién cargados, porque sus resultados esperados parten de ellos. |
| 5 | [`funciones_scripts.sql`](docs/etapa-05/procedimientos_funciones/funciones_scripts.sql) | Crea funciones y procedimientos, entre ellos `sp_InsertarProducto`. |
| 6 | [`transacciones_scripts.sql`](docs/etapa-05/transacciones/transacciones_scripts.sql) | Crea `sp_RegistrarVentaTransaccional` y ejecuta las pruebas. |
| 7 | [`seguridad_scripts.sql`](docs/etapa-05/seguridad/seguridad_scripts.sql) | Requiere el paso 5 (permiso de ejecución sobre `sp_InsertarProducto`) y el motor en modo mixto. |
| 8 | [`optimizacion_scripts.sql`](docs/etapa-05/optimizacion/optimizacion_scripts.sql) | Ejecutar al final: usa la tabla de auditoría del paso 4 y redefine con cobertura los índices creados en el paso 1. |

> **Atención:**
> - Los scripts borran o modifican datos y están pensados para un entorno de pruebas. Para volver al estado inicial, repetir los pasos 1 y 2.
> - Con el trigger que bloquea el `DELETE` sobre `pago` instalado, `datos_prueba.sql` por sí solo falla. Para recargar los datos hay que ejecutar antes `crear_bd.sql`.

---

## ![09](https://img.shields.io/badge/09-555555?style=flat-square)![INTEGRANTES](https://img.shields.io/badge/INTEGRANTES-EC4899?style=flat-square) Integrantes

- [Aguirre Mauricio Alejandro](https://github.com/USUARIO)
- [Iturrieta Waldemar](https://github.com/USUARIO)
- [Panzich Luca Santiago](https://github.com/USUARIO)
- [Pawlizki Micaela Nataly](https://github.com/USUARIO)
- [Sanchez Rodriguez Enzo Nahuel](https://github.com/USUARIO)
