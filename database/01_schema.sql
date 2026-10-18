-- Retail Store Management System - schema
-- Run in MySQL Workbench. This reset drops and recreates the project database.
-- WARNING: DROP DATABASE permanently deletes the existing retail_store database.
DROP DATABASE IF EXISTS retail_store;
CREATE DATABASE retail_store CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE retail_store;

CREATE TABLE Supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(100) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE Product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10,2) NOT NULL,
    supplier_id INT NOT NULL,
    CONSTRAINT chk_product_price CHECK (price >= 0),
    CONSTRAINT fk_product_supplier FOREIGN KEY (supplier_id)
        REFERENCES Supplier(supplier_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL UNIQUE,
    stock_qty INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 10,
    expiry_date DATE NULL,
    CONSTRAINT chk_inventory_stock CHECK (stock_qty >= 0),
    CONSTRAINT chk_inventory_reorder CHECK (reorder_level >= 0),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id)
        REFERENCES Product(product_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Employee (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(100) UNIQUE,
    salary DECIMAL(10,2) NOT NULL,
    manager_id INT NULL,
    CONSTRAINT chk_employee_salary CHECK (salary >= 0),
    CONSTRAINT fk_employee_manager FOREIGN KEY (manager_id)
        REFERENCES Employee(employee_id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE Customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    address VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE CustomerOrder (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    employee_id INT NOT NULL,
    order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status ENUM('PENDING','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    CONSTRAINT chk_order_total CHECK (total_amount >= 0),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_employee FOREIGN KEY (employee_id)
        REFERENCES Employee(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Sale_Item (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT chk_sale_item_quantity CHECK (quantity > 0),
    CONSTRAINT chk_sale_item_price CHECK (unit_price >= 0),
    CONSTRAINT fk_sale_item_order FOREIGN KEY (order_id)
        REFERENCES CustomerOrder(order_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sale_item_product FOREIGN KEY (product_id)
        REFERENCES Product(product_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;
