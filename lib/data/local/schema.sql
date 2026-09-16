PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS productos (
    id TEXT PRIMARY KEY,
    sku TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    marca TEXT,
    categoria TEXT,
    precio_venta_estandar REAL NOT NULL,
    stock_minimo INTEGER DEFAULT 5,
    activo INTEGER DEFAULT 1,
    creado_en TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS lotes (
    id TEXT PRIMARY KEY,
    producto_id TEXT NOT NULL,
    fecha_compra TEXT NOT NULL,
    cantidad_adquirida INTEGER NOT NULL,
    cantidad_disponible INTEGER NOT NULL,
    costo_unitario_real REAL NOT NULL,
    precio_base_promotor REAL NOT NULL,
    FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS promotores (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    telefono TEXT,
    activo INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS ventas (
    id TEXT PRIMARY KEY,
    fecha TEXT DEFAULT (datetime('now')),
    metodo_pago TEXT NOT NULL CHECK (metodo_pago IN ('EFECTIVO', 'TRANSFERENCIA')),
    modalidad_entrega TEXT NOT NULL CHECK (modalidad_entrega IN ('TIENDA', 'DELIVERY')),
    costo_flete REAL DEFAULT 0.0,
    total_cobrado REAL NOT NULL,
    ganancia_neta REAL NOT NULL,
    cliente_nombre TEXT,
    cliente_telefono TEXT,
    promotor_id TEXT,
    es_devolucion INTEGER DEFAULT 0,
    FOREIGN KEY (promotor_id) REFERENCES promotores(id)
);

CREATE TABLE IF NOT EXISTS detalle_ventas (
    id TEXT PRIMARY KEY,
    venta_id TEXT NOT NULL,
    lote_id TEXT NOT NULL,
    cantidad INTEGER NOT NULL,
    costo_unitario_aplicado REAL NOT NULL,
    precio_unitario_cobrado REAL NOT NULL,
    FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
    FOREIGN KEY (lote_id) REFERENCES lotes(id)
);

CREATE TABLE IF NOT EXISTS reservas (
    id TEXT PRIMARY KEY,
    promotor_id TEXT NOT NULL,
    lote_id TEXT NOT NULL,
    cantidad INTEGER NOT NULL,
    fecha_creacion TEXT DEFAULT (datetime('now')),
    fecha_expiracion TEXT NOT NULL,
    estado TEXT DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'CONCRETADA', 'EXPIRADA')),
    FOREIGN KEY (promotor_id) REFERENCES promotores(id),
    FOREIGN KEY (lote_id) REFERENCES lotes(id)
);

CREATE TABLE IF NOT EXISTS sync_queue (
    id TEXT PRIMARY KEY,
    tabla_afectada TEXT NOT NULL,
    registro_id TEXT NOT NULL,
    accion TEXT NOT NULL CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE')),
    payload_json TEXT NOT NULL,
    creado_en TEXT DEFAULT (datetime('now')),
    estado TEXT DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'SINCRONIZADO', 'FALLO')),
    intentos INTEGER DEFAULT 0
);
