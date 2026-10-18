"""Flask web application for the Retail Store Management System."""
from pathlib import Path
from decimal import Decimal, InvalidOperation
import os

import pymysql
from flask import Flask, flash, redirect, render_template, request, url_for

from db import get_connection

BASE_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = BASE_DIR / "frontend"

app = Flask(
    __name__,
    template_folder=str(FRONTEND_DIR),
    static_folder=str(FRONTEND_DIR),
    static_url_path="/frontend",
)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "local-development-key-change-me")


def fetch_all(sql, params=()):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()
    finally:
        conn.close()


def fetch_one(sql, params=()):
    rows = fetch_all(sql, params)
    return rows[0] if rows else None


def execute(sql, params=()):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            result = cur.lastrowid
        conn.commit()
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def call_procedure(name, args):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc(name, args)
            result = cur.fetchall()
            # Consume any additional result sets to keep the connection clean.
            while cur.nextset():
                pass
        conn.commit()
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def safe_error(exc):
    """Keep UI errors useful without dumping stack traces or credentials."""
    message = str(exc)
    if isinstance(exc, pymysql.MySQLError):
        return f"Database operation failed: {message}"
    return message


@app.template_filter("inr")
def inr(value):
    try:
        return f"₹{Decimal(str(value or 0)):,.2f}"
    except (InvalidOperation, ValueError):
        return "₹0.00"


@app.route("/")
def dashboard():
    try:
        stats = {
            "products": fetch_one("SELECT COUNT(*) AS n FROM Product")["n"],
            "customers": fetch_one("SELECT COUNT(*) AS n FROM Customer")["n"],
            "employees": fetch_one("SELECT COUNT(*) AS n FROM Employee")["n"],
            "stock_units": fetch_one("SELECT COALESCE(SUM(stock_qty),0) AS n FROM Inventory")["n"],
            "revenue": fetch_one(
                "SELECT COALESCE(SUM(total_amount),0) AS n FROM CustomerOrder WHERE status='COMPLETED'"
            )["n"],
            "low_stock": fetch_one(
                "SELECT COUNT(*) AS n FROM Inventory WHERE stock_qty <= reorder_level"
            )["n"],
        }
        recent_orders = fetch_all("""
            SELECT o.order_id, o.order_date, o.status, o.total_amount,
                   c.customer_name, e.employee_name
            FROM CustomerOrder o
            JOIN Customer c ON c.customer_id=o.customer_id
            JOIN Employee e ON e.employee_id=o.employee_id
            ORDER BY o.order_date DESC, o.order_id DESC LIMIT 6
        """)
        low_stock = fetch_all("""
            SELECT p.product_id, p.product_name, i.stock_qty, i.reorder_level
            FROM Product p JOIN Inventory i ON i.product_id=p.product_id
            WHERE i.stock_qty <= i.reorder_level
            ORDER BY i.stock_qty ASC LIMIT 6
        """)
        return render_template("dashboard.html", stats=stats, recent_orders=recent_orders, low_stock=low_stock)
    except Exception as exc:
        flash("Could not load dashboard. Import the database SQL scripts and verify backend/db.py settings. " + safe_error(exc), "danger")
        return render_template("dashboard.html", stats=None, recent_orders=[], low_stock=[])


@app.route("/products", methods=["GET", "POST"])
def products():
    if request.method == "POST":
        action = request.form.get("action", "add")
        try:
            if action == "add":
                name = request.form.get("product_name", "").strip()
                category = request.form.get("category", "").strip()
                price = Decimal(request.form.get("price", "0"))
                supplier_id = int(request.form.get("supplier_id", "0"))
                stock = int(request.form.get("stock_qty", "0"))
                call_procedure("AddProduct", (name, category or None, price, supplier_id, stock))
                flash("Product and inventory record created.", "success")
            elif action == "update":
                pid = int(request.form["product_id"])
                name = request.form["product_name"].strip()
                category = request.form.get("category", "").strip()
                price = Decimal(request.form["price"])
                if price < 0 or not name:
                    raise ValueError("Product name is required and price cannot be negative.")
                execute("UPDATE Product SET product_name=%s, category=%s, price=%s WHERE product_id=%s",
                        (name, category or None, price, pid))
                flash("Product updated.", "success")
            elif action == "delete":
                pid = int(request.form["product_id"])
                execute("DELETE FROM Product WHERE product_id=%s", (pid,))
                flash("Product deleted.", "success")
        except Exception as exc:
            flash(safe_error(exc), "danger")
        return redirect(url_for("products"))
    try:
        rows = fetch_all("""
            SELECT p.product_id,p.product_name,p.category,p.price,p.supplier_id,
                   s.supplier_name,i.stock_qty,i.reorder_level,i.expiry_date
            FROM Product p JOIN Supplier s ON s.supplier_id=p.supplier_id
            LEFT JOIN Inventory i ON i.product_id=p.product_id
            ORDER BY p.product_id
        """)
        suppliers = fetch_all("SELECT supplier_id,supplier_name FROM Supplier ORDER BY supplier_name")
    except Exception as exc:
        rows, suppliers = [], []
        flash("Could not load products. " + safe_error(exc), "danger")
    return render_template("products.html", products=rows, suppliers=suppliers)


