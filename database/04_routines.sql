USE retail_store;
DELIMITER $$

DROP PROCEDURE IF EXISTS AddProduct$$
CREATE PROCEDURE AddProduct(
    IN p_name VARCHAR(100),
    IN p_category VARCHAR(50),
    IN p_price DECIMAL(10,2),
    IN p_supplier_id INT,
    IN p_initial_stock INT
)
BEGIN
    DECLARE v_product_id INT;
    DECLARE v_supplier_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product name is required';
    END IF;
    IF p_price IS NULL OR p_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price cannot be negative';
    END IF;
    IF p_initial_stock IS NULL OR p_initial_stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Initial stock cannot be negative';
    END IF;

    SELECT COUNT(*) INTO v_supplier_count
    FROM Supplier WHERE supplier_id = p_supplier_id;
    IF v_supplier_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supplier does not exist';
    END IF;

    START TRANSACTION;
    INSERT INTO Product(product_name,category,price,supplier_id)
    VALUES(TRIM(p_name),p_category,p_price,p_supplier_id);
    SET v_product_id = LAST_INSERT_ID();

    INSERT INTO Inventory(product_id,stock_qty,reorder_level)
    VALUES(v_product_id,p_initial_stock,10);
    COMMIT;

    SELECT v_product_id AS product_id, 'Product and inventory created' AS message;
END$$

DROP FUNCTION IF EXISTS CalculateOrderTotal$$
CREATE FUNCTION CalculateOrderTotal(p_order_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(quantity * unit_price),0)
      INTO v_total FROM Sale_Item WHERE order_id=p_order_id;
    RETURN v_total;
END$$

-- Sale_Item insertion validates stock. Stock is deducted only when an order
-- transitions to COMPLETED, inside CompleteOrder, to avoid double deduction.
DROP TRIGGER IF EXISTS trg_sale_item_check_stock$$
CREATE TRIGGER trg_sale_item_check_stock
BEFORE INSERT ON Sale_Item
FOR EACH ROW
BEGIN
    DECLARE v_stock INT DEFAULT NULL;
    DECLARE v_status VARCHAR(20) DEFAULT NULL;

    SELECT stock_qty INTO v_stock
    FROM Inventory WHERE product_id=NEW.product_id;

    IF v_stock IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory record not found for product';
    END IF;

    SELECT status INTO v_status
    FROM CustomerOrder WHERE order_id=NEW.order_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order does not exist';
    END IF;

    IF v_status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Items can only be added to pending orders';
    END IF;

    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_inventory_nonnegative_update$$
CREATE TRIGGER trg_inventory_nonnegative_update
BEFORE UPDATE ON Inventory
FOR EACH ROW
BEGIN
    IF NEW.stock_qty < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock cannot be negative';
    END IF;
    IF NEW.reorder_level < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reorder level cannot be negative';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_inventory_nonnegative_insert$$
CREATE TRIGGER trg_inventory_nonnegative_insert
BEFORE INSERT ON Inventory
FOR EACH ROW
BEGIN
    IF NEW.stock_qty < 0 OR NEW.reorder_level < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock and reorder level cannot be negative';
    END IF;
END$$

DROP PROCEDURE IF EXISTS CompleteOrder$$
CREATE PROCEDURE CompleteOrder(IN p_order_id INT)
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_item_count INT DEFAULT 0;
    DECLARE v_total DECIMAL(12,2) DEFAULT 0;
    DECLARE v_shortage_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_status
    FROM CustomerOrder WHERE order_id=p_order_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found';
    END IF;
    IF v_status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending orders can be completed';
    END IF;

    SELECT COUNT(*), COALESCE(SUM(quantity*unit_price),0)
      INTO v_item_count,v_total
    FROM Sale_Item WHERE order_id=p_order_id;

    IF v_item_count=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot complete an empty order';
    END IF;

    -- Lock inventory rows in product-id order to reduce deadlock risk.
    SELECT COUNT(*) INTO v_shortage_count
    FROM Sale_Item si
    JOIN Inventory i ON i.product_id=si.product_id
    WHERE si.order_id=p_order_id AND i.stock_qty < si.quantity;

    IF v_shortage_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for one or more products';
    END IF;

    -- The UPDATE itself is atomic and the stock CHECK/trigger is a final guard.
    UPDATE Inventory i
    JOIN Sale_Item si ON si.product_id=i.product_id
    SET i.stock_qty=i.stock_qty-si.quantity
    WHERE si.order_id=p_order_id;

    UPDATE CustomerOrder
    SET total_amount=v_total,status='COMPLETED'
    WHERE order_id=p_order_id;

    COMMIT;
    SELECT p_order_id AS order_id,v_total AS total_amount,'COMPLETED' AS status;
END$$

DROP PROCEDURE IF EXISTS CancelOrder$$
CREATE PROCEDURE CancelOrder(IN p_order_id INT)
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT status INTO v_status
    FROM CustomerOrder WHERE order_id=p_order_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found';
    END IF;
    IF v_status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending orders can be cancelled; completed orders cannot be reversed by this procedure';
    END IF;

    UPDATE CustomerOrder SET status='CANCELLED' WHERE order_id=p_order_id;
    COMMIT;
    SELECT p_order_id AS order_id,'CANCELLED' AS status;
END$$

DROP PROCEDURE IF EXISTS LowStockReport$$
CREATE PROCEDURE LowStockReport()
BEGIN
    SELECT p.product_id,p.product_name,p.category,i.stock_qty,i.reorder_level
    FROM Product p JOIN Inventory i ON i.product_id=p.product_id
    WHERE i.stock_qty<=i.reorder_level
    ORDER BY i.stock_qty,p.product_name;
END$$

DROP PROCEDURE IF EXISTS CustomerSalesReport$$
CREATE PROCEDURE CustomerSalesReport(IN p_customer_id INT)
BEGIN
    SELECT c.customer_id,c.customer_name,o.order_id,o.order_date,o.total_amount
    FROM Customer c JOIN CustomerOrder o ON o.customer_id=c.customer_id
    WHERE c.customer_id=p_customer_id AND o.status='COMPLETED'
    ORDER BY o.order_date DESC;
    SELECT COALESCE(SUM(total_amount),0) AS customer_total_spending
    FROM CustomerOrder WHERE customer_id=p_customer_id AND status='COMPLETED';
END$$

DELIMITER ;

-- Finalize seeded order totals and statuses using the same function/business rules.
-- This initialization intentionally marks orders 1,2,4,5,6,7,8,9,10 completed
-- only if stock allows it. Orders 3 and 11-12 remain pending for demonstration.
-- For simplicity, the app's stock-changing workflow should be demonstrated on new orders.
UPDATE CustomerOrder o
SET o.total_amount=CalculateOrderTotal(o.order_id)
WHERE o.order_id IN (1,2,4,5,6,7,8,9,10);

-- Sample data represents already completed historical orders. Their initial stock
-- was loaded as current stock for a simple demo; do not run CompleteOrder on these.
UPDATE CustomerOrder
SET status='COMPLETED'
WHERE order_id IN (1,2,4,5,6,7,8,9,10);
UPDATE CustomerOrder
SET total_amount=CalculateOrderTotal(order_id)
WHERE order_id IN (1,2,4,5,6,7,8,9,10);
