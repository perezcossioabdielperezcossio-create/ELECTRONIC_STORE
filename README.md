# ElectronicStore POS & Gestión de Inventarios
### Memoria Técnica Oficial — v1.6.0 · Ubicaciones de Stock (TIENDA vs. ALMACÉN), Aislamiento de Dashboards por Rol, Flujo de Recepción de Mercancía, Pull-to-Refresh & Persistencia de Ventas COMPLETED con Reactividad Inmediata · Offline-First · Flutter + Cloud Firestore Real-Time

---

## Tabla de Contenidos
1. [Resumen del Proyecto](#1-resumen-del-proyecto)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Estructura de Directorios](#3-estructura-de-directorios)
4. [Stack Tecnológico](#4-stack-tecnológico)
5. [Esquema de Base de Datos SQLite](#5-esquema-de-base-de-datos-sqlite)
6. [Módulos Implementados](#6-módulos-implementados)
   - [6.1 Módulo de Autenticación, Roles (RBAC) & Seguridad](#61-módulo-de-autenticación-roles-rbac--seguridad)
   - [6.2 Módulo de Inventario (FIFO por Ubicación & Recepción de Mercancía)](#62-módulo-de-inventario-fifo-por-ubicación--recepción-de-mercancía)
   - [6.3 Módulo de Punto de Venta (POS Avanzado & Reactividad Inmediata)](#63-módulo-de-punto-de-venta-pos-avanzado--reactividad-inmediata)
   - [6.4 Módulo CRM de Clientes](#64-módulo-crm-de-clientes)
   - [6.5 Módulo de Repartidores & Deliveries](#65-módulo-de-repartidores--deliveries)
   - [6.6 Módulo de Promotores & Dropshipping](#66-módulo-de-promotores--dropshipping)
   - [6.7 Módulo de Dashboards Aislados por Rol & Auditoría Diaria](#67-módulo-de-dashboards-aislados-por-rol--auditoría-diaria)
7. [Motor Offline-First y Sincronización en Tiempo Real](#7-motor-offline-first-y-sincronización-en-tiempo-real)
8. [Matriz de Cumplimiento Funcional](#8-matriz-de-cumplimiento-funcional)
9. [Requisitos No Funcionales](#9-requisitos-no-funcionales)
10. [Seguridad & Credenciales de Fábrica](#10-seguridad--credenciales-de-fábrica)
11. [Guía de Ejecución y Pruebas](#11-guía-de-ejecución-y-pruebas)
12. [Historial de Versiones (Changelog)](#12-historial-de-versiones-changelog)

---

## 1. Resumen del Proyecto

**ElectronicStore** es una plataforma integral de **Punto de Venta (POS)**, **Gestión de Inventarios Multilote y Multiubicación (FIFO)**, **Control de Acceso Basado en Roles (RBAC)**, **Dashboards Aislados por Rol**, **CRM de Clientes** y **Gestión de Repartidores / Deliveries** desarrollada en **Flutter**.

Diseñada bajo el paradigma **Offline-First**, garantiza una operatividad del 100% de sus funcionalidades comerciales incluso en ausencia total de conexión a Internet, sincronizando bidireccionalmente los datos en tiempo real con **Cloud Firestore** al recuperar conectividad.

### Capacidades Clave:
- 🔐 **Autenticación y Seguridad RBAC:** Control estricto de roles (`Admin` vs. `Vendedor/Seller`), protección total de costos de compra y aprobación de nuevos vendedores mediante PIN maestro de Administrador.
- 🏢 **Separación Física de Stock (TIENDA vs. ALMACÉN):** Trazabilidad y consumo FIFO contextual según el canal de despacho; las ventas en tienda consumen estrictamente lotes en `TIENDA`, y despachos centrales consumen lotes en `ALMACEN`.
- 📦 **Costeo Real FIFO Multilote:** Seguimiento pormenorizado por lote con fecha de adquisición, costo unitario real y desglose transaccional en `detalle_ventas`.
- 📥 **Flujo de Recepción de Mercancía para Vendedor:** Recepción rápida de stock en tienda física (`ReceiveStockSheet`) con herencia automática de costos sin crear SKUs ni alterar el catálogo central.
- 🙈 **Protección de Precios Mayoristas:** Vendedores visualizan únicamente el precio al público ("Estándar: Bs. XX") y su stock disponible; los precios mayoristas y costos son exclusivos del perfil Administrador.
- 📊 **Dashboards Aislados por Rol:**
  - **Vendedor (`SellerDashboardView`):** Exclusividad en ventas propias, KPIs de rendimiento diario (Total Vendido, Transacciones, Comisión) y ocultamiento absoluto de márgenes o capital del negocio.
  - **Administrador (`DashboardOverviewView`):** Visión global con filtros segmentados por origen (`TODOS`, `ALMACEN`, `TIENDA`), selector de vendedor, arqueo por método de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`) y balance patrimonial consolidado.
- ⚡ **Persistencia `COMPLETED` & Reactividad Inmediata:** Registro garantizado de ventas con `status: 'COMPLETED'` e `is_locked: 1` en SQLite, `sync_queue` y Firestore. Actualización instantánea en memoria del arqueo del dashboard y descuento de stock en UI al finalizar el cobro.
- 🔄 **Pull-to-Refresh Transversal:** Gesto manual de recarga con `RefreshIndicator` en POS, catálogo de inventario y dashboards.
- 🇧🇴 **Moneda Oficial:** Valorización nativa en **Bolivianos (Bs.)**.
- 👥 **Módulo CRM de Clientes:** Directorio de clientes con autocompletado y alta rápida en ventana de cobro.
- 🛵 **Módulo de Repartidores & Delivery:** Administración de repartidores, flete dinámico y asignación en ventas a domicilio.
- ↩️ **Devoluciones Seguras (24h):** Ventana de anulación de ventas con restitución automática de stock al lote original.

---

## 2. Arquitectura del Sistema

El proyecto implementa los principios de **Clean Architecture** combinados con una organización modular **Feature-First** y el patrón **MVVM (Model-View-ViewModel)** mediante `Provider`:

```
┌──────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                    │
│     Views • ViewModels (ChangeNotifier) • UI Widgets     │
├──────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                        │
│         Entities • Use Cases • Repository Contracts      │
├──────────────────────────────────────────────────────────┤
│                       DATA LAYER                         │
│      Models • DataSources (Local/Remote) • Repos Impl    │
└──────────────────────────────────────────────────────────┘
         ↕ SQLite (sqflite v2)    ↕ Cloud Firestore Real-Time
```

### Patrones de Diseño Implementados:

| Patrón | Implementación y Beneficio |
|--------|----------------------------|
| **Clean Architecture** | Aislamiento total de las reglas de negocio (Domain) de los frameworks y persistencia (Data/Presentation). |
| **Feature-First** | Modularidad escalable por directorio en `lib/features/` (`auth`, `inventory`, `pos`, `clients`, `deliveries`, `promoters`, `dashboard`, `main`). |
| **MVVM + Provider** | Separación reactiva de la interfaz de usuario con `ChangeNotifier` y consumo granular (`Consumer` / `context.watch`). |
| **Repository Pattern** | Abstracción de orígenes de datos mediante contratos de interfaz y programación funcional con `dartz` (`Either<Failure, T>`). |
| **Offline-First Transactional Engine** | Inserción ACID atómica local en SQLite acompañada de registro transaccional en `sync_queue`. |
| **Location-Aware FIFO Allocation** | Consumo cronológico de lotes filtrado estrictamente por la ubicación física de la venta (`TIENDA` vs. `ALMACEN`). |
| **Instant Cross-ViewModel Reactivity** | Notificación y recarga inmediata entre ViewModels tras eventos críticos (checkout POS ➔ recarga inmediata de Dashboard e Inventario). |
| **Schema-Adaptive Queries (`PRAGMA table_info`)** | Consultas SQL dinámicas y resilientes que inspeccionan la presencia de columnas (`fecha_venta`/`created_at`, `status`, etc.) evitando fallos de compatibilidad. |
| **Date-Normalized Querying** | Comparación de fechas en SQLite compatible tanto con `YYYY-MM-DD` como ISO-8601 mediante `substr(fecha, 1, 10)` y `date(fecha)`. |
| **Role-Based Privacy Shield** | Ocultamiento contextual en la capa de presentación de costos de adquisición, precios mayoristas y márgenes comerciales según el rol activo. |
| **Pull-to-Refresh Gesture Handling** | Desencadenamiento asíncrono concurrente de recargas de catálogo, inventario y métricas al deslizar la vista hacia abajo. |

---

## 3. Estructura de Directorios

```
lib/
├── main.dart                          # Entry point, Inyección de Dependencias, Providers & MainAuthGate
├── firebase_options.dart              # Credenciales y configuración multi-plataforma de Firebase
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # Constantes de app, umbrales FIFO y versión de SQLite (v2)
│   │   └── route_constants.dart       # Nombres de rutas de navegación
│   ├── database/
│   │   └── database_helper.dart       # Singleton SQLite, PRAGMA foreign_keys, _onCreate y _onUpgrade (v2)
│   ├── errors/
│   │   ├── exceptions.dart            # Excepciones de bajo nivel
│   │   └── failures.dart              # Clases Failure para programación funcional (Either)
│   ├── sync/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── sync_local_datasource.dart        # Gestión de sync_queue en SQLite y sync de entidades
│   │   │   │   ├── remote_sync_datasource.dart       # Contrato de sincronización remota
│   │   │   │   └── firestore_remote_data_source.dart # Integración real con Cloud Firestore (sales COMPLETED, etc.)
│   │   │   └── models/
│   │   │       └── sync_operation_model.dart         # DTO de operaciones encoladas
│   │   └── domain/
│   │       └── services/
│   │           └── sync_manager.dart  # Motor orquestador Offline/Online y sincronizador en tiempo real
│   ├── theme/
│   │   └── app_theme.dart             # Definición del Design System (Material 3)
│   ├── usecases/
│   │   └── usecase.dart               # Interfaz genérica UseCase<Type, Params>
│   └── utils/
│       ├── currency_formatter.dart    # Formateo de moneda en Bolivianos (Bs.)
│       └── date_formatter.dart        # Formateo estandarizado de fechas ISO-8601
│
├── features/
│   ├── auth/                          # 🔐 MÓDULO DE AUTENTICACIÓN Y ROLES (RBAC)
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_local_datasource.dart        # Persistencia SQLite (users/usuarios) + Master Admins
│   │   │   │   └── auth_remote_datasource.dart       # Sincronización y registro en Firestore (users)
│   │   │   ├── models/user_model.dart                # DTO con serialización SQLite/Firestore y Master Admins
│   │   │   └── repositories/auth_repository_impl.dart# Lógica de login offline-first, sesión y registro
│   │   ├── domain/
│   │   │   ├── entities/user.dart                    # Entidad User, UserRole (admin/seller) y credenciales
│   │   │   ├── repositories/auth_repository.dart     # Contrato de repositorio de autenticación
│   │   │   └── usecases/
│   │   │       ├── get_current_session_usecase.dart  # Carga de sesión persistida
│   │   │       ├── login_usecase.dart                # Validación por Celular + PIN
│   │   │       ├── logout_usecase.dart               # Cierre seguro de sesión
│   │   │       ├── register_seller_usecase.dart      # Alta con validación de PIN de Admin
│   │   │       └── seed_master_admins_usecase.dart   # Siembra de cuentas maestras
│   │   └── presentation/
│   │       ├── viewmodels/auth_viewmodel.dart        # Estado de sesión, control RBAC y errores
│   │       ├── views/
│   │       │   ├── login_view.dart                   # Vista de acceso (Celular + PIN numérico)
│   │       │   └── register_seller_view.dart         # Formulario de alta de nuevo vendedor
│   │       └── widgets/
│   │           └── admin_approval_dialog.dart        # Diálogo de seguridad para PIN de Administrador
│   │
│   ├── main/
│   │   └── presentation/views/
│   │       └── home_shell_view.dart   # Shell con navegación dinámica RBAC (4 tabs Admin / 3 tabs Seller)
│   │
│   ├── clients/                       # 👥 MÓDULO CRM DE CLIENTES
│   │   ├── data/
│   │   │   ├── datasources/client_local_datasource.dart  # CRUD en tabla clientes + cola de sync
│   │   │   ├── models/client_model.dart
│   │   │   └── repositories/client_repository_impl.dart
│   │   └── domain/
│   │       ├── entities/client.dart
│   │       ├── repositories/client_repository.dart
│   │       └── usecases/
│   │           ├── get_clients_usecase.dart
│   │           └── save_client_usecase.dart
│   │
│   ├── deliveries/                    # 🛵 MÓDULO DE REPARTIDORES & DELIVERIES
│   │   ├── data/
│   │   │   ├── datasources/delivery_local_datasource.dart # CRUD en tabla deliveries + cola de sync
│   │   │   ├── models/delivery_model.dart
│   │   │   └── repositories/delivery_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/delivery.dart
│   │   │   ├── repositories/delivery_repository.dart
│   │   │   └── usecases/
│   │   │       ├── delete_delivery_usecase.dart
│   │   │       ├── get_deliveries_usecase.dart
│   │   │       └── save_delivery_usecase.dart
│   │   └── presentation/
│   │       └── widgets/
│   │           └── delivery_management_dialog.dart   # Modal de gestión integral de repartidores
│   │
│   ├── inventory/                     # 📦 MÓDULO DE INVENTARIO Y LOTES FIFO (TIENDA / ALMACÉN)
│   │   ├── data/
│   │   │   ├── datasources/inventory_local_data_source.dart
│   │   │   ├── models/lot_model.dart
│   │   │   ├── models/product_model.dart
│   │   │   └── repositories/inventory_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/lot.dart                     # Lote con campo location (TIENDA / ALMACEN)
│   │   │   ├── entities/product.dart                 # Stock total, stockInTienda y stockInAlmacen
│   │   │   ├── repositories/inventory_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_inventory_batch.dart
│   │   │       ├── consume_stock_fifo.dart
│   │   │       ├── create_product_with_lot_usecase.dart
│   │   │       ├── delete_product_usecase.dart
│   │   │       ├── get_all_products.dart
│   │   │       └── update_product_usecase.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── add_lot_sheet.dart
│   │       │   ├── add_product_lot_sheet.dart
│   │       │   ├── edit_product_sheet.dart
│   │       │   ├── receive_stock_sheet.dart        # Recepción de mercancía en tienda con herencia de costo
│   │       │   └── inventory_catalog_screen.dart   # Catálogo adaptable RBAC con pull-to-refresh
│   │       ├── viewmodels/inventory_viewmodel.dart
│   │       ├── views/inventory_list_view.dart      # Lista de inventario con pull-to-refresh
│   │       └── widgets/
│   │           ├── product_card.dart               # Tarjeta con desglose de ubicación y protección mayorista
│   │           └── stock_status_badge.dart
│   │
│   ├── pos/                           # 🛒 MÓDULO DE PUNTO DE VENTA (POS)
│   │   ├── data/
│   │   │   ├── datasources/pos_local_datasource.dart # FIFO transaccional, regla anti-pérdida, status COMPLETED
│   │   │   ├── models/sale_detail_model.dart
│   │   │   ├── models/sale_model.dart                # Status COMPLETED e is_locked = 1 garantizados
│   │   │   └── repositories/pos_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/sale.dart                    # Entidad Sale con SaleStatus.completed por defecto
│   │   │   ├── entities/sale_detail.dart           # Desglose de lote, costo y precio cobrado
│   │   │   ├── entities/sale_item.dart
│   │   │   ├── repositories/pos_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_sale.dart
│   │   │       ├── get_sales_by_date.dart
│   │   │       ├── process_sale_usecase.dart
│   │   │       └── void_sale_usecase.dart
│   │   └── presentation/
│   │       ├── viewmodels/pos_viewmodel.dart       # Carrito, CRM, Deliveries, anti-pérdida y refresh
│   │       ├── views/
│   │       │   ├── pos_sales_view.dart             # POS con pull-to-refresh y precios mayoristas ocultos a Seller
│   │       │   └── pos_screen.dart
│   │       └── widgets/
│   │           ├── cart_item_tile.dart
│   │           ├── checkout_bottom_sheet.dart      # Modal de cobro e instant sync post-venta
│   │           └── void_sale_dialog.dart           # Diálogo de anulación en ventana de 24h
│   │
│   ├── promoters/                     # 🤝 MÓDULO DE PROMOTORES & DROPSHIPPING
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
│   │       ├── views/promoters_view.dart
│   │       └── widgets/promoter_tile.dart
│   │
│   └── dashboard/                     # 📊 MÓDULO DE DASHBOARDS AISLADOS POR ROL & ARQUEO
│       ├── data/
│       │   ├── datasources/dashboard_local_datasource.dart # Queries normalizadas con PRAGMA table_info
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
│           ├── viewmodels/dashboard_viewmodel.dart # Manejo de selectedDate, sellerUsuarioId y loadAuditForDate
│           ├── views/
│           │   ├── dashboard_overview_view.dart    # Vista Admin: KPIs, arqueo, filtros segmentados y botón refresh
│           │   ├── seller_dashboard_view.dart      # Vista Vendedor: ventas personales, KPIs del día y pull-to-refresh
│           │   └── dashboard_screen.dart
│           └── widgets/summary_card.dart
│
└── assets/
    └── sql/
        └── schema.sql                         # DDL con esquema completo SQLite v2
```

---

## 4. Stack Tecnológico

| Tecnología | Versión | Uso y Justificación |
|------------|---------|---------------------|
| **Flutter SDK** | `>= 3.13.3` | Framework de desarrollo UI multiplataforma nativo. |
| **Dart** | `3.x` | Lenguaje orientado a objetos tipado con null-safety estricto. |
| **sqflite** | `^2.4.4` | Motor de base de datos relacional local en SQLite para arquitectura Offline-First. |
| **sqflite_common_ffi** | `^2.4.3` | Soporte de SQLite en memoria (`inMemoryDatabasePath`) para ejecución ultra rápida de tests. |
| **provider** | `^6.1.5` | Inyección de dependencias y gestión de estado reactivo mediante `ChangeNotifier`. |
| **dartz** | `^0.10.1` | Programación funcional: `Either<Failure, T>` en la capa de casos de uso y repositorios. |
| **equatable** | `^3.0.0` | Comparación de valor en entidades y modelos de dominio evitando boilerplate. |
| **uuid** | `^4.6.0` | Generación de identificadores universales (UUID v4) para transacciones locales y remotas. |
| **connectivity_plus** | `^7.3.1` | Detección reactiva del estado de conectividad de red. |
| **intl** | `^0.20.3` | Formateo numérico en moneda (Bs.) y parseo estandarizado de fechas. |
| **url_launcher** | `^6.3.1` | Integración con enlaces externos y mensajería directa de WhatsApp con clientes y repartidores. |
| **firebase_core** | `^4.15.0` | Inicialización del entorno multi-plataforma Firebase. |
| **cloud_firestore** | `^6.10.0` | Backend Cloud NoSQL para replicación bidireccional y escucha reactiva en vivo. |
| **mocktail** | `^1.0.5` | Framework de mocking para pruebas unitarias e instrumentadas sin boilerplate. |

---

## 5. Esquema de Base de Datos SQLite

La base de datos opera con **SQLite v2** y ejecución forzada de `PRAGMA foreign_keys = ON`.

```
┌───────────────────────────────────────┐
│               usuarios                │
│───────────────────────────────────────│
│ id (PK) • celular (UNIQUE)            │
│ nombre • pin • role (admin/seller)    │
│ tienda_nombre • activo                │
└───────────────────────────────────────┘

┌──────────────┐     ┌───────────────┐     ┌────────────────────────┐     ┌──────────────┐
│   clientes   │     │   products    │◄────│          lots          │     │  deliveries  │
│──────────────│     │───────────────│  FK │────────────────────────│     │──────────────│
│ id (PK)      │     │ id (PK)       │     │ id (PK)                │     │ id (PK)      │
│ nombre_alias │     │ sku (UNIQUE)  │     │ product_id FK          │     │ nombre       │
│ tel_whatsapp │     │ name          │     │ purchase_date          │     │ telefono     │
│ direc_predet │     │ brand         │     │ initial_qty            │     │ vehiculo     │
│ creado_en    │     │ category      │     │ current_qty            │     │ activo       │
└──────────────┘     │ standard_price│     │ real_unit_cost         │     │ creado_en    │
       ▲             │ min_stock     │     │ promoter_price         │     └──────────────┘
       │             └───────────────┘     │ location (TIENDA/ALM.) │            ▲
       │                     │             │ is_active              │            │
       │                     │             └────────────────────────┘            │
       │                     │                         │                         │
       │                     ▼                         ▼                         │
       │             ┌────────────────────────┐    ┌────────────────────────┐    │
       │             │     ventas (sales)     │◄───│detalle_ventas (items)  │    │
       │             │────────────────────────│ FK │────────────────────────│    │
       │             │ id (PK)                │    │ id (PK)                │    │
       │             │ cliente_id FK ─────────┼──┐ │ venta_id FK            │    │
       │             │ delivery_id FK ────────┼──┼─┼─►lote_id FK            │    │
       │             │ delivery_name          │  │ │ product_id FK          │    │
       │             │ usuario_id             │  │ │ cantidad               │    │
       │             │ origen_venta / store_l.│  │ │ costo_unitario_compra  │    │
       │             │ total_cobrado (total)  │  │ │ precio_unitario_cobrado│    │
       │             │ metodo_pago            │  │ │ line_discount          │    │
       │             │ tipo_entrega           │  │ └────────────────────────┘    │
       │             │ delivery_fee           │  │                               │
       │             │ fecha_venta(created_at)│  │                               │
       │             │ status ('COMPLETED')   │  │                               │
       │             │ is_locked (1)          │  │                               │
       │             └────────────────────────┘  │                               │
       │                     ▲                   │                               │
       └─────────────────────┴───────────────────┘                               │
                             │                                                   │
                             └───────────────────────────────────────────────────┘

┌──────────────────────────────────────┐     ┌──────────────┐     ┌──────────────┐
│              sync_queue              │     │  promoters   │     │ reservations │
│──────────────────────────────────────│     │──────────────│     │──────────────│
│ id (PK) • table_name • operation     │     │ id (PK)      │     │ id (PK)      │
│ payload (JSON con status COMPLETED)  │     │ name, phone  │     │ promoter_id  │
│ created_at • status • retry_count    │     │ is_active    │     │ lot_id, qty  │
└──────────────────────────────────────┘     └──────────────┘     │ expires_at   │
                                                                  └──────────────┘
```

---

## 6. Módulos Implementados

### 6.1 Módulo de Autenticación, Roles (RBAC) & Seguridad
- **Entidades:** `User`, `UserRole` (`admin`, `seller`).
- **Autenticación por Celular + PIN:** Validación contra base de datos local SQLite y sincronización bidireccional con la colección `users` en Firestore.
- **Master Admins Sembrados:** Cuentas maestras de Administrador sembradas automáticamente de fábrica en la inicialización.
- **Registro de Nuevos Vendedores con PIN de Seguridad:** Formulario `RegisterSellerView` protegido obligatoriamente por `AdminApprovalDialog` (PIN maestro de Administrador).
- **Navegación Dinámica por Roles en [`HomeShellView`](file:///d:/proyectos/electronic_store/lib/features/main/presentation/views/home_shell_view.dart):**
  - **Administrador (`Admin`):** 4 Pestañas completas (**Inventario** con costos y creación; **POS** comercial; **Dashboard** financiero global; **Promotores**).
  - **Vendedor (`Seller`):** 3 Pestañas (**Catálogo** con stock y recepción de mercancía; **POS** comercial; **Dashboard** de ventas personal).
- **Cierre de Sesión Seguro:** Diálogo de confirmación que limpia la sesión activa y redirige al Login.

---

### 6.2 Módulo de Inventario (FIFO por Ubicación & Recepción de Mercancía)
- **Entidades:** `Product`, `Lot`.
- **Ubicación Física de Stock:** Cada lote registra `location` (`TIENDA` vs. `ALMACEN`). Las entidades `Product` exponen `stockInTienda`, `stockInAlmacen` y `availableStock`.
- **Recepción de Mercancía para Tienda (`ReceiveStockSheet`):**
  - El vendedor no crea nuevos productos ni altera SKUs existentes en el catálogo.
  - La acción "Recibir Mercancía / Cargar Stock" permite seleccionar un producto del catálogo e ingresar unidades que se registran automáticamente con ubicación `TIENDA`, heredando el costo real del último lote ingresado.
- **Ocultamiento de Precios Mayoristas para Vendedor:**
  - En las tarjetas `ProductCard`, si el usuario tiene rol `seller`, la etiqueta y valor de "Mayorista: Bs. XX" y el costo de adquisición se ocultan por completo.
  - El vendedor únicamente visualiza el precio público ("Estándar: Bs. XX") y la disponibilidad en tienda y almacén central.
- **Gesto Pull-to-Refresh:** `InventoryCatalogScreen` e `InventoryListView` incorporan `RefreshIndicator` para recargar el inventario en paralelo con el catálogo POS.

---

### 6.3 Módulo de Punto de Venta (POS Avanzado & Reactividad Inmediata)
- **Búsqueda Instantánea Multi-Campo:** Filtrado reactivo por **Nombre**, **SKU** y **Marca**.
- **Ocultamiento de Precios Mayoristas en POS:** En `PosSalesView`, los badges de precio mayorista se ocultan automáticamente para el perfil vendedor.
- **Consumo FIFO Contextual por Ubicación:** Las ventas presenciales en tienda física descuentan exclusivamente lotes con `location == 'TIENDA'`. Los despachos desde almacén central descuentan lotes con `location == 'ALMACEN'`.
- **Regla Anti-Pérdida Transaccional:** Bloqueo en tiempo de ejecución si el total cobrado es inferior a la suma ponderada del costo real de compra ($\text{cartTotal} < \text{totalCostBase}$).
- **Persistencia Garantizada de Ventas `COMPLETED`:**
  - Toda venta exitosa se registra con `status = 'COMPLETED'` e `is_locked = 1` en SQLite (`ventas` y `sales`).
  - El payload enviado a `sync_queue` y a Cloud Firestore en la colección `sales` garantiza `status: "COMPLETED"` e `is_locked: true` (erradicando registros residuales como `pending`).
- **Reactividad Inmediata Post-Venta (Instant Sync):**
  - Al completar el cobro en `CheckoutBottomSheet`, se desencadena inmediatamente la recarga reactiva de `DashboardViewModel.loadAuditForDate(selectedDate)` y de `InventoryViewModel.loadProducts()`.
  - El arqueo de caja se actualiza al instante en la UI y el stock consumido se descuenta de inmediato en pantalla.
- **Devoluciones (24 Horas):** Diálogo `VoidSaleDialog` para anulación de transacciones con restitución íntegra de stock al lote original.

---

### 6.4 Módulo CRM de Clientes
- **Entidades:** `Client`.
- **Directorio Local & Remoto:** Persistencia en SQLite (`clientes`) y réplica automática en Firestore (`clients`).
- **Alta Rápida en Venta:** Modal "Nuevo Cliente CRM" integrado en el flujo de cobro sin perder el estado del carrito.

---

### 6.5 Módulo de Repartidores & Deliveries
- **Entidades:** `Delivery`.
- **CRUD Completo:** Diálogo `DeliveryManagementDialog` accesible desde el `AppBar` del POS para crear, editar, activar/desactivar y eliminar repartidores.
- **Atribución de Ventas:** Registro de repartidor y flete en la cabecera de la venta.

---

### 6.6 Módulo de Promotores & Dropshipping
- **Entidades:** `Promoter`, `Commission`.
- **Cálculo de Comisiones:** Algoritmo que respeta el precio piso del producto asegurando el margen del negocio.
- **Reservas Temporales (12h TTL):** Bloqueo transaccional de stock en SQLite (`reservations`) con liberación automática al vencer.

---

### 6.7 Módulo de Dashboards Aislados por Rol & Auditoría Diaria
- **Aislamiento Estricto por Rol:**
  - **Dashboard del Vendedor ([`SellerDashboardView`](file:///d:/proyectos/electronic_store/lib/features/dashboard/presentation/views/seller_dashboard_view.dart)):**
    - Muestra exclusivamente las ventas realizadas por el vendedor logueado (`usuario_id == celular`).
    - Oculta completamente métricas de capital inmovilizado, márgenes de utilidad y costos unitarios de compra.
    - Presenta KPIs personales: Total vendido en el día, transacciones concretadas y comisión por ventas.
    - Soporte completo para gesto Pull-to-Refresh.
  - **Dashboard del Administrador ([`DashboardOverviewView`](file:///d:/proyectos/electronic_store/lib/features/dashboard/presentation/views/dashboard_overview_view.dart)):**
    - Filtro segmentado interactivo por origen (`TODOS`, `ALMACEN`, `TIENDA`) y selector de vendedor.
    - Balance patrimonial completo (capital inmovilizado y ganancia potencial).
    - Desglose pormenorizado de arqueo por método de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`).
    - Botón de refresco manual en la AppBar (`IconButton` con icono `Icons.refresh`) que ejecuta `await dashboardViewModel.loadAuditForDate(selectedDate)`.
- **Normalización de Fechas en SQLite:**
  - Consultas en `DashboardLocalDatasource` mediante `(substr(..., 1, 10) = ? OR date(...) = date(?))`, garantizando que todas las ventas de la fecha seleccionada sean computadas con independencia de la hora o zona horaria local.
  - Inclusión de ventas `COMPLETED` y cómputo de ventas históricas no anuladas (`UPPER(status) != 'VOIDED' AND UPPER(status) != 'ANULADA'`).
- **Inspección Dinámica de Esquema (`PRAGMA table_info`):**
  - Adaptabilidad automática ante columnas presentes en tablas `sales` y `ventas`, garantizando compatibilidad retroactiva y robustez en entornos de pruebas y producción.

---

## 7. Motor Offline-First y Sincronización en Tiempo Real

```
[ Dispositivo A (Venta / Cliente / Repartidor / Usuario) ]
                       ↓
         SQLite Transaccional (ACID)
                       ↓
             sync_queue (PENDING)
                       ↓
            SyncManager (FIFO Push)
                       │
                       ▼
          [ Cloud Firestore Backend ]
           - products
           - lots
           - sales (status: COMPLETED, is_locked: true)
           - clients
           - deliveries
           - users
                       │
                       ▼
            SyncManager (Streams)
                       ↓
           [ Dispositivo B (Escucha) ]
                       ↓
             Actualización SQLite
                       ↓
             Notificación UI Reactiva
```

- **Resolución de Conflictos:** Algoritmo `First-Write-Wins` con preservación de `clientTimestamp` ISO-8601.
- **Monitor de Conectividad en UI:** Indicador visual en el `AppBar` con estados en vivo:
  - 🟢 **En Línea:** Icono `cloud_done` indicando base de datos sincronizada.
  - 🟠 **Fuera de Línea:** Icono `cloud_off` + badge con conteo de operaciones pendientes en cola.

---

## 8. Matriz de Cumplimiento Funcional

| RF | Descripción | Archivo / Componente Principal | Estado |
|----|-------------|--------------------------------|--------|
| **RF-01** | SKU único por producto | `inventory_local_data_source.dart` | ✅ |
| **RF-02** | Lotes independientes con costo real y ubicación (`TIENDA`/`ALMACEN`) | `lot.dart`, `lot_model.dart` | ✅ |
| **RF-03** | Stock consolidado y desglosado por tienda/almacén | `product.dart` (`stockInTienda`, `stockInAlmacen`) | ✅ |
| **RF-04** | Alertas de stock bajo y agotado | `stock_status_badge.dart` | ✅ |
| **RF-05** | Cálculo de capital inmovilizado | `inventory_viewmodel.dart` | ✅ |
| **RF-06** | Buscador POS multi-criterio (Nombre, SKU, Marca) | `pos_sales_view.dart`, `pos_viewmodel.dart` | ✅ |
| **RF-07** | Validación estricta de existencias | `pos_viewmodel.dart` | ✅ |
| **RF-08** | Regla anti-pérdida (precio $\ge$ costo) | `pos_viewmodel.dart` (`violatesAntiLoss`) | ✅ |
| **RF-09** | Descuento FIFO transaccional por lote | `pos_local_datasource.dart` | ✅ |
| **RF-10** | Múltiples métodos de pago (Efectivo, QR, Transf., Tarjeta) | `checkout_bottom_sheet.dart` | ✅ |
| **RF-11** | Modalidad de despacho (Tienda / Delivery con flete) | `checkout_bottom_sheet.dart` | ✅ |
| **RF-12** | Desglose FIFO en `detalle_ventas` (`sale_details`) | `sale_detail_model.dart`, `pos_local_datasource.dart` | ✅ |
| **RF-13** | CRM de Clientes con autocompletado y alta rápida | `client_local_datasource.dart`, `checkout_bottom_sheet.dart` | ✅ |
| **RF-14** | Devoluciones y anulación en ventana de 24 horas | `void_sale_dialog.dart`, `pos_local_datasource.dart` | ✅ |
| **RF-15** | Restitución de stock al lote original | `pos_local_datasource.dart` (`voidSale`) | ✅ |
| **RF-16** | Margen base promotor (`commissionRate`) | `promoter.dart` | ✅ |
| **RF-17** | Catálogo RBAC (Costos y precios mayoristas ocultos para vendedor) | `inventory_catalog_screen.dart`, `product_card.dart` | ✅ |
| **RF-18** | Precio piso respetado en dropshipping | `calculate_commission.dart` | ✅ |
| **RF-19** | Sincronización en vivo multidispositivo | `sync_manager.dart`, `firestore_remote_data_source.dart` | ✅ |
| **RF-20** | Reservas temporales dropshipping (12h TTL) | `schema.sql` → tabla `reservations` | ✅ |
| **RF-21** | Gestión y asignación de Repartidores / Deliveries | `delivery_management_dialog.dart`, `delivery_local_datasource.dart` | ✅ |
| **RF-22** | Balance patrimonial en vivo en Dashboard | `dashboard_viewmodel.dart`, `get_financial_overview_usecase.dart` | ✅ |
| **RF-23** | Arqueo diario de caja por método de pago | `dashboard_overview_view.dart`, `get_daily_cash_audit_usecase.dart` | ✅ |
| **RF-24** | Precios pactados y descuentos comerciales en POS | `pos_sales_view.dart`, `checkout_bottom_sheet.dart` | ✅ |
| **RF-25** | Autenticación de usuarios por Celular + PIN | `login_view.dart`, `auth_viewmodel.dart` | ✅ |
| **RF-26** | Control de Acceso Basado en Roles (Admin / Seller) | `user.dart`, `home_shell_view.dart` | ✅ |
| **RF-27** | Aprobación de nuevos vendedores con PIN de Administrador | `register_seller_view.dart`, `admin_approval_dialog.dart` | ✅ |
| **RF-28** | Persistencia y recuperación de sesión offline | `auth_local_datasource.dart`, `auth_repository_impl.dart` | ✅ |
| **RF-29** | Siembra automática de Administradores Maestros | `seed_master_admins_usecase.dart` | ✅ |
| **RF-30** | Migración SQLite v2 y creación defensiva de tablas | `database_helper.dart` (`_onUpgrade`) | ✅ |
| **RF-31** | Cierre seguro de sesión con confirmación | `home_shell_view.dart` (`_handleLogout`) | ✅ |
| **RF-32** | Replicación Firestore en 6 colecciones en tiempo real | `firestore_remote_data_source.dart` | ✅ |
| **RF-33** | Consumo FIFO contextual por ubicación (`TIENDA` vs `ALMACEN`) | `pos_local_datasource.dart`, `consume_stock_fifo.dart` | ✅ |
| **RF-34** | Dashboard aislado de Vendedor (`SellerDashboardView`) con privacidad | `seller_dashboard_view.dart` | ✅ |
| **RF-35** | Filtro segmentado en Dashboard Admin por origen y vendedor | `dashboard_overview_view.dart`, `dashboard_local_datasource.dart` | ✅ |
| **RF-36** | Flujo de Recepción de Mercancía en tienda (`ReceiveStockSheet`) | `receive_stock_sheet.dart` | ✅ |
| **RF-37** | Ocultamiento de precios mayoristas en POS y catálogo para vendedor | `pos_sales_view.dart`, `product_card.dart` | ✅ |
| **RF-38** | Pull-to-Refresh transversal (POS, Inventario, Dashboards) | `pos_sales_view.dart`, `inventory_catalog_screen.dart`, etc. | ✅ |
| **RF-39** | Persistencia forzada de ventas con `status: 'COMPLETED'` e `is_locked: 1` | `pos_local_datasource.dart`, `firestore_remote_data_source.dart` | ✅ |
| **RF-40** | Normalización de fechas en SQLite e inspección `PRAGMA table_info` | `dashboard_local_datasource.dart` | ✅ |
| **RF-41** | Instant Sync reactivo post-checkout a Dashboard e Inventario | `checkout_bottom_sheet.dart`, `dashboard_viewmodel.dart` | ✅ |

---

## 9. Requisitos No Funcionales

| RNF | Especificación | Estado |
|-----|----------------|--------|
| **RNF-01 Offline-First Total** | 100% de operaciones comerciales funcionales sin conexión a Internet; almacenamiento transaccional local en SQLite y despacho asíncrono. | ✅ |
| **RNF-02 Rendimiento & Baja Latencia** | Búsquedas en memoria sobre colecciones cacheadas en `ChangeNotifier`. Consultas indexadas y optimizadas en SQLite. | ✅ |
| **RNF-03 Integridad Transaccional ACID** | Uso estricto de `db.transaction()` para operaciones multi-tabla (productos, lotes, ventas, detalles, usuarios). | ✅ |
| **RNF-04 Seguridad y Privacidad Comercial** | Datos de costo de compra, precios mayoristas y márgenes de ganancia completamente inaccesibles para el perfil `Seller`. | ✅ |
| **RNF-05 Ergonomía Móvil & Gesto Táctil** | `BottomSheets` responsivos, teclados numéricos contextuales y soporte nativo de Pull-to-Refresh. | ✅ |
| **RNF-06 Calidad de Código y Testing** | 0 warnings/errores en `flutter analyze` y suite de **89 tests automatizados superados al 100%**. | ✅ |

---

## 10. Seguridad & Credenciales de Fábrica

Para entornos de desarrollo, pruebas y configuración inicial de sucursales, el sistema inicializa dos cuentas maestras de Administrador:

| Rol | Nombre | Celular | PIN de Acceso | Tienda / Sucursal |
|-----|--------|---------|---------------|-------------------|
| **Admin Maestro 1** | Abdiel Perez Cossio | `67606367` | `696910` | Almacén Central |
| **Admin Maestro 2** | Arianna Duran Nava | `77111575` | `000000` | Almacén Central |

> ⚠️ **Nota de Seguridad:** Estos PINs maestros son los únicos autorizados para desbloquear el diálogo de aprobación (`AdminApprovalDialog`) durante el registro de nuevos vendedores.

---

## 11. Guía de Ejecución y Pruebas

### Prerrequisitos
- **Flutter SDK** `>= 3.13.3`
- **Dart SDK** `>= 3.x`
- Archivo de configuración Firebase `android/app/google-services.json` configurado.

### Comandos de Terminal

```bash
# 1. Obtener dependencias del proyecto
flutter pub get

# 2. Ejecutar análisis estático (0 issues garantizados)
flutter analyze

# 3. Ejecutar la suite completa de pruebas unitarias y de integración (89/89 tests)
flutter test

# 4. Ejecutar la aplicación en dispositivo o emulador
flutter run

# 5. Generar paquete de producción para Android (APK Release)
flutter build apk --release
```

---

## 12. Historial de Versiones (Changelog)

### v1.6.0 — Persistencia de Ventas `COMPLETED`, Normalización de Fechas & Reactividad Inmediata
*Octubre 2026*
- 🛒 **Persistencia Forzada de Ventas `COMPLETED`:**
  - Corrección integral en `SaleModel`, `pos_local_datasource.dart` y `firestore_remote_data_source.dart`.
  - Las ventas exitosas en el POS ahora se persisten invariablemente con `status = 'COMPLETED'` e `is_locked = 1` en SQLite (`ventas` y `sales`).
  - El payload enviado a `sync_queue` y a Cloud Firestore en la colección `sales` garantiza `status: "COMPLETED"` e `is_locked: true` (eliminando registros residuales como `pending`).
- 📅 **Normalización de Fechas para Consultas de Dashboard:**
  - Consultas adaptativas en `dashboard_local_datasource.dart` que soportan tanto formato `YYYY-MM-DD` como ISO-8601 mediante `(substr(..., 1, 10) = ? OR date(...) = date(?))`.
  - Cómputo robusto que incluye todas las ventas con `status = 'COMPLETED'` y ventas históricas no anuladas (`UPPER(status) != 'VOIDED' AND UPPER(status) != 'ANULADA'`).
  - Inspección dinámica de esquema SQLite mediante `PRAGMA table_info` para evitar errores de columnas no existentes.
- ⚡ **Reactividad Inmediata Post-Venta (Instant Sync):**
  - En `checkout_bottom_sheet.dart`, al completar el cobro se desencadena inmediatamente la recarga reactiva de `DashboardViewModel.loadAuditForDate(selectedDate)` y de `InventoryViewModel.loadProducts()`.
  - Botón de refresco manual en la AppBar del Dashboard (`IconButton` con icono `Icons.refresh`) que ejecuta `await dashboardViewModel.loadAuditForDate(selectedDate)`.
- 🧪 **Suite de Pruebas Ampliada:**
  - Nueva suite `sales_status_and_dashboard_sync_test.dart` y compatibilidad retroactiva de tests de dashboard. Cobertura alcanzada: **89/89 tests superados al 100%**.

---

### v1.5.0 — Ajustes de Experiencia del Vendedor & Pull-to-Refresh Reactivo
*Octubre 2026*
- 🙈 **Ocultamiento de Precios Mayoristas al Perfil Vendedor:**
  - En `pos_sales_view.dart` y `product_card.dart`, si `authViewModel.currentUser.role == UserRole.seller`, se ocultan la etiqueta y valor de "Mayorista: Bs. XX".
  - El vendedor únicamente visualiza el precio público ("Estándar: Bs. XX") y su stock disponible.
- 📥 **Flujo de Recepción de Mercancía en Tienda (`ReceiveStockSheet`):**
  - El vendedor no crea productos nuevos desde cero (sin botón de nuevo SKU/nombre).
  - Acción "Recibir Mercancía / Cargar Stock" para sumar existencias a productos existentes asignándolos automáticamente a `TIENDA` y heredando el último costo.
- 🔄 **Gesto Pull-to-Refresh Unificado:**
  - Integración de `RefreshIndicator` en `PosSalesView`, `InventoryCatalogScreen`, `InventoryListView` y `SellerDashboardView`, recargando inventario, catálogo POS y auditorías del dashboard en paralelo.

---

### v1.4.0 — Aislamiento de Dashboards por Rol & Separación de Ubicaciones (TIENDA vs. ALMACÉN)
*Octubre 2026*
- 📊 **Aislamiento de Dashboards por Rol:**
  - `SellerDashboardView`: Visibilidad exclusiva de las ventas del vendedor logueado (`usuario_id`), con privacidad estricta sobre margen y capital, y KPIs de rendimiento personal.
  - `DashboardOverviewView`: Vista consolidada de Administrador con selector de sucursal (`TODOS`, `ALMACEN`, `TIENDA`), selector de vendedor y desglose de arqueo por método de pago.
- 🏢 **Consumo FIFO Contextual por Ubicación:**
  - Incorporación del campo `location` (`TIENDA` vs. `ALMACEN`) en cada lote.
  - Las ventas en tienda física descuentan estrictamente existencias con `location == 'TIENDA'`.

---

### v1.3.0 — Autenticación, Roles (RBAC), Seguridad & Migración SQLite v2
*Octubre 2026*
- 🔐 **Módulo de Autenticación (`features/auth`):**
  - Implementación de `User`, `UserModel` y `UserRole` (`admin`, `seller`).
  - Inicio de sesión por Celular + PIN con soporte Offline-First y persistencia de sesión.
  - Formulario de registro de vendedores (`RegisterSellerView`) protegido por PIN maestro de Administrador (`AdminApprovalDialog`).
- 🛡️ **Control de Acceso Basado en Roles (RBAC):**
  - `HomeShellView` dinámico: 4 pestañas para Administradores y 3 pestañas para Vendedores.
- 🗄️ **Migración de Base de Datos SQLite v2:**
  - Actualización de `AppConstants.dbVersion = 2`.
  - Creación defensiva de tablas `clientes`, `deliveries` y `usuarios` en `DatabaseHelper._onUpgrade`.

---

### v1.2.0 — POS Avanzado, CRM de Clientes, Deliveries & Desglose FIFO
*Octubre 2026*
- 👥 **Módulo CRM de Clientes:** Directorio `clientes`, autocompletado y alta rápida en checkout.
- 🛵 **Módulo de Repartidores & Delivery:** CRUD en `deliveries`, selección de despacho a domicilio y fletes.
- 🛒 **Flexibilidad Comercial en POS:** Búsqueda multi-criterio, controles `+/-`, precios pactados y descuentos globales.
- 📊 **Desglose FIFO Transaccional:** Registro pormenorizado en `detalle_ventas` (`sale_details`) con costo exacto por tramo.

---

### v1.1.0 — Navegación Unificada, Sincronización Real Firestore & CRUD Completo
*Octubre 2026*
- 🚀 **Navegación 4-Tabs:** Shell principal unificada con selector reactivo.
- ☁️ **Sincronización en Tiempo Real:** Integración con Cloud Firestore (`FirestoreRemoteDataSource`).
- 📦 **CRUD de Inventario:** Edición y borrado atómico en cascada de productos y lotes.

---

### v1.0.0 — Baseline Inicial
*Septiembre 2026*
- ✅ Arquitectura limpia modular (Domain / Data / Presentation).
- ✅ Motor de costeo FIFO y regla anti-pérdida.
- ✅ Persistencia SQLite local con `sync_queue`.
- ✅ Devoluciones en ventana de 24h y cálculo de comisiones para promotores.

---

*Memoria técnica desarrollada y mantenida por el equipo de ingeniería — INDECORP Group.*  
*Última actualización: Octubre 2026.*
