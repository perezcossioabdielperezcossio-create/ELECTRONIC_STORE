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

### Fase 1: Arquitectura Base y Modelado (✅ Completado)
- [x] Crear estructura de carpetas (Clean Architecture + Feature First).
- [x] Definir entidades de dominio (`Product`, `InventoryBatch`, `Sale`, `Promoter`, `Commission`).
- [x] Implementar Use Cases principales.
- [x] Configurar Datasources Locales (`sqflite`).
- [x] Crear Repositories.
- [x] Implementar ViewModels base (MVVM).
- [x] Plantillas de Vistas (Views) y Widgets.

### Fase 2: Implementación de Base de Datos y Persistencia (🚧 En Progreso)
- [ ] Configurar inicialización real de SQLite (`schema.sql`).
- [ ] Conectar Repositories con la UI para operaciones CRUD locales reales.
- [ ] Tests de acceso a datos locales.

### Fase 3: Interfaz de Usuario y Navegación (⏳ Pendiente)
- [ ] Implementar la navegación con GoRouter (Rutas definidas en `core/constants`).
- [ ] UI final de Inventario (Listado, Creación de Productos).
- [x] UI final del POS (Carrito, Selección de Productos, Checkout).
- [ ] UI final de Promotores y Comisiones.
- [ ] UI del Dashboard.

### Fase 4: Sincronización y Backend (⏳ Pendiente)
- [ ] Implementar lógica de `SyncManager` para enviar operaciones pendientes.
- [ ] Conectar con backend (REST API o Firebase).

## 🛠️ Tecnologías Utilizadas

- **Flutter / Dart**
- **Clean Architecture & MVVM**
- **State Management**: Provider (a través de `ChangeNotifier`)
- **Base de Datos Local**: `sqflite`
- **Result Type**: `dartz` (`Either`) para manejo funcional de errores.
- **Comparación de Objetos**: `equatable`
