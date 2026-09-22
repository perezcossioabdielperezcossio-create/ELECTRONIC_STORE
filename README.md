# Memoria Técnica Oficial y Matriz de Trazabilidad (v1.0.0)
## ElectronicStore - POS & Gestión de Inventarios Offline-First

## 1. Resumen Ejecutivo y Arquitectura del Sistema
**ElectronicStore** es una solución integral de Punto de Venta (POS) y Gestión de Inventarios desarrollada en Flutter, diseñada para operar en entornos con conectividad inestable (Offline-First). El sistema calcula el costeo utilizando el método FIFO real e independiente, valorizado en Bolivianos (Bs).

**Arquitectura Implementada:**
- **Patrón Base**: *Clean Architecture* segregado en capas lógicas: *Domain* (entidades y casos de uso abstractos), *Data* (orígenes de datos y repositorios), y *Presentation* (UI y gestión de estado).
- **Organización**: *Feature-First* (Módulos independientes por dominio).
  - `inventory`: Lógica de lotes y productos.
  - `pos`: Operaciones del punto de venta y carrito.
  - `promoters`: Lógica de negocio y catálogos RBAC.
  - `dashboard`: Métricas, arqueos e inteligencia de negocios.
  - `core/sync`: Motor offline y persistencia resiliente.
- **Gestión de Estado**: Patrón MVVM impulsado por `ChangeNotifier` (Provider/ListenableBuilder).
- **Programación Funcional**: Uso exhaustivo del paquete `dartz` (especialmente `Either`) para el control determinista de errores.
- **Persistencia**: Base de datos relacional y transaccional con SQLite (`sqflite`), implementando llaves foráneas (`PRAGMA foreign_keys = ON`).

---

## 2. Matriz de Cumplimiento Funcional Completa

| Requisito | Descripción / Alcance | Archivo(s) de Implementación (`lib/`) | Test Unitario Asociado (`test/`) | Estado |
| --- | --- | --- | --- | --- |
| **Módulo 1: Gestión de Inventario** | | | | |
| RF-01 | SKU Único | `inventory/domain/usecases/create_product_with_lot_usecase.dart` | `test/features/inventory/create_product_with_lot_usecase_test.dart` | ✅ Completado |
| RF-02 | Lotes independientes y costo real sin promediar | `inventory/domain/entities/lot.dart`, `inventory/data/models/lot_model.dart` | `test/features/inventory/lot_model_test.dart` | ✅ Completado |
| RF-03 | Stock en tiempo real y cálculo agregado | `inventory/domain/entities/product.dart` (`availableStock`) | `test/features/inventory/product_entity_test.dart` | ✅ Completado |
| RF-04 | Alertas de reposición (StockStatus) | `inventory/domain/entities/product.dart`, `inventory/presentation/widgets/stock_status_badge.dart` | `test/features/inventory/product_entity_test.dart` | ✅ Completado |
| RF-05 | Capital inmovilizado | `inventory/domain/entities/product.dart` | `test/features/inventory/product_entity_test.dart` | ✅ Completado |
| **Módulo 2: Punto de Venta (POS)** | | | | |
| RF-06 | Buscador POS dinámico < 200ms | `pos/presentation/viewmodels/pos_viewmodel.dart` | `test/features/pos/pos_viewmodel_test.dart` | ✅ Completado |
| RF-07 | Validación estricta de existencias | `pos/data/datasources/pos_local_datasource.dart` (`processSale`) | `test/features/pos/process_sale_test.dart` | ✅ Completado |
| RF-08 | Regla anti-pérdida (Protección de costo) | `pos/data/datasources/pos_local_datasource.dart` | `test/features/pos/process_sale_test.dart` | ✅ Completado |
| RF-09 | Descuento FIFO | `pos/data/datasources/pos_local_datasource.dart` | `test/features/pos/process_sale_test.dart` | ✅ Completado |
| RF-10 | Métodos de pago múltiples | `pos/domain/entities/sale.dart` | `test/features/pos/sale_entity_test.dart` | ✅ Completado |
| RF-11 | Opciones de despacho (Delivery/Store) | `pos/domain/entities/sale.dart` | `test/features/pos/sale_entity_test.dart` | ✅ Completado |
| RF-12 | FIFO en cascada multi-lote | `pos/data/datasources/pos_local_datasource.dart` | `test/features/pos/process_sale_test.dart` | ✅ Completado |
| RF-13 | CRM Básico (Cliente/Teléfono) | `pos/domain/entities/sale.dart` | `test/features/pos/sale_entity_test.dart` | ✅ Completado |
| RF-14 | Devoluciones en ventana de 24h | `pos/data/datasources/pos_local_datasource.dart` (`voidSale`) | `test/features/pos/void_sale_test.dart` | ✅ Completado |
| RF-15 | Reintegración al lote y Neutralización financiera | `pos/data/datasources/pos_local_datasource.dart` | `test/features/pos/void_sale_test.dart` | ✅ Completado |
| **Módulo 3: Promotores y Dropshipping** | | | | |
| RF-16 | Margen base promotor | `promoters/domain/entities/promoter.dart` | `test/features/promoters/promoter_test.dart` | ✅ Completado |
| RF-17 | Catálogo RBAC (Costos ocultos) | `promoters/presentation/viewmodels/catalog_viewmodel.dart` | `test/features/promoters/catalog_viewmodel_test.dart` | ✅ Completado |
| RF-18 | Precio piso respetado | `promoters/domain/usecases/calculate_commission_usecase.dart` | `test/features/promoters/commission_test.dart` | ✅ Completado |
| RF-19 | Sincronización de stock visible | `promoters/presentation/viewmodels/catalog_viewmodel.dart` | `test/features/promoters/catalog_viewmodel_test.dart` | ✅ Completado |
| RF-20 | Reservas dropshipping 12h | `promoters/domain/entities/reservation.dart` | `test/features/promoters/reservation_test.dart` | ✅ Completado |
| RF-21 | TTL (Time-To-Live) y retorno de stock automático | `promoters/domain/usecases/expire_reservations_usecase.dart` | `test/features/promoters/expire_reservations_test.dart` | ✅ Completado |
| RF-22 | Liquidación de ganancias compartidas | `promoters/domain/usecases/liquidate_commissions_usecase.dart` | `test/features/promoters/liquidate_commissions_test.dart` | ✅ Completado |
| RF-23 | Tasa de efectividad/conversión | `promoters/domain/entities/promoter.dart` | `test/features/promoters/promoter_test.dart` | ✅ Completado |
| **Módulo 4: Dashboard y Finanzas** | | | | |
| RF-24 | Balance patrimonial en vivo | `dashboard/domain/usecases/get_financial_overview_usecase.dart` | `test/features/dashboard/dashboard_metrics_test.dart` | ✅ Completado |
| RF-25 | Arqueo diario de flujos | `dashboard/domain/usecases/get_daily_cash_audit_usecase.dart` | `test/features/dashboard/dashboard_metrics_test.dart` | ✅ Completado |
| RF-26 | Separación (Costo reposición vs Ganancia neta) | `dashboard/data/datasources/dashboard_local_datasource.dart` | `test/features/dashboard/dashboard_metrics_test.dart` | ✅ Completado |
| RF-27 | Conciliación por método de pago (Efectivo/Bancos) | `dashboard/data/datasources/dashboard_local_datasource.dart` | `test/features/dashboard/dashboard_metrics_test.dart` | ✅ Completado |
| RF-28 | Discriminación de utilidades por canal (Directo vs Promotores) | `dashboard/domain/usecases/get_channel_profit_usecase.dart` | `test/features/dashboard/dashboard_metrics_test.dart` | ✅ Completado |

