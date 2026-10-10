-- Tabla de hechos: Ventas
CREATE TABLE sales_fact (
    sales_invoice_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    customer_name VARCHAR(200),
    total_amount DECIMAL(18,2),
    net_amount DECIMAL(18,2),
    tax_amount DECIMAL(18,2),
    invoice_date DATE,
    fiscal_year INTEGER,
    fiscal_month INTEGER,
    quarter INTEGER,
    territory VARCHAR(100),
    sales_rep VARCHAR(100)
) DISTKEY(customer_id) SORTKEY(invoice_date);

-- Tabla de hechos: Inventario
CREATE TABLE inventory_fact (
    inventory_id VARCHAR(50) PRIMARY KEY,
    item_code VARCHAR(50),
    item_name VARCHAR(200),
    warehouse VARCHAR(50),
    stock_quantity DECIMAL(18,2),
    stock_value DECIMAL(18,2),
    valuation_rate DECIMAL(18,2),
    last_movement_date DATE,
    inventory_turnover DECIMAL(10,2)
) DISTKEY(item_code) SORTKEY(warehouse);

-- Tabla de hechos: Finanzas
CREATE TABLE finance_fact (
    journal_entry_id VARCHAR(50) PRIMARY KEY,
    account VARCHAR(100),
    account_type VARCHAR(50),
    debit_amount DECIMAL(18,2),
    credit_amount DECIMAL(18,2),
    entry_date DATE,
    fiscal_year INTEGER,
    fiscal_period INTEGER,
    company VARCHAR(100)
) DISTKEY(account) SORTKEY(entry_date);

-- Tabla de dimensión: Clientes
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(200),
    customer_type VARCHAR(50),
    territory VARCHAR(100),
    customer_group VARCHAR(100),
    creation_date DATE,
    is_active BOOLEAN
) DISTSTYLE ALL;

-- Tabla de dimensión: Productos
CREATE TABLE dim_product (
    item_code VARCHAR(50) PRIMARY KEY,
    item_name VARCHAR(200),
    item_group VARCHAR(100),
    brand VARCHAR(50),
    uom VARCHAR(20),
    standard_cost DECIMAL(18,2),
    sales_price DECIMAL(18,2)
) DISTSTYLE ALL;