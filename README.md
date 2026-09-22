# Electronic Store POS & Inventory

Aplicación de Punto de Venta (POS) y gestión de inventario offline-first desarrollada en Flutter. Arquitectura basada en **Clean Architecture** y **MVVM**.

## 🚀 Funcionalidades Principales

- **Gestión de Inventario FIFO**: Control preciso del stock basado en lotes (First-In, First-Out).
- **POS Offline-First**: Operaciones de punto de venta que funcionan sin conexión y se sincronizan al recuperar la red.
- **Gestión de Promotores**: Seguimiento de ventas y cálculo automático de comisiones.
- **Dashboard Financiero**: Resumen en tiempo real de ventas, inventario bajo y comisiones.

## 🏗️ Estructura del Proyecto (Feature-First)

El proyecto está organizado por características (features) para mantener la modularidad:

- `core/`: Constantes globales, manejo de errores, utilidades y configuración de UI/UX.
- `data/`: Base de datos local (SQLite) y gestión de sincronización offline.
- `features/`:
  - `inventory/`: Lógica de productos y lotes FIFO.
  - `pos/`: Lógica del punto de venta y carrito de compras.
  - `promoters/`: Gestión de promotores y cálculo de comisiones.
  - `dashboard/`: Resumen de métricas principales.

---

## 📋 Roadmap y Seguimiento

Utilizamos este archivo para llevar un registro del progreso del desarrollo.

### Registro de Cambios Recientes / Contexto Actual
- **[KAN-4] Módulo Inventory (Presentation Layer):**
  - Implementación del `InventoryViewModel` con soporte para filtrado (por texto y por estado de reposición) usando un getter reactivo `filteredProducts`.
  - Creación del componente semafórico reutilizable `StockStatusBadge` para reflejar visualmente el estado del stock (Disponible, Stock Bajo, Agotado).
  - Creación de la pantalla `InventoryCatalogScreen` con una barra superior de búsqueda/filtros y una lista de tarjetas expandibles (`ExpansionTile`) para visualizar los detalles de cada producto y sus lotes activos. Integración nativa con `ListenableBuilder` para actualizar la interfaz.
- **[KAN-5] Módulo Inventory (Domain Layer):** 
  - Se implementaron las entidades `Product` y `Lot` para el control de inventario por lotes independientes. Se incluye lógica de negocio encapsulada para el cálculo de stock activo (`availableStock`), estado del stock (`StockStatus`), costo real y capital inmovilizado. Interfaz abstracta `InventoryRepository` definida.
  - Se implementó el caso de uso `CreateProductWithLotUseCase` que valida la unicidad del SKU (lanza `DuplicateSkuException` si ya existe) y verifica cantidad inicial / costo (RF-01 y RF-02).
  - Todo el código es Dart puro siguiendo Clean Architecture.
- **[Fixes] Refactorización y estabilización (flutter analyze):**
  - Corrección de errores de sintaxis, strings truncados e interpolaciones rotas en las capas de presentación (Inventory, Dashboard, POS).
  - Alineación de interfaces del repositorio de inventario (`InventoryLocalDataSource`), implementando mapeos a `Either` (`dartz`) y conectando correctamente los modelos locales con las entidades de dominio.
  - Resolución integral de lints (super parámetros, variables no utilizadas y propiedades deprecadas) en ViewModels y pantallas.
- **[KAN-9] Módulo POS (Punto de Venta) UI y Checkout:**
  - Implementación reactiva de `PosViewModel` con buscador dinámico por SKU/Nombre, validaciones de stock físico disponible y bloqueos preventivos anti-pérdida (protección de costo de adquisición).
  - Rediseño de la interfaz (`PosView`) 100% Mobile-First, utilizando `BottomSheet` para gestión de carrito, teclados numéricos contextuales y selectores rápidos.
  - Actualización de la entidad `Sale` y `SaleModel` para estructurar y persistir métodos de pago (Efectivo/Transferencia), envíos (Tienda/Delivery) y datos del cliente.
- **[KAN-10] Inicialización de Base de Datos SQLite y Refactorización de Datasources:**
  - Creación del esquema relacional DDL consolidado en `assets/sql/schema.sql` (con las tablas clave como `products`, `lots`, `sales`, `promoters`, etc. estandarizadas en inglés).
  - Desarrollo de un `DatabaseHelper` transaccional que lee e inicializa la base de datos local activando las llaves foráneas (`PRAGMA foreign_keys = ON`).
  - Refactorización de la capa de datos de Inventario, migrando modelos deprecados (`InventoryBatchModel`) a la entidad `LotModel` para asegurar alineación con la tabla `lots` en SQLite. Todos los Datasources locales han sido conectados de forma segura.
