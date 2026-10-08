# ElectronicStore POS & Gestión de Inventarios
### Memoria Técnica Oficial — v1.3.0 · Auth, Roles (RBAC), Seguridad, CRM, Deliveries & Migración SQLite · Offline-First · Flutter + Cloud Firestore Real-Time

---

## Tabla de Contenidos
1. [Resumen del Proyecto](#1-resumen-del-proyecto)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Estructura de Directorios](#3-estructura-de-directorios)
4. [Stack Tecnológico](#4-stack-tecnológico)
5. [Esquema de Base de Datos SQLite](#5-esquema-de-base-de-datos-sqlite)
6. [Módulos Implementados](#6-módulos-implementados)
   - [6.1 Módulo de Autenticación, Roles (RBAC) & Seguridad](#61-módulo-de-autenticación-roles-rbac--seguridad)
   - [6.2 Módulo de Inventario (FIFO & Costeo por Lotes)](#62-módulo-de-inventario-fifo--costeo-por-lotes)
   - [6.3 Módulo de Punto de Venta (POS Avanzado)](#63-módulo-de-punto-de-venta-pos-avanzado)
   - [6.4 Módulo CRM de Clientes](#64-módulo-crm-de-clientes)
   - [6.5 Módulo de Repartidores & Deliveries](#65-módulo-de-repartidores--deliveries)
   - [6.6 Módulo de Promotores & Dropshipping](#66-módulo-de-promotores--dropshipping)
   - [6.7 Módulo de Dashboard & Arqueo Diario](#67-módulo-de-dashboard--arqueo-diario)
7. [Motor Offline-First y Sincronización en Tiempo Real](#7-motor-offline-first-y-sincronización-en-tiempo-real)
8. [Matriz de Cumplimiento Funcional](#8-matriz-de-cumplimiento-funcional)
9. [Requisitos No Funcionales](#9-requisitos-no-funcionales)
10. [Seguridad & Credenciales de Fábrica](#10-seguridad--credenciales-de-fábrica)
11. [Guía de Ejecución y Pruebas](#11-guía-de-ejecución-y-pruebas)
12. [Historial de Versiones (Changelog)](#12-historial-de-versiones-changelog)

---

## 1. Resumen del Proyecto

**ElectronicStore** es una plataforma integral de **Punto de Venta (POS)**, **Gestión de Inventarios Multilote (FIFO)**, **Control de Acceso Basado en Roles (RBAC)**, **CRM de Clientes** y **Gestión de Repartidores / Deliveries** desarrollada en **Flutter**.

Diseñada específicamente bajo el paradigma **Offline-First**, garantiza operatividad total del 100% de sus funcionalidades comerciales aun en ausencia total de conexión a Internet, sincronizando bidireccionalmente los datos en tiempo real con **Cloud Firestore** al recuperar conectividad.

### Capacidades Clave:
- 🔐 **Autenticación y Seguridad RBAC:** Control estricto de roles (`Admin` vs. `Vendedor/Seller`), protección de costos reales de compra y aprobación de nuevos vendedores mediante PIN maestro de Administrador.
- 📦 **Costeo Real FIFO Multilote:** Seguimiento de inventario por lotes independientes con fecha, costo unitario real de compra y trazabilidad transaccional exacta.
- 🇧🇴 **Moneda Oficial:** Valorización nativa en **Bolivianos (Bs.)**.
- 🔄 **Sincronización Bidireccional en Vivo:** Réplica en tiempo real multidispositivo conectada a Cloud Firestore (`products`, `lots`, `sales`, `clients`, `deliveries`, `users`).
- 👥 **Módulo CRM de Clientes:** Directorio de clientes con autocompletado y alta rápida en ventana de cobro.
- 🛵 **Módulo de Repartidores & Delivery:** Administración de repartidores, flete dinámico y asignación en ventas a domicilio.
- 🛒 **POS Comercial de Alto Rendimiento:** Búsqueda multi-criterio (Nombre, SKU, Marca), controles rápidos `+/-`, precios pactados (Estándar vs. Mayorista), descuentos globales y regla anti-pérdida estricta.
- 📊 **Dashboard Patrimonial y Arqueo:** Métricas de capital inmovilizado, utilidad neta real, desglose de arqueo de caja por método de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`) e historial de ventas reactivo.
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
| **Live Snapshot Sync** | Escucha continua mediante `StreamSubscription` de colecciones Firestore con refresco automático de estado local. |
| **FIFO Multi-Lot Allocation** | Descuento automático de inventario lote por lote desglosado en `detalle_ventas` (`sale_details`). |
| **Strict Anti-Loss Shield** | Bloqueo en tiempo de ejecución de ventas cuyo total sea inferior al costo de adquisición ponderado. |
| **Database Migration Handler** | Migración defensiva en `DatabaseHelper._onUpgrade` (v1 ➔ v2) asegurando tablas sin pérdida de datos. |

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
│   │   │   │   └── firestore_remote_data_source.dart # Integración real con Cloud Firestore (CRUD en cascada)
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
│   ├── inventory/                     # 📦 MÓDULO DE INVENTARIO Y LOTES FIFO
│   │   ├── data/
│   │   │   ├── datasources/inventory_local_data_source.dart
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
│   │   │       ├── delete_product_usecase.dart
│   │   │       ├── get_all_products.dart
│   │   │       └── update_product_usecase.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── add_lot_sheet.dart
│   │       │   ├── add_product_lot_sheet.dart
│   │       │   ├── edit_product_sheet.dart
│   │       │   └── inventory_catalog_screen.dart   # Catálogo adaptable con protección de costos según rol
│   │       ├── viewmodels/inventory_viewmodel.dart
│   │       ├── views/inventory_list_view.dart
│   │       └── widgets/
│   │           ├── product_card.dart               # Tarjeta con acordeón de lotes y controles Admin
│   │           └── stock_status_badge.dart
│   │
│   ├── pos/                           # 🛒 MÓDULO DE PUNTO DE VENTA (POS)
│   │   ├── data/
│   │   │   ├── datasources/pos_local_datasource.dart # FIFO transaccional, regla anti-pérdida y voidSale
│   │   │   ├── models/sale_detail_model.dart
│   │   │   ├── models/sale_model.dart
│   │   │   └── repositories/pos_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/sale.dart
│   │   │   ├── entities/sale_detail.dart           # Desglose de lote, costo y precio cobrado
│   │   │   ├── entities/sale_item.dart
│   │   │   ├── repositories/pos_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_sale.dart
│   │   │       ├── get_sales_by_date.dart
│   │   │       ├── process_sale_usecase.dart
│   │   │       └── void_sale_usecase.dart
│   │   └── presentation/
│   │       ├── viewmodels/pos_viewmodel.dart       # Carrito, CRM, Deliveries, precios custom y anti-pérdida
│   │       ├── views/
│   │       │   ├── pos_sales_view.dart             # POS con buscador multi-campo y controles rápidos
│   │       │   └── pos_screen.dart
│   │       └── widgets/
│   │           ├── cart_item_tile.dart
│   │           ├── checkout_bottom_sheet.dart      # Modal de cobro (Cliente, Delivery, Pago, Descuento)
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
│   └── dashboard/                     # 📊 MÓDULO DE DASHBOARD & ARQUEO FINANCIERO
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
│           ├── viewmodels/dashboard_viewmodel.dart
│           ├── views/
│           │   ├── dashboard_overview_view.dart    # KPIs patrimoniales, arqueo y listado de ventas
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
| **sqflite_common_ffi** | `^2.4.3` | Soporte de SQLite en memoria (`inMemoryDatabasePath`) para ejecución rápida de tests unitarios y de integración. |
| **provider** | `^6.1.5` | Inyección de dependencias y gestión de estado reactivo mediante `ChangeNotifier`. |
| **dartz** | `^0.10.1` | Programación funcional: `Either<Failure, T>` en la capa de casos de uso y repositorios. |
| **equatable** | `^3.0.0` | Comparación de valor en entidades y modelos de dominio evitando boilerplate. |
| **uuid** | `^4.6.0` | Generación de identificadores únicos universales (UUID v4) para registros locales y remotos. |
| **connectivity_plus** | `^7.3.1` | Detección reactiva del estado de red (`WiFi`, `Móvil`, `Sin Conexión`). |
| **intl** | `^0.20.3` | Formateo numérico en moneda (Bs.) y fechas estandarizadas. |
| **url_launcher** | `^6.3.1` | Integración con enlaces externos y chat directo de WhatsApp con clientes y repartidores. |
| **firebase_core** | `^4.15.0` | Inicialización del entorno Firebase. |
| **cloud_firestore** | `^6.10.0` | Backend Cloud NoSQL para replicación bidireccional y escucha reactiva en tiempo real. |
| **mocktail** | `^1.0.5` | Framework de mocking para pruebas unitarias sin dependencias externas. |

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

┌──────────────────────────────────────┐     ┌──────────────┐     ┌──────────────┐
│              sync_queue              │     │  promoters   │     │ reservations │
│──────────────────────────────────────│     │──────────────│     │──────────────│
│ id (PK) • table_name • operation     │     │ id (PK)      │     │ id (PK)      │
│ payload (JSON) • created_at          │     │ name, phone  │     │ promoter_id  │
│ status (PENDING/SYNCED/FAILED)       │     │ is_active    │     │ lot_id, qty  │
│ retry_count                          │     └──────────────┘     │ expires_at   │
└──────────────────────────────────────┘                          └──────────────┘
```

---

## 6. Módulos Implementados

### 6.1 Módulo de Autenticación, Roles (RBAC) & Seguridad
- **Entidades:** `User`, `UserRole` (`admin`, `seller`).
- **Autenticación por Celular + PIN:** Validación contra base de datos local SQLite y sincronización bidireccional con la colección `users` en Firestore.
- **Master Admins Sembrados:** Cuentas maestras de Administrador sembradas automáticamente de fábrica en la inicialización.
- **Registro de Nuevos Vendedores con PIN de Seguridad:** Formulario `RegisterSellerView` que exige de forma obligatoria la autorización en tiempo real mediante `AdminApprovalDialog` (PIN maestro de Administrador) para poder dar de alta una nueva cuenta de vendedor.
- **Navegación Dinámica por Roles en [`HomeShellView`](file:///d:/proyectos/electronic_store/lib/features/main/presentation/views/home_shell_view.dart):**
  - **Administrador (`Admin`):** 4 Pestañas completas (**Inventario** con visualización de costos reales, creación/edición/borrado de productos y lotes; **POS** de cobro; **Dashboard** financiero global; **Promotores**).
  - **Vendedor (`Seller`):** 3 Pestañas (**Catálogo** en modo consulta sin acceso a costos de compra ni acciones destructivas; **POS** comercial; **Dashboard** de ventas). Costos reales ocultos en toda la experiencia.
- **Cierre de Sesión:** Diálogo de confirmación que limpia la sesión activa y redirige a la pantalla de Login.

---

### 6.2 Módulo de Inventario (FIFO & Costeo por Lotes)
- **Entidades:** `Product`, `Lot`.
- **Lógica de Costeo:** Cada ingreso físico genera un lote con su `real_unit_cost` y `purchase_date`. El stock disponible se calcula como $\sum \text{current\_quantity}$ de los lotes activos.
- **Métricas Patrimoniales:** Cálculo dinámico de capital inmovilizado y margen potencial proyectado.
- **Eliminación Atómica en Cascada:** Borrado seguro de producto y sus lotes asociados en SQLite con propagación de eventos `DELETE` a Firestore.

---

### 6.3 Módulo de Punto de Venta (POS Avanzado)
- **Búsqueda Instantánea Multi-Campo:** Filtrado reactivo en tiempo real por **Nombre**, **SKU** y **Marca**.
- **Controles Inline y Ajuste Rápido:** Botones `+` / `-` en lista y diálogo de cantidad y precio pactado (Estándar vs. Mayorista / Promotor).
- **Regla Anti-Pérdida Transaccional:** Validación que impide completar ventas si el total cobrado es inferior a la suma ponderada del costo real de compra ($\text{cartTotal} < \text{totalCostBase}$).
- **Descuento FIFO en Cascada:** Consumo cronológico de lotes registrando en `detalle_ventas` (`sale_details`) el tramo, lote, costo unitario y precio unitario cobrado.
- **Checkout Avanzado:** Selección o alta rápida de cliente CRM, selección de despacho (`TIENDA` o `DELIVERY` con flete), método de pago (`EFECTIVO`, `QR`, `TRANSFERENCIA`, `TARJETA`) y descuento global.
- **Devoluciones (24 Horas):** Diálogo `VoidSaleDialog` para anulación de transacciones con restitución íntegra de stock al lote correspondiente.

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

### 6.7 Módulo de Dashboard & Arqueo Diario
- **Balance Patrimonial:** Capital inmovilizado en stock y ganancia neta consolidada.
- **Arqueo Diario de Caja:** Desglose exacto de ingresos brutos, capital recuperado y utilidad real agrupado por método de pago.
- **Historial de Ventas:** Filtro por fecha interactivo (`DatePicker`) con detalle pormenorizado de ítems y clientes atendidos.

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
           - sales (con sale_details)
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
| **RF-02** | Lotes independientes con costo real | `lot.dart`, `lot_model.dart` | ✅ |
| **RF-03** | Stock consolidado en tiempo real | `product.dart` (`availableStock`) | ✅ |
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
| **RF-17** | Catálogo RBAC (Costos de compra ocultos para vendedores) | `inventory_catalog_screen.dart`, `product_card.dart` | ✅ |
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

---

## 9. Requisitos No Funcionales

| RNF | Especificación | Estado |
|-----|----------------|--------|
| **RNF-01 Offline-First Total** | 100% de operaciones funcionales sin conexión a Internet; almacenamiento transaccional local en SQLite y despacho asíncrono. | ✅ |
| **RNF-02 Rendimiento & Baja Latencia** | Búsquedas en memoria sobre colecciones cacheadas en `ChangeNotifier`. Consultas indexadas en SQLite. | ✅ |
| **RNF-03 Integridad Transaccional ACID** | Uso estricto de `db.transaction()` para operaciones multi-tabla (productos, lotes, ventas, detalles, usuarios). | ✅ |
| **RNF-04 Seguridad y Privacidad** | Datos de costo de compra inaccesibles para el perfil `Seller`. Aprobación protegida por PIN maestro. | ✅ |
| **RNF-05 Ergonomía Móvil** | `BottomSheets` responsivos, teclados numéricos contextuales y botones táctiles optimizados para tablets y teléfonos. | ✅ |
| **RNF-06 Calidad de Código y Testing** | 0 warnings en `flutter analyze` y suite de 61 tests automatizados superados con 100% de éxito. | ✅ |

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

# 3. Ejecutar la suite completa de pruebas unitarias y de integración
flutter test

# 4. Ejecutar la aplicación en dispositivo o emulador
flutter run

# 5. Generar paquete de producción para Android (APK Release)
flutter build apk --release
```

---

## 12. Historial de Versiones (Changelog)

### v1.3.0 — Autenticación, Roles (RBAC), Seguridad & Migración SQLite v2
*Octubre 2026*
- 🔐 **Módulo de Autenticación (`features/auth`):**
  - Implementación de `User`, `UserModel` y `UserRole` (`admin`, `seller`).
  - Inicio de sesión por Celular + PIN con soporte Offline-First y persistencia de sesión.
  - Formulario de registro de vendedores (`RegisterSellerView`) protegido por PIN maestro de Administrador (`AdminApprovalDialog`).
- 🛡️ **Control de Acceso Basado en Roles (RBAC):**
  - `HomeShellView` dinámico: 4 pestañas para Administradores (con acceso a costos, promotores y edición) y 3 pestañas para Vendedores (costos ocultos, modo consulta).
  - Encabezado con información del usuario activo, rol, sucursal y botón de cierre de sesión seguro.
- 🗄️ **Migración de Base de Datos SQLite v2:**
  - Actualización de `AppConstants.dbVersion = 2`.
  - Implementación de `DatabaseHelper._onUpgrade` y `_createMissingTables` para creación defensiva de tablas `clientes`, `deliveries`, `usuarios` y compatibilidad retroactiva.
- 🧪 **Suite de Pruebas Ampliada:**
  - Incorporación de pruebas para Auth (`auth_viewmodel_test.dart`, `auth_repository_impl_test.dart`, `auth_views_widget_test.dart`, `user_model_test.dart`) y migración de BD (`database_helper_migration_test.dart`). 61/61 tests superados exitosamente.

---

### v1.2.0 — POS Avanzado, CRM de Clientes, Deliveries & Desglose FIFO
*Octubre 2026*
- 👥 **Módulo CRM de Clientes:** Directorio `clientes`, autocompletado y alta rápida en checkout.
- 🛵 **Módulo de Repartidores & Delivery:** CRUD en `deliveries`, selección de despacho a domicilio y fletes.
- 🛒 **Flexibilidad Comercial en POS:** Búsqueda por Nombre/SKU/Marca, controles `+/-`, precios pactados (Estándar vs. Mayorista) y descuentos globales.
- 📊 **Desglose FIFO Transaccional:** Registro pormenorizado en `detalle_ventas` (`sale_details`) con lote y costo exacto por tramo.

---

### v1.1.0 — Navegación Unificada, Sincronización Real Firestore & CRUD Completo
*Octubre 2026*
- 🚀 **Navegación 4-Tabs:** Shell principal unificada con selector reactivo.
- ☁️ **Sincronización Real en Tiempo Real:** Integración con Cloud Firestore (`FirestoreRemoteDataSource`).
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