---

## 3. Matriz de Requisitos No Funcionales (RNF)

| RNF | Descripción | Estrategia de Implementación | Estado |
| --- | --- | --- | --- |
| **RNF-01** | Offline-First Permanente | Implementación del patrón `SyncQueue` mediante SQLite. Todas las escrituras insertan atómicamente sus payloads (`CREATE`, `UPDATE`, `DELETE`) en la tabla `sync_queue`. El servicio `SyncManager` procesa esta cola en segundo plano. | ✅ Completado |
| **RNF-02** | Rendimiento en Búsquedas | Consultas paginadas o limitadas en SQLite e índices virtuales (o mapeo en memoria `ChangeNotifier`) asegurando `< 200ms` por acción. | ✅ Completado |
| **RNF-03** | Consistencia & Resolución de Conflictos | Uso de transacciones `db.transaction()` (ACID) en cascada. Resolución `First-Write-Wins` implementada en el SyncManager basada en timestamps ISO-8601 originales, manteniendo la integridad contable. | ✅ Completado |
| **RNF-04** | Seguridad y Aislamiento (RBAC) | Filtrado condicional en Views y ViewModels según el perfil activo (Ej: Promotor no accede a `real_unit_cost`). | ✅ Completado |
| **RNF-05** | Ergonomía Móvil (UX/UI) | Pantallas diseñadas bajo estándar *Mobile-First*. Selectores rápidos, `BottomSheets` para flujos complejos y uso correcto de teclados virtuales contextuales (Numérico para montos). | ✅ Completado |
| **RNF-06** | Compatibilidad Multiplataforma | Desarrollo nativo con Flutter, adaptativo para pantallas de celulares/tablets en la rama de Android e iOS. | ✅ Completado |

---

## 4. Reporte de Calidad y Verificación (QA)

Se ha ejecutado una auditoría integral utilizando el utillaje estándar de Flutter.

### Análisis Estático (Linter)
- **Comando:** `flutter analyze`
- **Resultado:** **0 Issues Found!**
- El código se encuentra pulido en su totalidad, respetando *Effective Dart* sin importaciones ociosas ni variables sin inicializar.

### Pruebas Unitarias e Integración
- **Comando:** `flutter test`
- **Total de Tests:** Todos los flujos core ejecutados (Inventory, POS, Promoters, Dashboard, SyncManager).
- **Resultado:** **All tests passed!** (Éxito del 100%)
- *Nota:* Se utilizan pruebas en memoria pura (`sqflite_common_ffi`) para validar la ejecución en CI/CD sin necesidad de emulador.

---

## 5. Guía de Ejecución y Despliegue Rápido

Para replicar el entorno de producción v1.0.0, ejecuta los siguientes pasos en la terminal:

```bash
# 1. Clonar el repositorio y posicionarse en la rama develop o main (v1.0.0)
git clone https://gitlab.com/indecorp-group/electronic_store.git
cd electronic_store

# 2. Descargar las dependencias
flutter pub get

# 3. (Opcional) Ejecutar auditoría de calidad de código y tests para verificación
flutter analyze
flutter test

# 4. Lanzar la aplicación en el dispositivo conectado o emulador
flutter run
```

*Fin del Documento Técnico.*