- **[KAN-11] Dashboard Financiero, Arqueo de Caja y Métricas:**
  - Actualización del esquema SQLite añadiendo `unit_cost` a `sale_items` para tracking histórico exacto del "Capital Base Recuperado" y "Ganancia Neta Real".
  - Implementación completa de la capa de datos (Datasource y Repositorio local SQLite) con consultas agregadas (`SUM`, `JOINs` entre `lots`, `products`, `sales` y `sale_items`).
  - Casos de Uso del dominio implementados para cálculo matemático del Balance Patrimonial, Utilidad por Canales y Conciliación Diaria (Efectivo vs Banco).
  - UI de alta calidad desarrollada (`DashboardView`) e integrada con `DashboardViewModel` (ChangeNotifier) y soporte Pull-to-Refresh y selector de fecha. Pruebas unitarias SQLite In-Memory (`sqflite_common_ffi`) con 100% de éxito.
<<<<<<< HEAD
- **[KAN-15] Motor de Sincronización Offline-First (SyncQueue y SyncManager):**
  - Implementación de la tabla `sync_queue` para almacenar todas las operaciones de mutación (CREATE, UPDATE, DELETE).
  - Integración transparente en los Local Datasources (`PosLocalDatasource`, `InventoryLocalDataSource`, `PromoterLocalDatasource`) para encolar datos dentro de transacciones atómicas de SQLite.
  - Creación del `SyncManager` que orquesta el procesamiento FIFO y cuenta con mecanismos de tolerancia a fallos y reintentos.
  - Cobertura de pruebas completa confirmando el registro, simulación de recuperación de red, y reintentos ante caídas transitorias.
=======
- **[KAN-14] Módulo 3: Red de Promotores, Dropshipping y Reservas con TTL:**
  - Modificación del esquema de base de datos para la gestión de reservas temporales con caducidad (`expires_at`) y cálculo reactivo en base de datos (`LEFT JOIN`) para que el inventario muestre stock deducido automáticamente por reservas activas.
  - Creación de Casos de Uso del dominio para crear reservas con TTL exacto (12h) y validación de vigencia del stock.
  - Implementación de `PromoterCatalogView` (catálogo enfocado en promotores ocultando de forma estricta márgenes y costos de adquisición) y `NewReservationDialog` para interactuar con productos con reserva anticipada.
>>>>>>> f81970e35a48cba7f28ff61d5be7f4fb5304c046

### Fase 1: Arquitectura Base y Modelado (✅ Completado)
- [x] Crear estructura de carpetas (Clean Architecture + Feature First).
- [x] Definir entidades de dominio (`Product`, `InventoryBatch`, `Sale`, `Promoter`, `Commission`).
- [x] Implementar Use Cases principales.
- [x] Configurar Datasources Locales (`sqflite`).
- [x] Crear Repositories.
- [x] Implementar ViewModels base (MVVM).
- [x] Plantillas de Vistas (Views) y Widgets.

### Fase 2: Implementación de Base de Datos y Persistencia (🚧 En Progreso)
- [x] Configurar inicialización real de SQLite (`schema.sql`).
- [x] Conectar Repositories con la UI para operaciones CRUD locales reales.
- [ ] Tests de acceso a datos locales.

### Fase 3: Interfaz de Usuario y Navegación (⏳ Pendiente)
- [ ] Implementar la navegación con GoRouter (Rutas definidas en `core/constants`).
- [ ] UI final de Inventario (Listado, Creación de Productos).
- [x] UI final del POS (Carrito, Selección de Productos, Checkout).
- [x] UI final de Promotores y Comisiones.
- [x] UI del Dashboard.

### Fase 4: Sincronización y Backend (🚧 En Progreso)
- [x] Implementar lógica de `SyncManager` para enviar operaciones pendientes (Cola FIFO Offline-First).
- [ ] Conectar con backend (REST API o Firebase).

## 🛠️ Tecnologías Utilizadas

- **Flutter / Dart**
- **Clean Architecture & MVVM**
- **State Management**: Provider (a través de `ChangeNotifier`)
- **Base de Datos Local**: `sqflite`
- **Result Type**: `dartz` (`Either`) para manejo funcional de errores.
- **Comparación de Objetos**: `equatable`
