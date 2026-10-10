CREATE TABLE IF NOT EXISTS clientes (
    id TEXT PRIMARY KEY,
    nombre_alias TEXT NOT NULL,
    telefono_whatsapp TEXT NOT NULL,
    direccion_predet TEXT,
    creado_en TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS customers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS deliveries (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    telefono TEXT NOT NULL,
    vehiculo TEXT,
    activo INTEGER NOT NULL DEFAULT 1,
    creado_en TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    brand TEXT,
    category TEXT,
    standard_selling_price REAL NOT NULL,
    min_stock_threshold INTEGER DEFAULT 5,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS lots (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    purchase_date TEXT NOT NULL,
    initial_quantity INTEGER NOT NULL,
    current_quantity INTEGER NOT NULL,
    real_unit_cost REAL NOT NULL,
    promoter_base_price REAL,
    location TEXT NOT NULL DEFAULT 'ALMACEN',
    is_active INTEGER DEFAULT 1,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS promoters (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS ventas (
    id TEXT PRIMARY KEY,
    cliente_id TEXT,
    delivery_id TEXT,
    delivery_name TEXT,
    total_cobrado REAL NOT NULL,
    metodo_pago TEXT NOT NULL,
    tipo_entrega TEXT NOT NULL,
    fecha_venta TEXT NOT NULL,
    is_locked INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    payment_method TEXT,
    delivery_method TEXT,
    delivery_fee REAL DEFAULT 0.0,
    discount REAL DEFAULT 0.0,
    tax REAL DEFAULT 0.0,
    total REAL,
    status TEXT DEFAULT 'completed',
    customer_name TEXT,
    customer_phone TEXT,
    promoter_id TEXT,
    notes TEXT,
    store_location TEXT DEFAULT 'ALMACEN',
    origen_venta TEXT DEFAULT 'ALMACEN',
    usuario_id TEXT,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    FOREIGN KEY (delivery_id) REFERENCES deliveries(id),
    FOREIGN KEY (promoter_id) REFERENCES promoters(id)
);

CREATE TABLE IF NOT EXISTS detalle_ventas (
    id TEXT PRIMARY KEY,
    venta_id TEXT NOT NULL,
    lote_id TEXT,
    product_id TEXT,
    product_name TEXT,
    cantidad INTEGER NOT NULL,
    costo_unitario_compra REAL NOT NULL,
    precio_unitario_cobrado REAL NOT NULL,
    line_discount REAL DEFAULT 0.0,
    FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
    FOREIGN KEY (lote_id) REFERENCES lots(id)
);

CREATE TABLE IF NOT EXISTS sales (
    id TEXT PRIMARY KEY,
    cliente_id TEXT,
    delivery_id TEXT,
    delivery_name TEXT,
    total_cobrado REAL,
    metodo_pago TEXT,
    tipo_entrega TEXT,
    fecha_venta TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    payment_method TEXT NOT NULL,
    delivery_method TEXT NOT NULL,
    delivery_fee REAL DEFAULT 0.0,
    discount REAL DEFAULT 0.0,
    tax REAL DEFAULT 0.0,
    total REAL NOT NULL,
    status TEXT DEFAULT 'pending',
    customer_name TEXT,
    customer_phone TEXT,
    promoter_id TEXT,
    notes TEXT,
    is_locked INTEGER DEFAULT 0,
    store_location TEXT DEFAULT 'ALMACEN',
    origen_venta TEXT DEFAULT 'ALMACEN',
    usuario_id TEXT,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    FOREIGN KEY (delivery_id) REFERENCES deliveries(id),
    FOREIGN KEY (promoter_id) REFERENCES promoters(id)
);

CREATE TABLE IF NOT EXISTS sale_items (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    lote_id TEXT,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    cantidad INTEGER,
    quantity INTEGER NOT NULL,
    costo_unitario_compra REAL,
    precio_unitario_cobrado REAL,
    unit_price REAL NOT NULL,
    unit_cost REAL DEFAULT 0.0,
    line_discount REAL DEFAULT 0.0,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS reservations (
    id TEXT PRIMARY KEY,
    promoter_id TEXT NOT NULL,
    lot_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    status TEXT DEFAULT 'ACTIVA',
    FOREIGN KEY (promoter_id) REFERENCES promoters(id),
    FOREIGN KEY (lot_id) REFERENCES lots(id)
);

CREATE TABLE IF NOT EXISTS sync_queue (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING',
    retry_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS users (
    celular TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    pin TEXT NOT NULL,
    role TEXT NOT NULL,
    tienda_nombre TEXT NOT NULL,
    activo INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS usuarios (
    id TEXT PRIMARY KEY,
    celular TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    pin TEXT NOT NULL,
    role TEXT NOT NULL,
    tienda_nombre TEXT,
    activo INTEGER NOT NULL DEFAULT 1
);

