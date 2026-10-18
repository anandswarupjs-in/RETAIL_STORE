USE retail_store;

CREATE OR REPLACE VIEW LowStockProducts AS
SELECT p.product_id,p.product_name,p.category,i.stock_qty,i.reorder_level
FROM Product p JOIN Inventory i ON i.product_id=p.product_id
WHERE i.stock_qty<=i.reorder_level;

CREATE OR REPLACE VIEW ProductSupplierInventory AS
SELECT p.product_id,p.product_name,p.category,p.price,
       s.supplier_id,s.supplier_name,s.phone AS supplier_phone,
       i.stock_qty,i.reorder_level,i.expiry_date
FROM Product p JOIN Supplier s ON s.supplier_id=p.supplier_id
JOIN Inventory i ON i.product_id=p.product_id;

CREATE OR REPLACE VIEW CompletedSalesSummary AS
SELECT o.order_id,o.order_date,o.total_amount,c.customer_name,e.employee_name
FROM CustomerOrder o
JOIN Customer c ON c.customer_id=o.customer_id
JOIN Employee e ON e.employee_id=o.employee_id
WHERE o.status='COMPLETED';

CREATE OR REPLACE VIEW BestSellingProducts AS
SELECT p.product_id,p.product_name,SUM(si.quantity) AS units_sold,
       SUM(si.quantity*si.unit_price) AS sales_value
FROM Product p
JOIN Sale_Item si ON si.product_id=p.product_id
JOIN CustomerOrder o ON o.order_id=si.order_id
WHERE o.status='COMPLETED'
GROUP BY p.product_id,p.product_name;

CREATE INDEX idx_product_category ON Product(category);
CREATE INDEX idx_order_date ON CustomerOrder(order_date);
CREATE INDEX idx_order_status ON CustomerOrder(status);
CREATE INDEX idx_sale_item_product ON Sale_Item(product_id);

-- Example view checks:
SELECT * FROM LowStockProducts;
SELECT * FROM ProductSupplierInventory;
SELECT * FROM CompletedSalesSummary;
SELECT * FROM BestSellingProducts ORDER BY units_sold DESC;
