# ElectronicStore POS & Gestión de Inventarios
### Memoria Técnica Oficial — v1.1.0 · Offline-First · Flutter + Firebase Firestore Real-Time

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

**ElectronicStore** es una solución integral de **Punto de Venta (POS)** y **Gestión de Inventarios** desarrollada en **Flutter**, diseñada para operar en entornos con conectividad inestable (**Offline-First**) y con soporte de sincronización reactiva en tiempo real entre múltiples dispositivos conectados a **Cloud Firestore**.

**Características principales:**
- ✅ Costeo real por lotes con método **FIFO** (First-In, First-Out)
- ✅ Valorizado en **Bolivianos (Bs.)**
- ✅ Sincronización bidireccional reactiva y en vivo con **Firebase Firestore**
- ✅ Control de acceso basado en roles (**RBAC**) para promotores
- ✅ Dashboard financiero con métricas, arqueo diario e historial de ventas en tiempo real
- ✅ Soporte para ventas con devoluciones en ventana de 24h
- ✅ Navegación unificada de 4 pestañas (Inventario, POS, Dashboard, Promotores) con refresco reactivo
- ✅ CRUD integral de productos y lotes con borrado atómico en cascada y registro en cola de sincronización

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
| **Feature-First** | Cada módulo es un directorio independiente dentro de `lib/features/` |
| **MVVM** | ViewModels con `ChangeNotifier` + Provider / `Consumer` en UI |
| **Repository Pattern** | Contratos en Domain, implementaciones en Data |
| **Functional Error Handling** | `dartz` `Either<Failure, T>` en toda la capa de dominio |
| **Offline-First / SyncQueue** | Escrituras atómicas a `sync_queue` SQLite, procesadas por `SyncManager` hacia Firestore |
| **Live Multi-Device Sync** | Escucha continua de Firestore snapshots (`products`, `lots`, `sales`) y refresco reactivo |
| **FIFO Cascading** | Consumo de stock ordenado cronológicamente a través de múltiples lotes con reflejo en `sync_queue` |
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
│   │   │   │   ├── sync_local_datasource.dart       # CRUD de sync_queue en SQLite + sync de tablas
│   │   │   │   ├── remote_sync_datasource.dart      # Interfaz + MockRemote
│   │   │   │   └── firestore_remote_data_source.dart # Impl real con Firestore (INSERT/UPDATE/DELETE en cascada)
│   │   │   └── models/
│   │   │       └── sync_operation_model.dart        # Modelo de operación pendiente
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
├── data/
│   └── sync/
│       └── sync_manager.dart          # ⚠️ LEGACY — stub sin uso activo (marcado para deprecación)
│
├── features/
│   ├── main/
│   │   └── presentation/views/
│   │       └── home_shell_view.dart   # Shell con BottomNav de 4 tabs (Inv, POS, Dash, Prom) + Sync Indicator
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
│   │   │       ├── delete_product_usecase.dart        # Eliminación atómica en cascada
│   │   │       ├── get_all_products.dart
│   │   │       └── update_product_usecase.dart        # Actualización de metadata
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── add_lot_sheet.dart                 # Registro de nuevo lote
│   │       │   ├── add_product_lot_sheet.dart         # Alta de producto + lote inicial
│   │       │   ├── edit_product_sheet.dart            # Edición de producto
│   │       │   └── inventory_catalog_screen.dart      # Catálogo con buscador y filtros
│   │       ├── viewmodels/inventory_viewmodel.dart    # Estado reactivo del inventario
│   │       ├── views/inventory_list_view.dart
│   │       └── widgets/
│   │           ├── product_card.dart                  # Tarjeta con acordeón de lotes y acciones (edit/delete)
│   │           └── stock_status_badge.dart
│   │
│   ├── pos/
│   │   ├── data/
│   │   │   ├── datasources/pos_local_datasource.dart  # FIFO, antiloss, voidSale, sync_queue con items
│   │   │   ├── models/sale_model.dart
│   │   │   └── repositories/pos_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/sale.dart
│   │   │   ├── entities/sale_item.dart
│   │   │   ├── repositories/pos_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_sale.dart
│   │   │       ├── get_sales_by_date.dart
│   │   │       ├── process_sale_usecase.dart
│   │   │       └── void_sale_usecase.dart
│   │   └── presentation/
│   │       ├── viewmodels/pos_viewmodel.dart          # Gestión de carrito, validación anti-pérdida y refresh
│   │       ├── views/
│   │       │   ├── pos_view.dart
│   │       │   ├── pos_sales_view.dart                # Vista POS con selector rápido (+ / -) por producto
│   │       │   └── pos_screen.dart                    # Alias de PosSalesView
│   │       └── widgets/
│   │           ├── cart_item_tile.dart
│   │           ├── checkout_bottom_sheet.dart         # Modal con 4 métodos de pago (Efectivo, QR, Transf, Tarjeta)
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
│   │       ├── views/promoters_view.dart              # Vista de promotores integrada en HomeShellView
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
│           ├── viewmodels/dashboard_viewmodel.dart    # Métricas patrimoniales e historial de ventas
│           ├── views/
│           │   ├── dashboard_overview_view.dart      # Vista Dashboard con KPI cards e Historial de Ventas
│           │   └── dashboard_screen.dart             # Alias de DashboardOverviewView
│           └── widgets/summary_card.dart
│
assets/
└── sql/
    └── schema.sql                     # DDL completo de la base de datos SQLite
