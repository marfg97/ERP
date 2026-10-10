mysql -h erpnext-dev-ha-single-region-erpnextdb-mizgjhv6ygda.calu0eqgkv6d.us-east-1.rds.amazonaws.com \
  -u admin \
  -p'erpnextDBPass123!' \
  -D erpnext




  -- ============================================
-- 25 FACTURAS DE VENTA - MANUFACTURA DE MUEBLES
-- ============================================

INSERT INTO `tabSales Invoice` (
    name,
    customer,
    customer_name,
    posting_date,
    due_date,
    grand_total,
    rounded_total,
    total_taxes_and_charges,
    base_grand_total,
    status,
    docstatus,
    customer_group,
    territory,
    currency,
    company,
    selling_price_list,
    ignore_pricing_rule,
    debit_to,
    cost_center
) VALUES
('SI-2026-009', 'CUST-009', 'Mueblería Moderna SAC', '2026-01-20', '2026-02-19', 4500.00, 4500.00, 810.00, 4500.00, 'Paid', 1, 'Mayorista', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-010', 'CUST-010', 'Distribuidora Andina EIRL', '2026-02-05', '2026-03-07', 3200.00, 3200.00, 576.00, 3200.00, 'Paid', 1, 'Distribuidor', 'Arequipa', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-011', 'CUST-011', 'Tiendas del Hogar SAC', '2026-02-25', '2026-03-27', 5800.00, 5800.00, 1044.00, 5800.00, 'Paid', 1, 'Minorista', 'Trujillo', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-012', 'CUST-012', 'Mobiliario Perú EIRL', '2026-03-15', '2026-04-14', 2200.00, 2200.00, 396.00, 2200.00, 'Paid', 1, 'Mayorista', 'Cusco', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-013', 'CUST-013', 'Decoración y Estilo SAC', '2026-04-01', '2026-05-01', 3700.00, 3700.00, 666.00, 3700.00, 'Paid', 1, 'Minorista', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-014', 'CUST-014', 'Inmobiliaria Los Portales', '2026-04-10', '2026-05-10', 8500.00, 8500.00, 1530.00, 8500.00, 'Paid', 1, 'Corporativo', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-015', 'CUST-015', 'Hoteles del Sur SAC', '2026-04-22', '2026-05-22', 2300.00, 2300.00, 414.00, 2300.00, 'Paid', 1, 'Corporativo', 'Arequipa', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-016', 'CUST-016', 'Oficinas Modernas EIRL', '2026-05-08', '2026-06-07', 4200.00, 4200.00, 756.00, 4200.00, 'Paid', 1, 'Corporativo', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-017', 'CUST-017', 'Inversiones Madereras SAC', '2026-05-20', '2026-06-19', 3100.00, 3100.00, 558.00, 3100.00, 'Paid', 1, 'Mayorista', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-018', 'CUST-018', 'Centros Comerciales del Norte', '2026-06-05', '2026-07-05', 6800.00, 6800.00, 1224.00, 6800.00, 'Unpaid', 1, 'Corporativo', 'Trujillo', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-019', 'CUST-019', 'Muebles La Casa', '2026-06-20', '2026-07-20', 5600.00, 5600.00, 1008.00, 5600.00, 'Paid', 1, 'Minorista', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-020', 'CUST-020', 'Arte y Diseño', '2026-07-08', '2026-08-07', 7200.00, 7200.00, 1296.00, 7200.00, 'Unpaid', 1, 'Minorista', 'Arequipa', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-021', 'CUST-021', 'Muebles El Roble', '2026-07-22', '2026-08-21', 3400.00, 3400.00, 612.00, 3400.00, 'Paid', 1, 'Minorista', 'Cusco', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-022', 'CUST-022', 'Bienestar Hogar', '2026-08-08', '2026-09-07', 4800.00, 4800.00, 864.00, 4800.00, 'Paid', 1, 'Minorista', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-023', 'CUST-023', 'Muebles El Nogal', '2026-08-25', '2026-09-24', 9000.00, 9000.00, 1620.00, 9000.00, 'Unpaid', 1, 'Minorista', 'Trujillo', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-024', 'CUST-024', 'Distribuidora Maderas del Perú', '2026-09-05', '2026-10-05', 6200.00, 6200.00, 1116.00, 6200.00, 'Paid', 1, 'Distribuidor', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-025', 'CUST-025', 'Muebles Express SAC', '2026-09-18', '2026-10-18', 3500.00, 3500.00, 630.00, 3500.00, 'Paid', 1, 'Distribuidor', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-026', 'CUST-026', 'Distribuidora del Centro EIRL', '2026-10-05', '2026-11-04', 5300.00, 5300.00, 954.00, 5300.00, 'Unpaid', 1, 'Distribuidor', 'Cusco', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-027', 'CUST-027', 'Muebles de Calidad SAC', '2026-10-22', '2026-11-21', 7800.00, 7800.00, 1404.00, 7800.00, 'Paid', 1, 'Distribuidor', 'Arequipa', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-028', 'CUST-028', 'Distribuidora del Sur EIRL', '2026-11-08', '2026-12-08', 4600.00, 4600.00, 828.00, 4600.00, 'Paid', 1, 'Distribuidor', 'Tacna', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-029', 'CUST-029', 'Universidad San Martín', '2026-11-22', '2026-12-22', 6400.00, 6400.00, 1152.00, 6400.00, 'Unpaid', 1, 'Corporativo', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-030', 'CUST-030', 'Hospital Regional', '2026-12-05', '2027-01-04', 7200.00, 7200.00, 1296.00, 7200.00, 'Paid', 1, 'Corporativo', 'Arequipa', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-031', 'CUST-031', 'Municipalidad de Lima', '2026-12-18', '2027-01-17', 5100.00, 5100.00, 918.00, 5100.00, 'Paid', 1, 'Corporativo', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-032', 'CUST-032', 'Banco del Sur SAC', '2026-12-25', '2027-01-24', 8900.00, 8900.00, 1602.00, 8900.00, 'Unpaid', 1, 'Corporativo', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E'),
('SI-2026-033', 'CUST-033', 'Telecomunicaciones Andinas', '2026-12-30', '2027-01-29', 6700.00, 6700.00, 1206.00, 6700.00, 'Unpaid', 1, 'Corporativo', 'Lima', 'PEN', 'ERPNext Company', 'Standard Selling', 0, 'Debtors - E', 'Main - E');