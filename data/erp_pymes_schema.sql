-- ============================================================================
-- SCHEMA ERP PARA PYMES + BI + AGENTES IA
-- Motor: MariaDB (Amazon RDS)
-- Charset: utf8mb4 / InnoDB (soporte transaccional + FKs)
--
-- Supuestos de diseño:
--  - Esquema multi-tenant: "companies" permite operar varias Pymes en la
--    misma base de datos (útil si el proyecto sirve a más de un cliente).
--    Si vas a operar una sola empresa, puedes ignorar company_id o dejarlo
--    fijo en 1.
--  - Este schema es INDEPENDIENTE de las tablas internas de Frappe/ERPNext
--    (esas se autogeneran desde los DocTypes). Úsalo si vas a construir tu
--    propia capa de datos/API para Pymes, o como base de datos analítica y
--    de agentes IA que convive junto al RDS de ERPNext.
--  - Los IDs son BIGINT UNSIGNED AUTO_INCREMENT (simple y rápido). Si vas a
--    exponer estos IDs públicamente, considera agregar una columna UUID
--    adicional en las tablas de cabecera (orders, invoices, etc).
--  - Todas las FK usan ON DELETE RESTRICT por defecto para proteger
--    integridad contable/histórica, salvo relaciones "detalle de cabecera"
--    (líneas de documentos) que usan CASCADE.
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- MÓDULO A: ORGANIZACIÓN Y SEGURIDAD
-- ============================================================================