```

---

## 4. Stack Tecnológico

| Tecnología | Versión | Uso |
|------------|---------|-----|
| **Flutter** | SDK >= 3.13.3 | Framework UI multiplataforma |
| **Dart** | 3.x | Lenguaje principal |
| **sqflite** | ^2.4.4 | Persistencia SQLite local (Offline-First) |
| **sqflite_common_ffi** | ^2.4.3 | SQLite en memoria para tests |
| **provider** | ^6.1.5 | Gestión de estado (MVVM) |
| **dartz** | ^0.10.1 | Programación funcional: `Either<Failure, T>` |
| **equatable** | ^3.0.0 | Comparación de valor en entidades |
| **uuid** | ^4.6.0 | Generación de UUIDs v4 para IDs |
| **connectivity_plus** | ^7.3.1 | Detección de conectividad de red |
| **intl** | ^0.20.3 | Internacionalización y formato de fechas/moneda |
| **path_provider** | ^2.1.6 | Rutas de sistema de archivos |
| **path** | ^1.9.1 | Manipulación de rutas |
| **firebase_core** | ^4.15.0 | Inicialización de Firebase |
| **firebase_auth** | ^6.7.0 | Autenticación Firebase |
| **cloud_firestore** | ^6.10.0 | Backend remoto para sincronización real en producción |
| **mocktail** | ^1.0.5 | Mocking en tests unitarios |

---

## 5. Esquema de Base de Datos

SQLite — `PRAGMA foreign_keys = ON` activo. El esquema completo se carga desde `assets/sql/schema.sql` al crear la base de datos.

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│   products   │◄────│     lots      │     │  promoters   │
│──────────────│  FK │───────────────│     │──────────────│
│ id (PK)      │     │ id (PK)       │     │ id (PK)      │
│ sku (UNIQUE) │     │ product_id FK │     │ name         │
│ name         │     │ purchase_date │     │ phone        │
│ brand        │     │ initial_qty   │     │ commission   │
│ category     │     │ current_qty   │     │ is_active    │
│ sell_price   │     │ real_unit_cost│     └──────────────┘
│ min_stock    │     │ promoter_price│              │
└──────────────┘     │ is_active     │              │
        │            └───────────────┘              │
        │                    │                      │
        ▼                    ▼                      ▼
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│    sales     │◄────│  sale_items   │     │ reservations │
│──────────────│  FK │───────────────│     │──────────────│
│ id (PK)      │     │ id (PK)       │     │ id (PK)      │
│ created_at   │     │ sale_id FK    │     │ promoter_id  │
│ payment_meth │     │ product_id FK │     │ lot_id FK    │
│ delivery_meth│     │ quantity      │     │ quantity     │
│ total        │     │ unit_price    │     │ expires_at   │
│ status       │     │ unit_cost     │     │ status       │
│ promoter_id  │     │ line_discount │     └──────────────┘
└──────────────┘     └───────────────┘

┌──────────────────────────────────────┐
│              sync_queue              │
│──────────────────────────────────────│
│ id • table_name • operation          │
│ payload (JSON) • created_at          │
│ status (PENDING/SYNCED/FAILED)       │
│ retry_count                          │
└──────────────────────────────────────┘
```