@app.route("/inventory", methods=["GET", "POST"])
def inventory():
    if request.method == "POST":
        try:
            pid = int(request.form["product_id"])
            qty = int(request.form["stock_qty"])
            reorder = int(request.form["reorder_level"])
            expiry = request.form.get("expiry_date") or None
            execute("UPDATE Inventory SET stock_qty=%s,reorder_level=%s,expiry_date=%s WHERE product_id=%s",
                    (qty, reorder, expiry, pid))
            flash("Inventory updated.", "success")
        except Exception as exc:
            flash(safe_error(exc), "danger")
        return redirect(url_for("inventory"))
    try:
        rows = fetch_all("""
            SELECT i.inventory_id,i.product_id,p.product_name,i.stock_qty,i.reorder_level,i.expiry_date,
                   CASE WHEN i.stock_qty=0 THEN 'OUT OF STOCK'
                        WHEN i.stock_qty<=i.reorder_level THEN 'LOW STOCK' ELSE 'IN STOCK' END AS stock_status
            FROM Inventory i JOIN Product p ON p.product_id=i.product_id
            ORDER BY i.stock_qty ASC,p.product_name
        """)
    except Exception as exc:
        rows = []
        flash(safe_error(exc), "danger")
    return render_template("inventory.html", inventory=rows)


@app.route("/customers", methods=["GET", "POST"])
def customers():
    if request.method == "POST":
        try:
            action = request.form.get("action", "add")
            if action == "add":
                execute("INSERT INTO Customer(customer_name,phone,address) VALUES(%s,%s,%s)",
                        (request.form["customer_name"].strip(), request.form.get("phone") or None,
                         request.form.get("address") or None))
                flash("Customer added.", "success")
            elif action == "update":
                execute("UPDATE Customer SET customer_name=%s,phone=%s,address=%s WHERE customer_id=%s",
                        (request.form["customer_name"].strip(), request.form.get("phone") or None,
                         request.form.get("address") or None, int(request.form["customer_id"])))
                flash("Customer updated.", "success")
        except Exception as exc:
            flash(safe_error(exc), "danger")
        return redirect(url_for("customers"))
    try:
        rows = fetch_all("""
            SELECT c.*,COUNT(o.order_id) AS order_count
            FROM Customer c LEFT JOIN CustomerOrder o ON o.customer_id=c.customer_id
            GROUP BY c.customer_id ORDER BY c.customer_id
        """)
    except Exception as exc:
        rows = []
        flash(safe_error(exc), "danger")
    return render_template("customers.html", customers=rows)


@app.route("/suppliers", methods=["GET", "POST"])
def suppliers():
    if request.method == "POST":
        try:
            action = request.form.get("action", "add")
            if action == "add":
                execute("INSERT INTO Supplier(supplier_name,phone,email) VALUES(%s,%s,%s)",
                        (request.form["supplier_name"].strip(), request.form.get("phone") or None,
                         request.form.get("email") or None))
                flash("Supplier added.", "success")
            elif action == "update":
                execute("UPDATE Supplier SET supplier_name=%s,phone=%s,email=%s WHERE supplier_id=%s",
                        (request.form["supplier_name"].strip(), request.form.get("phone") or None,
                         request.form.get("email") or None, int(request.form["supplier_id"])))
                flash("Supplier updated.", "success")
        except Exception as exc:
            flash(safe_error(exc), "danger")
        return redirect(url_for("suppliers"))
    try:
        rows = fetch_all("""
            SELECT s.*,COUNT(p.product_id) AS product_count
            FROM Supplier s LEFT JOIN Product p ON p.supplier_id=s.supplier_id
            GROUP BY s.supplier_id ORDER BY s.supplier_id
        """)
    except Exception as exc:
        rows = []
        flash(safe_error(exc), "danger")
    return render_template("suppliers.html", suppliers=rows)