CREATE TABLE companies (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL,
    legal_name      VARCHAR(200),
    tax_id          VARCHAR(30)     UNIQUE,          -- RUC / NIT / RFC
    currency        CHAR(3)         NOT NULL DEFAULT 'PEN',
    timezone        VARCHAR(50)     NOT NULL DEFAULT 'America/Lima',
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE branches (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    name            VARCHAR(150)    NOT NULL,
    address         VARCHAR(255),
    is_main         BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_branches_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE roles (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(50)     NOT NULL UNIQUE,  -- Admin, Ventas, Compras, Contable, Almacen, Agente_IA...
    description     VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE users (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    branch_id       BIGINT UNSIGNED,
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(150)    NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    last_login_at   DATETIME,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_users_company_email (company_id, email),
    CONSTRAINT fk_users_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_users_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_roles (
    user_id         BIGINT UNSIGNED NOT NULL,
    role_id         BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO B: TERCEROS (clientes / proveedores unificados)
-- ============================================================================

CREATE TABLE partners (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id          BIGINT UNSIGNED NOT NULL,
    type                ENUM('customer','supplier','both') NOT NULL,
    business_name       VARCHAR(200)    NOT NULL,
    trade_name          VARCHAR(200),
    tax_id              VARCHAR(30),
    email               VARCHAR(150),
    phone               VARCHAR(30),
    credit_limit        DECIMAL(14,2)   NOT NULL DEFAULT 0,
    payment_terms_days  INT             NOT NULL DEFAULT 0,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_partners_company_taxid (company_id, tax_id),
    CONSTRAINT fk_partners_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE partner_addresses (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    partner_id      BIGINT UNSIGNED NOT NULL,
    label           VARCHAR(50)     NOT NULL DEFAULT 'fiscal',  -- fiscal, envio, facturacion
    address_line    VARCHAR(255)    NOT NULL,
    city            VARCHAR(100),
    state           VARCHAR(100),
    country         VARCHAR(100),
    postal_code     VARCHAR(20),
    is_default      BOOLEAN         NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_paddr_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE partner_contacts (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    partner_id      BIGINT UNSIGNED NOT NULL,
    full_name       VARCHAR(150)    NOT NULL,
    email           VARCHAR(150),
    phone           VARCHAR(30),
    position        VARCHAR(100),
    CONSTRAINT fk_pcontact_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO C: CATÁLOGO E INVENTARIO
-- ============================================================================

CREATE TABLE product_categories (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    parent_id       BIGINT UNSIGNED,                 -- auto-referencia: árbol de categorías
    name            VARCHAR(150)    NOT NULL,
    CONSTRAINT fk_pcat_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pcat_parent FOREIGN KEY (parent_id) REFERENCES product_categories(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE products (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id          BIGINT UNSIGNED NOT NULL,
    category_id         BIGINT UNSIGNED,
    sku                 VARCHAR(50)     NOT NULL,
    name                VARCHAR(200)    NOT NULL,
    description         TEXT,
    unit_of_measure     VARCHAR(20)     NOT NULL DEFAULT 'UND',
    cost_price          DECIMAL(14,4)   NOT NULL DEFAULT 0,
    sale_price          DECIMAL(14,4)   NOT NULL DEFAULT 0,
    tax_rate            DECIMAL(5,2)    NOT NULL DEFAULT 18.00,
    track_inventory     BOOLEAN         NOT NULL DEFAULT TRUE,
    min_stock           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_products_company_sku (company_id, sku),
    CONSTRAINT fk_products_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES product_categories(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE warehouses (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    branch_id       BIGINT UNSIGNED,
    name            VARCHAR(150)    NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_wh_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_wh_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE inventory_stock (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id      BIGINT UNSIGNED NOT NULL,
    warehouse_id    BIGINT UNSIGNED NOT NULL,
    quantity        DECIMAL(14,3)   NOT NULL DEFAULT 0,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_stock_product_wh (product_id, warehouse_id),
    CONSTRAINT fk_stock_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_stock_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Kardex: bitácora de movimientos, append-only (no se edita ni borra)
CREATE TABLE inventory_movements (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    product_id      BIGINT UNSIGNED NOT NULL,
    warehouse_id    BIGINT UNSIGNED NOT NULL,
    movement_type   ENUM('in','out','transfer','adjustment') NOT NULL,
    quantity        DECIMAL(14,3)   NOT NULL,
    unit_cost       DECIMAL(14,4)   NOT NULL DEFAULT 0,
    reference_type  VARCHAR(50),           -- 'sales_invoice','purchase_invoice','adjustment'
    reference_id    BIGINT UNSIGNED,       -- referencia polimórfica (no lleva FK física a propósito)
    movement_date   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      BIGINT UNSIGNED,
    CONSTRAINT fk_mov_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mov_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_mov_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_mov_user FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_mov_date (movement_date),
    INDEX idx_mov_reference (reference_type, reference_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO D: VENTAS
-- ============================================================================

CREATE TABLE sales_orders (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    branch_id       BIGINT UNSIGNED,
    partner_id      BIGINT UNSIGNED NOT NULL,       -- cliente
    order_number    VARCHAR(30)     NOT NULL,
    order_date      DATE            NOT NULL,
    status          ENUM('draft','confirmed','invoiced','cancelled') NOT NULL DEFAULT 'draft',
    currency        CHAR(3)         NOT NULL DEFAULT 'PEN',
    subtotal        DECIMAL(14,2)   NOT NULL DEFAULT 0,
    tax_total       DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    created_by      BIGINT UNSIGNED,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_so_company_number (company_id, order_number),
    CONSTRAINT fk_so_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_so_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_so_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_so_user FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_so_date (order_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_order_items (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sales_order_id  BIGINT UNSIGNED NOT NULL,
    product_id      BIGINT UNSIGNED NOT NULL,
    quantity        DECIMAL(14,3)   NOT NULL,
    unit_price      DECIMAL(14,4)   NOT NULL,
    discount_pct    DECIMAL(5,2)    NOT NULL DEFAULT 0,
    tax_rate        DECIMAL(5,2)    NOT NULL DEFAULT 0,
    line_total      DECIMAL(14,2)   NOT NULL,
    CONSTRAINT fk_soi_order FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_soi_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_invoices (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    sales_order_id  BIGINT UNSIGNED,
    partner_id      BIGINT UNSIGNED NOT NULL,
    invoice_number  VARCHAR(30)     NOT NULL,
    issue_date      DATE            NOT NULL,
    due_date        DATE,
    status          ENUM('draft','issued','paid','partially_paid','overdue','cancelled') NOT NULL DEFAULT 'draft',
    subtotal        DECIMAL(14,2)   NOT NULL DEFAULT 0,
    tax_total       DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    balance_due     DECIMAL(14,2)   NOT NULL DEFAULT 0,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_si_company_number (company_id, invoice_number),
    CONSTRAINT fk_si_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_si_order FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_si_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_si_dates (issue_date, due_date),
    INDEX idx_si_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_invoice_items (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sales_invoice_id    BIGINT UNSIGNED NOT NULL,
    product_id          BIGINT UNSIGNED NOT NULL,
    quantity            DECIMAL(14,3)   NOT NULL,
    unit_price          DECIMAL(14,4)   NOT NULL,
    discount_pct        DECIMAL(5,2)    NOT NULL DEFAULT 0,
    tax_rate            DECIMAL(5,2)    NOT NULL DEFAULT 0,
    line_total          DECIMAL(14,2)   NOT NULL,
    CONSTRAINT fk_sii_invoice FOREIGN KEY (sales_invoice_id) REFERENCES sales_invoices(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sii_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payments_received (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sales_invoice_id    BIGINT UNSIGNED NOT NULL,
    payment_date        DATE            NOT NULL,
    amount               DECIMAL(14,2)   NOT NULL,
    method               ENUM('cash','transfer','card','other') NOT NULL,
    reference            VARCHAR(100),
    created_by           BIGINT UNSIGNED,
    CONSTRAINT fk_pr_invoice FOREIGN KEY (sales_invoice_id) REFERENCES sales_invoices(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pr_user FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO E: COMPRAS (estructura simétrica a Ventas)
-- ============================================================================

CREATE TABLE purchase_orders (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    branch_id       BIGINT UNSIGNED,
    partner_id      BIGINT UNSIGNED NOT NULL,       -- proveedor
    order_number    VARCHAR(30)     NOT NULL,
    order_date      DATE            NOT NULL,
    status          ENUM('draft','confirmed','invoiced','cancelled') NOT NULL DEFAULT 'draft',
    currency        CHAR(3)         NOT NULL DEFAULT 'PEN',
    subtotal        DECIMAL(14,2)   NOT NULL DEFAULT 0,
    tax_total       DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    created_by      BIGINT UNSIGNED,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_po_company_number (company_id, order_number),
    CONSTRAINT fk_po_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_po_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_po_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_po_user FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase_order_items (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    purchase_order_id   BIGINT UNSIGNED NOT NULL,
    product_id           BIGINT UNSIGNED NOT NULL,
    quantity              DECIMAL(14,3)   NOT NULL,
    unit_price            DECIMAL(14,4)   NOT NULL,
    discount_pct          DECIMAL(5,2)    NOT NULL DEFAULT 0,
    tax_rate              DECIMAL(5,2)    NOT NULL DEFAULT 0,
    line_total            DECIMAL(14,2)   NOT NULL,
    CONSTRAINT fk_poi_order FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase_invoices (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id           BIGINT UNSIGNED NOT NULL,
    purchase_order_id    BIGINT UNSIGNED,
    partner_id            BIGINT UNSIGNED NOT NULL,
    invoice_number        VARCHAR(30)     NOT NULL,
    issue_date            DATE            NOT NULL,
    due_date              DATE,
    status                ENUM('draft','issued','paid','partially_paid','overdue','cancelled') NOT NULL DEFAULT 'draft',
    subtotal              DECIMAL(14,2)   NOT NULL DEFAULT 0,
    tax_total             DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total                 DECIMAL(14,2)   NOT NULL DEFAULT 0,
    balance_due           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    created_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_pi_company_number (company_id, invoice_number),
    CONSTRAINT fk_pi_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pi_order FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_pi_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_pi_dates (issue_date, due_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase_invoice_items (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    purchase_invoice_id     BIGINT UNSIGNED NOT NULL,
    product_id                BIGINT UNSIGNED NOT NULL,
    quantity                  DECIMAL(14,3)   NOT NULL,
    unit_price                DECIMAL(14,4)   NOT NULL,
    discount_pct               DECIMAL(5,2)    NOT NULL DEFAULT 0,
    tax_rate                   DECIMAL(5,2)    NOT NULL DEFAULT 0,
    line_total                  DECIMAL(14,2)   NOT NULL,
    CONSTRAINT fk_pii_invoice FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pii_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payments_made (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    purchase_invoice_id      BIGINT UNSIGNED NOT NULL,
    payment_date               DATE            NOT NULL,
    amount                      DECIMAL(14,2)   NOT NULL,
    method                       ENUM('cash','transfer','card','other') NOT NULL,
    reference                    VARCHAR(100),
    created_by                   BIGINT UNSIGNED,
    CONSTRAINT fk_pm_invoice FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pm_user FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO F: CONTABILIDAD
-- ============================================================================

CREATE TABLE chart_of_accounts (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    parent_id       BIGINT UNSIGNED,
    code            VARCHAR(20)     NOT NULL,
    name            VARCHAR(150)    NOT NULL,
    account_type    ENUM('asset','liability','equity','income','expense') NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_coa_company_code (company_id, code),
    CONSTRAINT fk_coa_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_coa_parent FOREIGN KEY (parent_id) REFERENCES chart_of_accounts(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE fiscal_periods (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    name            VARCHAR(20)     NOT NULL,      -- '2026-01'
    start_date      DATE            NOT NULL,
    end_date        DATE            NOT NULL,
    is_closed       BOOLEAN         NOT NULL DEFAULT FALSE,
    UNIQUE KEY uq_fp_company_name (company_id, name),
    CONSTRAINT fk_fp_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE journal_entries (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id           BIGINT UNSIGNED NOT NULL,
    fiscal_period_id      BIGINT UNSIGNED NOT NULL,
    entry_date              DATE            NOT NULL,
    reference_type           VARCHAR(50),
    reference_id              BIGINT UNSIGNED,
    description                VARCHAR(255),
    created_by                  BIGINT UNSIGNED,
    created_at                   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_je_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_je_period FOREIGN KEY (fiscal_period_id) REFERENCES fiscal_periods(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_je_user FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_je_date (entry_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE journal_entry_lines (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    journal_entry_id         BIGINT UNSIGNED NOT NULL,
    account_id                 BIGINT UNSIGNED NOT NULL,
    partner_id                   BIGINT UNSIGNED,
    debit                          DECIMAL(14,2)   NOT NULL DEFAULT 0,
    credit                          DECIMAL(14,2)   NOT NULL DEFAULT 0,
    CONSTRAINT fk_jel_entry FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_jel_account FOREIGN KEY (account_id) REFERENCES chart_of_accounts(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_jel_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO G: BI / DATA WAREHOUSE (esquema estrella para dashboards)
-- Poblado por un proceso ETL (recomendado: workflow de n8n programado o
-- Step Functions) que lee de las tablas transaccionales de arriba.
-- ============================================================================

CREATE TABLE dim_date (
    date_key        INT             PRIMARY KEY,     -- formato YYYYMMDD
    full_date       DATE            NOT NULL,
    day             TINYINT         NOT NULL,
    month           TINYINT         NOT NULL,
    year            SMALLINT        NOT NULL,
    quarter         TINYINT         NOT NULL,
    week_of_year    TINYINT         NOT NULL,
    day_name        VARCHAR(15)     NOT NULL,
    month_name      VARCHAR(15)     NOT NULL,
    is_weekend      BOOLEAN         NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Dimensión de terceros (SCD tipo 2: conserva historial de cambios)
CREATE TABLE dim_partner (
    partner_key     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    partner_id      BIGINT UNSIGNED NOT NULL,
    company_id      BIGINT UNSIGNED NOT NULL,
    business_name   VARCHAR(200)    NOT NULL,
    partner_type    ENUM('customer','supplier','both') NOT NULL,
    segment         VARCHAR(50),
    city            VARCHAR(100),
    country         VARCHAR(100),
    valid_from      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to        DATETIME,
    is_current      BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_dimpartner_partner FOREIGN KEY (partner_id) REFERENCES partners(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_dimpartner_current (partner_id, is_current)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Dimensión de productos (SCD tipo 2)
CREATE TABLE dim_product (
    product_key     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id      BIGINT UNSIGNED NOT NULL,
    company_id      BIGINT UNSIGNED NOT NULL,
    sku             VARCHAR(50)     NOT NULL,
    name            VARCHAR(200)    NOT NULL,
    category_name   VARCHAR(150),
    valid_from      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to        DATETIME,
    is_current      BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_dimproduct_product FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_dimproduct_current (product_id, is_current)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE fact_sales (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id           BIGINT UNSIGNED NOT NULL,
    date_key               INT             NOT NULL,
    partner_key              BIGINT UNSIGNED NOT NULL,
    product_key                BIGINT UNSIGNED NOT NULL,
    sales_invoice_id             BIGINT UNSIGNED NOT NULL,
    quantity                       DECIMAL(14,3)   NOT NULL,
    unit_price                       DECIMAL(14,4)   NOT NULL,
    discount_amount                    DECIMAL(14,2)   NOT NULL DEFAULT 0,
    tax_amount                           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total_amount                           DECIMAL(14,2)   NOT NULL,
    cost_amount                              DECIMAL(14,2)   NOT NULL DEFAULT 0,
    margin_amount                              DECIMAL(14,2)   NOT NULL DEFAULT 0,
    CONSTRAINT fk_fs_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fs_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fs_partner FOREIGN KEY (partner_key) REFERENCES dim_partner(partner_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fs_product FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fs_invoice FOREIGN KEY (sales_invoice_id) REFERENCES sales_invoices(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_fs_date (date_key),
    INDEX idx_fs_partner (partner_key),
    INDEX idx_fs_product (product_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE fact_purchases (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id                BIGINT UNSIGNED NOT NULL,
    date_key                    INT             NOT NULL,
    partner_key                   BIGINT UNSIGNED NOT NULL,
    product_key                     BIGINT UNSIGNED NOT NULL,
    purchase_invoice_id               BIGINT UNSIGNED NOT NULL,
    quantity                            DECIMAL(14,3)   NOT NULL,
    unit_cost                             DECIMAL(14,4)   NOT NULL,
    tax_amount                              DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total_amount                              DECIMAL(14,2)   NOT NULL,
    CONSTRAINT fk_fp_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fp_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fp_partner FOREIGN KEY (partner_key) REFERENCES dim_partner(partner_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fp_product FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fp_invoice FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_fp_date (date_key),
    INDEX idx_fp_partner (partner_key),
    INDEX idx_fp_product (product_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE fact_inventory_movement (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    date_key        INT             NOT NULL,
    product_key     BIGINT UNSIGNED NOT NULL,
    warehouse_id    BIGINT UNSIGNED NOT NULL,
    movement_type   ENUM('in','out','transfer','adjustment') NOT NULL,
    quantity        DECIMAL(14,3)   NOT NULL,
    unit_cost       DECIMAL(14,4)   NOT NULL DEFAULT 0,
    total_cost      DECIMAL(14,2)   NOT NULL DEFAULT 0,
    CONSTRAINT fk_fim_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fim_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fim_product FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fim_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_fim_date (date_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Snapshot diario de KPIs, pre-calculado para que los dashboards de BI
-- no tengan que agregar millones de filas en tiempo real.
CREATE TABLE kpi_daily_snapshot (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id                BIGINT UNSIGNED NOT NULL,
    date_key                    INT             NOT NULL,
    total_sales                   DECIMAL(14,2)   NOT NULL DEFAULT 0,
    total_purchases                 DECIMAL(14,2)   NOT NULL DEFAULT 0,
    gross_margin                      DECIMAL(14,2)   NOT NULL DEFAULT 0,
    new_customers                       INT             NOT NULL DEFAULT 0,
    accounts_receivable                   DECIMAL(14,2)   NOT NULL DEFAULT 0,
    accounts_payable                        DECIMAL(14,2)   NOT NULL DEFAULT 0,
    inventory_value                           DECIMAL(14,2)   NOT NULL DEFAULT 0,
    created_at                                  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_kpi_company_date (company_id, date_key),
    CONSTRAINT fk_kpi_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_kpi_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- MÓDULO H: AGENTES IA (Bedrock + n8n + Step Functions)
-- ============================================================================

CREATE TABLE ai_agents (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id           BIGINT UNSIGNED NOT NULL,
    name                   VARCHAR(100)    NOT NULL,      -- 'Asistente de Cobranza'
    role_description         VARCHAR(255),
    bedrock_model_id           VARCHAR(150)    NOT NULL,     -- ej. anthropic.claude-sonnet-...
    system_prompt                 TEXT,
    status                          ENUM('active','inactive','testing') NOT NULL DEFAULT 'testing',
    created_at                        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_agent_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_agent_tools (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agent_id        BIGINT UNSIGNED NOT NULL,
    tool_name       VARCHAR(100)    NOT NULL,     -- 'query_sales_db','create_invoice','send_email'
    tool_config     JSON,
    is_enabled      BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_tool_agent FOREIGN KEY (agent_id) REFERENCES ai_agents(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_conversations (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    agent_id        BIGINT UNSIGNED NOT NULL,
    user_id         BIGINT UNSIGNED,               -- NULL si la inició un workflow automático
    channel         ENUM('web','whatsapp','email','n8n_workflow','api') NOT NULL,
    status          ENUM('open','closed') NOT NULL DEFAULT 'open',
    started_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at        DATETIME,
    CONSTRAINT fk_conv_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_conv_agent FOREIGN KEY (agent_id) REFERENCES ai_agents(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_conv_user FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_messages (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    conversation_id       BIGINT UNSIGNED NOT NULL,
    role                    ENUM('user','agent','tool','system') NOT NULL,
    content                   TEXT            NOT NULL,
    tokens_used                 INT,
    created_at                    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_msg_conv FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_msg_conv_created (conversation_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tareas ejecutadas por agentes, orquestadas por Step Functions y/o n8n
CREATE TABLE ai_agent_tasks (
    id                              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id                        BIGINT UNSIGNED NOT NULL,
    agent_id                            BIGINT UNSIGNED NOT NULL,
    conversation_id                       BIGINT UNSIGNED,
    task_type                               VARCHAR(100)    NOT NULL,  -- 'generar_reporte_ventas','conciliar_pagos'
    input_payload                             JSON,
    output_payload                              JSON,
    status                                        ENUM('queued','running','succeeded','failed') NOT NULL DEFAULT 'queued',
    step_functions_execution_arn                    VARCHAR(255),
    n8n_execution_id                                  VARCHAR(100),
    started_at                                          DATETIME,
    finished_at                                           DATETIME,
    CONSTRAINT fk_task_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_task_agent FOREIGN KEY (agent_id) REFERENCES ai_agents(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_task_conv FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_task_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ai_agent_task_logs (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id         BIGINT UNSIGNED NOT NULL,
    step_name       VARCHAR(100),
    log_level       ENUM('info','warning','error') NOT NULL DEFAULT 'info',
    message         TEXT,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tasklog_task FOREIGN KEY (task_id) REFERENCES ai_agent_tasks(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Base de conocimiento para RAG (políticas, manuales, catálogos)
CREATE TABLE knowledge_base_documents (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id      BIGINT UNSIGNED NOT NULL,
    title           VARCHAR(255)    NOT NULL,
    source_type     ENUM('policy','manual','faq','product_catalog','other') NOT NULL DEFAULT 'other',
    source_url      VARCHAR(500),
    uploaded_by     BIGINT UNSIGNED,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kbdoc_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_kbdoc_user FOREIGN KEY (uploaded_by) REFERENCES users(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- IMPORTANTE: MariaDB no tiene tipo VECTOR nativo en todas las versiones
-- soportadas por RDS todavía. Aquí solo se guarda el contenido y una
-- referencia (embedding_vector_id) a un vector store externo recomendado:
-- Amazon Bedrock Knowledge Bases + OpenSearch Serverless.
CREATE TABLE knowledge_base_chunks (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    document_id               BIGINT UNSIGNED NOT NULL,
    chunk_index                  INT             NOT NULL,
    content                         TEXT            NOT NULL,
    embedding_vector_id               VARCHAR(150),   -- id en el vector store externo
    created_at                          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kbchunk_doc FOREIGN KEY (document_id) REFERENCES knowledge_base_documents(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Trazabilidad de ejecuciones de n8n disparadas por eventos del ERP
-- (ej. "factura emitida" -> dispara workflow -> agente IA -> Step Functions)
CREATE TABLE n8n_workflow_runs (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id            BIGINT UNSIGNED NOT NULL,
    workflow_name           VARCHAR(150)    NOT NULL,
    n8n_execution_id           VARCHAR(100)    NOT NULL,
    trigger_reference_type       VARCHAR(50),        -- 'sales_invoice','purchase_order', etc.
    trigger_reference_id           BIGINT UNSIGNED,
    status                            ENUM('running','success','error') NOT NULL DEFAULT 'running',
    started_at                          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at                           DATETIME,
    CONSTRAINT fk_n8nrun_company FOREIGN KEY (company_id) REFERENCES companies(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_n8nrun_trigger (trigger_reference_type, trigger_reference_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