---

## 6. Módulos Implementados

### 6.1 Módulo Inventory (Gestión de Inventarios)

**Entidades:** `Product`, `Lot`

**Lógica de negocio:**
- SKU único por producto (validado a nivel de BD por constraint `UNIQUE`).
- Cada ingreso de mercancía crea un **lote independiente** con su `real_unit_cost` y fecha de compra.
- `Product.availableStock` = suma de `current_quantity` de lotes activos calculada dinámicamente.
- `StockStatus`: `ok` / `lowStock` / `outOfStock` basado en `minStockThreshold`.
- Capital inmovilizado = Σ(`lot.current_qty × lot.real_unit_cost`).
- Ganancia potencial estimada = Σ(`(sell_price − lot.cost) × lot.current_qty`).
- **Eliminación atómica en cascada:** Al eliminar un producto, se eliminan todos sus lotes asociados en una sola transacción SQLite y se registran operaciones `DELETE` en la `sync_queue`.

**Casos de uso:**

| UseCase | Descripción |
|---------|-------------|
| `GetAllProducts` | Lista todos los productos con sus lotes activos asociados |
| `CreateProductWithLotUseCase` | Crea producto + primer lote en una transacción atómica |
| `AddLotUseCase` | Agrega nuevo lote de stock a un producto existente |
| `ConsumeStockFifo` | Descuenta stock en orden FIFO (lote más antiguo primero) |
| `UpdateProductUseCase` | Actualiza la metadata del producto (nombre, marca, categoría, precio, stock mínimo) |
| `DeleteProductUseCase` | Elimina producto y sus lotes en cascada registrando la sincronización |

**UI:** `InventoryCatalogScreen` con búsqueda en tiempo real, chips de filtro (`Todos`, `Stock Bajo`, `Agotados`), `ProductCard` con **acordeón desplegable de inspección de lotes** (con fecha, costo unitario, cantidad disponible/inicial y capital inmovilizado), modales `AddProductLotSheet`, `AddLotSheet` y `EditProductSheet`.

---

### 6.2 Módulo POS (Punto de Venta)

**Entidades:** `Sale`, `SaleItem`

**Lógica de negocio crítica:**
- **Búsqueda instantánea:** Filtrado en memoria sobre lista local en `PosViewModel`.
- **Controles rápidos en catálogo POS:** Botones interactivos `+` y `-` directamente en la lista de productos con visualizador de unidades agregadas.
- **Validación de stock:** `addItem()` valida `newQty <= product.availableStock` e inhabilita agregar unidades sin stock.
- **Regla anti-pérdida:** `finalPrice` no puede ser menor al costo de adquisición; `checkout()` bloquea ventas donde `cartTotal < totalCostBase`.
- **FIFO en cascada multi-lote:** `processSale` descuenta lotes por `purchase_date ASC`, consumiendo múltiples lotes si es necesario y encolando la actualización de cada lote en `sync_queue`.
- **Refresco reactivo post-venta:** Al completar una venta exitosa, el catálogo de productos recarga el stock actualizado inmediatamente.
- **Métodos de pago:** `EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA` (con selector de `ChoiceChips` en modal).
- **Despacho:** `TIENDA` o `DELIVERY` (con recargo de envío independiente).
- **CRM básico:** Registro de `customerName` y `customerPhone`.
- **Devoluciones (24h):** `voidSale()` valida la ventana de 24h, revierte el consumo FIFO restituyendo el stock al lote original y anula financieramente la venta.