@app.route("/employees", methods=["GET", "POST"])
def employees():
    if request.method == "POST":
        try:
            action = request.form.get("action", "add")
            if action == "add":
                manager = request.form.get("manager_id") or None
                execute("""INSERT INTO Employee(employee_name,phone,email,salary,manager_id)
                           VALUES(%s,%s,%s,%s,%s)""",
                        (request.form["employee_name"].strip(), request.form.get("phone") or None,
                         request.form.get("email") or None, Decimal(request.form["salary"]),
                         int(manager) if manager else None))
                flash("Employee added.", "success")
            elif action == "update":
                manager = request.form.get("manager_id") or None
                execute("""UPDATE Employee SET employee_name=%s,phone=%s,email=%s,salary=%s,manager_id=%s
                           WHERE employee_id=%s""",
                        (request.form["employee_name"].strip(), request.form.get("phone") or None,
                         request.form.get("email") or None, Decimal(request.form["salary"]),
                         int(manager) if manager else None, int(request.form["employee_id"])))
                flash("Employee updated.", "success")
        except Exception as exc:
            flash(safe_error(exc), "danger")
        return redirect(url_for("employees"))
    try:
        rows = fetch_all("""
            SELECT e.employee_id,e.employee_name,e.phone,e.email,e.salary,e.manager_id,
                   m.employee_name AS manager_name
            FROM Employee e LEFT JOIN Employee m ON e.manager_id=m.employee_id
            ORDER BY e.employee_id
        """)
        managers = fetch_all("SELECT employee_id,employee_name FROM Employee ORDER BY employee_name")
    except Exception as exc:
        rows, managers = [], []
        flash(safe_error(exc), "danger")
    return render_template("employees.html", employees=rows, managers=managers)


@app.route("/sales", methods=["GET", "POST"])
def sales():
    if request.method == "POST":
        action = request.form.get("action")
        try:
            if action == "create":
                customer_id = int(request.form["customer_id"])
                employee_id = int(request.form["employee_id"])
                with __import__("contextlib").closing(get_connection()) as conn:
                    try:
                        with conn.cursor() as cur:
                            cur.execute("""INSERT INTO CustomerOrder(customer_id,employee_id,status,total_amount)
                                           VALUES(%s,%s,'PENDING',0)""", (customer_id, employee_id))
                            order_id = cur.lastrowid
                            product_ids = request.form.getlist("product_id")
                            quantities = request.form.getlist("quantity")
                            if not product_ids or len(product_ids) != len(quantities):
                                raise ValueError("Choose at least one product and quantity.")
                            for product_id, quantity in zip(product_ids, quantities):
                                pid, qty = int(product_id), int(quantity)
                                if qty <= 0:
                                    raise ValueError("Quantities must be greater than zero.")
                                cur.execute("SELECT price FROM Product WHERE product_id=%s", (pid,))
                                product = cur.fetchone()
                                if not product:
                                    raise ValueError(f"Product {pid} does not exist.")
                                cur.execute("""INSERT INTO Sale_Item(order_id,product_id,quantity,unit_price)
                                               VALUES(%s,%s,%s,%s)""",
                                            (order_id, pid, qty, product["price"]))
                            conn.commit()
                        flash(f"Pending order #{order_id} created. Complete it to deduct stock.", "success")
                    except Exception:
                        conn.rollback()
                        raise
            elif action == "complete":
                call_procedure("CompleteOrder", (int(request.form["order_id"]),))
                flash("Order completed and stock updated.", "success")
            elif action == "cancel":
                call_procedure("CancelOrder", (int(request.form["order_id"]),))
                flash("Order cancelled.", "success")
        except Exception as exc:
            flash(safe_error(exc), "danger")
        return redirect(url_for("sales"))
    try:
        orders = fetch_all("""
            SELECT o.order_id,o.order_date,o.status,o.total_amount,c.customer_name,e.employee_name,
                   COUNT(si.product_id) AS item_count
            FROM CustomerOrder o JOIN Customer c ON c.customer_id=o.customer_id
            JOIN Employee e ON e.employee_id=o.employee_id
            LEFT JOIN Sale_Item si ON si.order_id=o.order_id
            GROUP BY o.order_id ORDER BY o.order_id DESC
        """)
        customers = fetch_all("SELECT customer_id,customer_name FROM Customer ORDER BY customer_name")
        employees = fetch_all("SELECT employee_id,employee_name FROM Employee ORDER BY employee_name")
        products = fetch_all("SELECT product_id,product_name,price FROM Product ORDER BY product_name")
        items = fetch_all("""
            SELECT si.order_id,p.product_name,si.quantity,si.unit_price,
                   si.quantity*si.unit_price AS line_total
            FROM Sale_Item si JOIN Product p ON p.product_id=si.product_id
            ORDER BY si.order_id DESC,p.product_name
        """)
    except Exception as exc:
        orders, customers, employees, products, items = [], [], [], [], []
        flash(safe_error(exc), "danger")
    return render_template("sales.html", orders=orders, customers=customers, employees=employees,
                           products=products, items=items)


