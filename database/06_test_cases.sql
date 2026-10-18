USE retail_store;

-- Run after 04_routines.sql and 05_views_indexes.sql.
-- These examples create disposable test records; clean them up only after review.

-- TEST 1: valid product creation (choose an existing supplier ID)
CALL AddProduct('TEST - Wireless Mouse','Test',99.00,1,5);
SELECT p.product_id,p.product_name,i.stock_qty
FROM Product p JOIN Inventory i ON i.product_id=p.product_id
WHERE p.product_name='TEST - Wireless Mouse';

-- TEST 2: invalid negative price. Expected: SQLSTATE 45000.
-- Uncomment to test:
-- CALL AddProduct('Invalid Price','Test',-1.00,1,5);

-- TEST 3: invalid supplier. Expected: SQLSTATE 45000.
-- Uncomment to test:
-- CALL AddProduct('Invalid Supplier','Test',10.00,999999,5);

-- TEST 4: negative stock. Expected: CHECK constraint or trigger error.
-- Uncomment to test:
-- UPDATE Inventory SET stock_qty=-1 WHERE product_id=1;

-- TEST 5: create a new pending order and add one item
START TRANSACTION;
INSERT INTO CustomerOrder(customer_id,employee_id,status,total_amount)
VALUES(1,2,'PENDING',0);
SET @test_order_id=LAST_INSERT_ID();
INSERT INTO Sale_Item(order_id,product_id,quantity,unit_price)
SELECT @test_order_id,product_id,1,price FROM Product WHERE product_id=1;
COMMIT;
SELECT @test_order_id AS test_order_id;

-- TEST 6: valid order completion. It deducts inventory and commits atomically.
-- Uncomment the next line after checking the order ID above:
-- CALL CompleteOrder(@test_order_id);

-- TEST 7: repeated completion. Expected: rejected, no second deduction.
-- Uncomment after successful completion:
-- CALL CompleteOrder(@test_order_id);

-- TEST 8: pending cancellation. Create a separate pending order, then cancel it.
INSERT INTO CustomerOrder(customer_id,employee_id,status,total_amount)
VALUES(2,3,'PENDING',0);
SET @cancel_order_id=LAST_INSERT_ID();
CALL CancelOrder(@cancel_order_id);
SELECT order_id,status FROM CustomerOrder WHERE order_id=@cancel_order_id;

-- TEST 9: order total function
SELECT CalculateOrderTotal(1) AS calculated_total;

-- TEST 10: completed-sales reports exclude pending/cancelled
SELECT order_id,status,total_amount
FROM CustomerOrder
WHERE status IN ('PENDING','CANCELLED');

-- Procedure demonstrations
CALL LowStockReport();
CALL CustomerSalesReport(1);

-- Note: this script deliberately comments out destructive/expected-error tests
-- so that executing the full file does not stop at the first intentional failure.