**UI:** `PosSalesView` (alias `PosScreen`) con buscador, controles inline `+/-`, `CheckoutBottomSheet` modal completo y diálogo de anulación `VoidSaleDialog`.

---

### 6.3 Módulo Promoters (Promotores & Dropshipping)

**Entidades:** `Promoter`, `Commission`

**Lógica de negocio:**
- Cada promotor tiene un `commissionRate` configurable (0–100%).
- Catálogo RBAC: costos reales de compra (`real_unit_cost`) ocultos para perfiles de promotores.
- `calculate_commission.dart`: calcula la comisión respetando el precio piso del producto.
- Reservas de stock de 12 horas en SQLite (`reservations`) con TTL automático.

**UI:** `PromotersView` con listado reactivo de promotores, estados activos/inactivos y métricas de comisión integrada en la barra de navegación principal.

---

### 6.4 Módulo Dashboard (Finanzas & Reportes)

**Entidades:** `DashboardSummary`, `FinancialMetrics`

**Lógica de negocio:**
- **Balance patrimonial en vivo:** Cálculo instantáneo de capital inmovilizado en stock y ganancia potencial total.
- **Arqueo diario de caja:** Desglose por método de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`) de ingreso bruto, capital recuperado y utilidad neta real.
- **Historial de ventas del día:** Registro y listado cronológico de ventas por fecha seleccionada con hora, total cobrado, método de pago e ítems vendidos.
- **Canal de utilidades:** Distribución comparativa entre ventas de mostrador directas vs. ventas por canal de promotores.

**UI:** `DashboardOverviewView` (accesible como `DashboardScreen`) con:
- Selector interactivo de fechas (`DatePicker`) y botón rápido de "Hoy".
- 3 Tarjetas resumen principales (Total Ventas del Día, Ganancia Neta Real e Ingresos - Costo FIFO, Capital Inmovilizado).
- Sección de Historial de Ventas diarias con badges de método de pago y estado.
- Acordeón de Arqueo de Caja con desglose detallado y métricas de canal.

---

## 7. Motor Offline-First y Sincronización en Tiempo Real

### Arquitectura del SyncManager y Sincronización Multidispositivo

```
[ Dispositivo A ]                                  [ Cloud Firestore ]                              [ Dispositivo B ]
Venta / Producto                                       Colecciones:                                 Escucha Reactiva
       ↓                                          - products                                               ↓
SQLite (ACID txn)                                 - lots                                            SyncManager (Stream)
       ↓                                          - sales                                                  ↓
sync_queue (PENDING)                                   ↑                                            syncProducts/Lots/Sales
       ↓                                               │                                                   ↓
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
| RF-06 | Buscador POS dinámico < 200ms | `pos_viewmodel.dart`, `pos_sales_view.dart` | ✅ |
| RF-07 | Validación estricta de existencias | `pos_viewmodel.dart` (`addItem`) | ✅ |
| RF-08 | Regla anti-pérdida (precio >= costo) | `pos_viewmodel.dart` (`checkout`) | ✅ |
| RF-09 | Descuento FIFO por lote | `pos_local_datasource.dart` | ✅ |
| RF-10 | Métodos de pago múltiples | `sale.dart`, `checkout_bottom_sheet.dart` | ✅ |
| RF-11 | Opciones de despacho (Delivery/Tienda) | `sale.dart`, `pos_viewmodel.dart` | ✅ |
| RF-12 | FIFO en cascada multi-lote | `pos_local_datasource.dart` | ✅ |
| RF-13 | CRM básico (cliente + teléfono) | `sale.dart`, `checkout_bottom_sheet.dart` | ✅ |
| RF-14 | Devoluciones en ventana de 24h | `pos_local_datasource.dart` (`voidSale`) | ✅ |
| RF-15 | Reintegración al lote + neutralización | `pos_local_datasource.dart` | ✅ |
| RF-16 | Margen base promotor (`commissionRate`) | `promoter.dart` | ✅ |
| RF-17 | Catálogo RBAC (costos ocultos) | `promoters_viewmodel.dart` | ✅ |
| RF-18 | Precio piso respetado | `calculate_commission.dart` | ✅ |
| RF-19 | Sincronización de stock visible | `inventory_viewmodel.dart` | ✅ |
| RF-20 | Reservas dropshipping 12h | `schema.sql` → tabla `reservations` | ✅ |
| RF-21 | TTL y retorno de stock automático | `promoter_local_datasource.dart` | ✅ |
| RF-22 | Liquidación de ganancias compartidas | `calculate_commission.dart` | ✅ |
| RF-23 | Tasa de efectividad/conversión | `promoter.dart` | ✅ |
| RF-24 | Balance patrimonial en vivo | `get_financial_overview_usecase.dart` | ✅ |
| RF-25 | Arqueo diario de flujos | `get_daily_cash_audit_usecase.dart` | ✅ |
| RF-26 | Separación costo reposición / ganancia | `dashboard_local_datasource.dart` | ✅ |
| RF-27 | Conciliación por método de pago | `dashboard_local_datasource.dart` | ✅ |
| RF-28 | Utilidades por canal (directo/promotores) | `dashboard_local_datasource.dart` | ✅ |

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

