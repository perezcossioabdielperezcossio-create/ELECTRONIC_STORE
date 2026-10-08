# ElectronicStore POS & Gestión de Inventarios
### Memoria Técnica Oficial — v1.2.0 · POS Avanzado, CRM & Repartidores · Offline-First · Flutter + Firebase Firestore Real-Time

---

## Tabla de Contenidos
1. [Resumen del Proyecto](#1-resumen-del-proyecto)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Estructura de Directorios](#3-estructura-de-directorios)
4. [Stack Tecnológico](#4-stack-tecnológico)
5. [Esquema de Base de Datos](#5-esquema-de-base-de-datos)
6. [Módulos Implementados](#6-módulos-implementados)
7. [Motor Offline-First y Sincronización en Tiempo Real](#7-motor-offline-first-y-sincronización-en-tiempo-real)
8. [Matriz de Cumplimiento Funcional](#8-matriz-de-cumplimiento-funcional)
9. [Requisitos No Funcionales](#9-requisitos-no-funcionales)
10. [Pendientes y Deuda Técnica](#10-pendientes-y-deuda-técnica)
11. [Guía de Ejecución](#11-guía-de-ejecución)
12. [Historial de Cambios](#12-historial-de-cambios)

---

## 1. Resumen del Proyecto

**ElectronicStore** es una solución integral de **Punto de Venta (POS)**, **Gestión de Inventarios**, **CRM de Clientes** y **Gestión de Entregas (Deliveries)** desarrollada en **Flutter**, diseñada para operar en entornos con conectividad inestable (**Offline-First**) y con soporte de sincronización reactiva bidireccional en tiempo real entre múltiples dispositivos conectados a **Cloud Firestore**.

**Características principales:**
- ✅ Costeo real por lotes con método **FIFO** (First-In, First-Out) y desglose transaccional por lote.
- ✅ Valorizado en **Bolivianos (Bs.)**.
- ✅ Sincronización bidireccional reactiva y en vivo con **Firebase Firestore** (`products`, `lots`, `sales`, `clients`, `deliveries`).
- ✅ **Módulo CRM de Clientes:** Directorio de clientes con teléfono, WhatsApp y dirección predeterminada, autocompletado y alta rápida durante el checkout.
- ✅ **Módulo de Repartidores & Delivery:** CRUD de repartidores, asignación en ventas con modalidad a domicilio, flete dinámico y sincronización en tiempo real.
- ✅ **Flexibilidad Comercial en POS:** Búsqueda rápida por Nombre, SKU y Marca; controles rápidos `+/-`, modal de ajuste de cantidad y precios pactados (precio estándar vs. mayorista), edición de precio unitario en carrito y descuentos globales.
- ✅ Control de acceso basado en roles (**RBAC**) para promotores y dropshipping con reservas automáticas (12h TTL).
- ✅ Dashboard financiero con balance patrimonial en vivo, desglose de arqueo diario por método de pago e historial de ventas reactivo.
- ✅ Soporte para ventas con devoluciones en ventana de 24h y restitución de stock al lote correspondiente.
- ✅ Navegación unificada de 4 pestañas (Inventario, POS, Dashboard, Promotores) con refresco reactivo.
- ✅ CRUD integral de productos y lotes con borrado atómico en cascada y registro en cola de sincronización.

---

## 2. Arquitectura del Sistema

```
┌──────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                    │
│           Views • ViewModels (ChangeNotifier)            │
├──────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                        │
│         Entities • Use Cases • Repository Contracts      │
├──────────────────────────────────────────────────────────┤
│                       DATA LAYER                         │
│      Models • DataSources (Local/Remote) • Repos Impl    │
└──────────────────────────────────────────────────────────┘
         ↕ SQLite (sqflite)      ↕ Firebase Firestore
```

**Patrones aplicados:**

| Patrón | Descripción |
|--------|-------------|
| **Clean Architecture** | Separación estricta en capas Domain / Data / Presentation |
| **Feature-First** | Cada módulo es un directorio independiente dentro de `lib/features/` (`inventory`, `pos`, `clients`, `deliveries`, `promoters`, `dashboard`, `main`) |
| **MVVM** | ViewModels con `ChangeNotifier` + Provider / `Consumer` en UI |
| **Repository Pattern** | Contratos en Domain, implementaciones en Data |
| **Functional Error Handling** | `dartz` `Either<Failure, T>` en toda la capa de dominio |
| **Offline-First / SyncQueue** | Escrituras atómicas a `sync_queue` SQLite, procesadas por `SyncManager` hacia Firestore |
| **Live Multi-Device Sync** | Escucha continua de Firestore snapshots (`products`, `lots`, `sales`, `clients`, `deliveries`) y refresco reactivo |
| **FIFO Cascading Multi-Lot** | Consumo de stock cronológico desglosado en `detalle_ventas` (`sale_details`) con costo exacto por tramo |
| **Anti-Loss Validation** | Bloqueo transaccional de ventas por debajo del costo real ponderado |
| **Atomic Cascade Deletion** | Eliminación de entidades padre e hijos con propagación de eliminación a la nube |

---

## 3. Estructura de Directorios

```
lib/
├── main.dart                          # Entry point. Inyección de dependencias + MultiProvider (Firestore Real)
├── firebase_options.dart              # Configuración de Firebase por plataforma
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # Nombre/versión de la DB, rutas
│   │   └── route_constants.dart       # Constantes de rutas nombradas
│   ├── database/
│   │   └── database_helper.dart       # Singleton SQLite con FK habilitadas
│   ├── errors/
│   │   ├── exceptions.dart            # Excepciones de la capa de datos
│   │   └── failures.dart              # Failures de la capa de dominio
│   ├── sync/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── sync_local_datasource.dart        # CRUD de sync_queue en SQLite + sync de tablas
│   │   │   │   ├── remote_sync_datasource.dart       # Interfaz + MockRemote
│   │   │   │   └── firestore_remote_data_source.dart # Impl real con Firestore (INSERT/UPDATE/DELETE en cascada)
│   │   │   └── models/
│   │   │       └── sync_operation_model.dart         # Modelo de operación pendiente
│   │   └── domain/
│   │       └── services/
│   │           └── sync_manager.dart  # Motor Offline y sincronización en tiempo real (ChangeNotifier)
│   ├── theme/
│   │   └── app_theme.dart             # Tema Material 3 de la app
│   ├── usecases/
│   │   └── usecase.dart               # Clase base UseCase + NoParams
│   └── utils/
│       ├── currency_formatter.dart    # Formateador de moneda en Bs.
│       └── date_formatter.dart        # Formateador de fechas ISO-8601
│
├── features/
│   ├── main/
│   │   └── presentation/views/
│   │       └── home_shell_view.dart   # Shell con BottomNav de 4 tabs (Inv, POS, Dash, Prom) + Sync Indicator
│   │
│   ├── clients/
│   │   ├── data/
│   │   │   ├── datasources/client_local_datasource.dart  # Operaciones SQLite + sync_queue en 'clients'
│   │   │   ├── models/client_model.dart
│   │   │   └── repositories/client_repository_impl.dart
│   │   └── domain/
│   │       ├── entities/client.dart
│   │       ├── repositories/client_repository.dart
│   │       └── usecases/
│   │           ├── get_clients_usecase.dart              # Listado y búsqueda de clientes
│   │           └── save_client_usecase.dart              # Guardado local + cola de sincronización
│   │
│   ├── deliveries/
│   │   ├── data/
│   │   │   ├── datasources/delivery_local_datasource.dart # CRUD SQLite + sync_queue en 'deliveries'
│   │   │   ├── models/delivery_model.dart
│   │   │   └── repositories/delivery_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/delivery.dart
│   │   │   ├── repositories/delivery_repository.dart
│   │   │   └── usecases/
│   │   │       ├── delete_delivery_usecase.dart          # Baja de repartidor + sync DELETE
│   │   │       ├── get_deliveries_usecase.dart           # Obtención de repartidores activos
│   │   │       └── save_delivery_usecase.dart            # Alta / Edición de repartidor
│   │   └── presentation/
│   │       └── widgets/
│   │           └── delivery_management_dialog.dart       # Modal interactivo de administración de repartidores
│   │
│   ├── inventory/
│   │   ├── data/
│   │   │   ├── datasources/inventory_local_data_source.dart # Operaciones SQLite + registro sync_queue
│   │   │   ├── models/lot_model.dart
│   │   │   ├── models/product_model.dart
│   │   │   └── repositories/inventory_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/lot.dart
│   │   │   ├── entities/product.dart
│   │   │   ├── repositories/inventory_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_inventory_batch.dart
│   │   │       ├── consume_stock_fifo.dart
│   │   │       ├── create_product_with_lot_usecase.dart
│   │   │       ├── delete_product_usecase.dart         # Eliminación atómica en cascada
│   │   │       ├── get_all_products.dart
│   │   │       └── update_product_usecase.dart         # Actualización de metadata
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── add_lot_sheet.dart                  # Registro de nuevo lote
│   │       │   ├── add_product_lot_sheet.dart          # Alta de producto + lote inicial
│   │       │   ├── edit_product_sheet.dart             # Edición de producto
│   │       │   └── inventory_catalog_screen.dart       # Catálogo con buscador y filtros
│   │       ├── viewmodels/inventory_viewmodel.dart     # Estado reactivo del inventario
│   │       ├── views/inventory_list_view.dart
│   │       └── widgets/
│   │           ├── product_card.dart                   # Tarjeta con acordeón de lotes y acciones (edit/delete)
│   │           └── stock_status_badge.dart
│   │
│   ├── pos/
│   │   ├── data/
│   │   │   ├── datasources/pos_local_datasource.dart   # FIFO multi-lote, anti-pérdida, voidSale, sync_queue con desglose
│   │   │   ├── models/sale_detail_model.dart           # Modelo para detalle_ventas / sale_details
│   │   │   ├── models/sale_model.dart
│   │   │   └── repositories/pos_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/sale.dart
│   │   │   ├── entities/sale_detail.dart               # Entidad para desglose de costo y lote consumido
│   │   │   ├── entities/sale_item.dart
│   │   │   ├── repositories/pos_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_sale.dart
│   │   │       ├── get_sales_by_date.dart
│   │   │       ├── process_sale_usecase.dart
│   │   │       └── void_sale_usecase.dart
│   │   └── presentation/
│   │       ├── viewmodels/pos_viewmodel.dart           # Carrito, CRM, Deliveries, precios custom y anti-pérdida
│   │       ├── views/
│   │       │   ├── pos_view.dart
│   │       │   ├── pos_sales_view.dart                 # POS con buscador (Nombre/SKU/Marca) y controles inline
│   │       │   └── pos_screen.dart                     # Alias de PosSalesView
│   │       └── widgets/
│   │           ├── cart_item_tile.dart
│   │           ├── checkout_bottom_sheet.dart          # Modal avanzado de cobro (CRM, Repartidor, Métodos, Descuentos)
│   │           └── void_sale_dialog.dart
│   │
│   ├── promoters/
│   │   ├── data/
│   │   │   ├── datasources/promoter_local_datasource.dart
│   │   │   ├── models/promoter_model.dart
│   │   │   └── repositories/promoter_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/commission.dart
│   │   │   ├── entities/promoter.dart
│   │   │   ├── repositories/promoter_repository.dart
│   │   │   └── usecases/
│   │   │       ├── calculate_commission.dart
│   │   │       └── get_all_promoters.dart
│   │   └── presentation/
│   │       ├── viewmodels/promoters_viewmodel.dart
│   │       ├── views/promoters_view.dart               # Vista de promotores integrada en HomeShellView
│   │       └── widgets/promoter_tile.dart
│   │
│   └── dashboard/
│       ├── data/
│       │   ├── datasources/dashboard_local_datasource.dart
│       │   ├── models/dashboard_summary_model.dart
│       │   ├── models/financial_metrics_model.dart
│       │   └── repositories/dashboard_repository_impl.dart
│       ├── domain/
│       │   ├── entities/dashboard_summary.dart
│       │   ├── repositories/dashboard_repository.dart
│       │   └── usecases/
│       │       ├── get_daily_cash_audit_usecase.dart
│       │       └── get_financial_overview_usecase.dart
│       └── presentation/
│           ├── viewmodels/dashboard_viewmodel.dart     # Métricas patrimoniales e historial de ventas reactivo
│           ├── views/
│           │   ├── dashboard_overview_view.dart        # Vista Dashboard con KPI cards e Historial de Ventas
│           │   └── dashboard_screen.dart               # Alias de DashboardOverviewView
│           └── widgets/summary_card.dart
│
assets/
└── sql/
    └── schema.sql                                      # DDL completo de la base de datos SQLite
```

---

## 4. Stack Tecnológico

| Tecnología | Versión | Uso |
|------------|---------|-----|
| **Flutter** | SDK >= 3.13.3 | Framework UI multiplataforma |
| **Dart** | 3.x | Lenguaje principal |
| **sqflite** | ^2.4.4 | Persistencia SQLite local (Offline-First) |
| **sqflite_common_ffi** | ^2.4.3 | SQLite en memoria para tests unitarios y de integración |
| **provider** | ^6.1.5 | Gestión de estado (MVVM) |
| **dartz** | ^0.10.1 | Programación funcional: `Either<Failure, T>` |
| **equatable** | ^3.0.0 | Comparación de valor en entidades |
| **uuid** | ^4.6.0 | Generación de UUIDs v4 para IDs |
| **connectivity_plus** | ^7.3.1 | Detección de conectividad de red |
| **intl** | ^0.20.3 | Internacionalización y formato de fechas/moneda |
| **path_provider** | ^2.1.6 | Rutas de sistema de archivos |
| **path** | ^1.9.1 | Manipulación de rutas |
| **url_launcher** | ^6.3.1 | Apertura de enlaces externos y chat directo de WhatsApp |
| **firebase_core** | ^4.15.0 | Inicialización de Firebase |
| **firebase_auth** | ^6.7.0 | Autenticación Firebase |
| **cloud_firestore** | ^6.10.0 | Backend remoto para sincronización real en tiempo real |
| **mocktail** | ^1.0.5 | Mocking en tests unitarios |

---

## 5. Esquema de Base de Datos

SQLite — `PRAGMA foreign_keys = ON` activo. El esquema completo se carga desde `assets/sql/schema.sql` al inicializar la base de datos.

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐     ┌──────────────┐
│   clientes   │     │   products    │◄────│     lots     │     │  deliveries  │
│──────────────│     │───────────────│  FK │──────────────│     │──────────────│
│ id (PK)      │     │ id (PK)       │     │ id (PK)      │     │ id (PK)      │
│ nombre_alias │     │ sku (UNIQUE)  │     │ product_id FK│     │ nombre       │
│ tel_whatsapp │     │ name          │     │ purchase_date│     │ telefono     │
│ direc_predet │     │ brand         │     │ initial_qty  │     │ vehiculo     │
│ creado_en    │     │ category      │     │ current_qty  │     │ activo       │
└──────────────┘     │ standard_price│     │ real_unit_cost     │ creado_en    │
       ▲             │ min_stock     │     │ promoter_price     └──────────────┘
       │             └───────────────┘     │ is_active    │            ▲
       │                     │             └──────────────┘            │
       │                     │                    │                    │
       │                     ▼                    ▼                    │
       │             ┌───────────────┐    ┌───────────────┐            │
       │             │    ventas     │◄───│detalle_ventas │            │
       │             │   (sales)     │ FK │ (sale_items)  │            │
       │             │───────────────│    │───────────────│            │
       │             │ id (PK)       │    │ id (PK)       │            │
       │             │ cliente_id FK ┼──┐ │ venta_id FK   │            │
       │             │ delivery_id FK┼──┼─┼─►lote_id FK   │            │
       │             │ delivery_name │  │ │ product_id FK │            │
       │             │ total_cobrado │  │ │ cantidad      │            │
       │             │ metodo_pago   │  │ │ costo_unit_com│            │
       │             │ tipo_entrega  │  │ │ precio_unit_cb│            │
       │             │ delivery_fee  │  │ │ line_discount │            │
       │             │ fecha_venta   │  │ └───────────────┘            │
       │             │ is_locked     │  │                              │
       │             └───────────────┘  │                              │
       │                     ▲          │                              │
       └─────────────────────┴──────────┘                              │
                             │                                         │
                             └─────────────────────────────────────────┘

┌──────────────────────────────────────┐     ┌──────────────┐
│              sync_queue              │     │  promoters   │
│──────────────────────────────────────│     │──────────────│
│ id • table_name • operation          │     │ id (PK)      │
│ payload (JSON) • created_at          │     │ name, phone  │
│ status (PENDING/SYNCED/FAILED)       │     │ is_active    │
│ retry_count                          │     └──────────────┘
└──────────────────────────────────────┘
```

---

## 6. Módulos Implementados

### 6.1 Módulo Inventory (Gestión de Inventarios)

**Entidades:** `Product`, `Lot`

**Lógica de negocio:**
- SKU único por producto (validado a nivel de BD por constraint `UNIQUE`).
- Cada ingreso de mercancía crea un **lote independiente** con su `real_unit_cost`, `promoter_base_price` y fecha de compra.
- `Product.availableStock` = suma de `current_quantity` de lotes activos calculada dinámicamente.
- `StockStatus`: `ok` / `lowStock` / `outOfStock` basado en `min_stock_threshold`.
- Capital inmovilizado = $\sum (\text{lot.current\_qty} \times \text{lot.real\_unit\_cost})$.
- Ganancia potencial estimada = $\sum ((\text{sell\_price} - \text{lot.cost}) \times \text{lot.current\_qty})$.
- **Eliminación atómica en cascada:** Al eliminar un producto, se eliminan todos sus lotes asociados en una sola transacción SQLite y se registran operaciones `DELETE` en la `sync_queue`.

**Casos de uso:**
- `GetAllProducts`: Lista productos con lotes activos y stock disponible.
- `CreateProductWithLotUseCase`: Alta transaccional de producto y lote inicial.
- `AddLotUseCase`: Incorporación de lote a producto existente.
- `ConsumeStockFifo`: Consumo de inventario por orden de antigüedad.
- `UpdateProductUseCase`: Actualización de metadatos de producto.
- `DeleteProductUseCase`: Eliminación atómica en cascada con réplica a Firestore.

**UI:** `InventoryCatalogScreen` con búsqueda instantánea, filtros por estado (`Todos`, `Stock Bajo`, `Agotados`), `ProductCard` con acordeón de inspección de lotes (costo, fecha, disponibles vs. iniciales) y modales `AddProductLotSheet`, `AddLotSheet` y `EditProductSheet`.

---

### 6.2 Módulo POS (Punto de Venta Avanzado)

**Entidades:** `Sale`, `SaleItem`, `SaleDetail`

**Lógica de negocio crítica:**
- **Búsqueda instantánea multi-criterio:** Búsqueda en tiempo real por **Nombre**, **SKU** y **Marca** directamente en la vista del POS.
- **Controles rápidos en catálogo POS:** Botones interactivos `+` y `-` directamente en la lista de productos con badge indicador de unidades seleccionadas.
- **Selector y Diálogo de Personalización de Precios:** Diálogo `_showAddCustomPriceDialog` para ingresar cantidad deseada y seleccionar rápidamente entre precio **Estándar** o **Mayorista (Promotor)**, o fijar un precio unitario pactado ad-hoc.
- **Validación de existencias:** Validación estricta que impide agregar al carrito cantidades superiores al stock disponible total.
- **Regla anti-pérdida estricta:** Bloqueo de checkout si el total cobrado resulta inferior a la sumatoria de costos reales de compra ($\text{cartTotal} < \text{totalCostBase}$).
- **FIFO Multi-Lote con Desglose Transaccional:** `processSale` descuenta lotes ordenados por `purchase_date ASC`, registrando en `detalle_ventas` cada tramo consumido con su `lote_id`, `costo_unitario_compra` y `precio_unitario_cobrado`.
- **Integración CRM en Checkout:** Selector de clientes registrados con opción a alta rápida ("Nuevo Cliente CRM") sin abandonar la venta.
- **Asignación de Repartidores & Delivery:** Selección de modalidad `TIENDA` o `DELIVERY`, asignación de repartidor desde el directorio local y flete adicional configurable.
- **Descuento Global:** Aplicación de descuento comercial global recalculado en tiempo real.
- **Devoluciones (24h):** `voidSale()` valida la ventana de 24h, restituye el stock al lote original y anula financieramente la venta en SQLite y Firestore.

**UI:** `PosSalesView` con buscador, controles inline `+/-`, botón de acceso a repartidores, `CheckoutBottomSheet` avanzado y diálogo `VoidSaleDialog`.

---

### 6.3 Módulo CRM de Clientes (`features/clients`)

**Entidades:** `Client`

**Lógica de negocio:**
- Registro de clientes con `nombreAlias`, `telefonoWhatsapp`, `direccionPredet` y fecha de creación.
- Cliente predeterminado por defecto: "Cliente Mostrador".
- Persistencia local inmediata en SQLite (`clientes`) y encolamiento automático en `sync_queue` (`clients`).
- Sincronización reactiva bidireccional mediante `listenToRemoteClients()` en Firestore.

**Casos de uso:**
- `GetClientsUseCase`: Obtiene el catálogo de clientes ordenados alfabéticamente.
- `SaveClientUseCase`: Guarda o actualiza un cliente localmente y genera la mutación de sincronización.

---

### 6.4 Módulo de Repartidores & Deliveries (`features/deliveries`)

**Entidades:** `Delivery`

**Lógica de negocio:**
- Registro de repartidores con `nombre`, `telefono`, `vehiculo` y estado `activo`.
- Administración completa (Crear, Editar, Activar/Desactivar, Eliminar) mediante `DeliveryManagementDialog`.
- Persistencia en SQLite (`deliveries`) y sincronización reactiva en tiempo real con Firestore (`deliveries`).
- Vinculación directa con ventas (`delivery_id`, `delivery_name`, `delivery_fee`).

**Casos de uso:**
- `GetDeliveriesUseCase`: Lista repartidores registrados.
- `SaveDeliveryUseCase`: Crea o edita repartidores y encola operación `INSERT` / `UPDATE`.
- `DeleteDeliveryUseCase`: Da de baja el repartidor y encola operación `DELETE`.

---

### 6.5 Módulo Promoters (Promotores & Dropshipping)

**Entidades:** `Promoter`, `Commission`

**Lógica de negocio:**
- Cada promotor tiene un `commissionRate` configurable (0–100%).
- Catálogo RBAC: costos reales de compra (`real_unit_cost`) ocultos para perfiles de promotores.
- `calculate_commission.dart`: calcula la comisión respetando el precio piso del producto.
- Reservas de stock de 12 horas en SQLite (`reservations`) con TTL automático.

**UI:** `PromotersView` con listado reactivo de promotores, estados activos/inactivos y métricas de comisión integrada en la barra de navegación principal.

---

### 6.6 Módulo Dashboard (Finanzas & Reportes)

**Entidades:** `DashboardSummary`, `FinancialMetrics`

**Lógica de negocio:**
- **Balance patrimonial en vivo:** Cálculo instantáneo de capital inmovilizado en stock y ganancia potencial total.
- **Arqueo diario de caja:** Desglose por método de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`) de ingreso bruto, capital recuperado y utilidad neta real.
- **Historial de ventas del día:** Registro y listado cronológico de ventas por fecha seleccionada con hora, total cobrado, método de pago, cliente e ítems vendidos.
- **Canal de utilidades:** Distribución comparativa entre ventas de mostrador directas vs. ventas por canal de promotores.

**UI:** `DashboardOverviewView` con selector interactivo de fechas (`DatePicker`), 3 tarjetas resumen clave (Total Ventas, Ganancia Neta Real, Capital Inmovilizado), historial diario y desglose de arqueo por método de pago.

---

## 7. Motor Offline-First y Sincronización en Tiempo Real

### Arquitectura de Sincronización Multidispositivo

```
[ Dispositivo A ]                                  [ Cloud Firestore ]                              [ Dispositivo B ]
Venta / Cliente / Repartidor                           Colecciones:                                 Escucha Reactiva
       ↓                                          - products                                               ↓
SQLite (ACID txn)                                 - lots                                            SyncManager (Streams)
       ↓                                          - sales (con sale_details)                               ↓
sync_queue (PENDING)                              - clients                                         SyncLocalDataSource
       ↓                                          - deliveries                                             ↓
SyncManager (FIFO Push) ───────────────────────────────┘                                            Actualiza SQLite local
                                                                                                           ↓
                                                                                                    Notifica UI Reactiva
```

**Componentes:**

| Clase | Archivo | Rol |
|-------|---------|-----|
| `SyncManager` | `core/sync/domain/services/sync_manager.dart` | Orquestador reactivo. Escucha cambios de red y procesa la cola FIFO hacia Firestore |
| `SyncLocalDataSourceImpl` | `core/sync/data/datasources/sync_local_datasource.dart` | Persistencia y gestión de `sync_queue` en SQLite y sincronización de colecciones |
| `FirestoreRemoteDataSource` | `core/sync/data/datasources/firestore_remote_data_source.dart` | Implementación real conectada a Cloud Firestore (INSERT/UPDATE/DELETE en cascada) |
| `MockRemoteSyncDataSource` | `core/sync/data/datasources/remote_sync_datasource.dart` | Mock para pruebas unitarias sin dependencias de red |
| `SyncOperationModel` | `core/sync/data/models/sync_operation_model.dart` | DTO de operaciones pendientes |

**Resolución de conflictos:** `First-Write-Wins` sustentado en `clientTimestamp` ISO-8601 preservado en cada mutación.

**Indicador de Conectividad en UI:** `HomeShellView` cuenta con un monitor en el `AppBar`:
- 🟢 Icono `cloud_done`: sincronizado con Firestore.
- 🟠 Icono `cloud_off` + badge numérico: operando offline con $N$ transacciones en cola pendientes de sincronizar.

---

## 8. Matriz de Cumplimiento Funcional

| RF | Descripción | Archivo Principal | Estado |
|----|-------------|-------------------|--------|
| RF-01 | SKU Único por producto | `inventory_local_data_source.dart` | ✅ |
| RF-02 | Lotes independientes con costo real | `lot.dart`, `lot_model.dart` | ✅ |
| RF-03 | Stock en tiempo real y agregado | `product.dart` (`availableStock`) | ✅ |
| RF-04 | Alertas de reposición (`StockStatus`) | `product.dart`, `stock_status_badge.dart` | ✅ |
| RF-05 | Capital inmovilizado en tiempo real | `product.dart`, `inventory_viewmodel.dart` | ✅ |
| RF-06 | Buscador POS dinámico (Nombre, SKU, Marca) | `pos_viewmodel.dart`, `pos_sales_view.dart` | ✅ |
| RF-07 | Validación estricta de existencias | `pos_viewmodel.dart` (`addItem`) | ✅ |
| RF-08 | Regla anti-pérdida (precio >= costo) | `pos_viewmodel.dart` (`checkout`) | ✅ |
| RF-09 | Descuento FIFO por lote | `pos_local_datasource.dart` | ✅ |
| RF-10 | Métodos de pago múltiples (Efectivo, QR, Transf., Tarjeta) | `sale.dart`, `checkout_bottom_sheet.dart` | ✅ |
| RF-11 | Opciones de despacho (Delivery / Tienda con flete) | `sale.dart`, `checkout_bottom_sheet.dart` | ✅ |
| RF-12 | FIFO en cascada multi-lote con desglose (`detalle_ventas`) | `pos_local_datasource.dart`, `sale_detail.dart` | ✅ |
| RF-13 | CRM de Clientes (Directorio, Teléfono, WhatsApp, Dirección) | `client.dart`, `client_local_datasource.dart` | ✅ |
| RF-14 | Devoluciones en ventana de 24h | `pos_local_datasource.dart` (`voidSale`) | ✅ |
| RF-15 | Reintegración al lote + neutralización financiera | `pos_local_datasource.dart` | ✅ |
| RF-16 | Margen base promotor (`commissionRate`) | `promoter.dart` | ✅ |
| RF-17 | Catálogo RBAC (costos ocultos) | `promoters_viewmodel.dart` | ✅ |
| RF-18 | Precio piso respetado | `calculate_commission.dart` | ✅ |
| RF-19 | Sincronización de stock visible multidispositivo | `inventory_viewmodel.dart`, `sync_manager.dart` | ✅ |
| RF-20 | Reservas dropshipping 12h | `schema.sql` → tabla `reservations` | ✅ |
| RF-21 | TTL y retorno de stock automático | `promoter_local_datasource.dart` | ✅ |
| RF-22 | Liquidación de ganancias compartidas | `calculate_commission.dart` | ✅ |
| RF-23 | Gestión de Repartidores & Asignación en POS | `delivery.dart`, `delivery_management_dialog.dart` | ✅ |
| RF-24 | Balance patrimonial en vivo | `get_financial_overview_usecase.dart` | ✅ |
| RF-25 | Arqueo diario de flujos por método de pago | `get_daily_cash_audit_usecase.dart` | ✅ |
| RF-26 | Separación costo reposición / ganancia neta | `dashboard_local_datasource.dart` | ✅ |
| RF-27 | Precios pactados y descuentos comerciales en POS | `pos_viewmodel.dart`, `pos_sales_view.dart` | ✅ |
| RF-28 | Sincronización Firestore en tiempo real (5 colecciones) | `firestore_remote_data_source.dart`, `sync_manager.dart` | ✅ |

---

## 9. Requisitos No Funcionales

| RNF | Descripción | Estado |
|-----|-------------|--------|
| **RNF-01 Offline-First** | Todas las escrituras pasan primero por SQLite + `sync_queue`. Operación 100% offline garantizada. | ✅ |
| **RNF-02 Rendimiento** | Búsquedas en memoria sobre colecciones en `ChangeNotifier`. Consultas indexadas en SQLite. | ✅ |
| **RNF-03 Consistencia ACID** | Transacciones `db.transaction()` en cascada con integridad referencial. Sincronización `First-Write-Wins`. | ✅ |
| **RNF-04 Seguridad RBAC** | Costos de adquisición ocultos en vistas de promotores y perfiles restringidos. | ✅ |
| **RNF-05 UX Móvil** | `BottomSheets` responsivos, teclados numéricos contextuales y controles táctiles directos `+/-`. | ✅ |
| **RNF-06 Multiplataforma** | Flutter nativo para Android / iOS con configuración Firebase por plataforma. | ✅ |

---

## 10. Pendientes y Deuda Técnica

### 🟢 Resueltos en v1.2.0

- ✅ **P-01 Resuelto:** Dashboard e Historial de Ventas integrado como pestaña principal en `HomeShellView`.
- ✅ **P-02 Resuelto:** Módulo Promotores integrado en `HomeShellView` e inyectado en `main.dart`.
- ✅ **P-04 Resuelto:** `FirestoreRemoteDataSource` conectada como fuente remota real y reactiva en `main.dart`.
- ✅ **P-07 Resuelto:** Módulo CRM de Clientes y Gestión de Repartidores integrados con selector en `CheckoutBottomSheet`.

---

### 🔴 Crítico — Siguientes Pasos

| # | Descripción | Impacto | Archivo(s) Relacionado(s) |
|---|-------------|---------|--------------------------|
| **P-03** | **Firebase Auth & Login:** Implementar pantalla de inicio de sesión, registro de usuarios y control de sesiones seguras antes de acceder a la shell principal. | Alto | `main.dart`, flujo de Auth |

---

### 🟡 Importante — Mejoras y Completación

| # | Descripción | Impacto |
|---|-------------|---------|
| **P-05** | **Limpieza de stub legacy:** Eliminar archivo obsoleto `lib/data/sync/sync_manager.dart`. | Bajo |
| **P-06** | **Migraciones SQLite:** Implementar lógica de migración en `DatabaseHelper._onUpgrade` al incrementar versión de DB. | Medio |

---

### 🟢 Mejoras Opcionales / Futuro

| # | Descripción |
|---|-------------|
| **P-10** | `RetryPolicy` con backoff exponencial para operaciones fallidas en `SyncManager`. |
| **P-11** | Aplicar el tema global `AppTheme` en `main.dart`. |
| **P-12** | Paginación virtualizada para catálogos con más de 10,000 productos. |
| **P-13** | Soporte para subida y visualización de imágenes de productos (Firebase Storage). |
| **P-14** | Exportación de reportes financieros a PDF y Excel/CSV desde el Dashboard. |
| **P-15** | Notificaciones push (FCM) ante alertas de stock mínimo o quiebre de inventario. |

---

## 11. Guía de Ejecución

### Prerrequisitos
- Flutter SDK >= 3.13.3
- Dart SDK >= 3.x
- Dispositivo físico o emulador Android / simulador iOS
- Archivo `android/app/google-services.json` configurado

### Comandos Principales

```bash
# 1. Clonar el repositorio
git clone https://gitlab.com/indecorp-group/electronic_store.git
cd electronic_store

# 2. Instalar dependencias
flutter pub get

# 3. Análisis estático (calidad de código)
flutter analyze

# 4. Ejecutar suite de pruebas unitarias y de integración
flutter test

# 5. Ejecutar la aplicación en modo desarrollo
flutter run

# 6. Compilar paquete para producción (Android APK)
flutter build apk --release
```

---

## 12. Historial de Cambios

### v1.2.0 — POS Avanzado, CRM de Clientes, Gestión de Repartidores y Desglose FIFO Detallado
*Octubre 2026*

- 👥 **Módulo CRM de Clientes (`features/clients`):**
  - Entidad `Client`, persistencia en tabla `clientes` y sincronización reactiva con la colección `clients` en Firestore.
  - Autocompletado y diálogo de alta rápida de nuevos clientes ("Nuevo Cliente CRM") directamente dentro del modal de checkout.
- 🛵 **Módulo de Repartidores & Delivery (`features/deliveries`):**
  - Entidad `Delivery`, CRUD completo con diálogo `DeliveryManagementDialog`.
  - Atribución de repartidor en ventas a domicilio (`delivery_id`, `delivery_name`, `delivery_fee`), persistencia en SQLite y réplica en Firestore.
- 🛒 **POS Avanzado & Flexibilidad Comercial:**
  - Búsqueda instantánea multi-campo por **Nombre**, **SKU** y **Marca**.
  - Selector de precios pactados con chips rápidos de precio **Estándar** vs. **Mayorista (Promotor)**.
  - Diálogo de personalización de precio unitario cobrado y cantidad por producto.
  - Edición de precios en el carrito de compras y campo de **Descuento Global**.
- 📊 **Desglose FIFO Detallado (`detalle_ventas` / `sale_details`):**
  - Registro pormenorizado en SQLite y Firestore de cada lote consumido, costo unitario de compra y precio unitario cobrado por tramo.
- 🔄 **Sincronización Firestore Ampliada:**
  - Canales de escucha en tiempo real (`Stream`) añadidos para `clients` y `deliveries`.
  - Replicación de `sale_details` en el payload de sincronización de ventas.
- 🧪 **Suite de Pruebas de Integración y POS Avanzado:**
  - Incorporación de `pos_advanced_crm_sales_sync_test.dart` validando el flujo completo de CRM, Deliveries, precios custom y réplica remota.

---

### v1.1.0 — Navegación Unificada, Sincronización Real con Firestore y CRUD Completo
*Octubre 2026*

- 🚀 **Navegación 4-Tabs en `HomeShellView`:** Integración de Inventario, POS, Dashboard y Promotores en el `BottomNavigationBar`.
- ☁️ **Sincronización Real con Cloud Firestore:** Conexión de `FirestoreRemoteDataSource` en `main.dart`, soportando operaciones `INSERT`, `UPDATE` y `DELETE` en cascada.
- 🔄 **Sincronización Multidispositivo en Vivo:** `SyncManager.startRealtimeSync()` activo al iniciar la app.
- 📦 **CRUD Completo de Inventario:** Edición y eliminación en cascada de productos y lotes.

---

### v1.0.0 — Baseline Inicial
*Septiembre 2026*

- ✅ Arquitectura limpia modular (Domain / Data / Presentation).
- ✅ Motor de costeo FIFO y reglas anti-pérdida.
- ✅ Persistencia SQLite local con soporte para `sync_queue`.
- ✅ Gestión de ventas, devoluciones en ventana de 24h y cálculo de comisiones para promotores.
- ✅ Dashboard financiero base con balance patrimonial y arqueo diario.

---

*Documento mantenido por el equipo de desarrollo — INDECORP Group.*  
*Última actualización: Octubre 2026.*
