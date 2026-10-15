# Casos de Uso del Sistema

Este documento detalla todos los casos de uso previstos para el sistema **Retro Games**, abarcando tanto las operaciones generales definidas en el alcance del proyecto como las consultas analíticas específicas desarrolladas en la Etapa IV.

## Módulo 1: Catálogo y Compras (Rol: Cliente)

### CU-01: Exploración y Filtrado del Catálogo
*   **Actor:** Cliente (registrado o visitante).
*   **Descripción:** El usuario puede navegar por la tienda en línea, visualizar los productos con sus imágenes (URL o archivo), precio original, descuentos y estado de conservación (Nuevo, Usado, En Caja).
*   **Reglas asociadas:** Solo se muestran productos activos y con stock disponible.

### CU-02: Gestión del Carrito de Compras
*   **Actor:** Cliente.
*   **Descripción:** El usuario puede agregar productos al carrito, modificar cantidades o eliminar ítems. 
*   **Reglas asociadas:** El sistema genera una venta temporal en estado `CARRITO`. No se exige método de pago en esta instancia.

### CU-03: Checkout y Concreción de Compra
*   **Actor:** Cliente (requiere registro).
*   **Descripción:** El cliente confirma el carrito ingresando sus datos de contacto, dirección de entrega y seleccionando un método de pago habilitado.
*   **Reglas asociadas:** La venta pasa a estado `PENDIENTE` (si requiere validación) o `PAGADA` (si se registra el cobro). Se congela el precio unitario histórico de cada producto en el detalle.

---

## Módulo 2: Panel Administrativo (Rol: Personal Administrativo)

### CU-04: Gestión de Inventario y Catálogo
*   **Actor:** Personal Administrativo.
*   **Descripción:** Permite dar de alta, baja (lógica mediante campo `activo`) y modificar videojuegos, consolas, accesorios y sus categorías.
*   **Reglas asociadas:** Incluye la parametrización del umbral de `stock_minimo` (RN-07) y la restricción de no eliminar categorías con productos asociados (RN-03).

### CU-05: Gestión de Ventas y Cobros
*   **Actor:** Personal Administrativo.
*   **Descripción:** Seguimiento del ciclo de vida de la venta, actualizando sus estados (`PAGADA`, `ENVIADA`, `ENTREGADA`, `CANCELADA`) y administrando los métodos de pago habilitados en la plataforma.
*   **Reglas asociadas:** No se gestiona logística externa, solo el estado interno (RN-12). Una venta admite un solo pago por el monto total (RN-13).

---

## Módulo 3: Analítica y Consultas Avanzadas (Etapa IV)

Estos casos de uso cuentan con desarrollo SQL específico en el directorio `sql/consultas/`.

### CU-06: Emisión de Comprobante de Venta
*   **Actor:** Personal Administrativo / Sistema.
*   **Descripción:** Generación de un ticket consolidado de la venta, detallando cliente, dirección, método de pago, ítems con subtotales calculados y el total acumulado de la operación.
*   **Reglas asociadas:** Solo se emite para ventas efectivamente concretadas (`PAGADA`, `ENVIADA`, `ENTREGADA`).
*   **Script de respaldo:** `comprobante_venta.sql`.

### CU-07: Reporte Agregado de Ventas por Categoría
*   **Actor:** Personal Administrativo.
*   **Descripción:** Consolidación métrica del rendimiento comercial agrupado por rubro (categoría) dentro de un rango de fechas parametrizable. Evalúa unidades físicas vendidas, recaudación y ticket promedio.
*   **Objetivo:** Toma de decisiones estratégicas sobre reposición de stock.
*   **Script de respaldo:** `informe_ventas.sql`.

### CU-08: Identificación de Clientes de Alto Valor
*   **Actor:** Personal Administrativo.
*   **Descripción:** Consulta analítica que detecta a los clientes cuyo gasto total acumulado (en ventas concretadas) supera el promedio general de gasto por cliente de la tienda.
*   **Objetivo:** Priorizar el seguimiento comercial, fidelización y oferta anticipada de artículos retro de colección.
*   **Script de respaldo:** `consulta_avanzada.sql`.