@app.route("/reports")
def reports():
    """
    Reports and analytics page.

    Fetches report data from MySQL and sends it to the
    frontend for rendering tables, bar charts, and pie charts.
    """

    try:
        # --------------------------------------------------
        # 1. MONTHLY REVENUE
        # --------------------------------------------------
        summary = fetch_all("""
            SELECT
                DATE_FORMAT(order_date, '%%Y-%%m') AS month,
                COUNT(*) AS completed_orders,
                COALESCE(SUM(total_amount), 0) AS revenue
            FROM CustomerOrder
            WHERE status = 'COMPLETED'
            GROUP BY DATE_FORMAT(order_date, '%%Y-%%m')
            ORDER BY month DESC
            LIMIT 12
        """)

        # Reverse the rows so the chart displays
        # months from oldest to newest.
        summary = list(reversed(summary))

        # --------------------------------------------------
        # 2. BEST-SELLING PRODUCTS
        # --------------------------------------------------
        best = fetch_all("""
            SELECT
                p.product_id,
                p.product_name,
                SUM(si.quantity) AS units_sold,
                COALESCE(
                    SUM(si.quantity * si.unit_price), 0
                ) AS sales_value
            FROM Sale_Item si
            JOIN Product p
                ON p.product_id = si.product_id
            JOIN CustomerOrder o
                ON o.order_id = si.order_id
            WHERE o.status = 'COMPLETED'
            GROUP BY
                p.product_id,
                p.product_name
            ORDER BY units_sold DESC
            LIMIT 10
        """)

        # --------------------------------------------------
        # 3. TOP CUSTOMERS
        # --------------------------------------------------
        top_customers = fetch_all("""
            SELECT
                c.customer_id,
                c.customer_name,
                COUNT(o.order_id) AS orders_count,
                COALESCE(SUM(o.total_amount), 0) AS spending
            FROM Customer c
            JOIN CustomerOrder o
                ON o.customer_id = c.customer_id
            WHERE o.status = 'COMPLETED'
            GROUP BY
                c.customer_id,
                c.customer_name
            ORDER BY spending DESC
            LIMIT 10
        """)

        # --------------------------------------------------
        # 4. SALES BY EMPLOYEE
        # --------------------------------------------------
        by_employee = fetch_all("""
            SELECT
                e.employee_id,
                e.employee_name,
                COUNT(o.order_id) AS orders_count,
                COALESCE(SUM(o.total_amount), 0) AS revenue
            FROM Employee e
            LEFT JOIN CustomerOrder o
                ON o.employee_id = e.employee_id
                AND o.status = 'COMPLETED'
            GROUP BY
                e.employee_id,
                e.employee_name
            ORDER BY revenue DESC
        """)

        # --------------------------------------------------
        # 5. LOW-STOCK REPORT
        # --------------------------------------------------
        low = fetch_all("""
            SELECT *
            FROM LowStockProducts
            ORDER BY stock_qty ASC
        """)

        # --------------------------------------------------
        # 6. PRODUCT SALES DISTRIBUTION
        # --------------------------------------------------
        product_distribution = fetch_all("""
            SELECT
                p.product_name,
                COALESCE(
                    SUM(si.quantity * si.unit_price), 0
                ) AS sales_value
            FROM Product p
            JOIN Sale_Item si
                ON si.product_id = p.product_id
            JOIN CustomerOrder o
                ON o.order_id = si.order_id
            WHERE o.status = 'COMPLETED'
            GROUP BY
                p.product_id,
                p.product_name
            HAVING SUM(si.quantity * si.unit_price) > 0
            ORDER BY sales_value DESC
        """)

        # --------------------------------------------------
        # 7. INVENTORY DISTRIBUTION
        # --------------------------------------------------
        inventory_distribution = fetch_all("""
            SELECT
                p.product_name,
                i.stock_qty
            FROM Product p
            JOIN Inventory i
                ON i.product_id = p.product_id
            WHERE i.stock_qty > 0
            ORDER BY i.stock_qty DESC
        """)

        # --------------------------------------------------
        # 8. PREPARE CHART DATA
        # --------------------------------------------------

        # Monthly revenue bar chart
        monthly_chart = {
            "labels": [
                str(row["month"])
                for row in summary
            ],
            "revenue": [
                float(row["revenue"] or 0)
                for row in summary
            ],
            "orders": [
                int(row["completed_orders"] or 0)
                for row in summary
            ]
        }

        # Best-selling products bar chart
        best_sellers_chart = {
            "labels": [
                row["product_name"]
                for row in best
            ],
            "units": [
                int(row["units_sold"] or 0)
                for row in best
            ]
        }

        # Top customers bar chart
        customer_chart = {
            "labels": [
                row["customer_name"]
                for row in top_customers
            ],
            "spending": [
                float(row["spending"] or 0)
                for row in top_customers
            ]
        }

        # Sales by employee bar chart
        employee_chart = {
            "labels": [
                row["employee_name"]
                for row in by_employee
            ],
            "revenue": [
                float(row["revenue"] or 0)
                for row in by_employee
            ]
        }

        # Product sales pie chart
        product_pie_chart = {
            "labels": [
                row["product_name"]
                for row in product_distribution
            ],
            "values": [
                float(row["sales_value"] or 0)
                for row in product_distribution
            ]
        }

        # Current inventory pie chart
        inventory_pie_chart = {
            "labels": [
                row["product_name"]
                for row in inventory_distribution
            ],
            "values": [
                int(row["stock_qty"] or 0)
                for row in inventory_distribution
            ]
        }

        # --------------------------------------------------
        # 9. SUMMARY CARDS
        # --------------------------------------------------

        total_revenue = sum(
            float(row["revenue"] or 0)
            for row in summary
        )

        total_completed_orders = sum(
            int(row["completed_orders"] or 0)
            for row in summary
        )

        total_units_sold = sum(
            int(row["units_sold"] or 0)
            for row in best
        )

        # Summary cards should describe the same 12-month
        # window represented by the monthly chart.
        report_stats = {
            "revenue": total_revenue,
            "orders": total_completed_orders,
            "units_sold": total_units_sold,
            "low_stock": len(low)
        }

    except Exception as exc:
        summary = []
        best = []
        top_customers = []
        by_employee = []
        low = []

        monthly_chart = {
            "labels": [],
            "revenue": [],
            "orders": []
        }

        best_sellers_chart = {
            "labels": [],
            "units": []
        }

        customer_chart = {
            "labels": [],
            "spending": []
        }

        employee_chart = {
            "labels": [],
            "revenue": []
        }

        product_pie_chart = {
            "labels": [],
            "values": []
        }

        inventory_pie_chart = {
            "labels": [],
            "values": []
        }

        report_stats = {
            "revenue": 0,
            "orders": 0,
            "units_sold": 0,
            "low_stock": 0
        }

        flash(
            "Could not load reports. Verify that the database "
            "SQL scripts have been installed. "
            + safe_error(exc),
            "danger"
        )

    return render_template(
        "reports.html",
        summary=summary,
        best=best,
        top_customers=top_customers,
        by_employee=by_employee,
        low=low,
        monthly_chart=monthly_chart,
        best_sellers_chart=best_sellers_chart,
        customer_chart=customer_chart,
        employee_chart=employee_chart,
        product_pie_chart=product_pie_chart,
        inventory_pie_chart=inventory_pie_chart,
        report_stats=report_stats
    )

@app.route("/health")
def health():
    try:
        result = fetch_one("SELECT DATABASE() AS database_name, VERSION() AS mysql_version")
        return {"status": "ok", **result}
    except Exception as exc:
        return {"status": "error", "message": safe_error(exc)}, 500


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.getenv("PORT", "5000")), debug=True)
