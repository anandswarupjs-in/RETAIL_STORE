# Retail Store Management System

A beginner-friendly Flask + MySQL application for a retail store. The database is the source of truth for products, suppliers, stock, employees, customers, orders, and sales reporting.

## Folder structure

```text
retail-store/
├── frontend/                 # HTML templates, CSS, JavaScript (no nested folders)
├── backend/
│   ├── app.py                # Flask routes and application
│   ├── db.py                 # PyMySQL connection helper
│   └── requirements.txt
├── database/
│   ├── 01_schema.sql
│   ├── 02_sample_data.sql
│   ├── 03_queries.sql
│   ├── 04_routines.sql
│   ├── 05_views_indexes.sql
│   └── 06_test_cases.sql
└── README.md
```

## Database entities

- `Supplier`: supplier contacts.
- `Product`: catalog, price and supplier foreign key.
- `Inventory`: one stock record per product.
- `Employee`: staff and self-referencing manager relationship.
- `Customer`: customer contact details.
- `CustomerOrder`: order header, customer, employee, status and total.
- `Sale_Item`: order/product junction table with quantity and historical unit price.

`CustomerOrder` and `Sale_Item` extend the hand-drawn ER model into a standard order-header/order-line design. This makes multiple products per order, historical prices and order totals unambiguous.

## Database routines

- `AddProduct`: inserts Product and Inventory in one transaction.
- `CalculateOrderTotal(order_id)`: sums quantity × historical unit price.
- `trg_sale_item_check_stock`: validates that the order is pending and an inventory row exists. Actual stock availability is checked again at completion.
- Inventory triggers and CHECK constraints prevent negative stock.
- `CompleteOrder(order_id)`: locks the order, validates stock, updates inventory, calculates total and marks the order completed in one transaction.
- `CancelOrder(order_id)`: cancels only pending orders; completed orders cannot be reversed by this simple procedure.
- `LowStockReport()`: lists products at/below reorder level.
- `CustomerSalesReport(customer_id)`: shows completed orders and total spending.

**Stock policy:** stock is deducted only by `CompleteOrder`, not when a pending order's lines are entered. Do not add another stock-deduction trigger; doing so would double-deduct inventory. For production systems, use stronger locking and carefully test concurrent sales.

## Requirements

- Python 3.10+
- MySQL Server 8.x
- MySQL Workbench
- Internet connection for Bootstrap CDN (or replace with local Bootstrap files)

## 1. Create the database in MySQL Workbench

1. Start MySQL Server and open MySQL Workbench.
2. Connect to your local MySQL Server connection.
3. Open `database/01_schema.sql` and execute it.
4. Execute `database/02_sample_data.sql`.
5. Execute `database/04_routines.sql`.
6. Execute `database/05_views_indexes.sql`.
7. Execute `database/03_queries.sql` to demonstrate queries.
8. Execute `database/06_test_cases.sql` when ready to test.

The schema script drops and recreates `retail_store`. **It deletes an existing database with that name. Back up data before running it.**

Important sample-data note: sample rows are illustrative historical transactions. They are marked completed for reports, while the seeded inventory is intended as a convenient current-state snapshot. For a strict stock ledger demonstration, create new pending orders in the application and complete them using the procedure.

## 2. Configure Python

Open PowerShell in the `retail-store` project root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r .\backend\requirements.txt
```

If PowerShell blocks activation, either permit the script for the current process with `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, or use the virtual environment's Python directly.

## 3. Configure database credentials

The app reads these environment variables. Replace the example values with your own local MySQL settings.

```powershell
$env:DB_HOST = "127.0.0.1"
$env:DB_PORT = "3306"
$env:DB_USER = "root"
$env:DB_PASSWORD = "YOUR_MYSQL_PASSWORD"
$env:DB_NAME = "retail_store"
$env:FLASK_SECRET_KEY = "change-this-for-local-development"
```

Do not publish your real password or commit it to source control. An empty password may work only if your local MySQL account is configured that way.

## 4. Start the app

From the project root:

```powershell
python .\backend\app.py
```

Open `http://127.0.0.1:5000` in your browser. Test `http://127.0.0.1:5000/health` to check database connectivity and the selected database.

## SQL topics for evaluation

The SQL files demonstrate primary and foreign keys, UNIQUE and CHECK constraints, INNER JOIN, LEFT JOIN, self-join, aggregate functions, GROUP BY, HAVING, subqueries, EXISTS/NOT EXISTS, ORDER BY/LIMIT, stored procedures, a stored function, triggers, transactions, views, indexes, and negative test cases.

## Important limitations

- This is a local academic demonstration, not a production-ready public service.
- Login is a clearly labelled placeholder page; no fake authentication is claimed.
- There is no completed-order reversal in `CancelOrder`; it rejects cancellation of completed orders to prevent untracked stock changes.
- For production use, add authentication/authorization, CSRF protection, audit logs, a stock movement ledger, stronger concurrency testing, backups, and secure secret management.
- The SQL scripts target MySQL 8.x. If your server is older, some syntax or CHECK enforcement may differ.