### 🟢 Resueltos en v1.1.0

- ✅ **P-01 Resuelto:** Dashboard e Historial de Ventas integrado como pestaña principal en `HomeShellView`.
- ✅ **P-02 Resuelto:** Módulo Promotores integrado en `HomeShellView` e inyectado en `main.dart`.
- ✅ **P-04 Resuelto:** `FirestoreRemoteDataSource` conectada como fuente remota real y reactiva en `main.dart`.

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
| **P-07** | **Selector de promotor en POS:** Exponer dropdown/selector de promotor en el `CheckoutBottomSheet` para atribuir ventas directas. | Medio |

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

### v1.1.0 — Navegación Unificada, Sincronización Real con Firestore y CRUD Completo
*Octubre 2026*

- 🚀 **Navegación 4-Tabs en `HomeShellView`:** Integración de Inventario, POS, Dashboard y Promotores en el `BottomNavigationBar` con recarga reactiva de datos al cambiar de pestaña.
- ☁️ **Sincronización Real con Cloud Firestore:** Conexión de `FirestoreRemoteDataSource` en `main.dart`, soportando operaciones `INSERT`, `UPDATE` y `DELETE` en cascada (productos y lotes).
- 🔄 **Sincronización Multidispositivo en Vivo:** `SyncManager.startRealtimeSync()` activo al iniciar la app, escuchando snapshots de Firestore y actualizando SQLite localmente para reflejar ventas y altas de productos entre dos dispositivos de forma automática.
- 📦 **CRUD Completo de Inventario:**
  - Implementación de `UpdateProductUseCase` y `EditProductSheet` para edición de datos de producto.
  - Implementación de `DeleteProductUseCase` con eliminación atómica en cascada (producto + lotes) y propagación a la cola de sincronización.
  - Rediseño de `ProductCard` con acordeón detallado de inspección de lotes (fecha, costo unitario, cantidad disponible/inicial, capital inmovilizado) y prevención de desbordamientos mediante `Wrap` responsivos.
- 🛒 **Mejoras en Punto de Venta (POS):**
  - Controles directos de cantidad `+` y `-` en la lista de productos del POS.
  - Soporte completo para 4 métodos de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`) mediante `ChoiceChips` en `CheckoutBottomSheet`.
  - Registro automático de actualización de lotes en `sync_queue` tras compras con consumo FIFO multi-lote.
  - Refresco reactivo automático del stock en la vista de POS tras completar el checkout.
- 📊 **Historial y Métricas en Dashboard:**
  - Inclusión de las 3 tarjetas resumen clave (Total Ventas del Día, Ganancia Neta Real, Capital Inmovilizado).
  - Historial detallado de ventas por fecha seleccionada con hora, total y método de pago.
- 🧪 **Suite de Pruebas Ampliada:** Nuevos tests de eliminación en cascada (`inventory_atomic_cascade_test.dart`), sincronización DELETE (`sync_manager_test.dart`) y pruebas de navegación shell (`home_shell_view_test.dart`).

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
