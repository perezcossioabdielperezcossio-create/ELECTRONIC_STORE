CREATE TABLE IF NOT EXISTS customers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    created_at TEXT DEFAULT (datetime('now'))
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
    is_active INTEGER DEFAULT 1,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS promoters (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sales (
    id TEXT PRIMARY KEY,
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
    FOREIGN KEY (promoter_id) REFERENCES promoters(id)
);

CREATE TABLE IF NOT EXISTS sale_items (
    id TEXT PRIMARY KEY,
    sale_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price REAL NOT NULL,
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
    affected_table TEXT NOT NULL,
    record_id TEXT NOT NULL,
    action TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    status TEXT DEFAULT 'PENDIENTE',
    retry_count INTEGER DEFAULT 0
);
