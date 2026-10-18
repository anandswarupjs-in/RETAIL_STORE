USE retail_store;
START TRANSACTION;

INSERT INTO Supplier(supplier_name,phone,email) VALUES
('Northstar Electronics','9876501001','northstar@example.com'),
('FreshMart Distributors','9876501002','freshmart@example.com'),
('OfficeHub Wholesale','9876501003','officehub@example.com'),
('HomeEase Supplies','9876501004','homeease@example.com'),
('StyleLine Trading','9876501005','styleline@example.com');

INSERT INTO Product(product_name,category,price,supplier_id) VALUES
('Wireless Mouse','Electronics',799.00,1),
('USB-C Cable','Electronics',299.00,1),
('Bluetooth Speaker','Electronics',1999.00,1),
('Notebook A5','Stationery',80.00,3),
('Ballpoint Pen Pack','Stationery',120.00,3),
('Desk Lamp','Home',899.00,4),
('Storage Box','Home',349.00,4),
('Coffee 250g','Grocery',250.00,2),
('Green Tea 100g','Grocery',180.00,2),
('Olive Oil 500ml','Grocery',650.00,2),
('Cotton T-Shirt','Clothing',599.00,5),
('Umbrella','Accessories',449.00,5),
('Keyboard','Electronics',1299.00,1),
('Water Bottle','Home',299.00,4),
('Gift Wrap Roll','Stationery',99.00,3);

INSERT INTO Inventory(product_id,stock_qty,reorder_level,expiry_date) VALUES
(1,40,10,NULL),(2,8,10,NULL),(3,0,5,NULL),(4,100,20,NULL),(5,60,15,NULL),
(6,12,5,NULL),(7,7,10,NULL),(8,35,10,'2027-06-30'),(9,6,10,'2027-03-31'),
(10,18,5,'2027-09-30'),(11,22,8,NULL),(12,4,5,NULL),(13,15,5,NULL),
(14,50,12,NULL),(15,3,10,NULL);

INSERT INTO Employee(employee_name,phone,email,salary,manager_id) VALUES
('Priya Menon','9000010001','priya@example.com',65000,NULL),
('Rahul Nair','9000010002','rahul@example.com',42000,1),
('Sneha Das','9000010003','sneha@example.com',39000,1),
('Arjun Rao','9000010004','arjun@example.com',35000,2),
('Meera Shah','9000010005','meera@example.com',33000,2),
('Kiran Paul','9000010006','kiran@example.com',31000,3);

INSERT INTO Customer(customer_name,phone,address) VALUES
('Asha Kumar','8000000001','Kochi, Kerala'),
('Rohan Das','8000000002','Kottayam, Kerala'),
('Nisha Thomas','8000000003','Kasaragod, Kerala'),
('Vivek Nair','8000000004','Thrissur, Kerala'),
('Diya Menon','8000000005','Kozhikode, Kerala'),
('Adil Rahman','8000000006','Kannur, Kerala'),
('Anu Joseph','8000000007','Alappuzha, Kerala'),
('Manu Krishnan','8000000008','Palakkad, Kerala'),
('Sara Ali','8000000009','Kollam, Kerala'),
('Dev Raj','8000000010','Thiruvananthapuram, Kerala');

-- Order dates are explicit to make the report demonstration repeatable.
INSERT INTO CustomerOrder(customer_id,employee_id,order_date,total_amount,status) VALUES
(1,2,'2026-01-05 10:00:00',0,'PENDING'),
(2,3,'2026-01-08 11:15:00',0,'PENDING'),
(1,4,'2026-02-02 12:00:00',0,'PENDING'),
(3,2,'2026-02-14 13:30:00',0,'PENDING'),
(4,5,'2026-03-10 15:00:00',0,'PENDING'),
(5,3,'2026-03-18 16:20:00',0,'PENDING'),
(6,6,'2026-04-01 09:45:00',0,'PENDING'),
(7,4,'2026-04-12 10:30:00',0,'PENDING'),
(8,5,'2026-05-07 14:00:00',0,'PENDING'),
(9,2,'2026-05-19 17:10:00',0,'PENDING'),
(10,3,'2026-06-03 11:00:00',0,'PENDING'),
(2,6,'2026-06-21 12:15:00',0,'PENDING');

-- Historical prices are captured here. Order totals/status are finalized below
-- after routines and triggers have been installed by 04_routines.sql.
INSERT INTO Sale_Item(order_id,product_id,quantity,unit_price) VALUES
(1,1,1,799.00),(1,2,2,299.00),
(2,4,5,80.00),(2,5,2,120.00),
(3,3,1,1999.00),(3,6,1,899.00),
(4,8,3,250.00),(4,9,2,180.00),
(5,11,2,599.00),(5,12,1,449.00),
(6,13,1,1299.00),(6,14,2,299.00),
(7,10,1,650.00),(7,8,2,250.00),
(8,4,10,80.00),(8,15,3,99.00),
(9,1,2,799.00),(9,13,1,1299.00),
(10,6,1,899.00),(10,7,2,349.00);

COMMIT;
