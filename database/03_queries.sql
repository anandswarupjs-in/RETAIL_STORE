USE retail_store;

-- 1. All suppliers
SELECT * FROM Supplier;

-- 2. All products
SELECT * FROM Product;

-- 3. All customers
SELECT * FROM Customer;

-- 4. All employees
SELECT * FROM Employee;

-- 5. Products and stock
SELECT p.product_id,p.product_name,i.stock_qty
FROM Product p JOIN Inventory i ON i.product_id=p.product_id;

-- 6. Products with supplier names (INNER JOIN)
SELECT p.product_name,p.category,p.price,s.supplier_name
FROM Product p JOIN Supplier s ON s.supplier_id=p.supplier_id;

-- 7. Products with inventory details
SELECT p.product_name,i.stock_qty,i.reorder_level,i.expiry_date
FROM Product p JOIN Inventory i ON i.product_id=p.product_id;

-- 8. Orders with customer and employee names
SELECT o.order_id,o.order_date,o.status,o.total_amount,c.customer_name,e.employee_name
FROM CustomerOrder o
JOIN Customer c ON c.customer_id=o.customer_id
JOIN Employee e ON e.employee_id=o.employee_id;

-- 9. Employee-manager self join (LEFT JOIN)
SELECT e.employee_name AS employee, m.employee_name AS manager
FROM Employee e LEFT JOIN Employee m ON e.manager_id=m.employee_id;

-- 10. Products in completed orders
SELECT o.order_id,p.product_name,si.quantity,si.unit_price
FROM CustomerOrder o
JOIN Sale_Item si ON si.order_id=o.order_id
JOIN Product p ON p.product_id=si.product_id
WHERE o.status='COMPLETED';

-- 11. Number of products
SELECT COUNT(*) AS product_count FROM Product;

-- 12. Total inventory units
SELECT COALESCE(SUM(stock_qty),0) AS inventory_units FROM Inventory;

-- 13. Estimated inventory value at current selling prices (not acquisition cost)
SELECT SUM(p.price*i.stock_qty) AS estimated_inventory_retail_value
FROM Product p JOIN Inventory i ON i.product_id=p.product_id;

-- 14. Completed sales revenue
SELECT COALESCE(SUM(total_amount),0) AS completed_revenue
FROM CustomerOrder WHERE status='COMPLETED';

-- 15. Completed spending by customer
SELECT c.customer_name,SUM(o.total_amount) AS spending
FROM Customer c JOIN CustomerOrder o ON o.customer_id=c.customer_id
WHERE o.status='COMPLETED'
GROUP BY c.customer_id,c.customer_name ORDER BY spending DESC;

-- 16. Units sold by product
SELECT p.product_name,SUM(si.quantity) AS units_sold
FROM Product p JOIN Sale_Item si ON si.product_id=p.product_id
JOIN CustomerOrder o ON o.order_id=si.order_id
WHERE o.status='COMPLETED'
GROUP BY p.product_id,p.product_name ORDER BY units_sold DESC;

-- 17. Monthly revenue
SELECT YEAR(order_date) AS sales_year,MONTH(order_date) AS sales_month,
       SUM(total_amount) AS revenue
FROM CustomerOrder WHERE status='COMPLETED'
GROUP BY YEAR(order_date),MONTH(order_date)
ORDER BY sales_year,sales_month;

-- 18. Revenue by employee
SELECT e.employee_name,COALESCE(SUM(o.total_amount),0) AS revenue
FROM Employee e LEFT JOIN CustomerOrder o
ON o.employee_id=e.employee_id AND o.status='COMPLETED'
GROUP BY e.employee_id,e.employee_name ORDER BY revenue DESC;

-- 19. Low stock
SELECT p.product_name,i.stock_qty,i.reorder_level
FROM Product p JOIN Inventory i ON i.product_id=p.product_id
WHERE i.stock_qty<=i.reorder_level;

-- 20. Products above a price threshold
SELECT * FROM Product WHERE price>500;

-- 21. Customers spending more than ₹5,000
SELECT c.customer_name,SUM(o.total_amount) AS spending
FROM Customer c JOIN CustomerOrder o ON o.customer_id=c.customer_id
WHERE o.status='COMPLETED'
GROUP BY c.customer_id,c.customer_name
HAVING SUM(o.total_amount)>5000;

-- 22. Employees earning above average salary
SELECT employee_name,salary FROM Employee
WHERE salary>(SELECT AVG(salary) FROM Employee);

-- 23. Products priced above average
SELECT product_name,price FROM Product
WHERE price>(SELECT AVG(price) FROM Product);

-- 24. Employees earning above average
SELECT employee_name,salary FROM Employee
WHERE salary>(SELECT AVG(salary) FROM Employee);

-- 25. Products never sold
SELECT p.product_id,p.product_name
FROM Product p
WHERE NOT EXISTS (SELECT 1 FROM Sale_Item si WHERE si.product_id=p.product_id);

-- 26. Customers with at least one completed order
SELECT DISTINCT c.customer_id,c.customer_name
FROM Customer c WHERE EXISTS (
    SELECT 1 FROM CustomerOrder o
    WHERE o.customer_id=c.customer_id AND o.status='COMPLETED'
);

-- 27. Five most expensive products
SELECT product_name,price FROM Product ORDER BY price DESC LIMIT 5;

-- 28. Five best-selling products
SELECT p.product_name,SUM(si.quantity) AS units_sold
FROM Product p JOIN Sale_Item si ON si.product_id=p.product_id
JOIN CustomerOrder o ON o.order_id=si.order_id
WHERE o.status='COMPLETED'
GROUP BY p.product_id,p.product_name ORDER BY units_sold DESC LIMIT 5;

-- 29. Five highest-spending customers
SELECT c.customer_name,SUM(o.total_amount) AS spending
FROM Customer c JOIN CustomerOrder o ON o.customer_id=c.customer_id
WHERE o.status='COMPLETED'
GROUP BY c.customer_id,c.customer_name ORDER BY spending DESC LIMIT 5;

-- 30. Revenue in a selected month
SELECT SUM(total_amount) AS monthly_revenue
FROM CustomerOrder
WHERE status='COMPLETED'
  AND order_date >= '2026-01-01' AND order_date < '2026-02-01';

-- 31. Products requiring restocking
SELECT * FROM LowStockProducts;

-- 32. Pending orders
SELECT * FROM CustomerOrder WHERE status='PENDING';

-- 33. Cancelled orders
SELECT * FROM CustomerOrder WHERE status='CANCELLED';

-- 34. Total value of completed orders
SELECT SUM(total_amount) AS total_completed_order_value
FROM CustomerOrder WHERE status='COMPLETED';

-- 35. Compare stored order totals with calculated line totals
SELECT o.order_id,o.total_amount AS stored_total,
       CalculateOrderTotal(o.order_id) AS calculated_total
FROM CustomerOrder o;
