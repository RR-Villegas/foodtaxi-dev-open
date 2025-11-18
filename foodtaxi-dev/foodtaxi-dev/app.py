from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify, json
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from cryptography.fernet import Fernet
from datetime import datetime, timedelta
import random
from collections import defaultdict
import base64
import mysql.connector
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import secrets
import os
import time
import re


app = Flask(__name__)
app.secret_key = 'your_secret_key_here'

# Upload folder for product images
UPLOAD_FOLDER = os.path.join(app.root_path, "static", "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)  # ensure folder exists
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Placeholder image folder (static, only for display)
PLACEHOLDER_IMAGE = "/static/images/placeholder.png"


# Email configuration
SENDER_EMAIL = "your_email@gmail.com"
SENDER_PASSWORD = "mdrd raly rsgq orsk"

@app.context_processor
def inject_user_type():
    if 'account_id' in session:
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT user_type FROM accounts WHERE account_id = %s", (session['account_id'],))
        user = cursor.fetchone()
        cursor.close()
        db.close()
        return {'user_type': user['user_type'] if user else 'buyer'}
    return {'user_type': None}

# Configure upload folder
UPLOAD_FOLDER = 'foodtaxi-dev/static/uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

# Encryption key for profile images
ENCRYPTION_KEY = Fernet.generate_key()
cipher = Fernet(ENCRYPTION_KEY)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# ===============================
# DATABASE CONNECTION
# ===============================

def get_db_connection():
    return mysql.connector.connect(

    host="localhost",
    user="root",             # your MySQL username
    password="",             # your MySQL password
    database="foodweb_db"
)

# ===============================
# AUTH DECORATORS
# ===============================
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('account_id'):
            flash("Please log in to continue.", "warning")
            return redirect(url_for('login', next=request.endpoint))
        return f(*args, **kwargs)
    return decorated_function


def guest_only(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if request.endpoint == 'login' and request.method == 'POST':
            return f(*args, **kwargs)
        if 'account_id' in session:
            flash("You're already logged in!", "info")
            return redirect(url_for('homepage'))
        return f(*args, **kwargs)
    return decorated_function


# ✅ Admin-only decorator
def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        account_id = session.get('account_id')
        if not account_id:
            flash("Please log in to continue.", "warning")
            return redirect(url_for('login'))

        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT user_type FROM accounts WHERE account_id = %s", (account_id,))
        user = cursor.fetchone()
        cursor.close()
        db.close()

        if not user or user['user_type'] != 'admin':
            flash("Access denied: Admins only.", "danger")
            return redirect(url_for('homepage'))

        return f(*args, **kwargs)
    return decorated_function


# ✅ Admin Dashboard route
@app.route('/admin/dashboard')
@admin_required
def admin_dashboard():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("SELECT COUNT(*) AS total_users FROM accounts")
    total_users = cursor.fetchone()['total_users']

    cursor.execute("SELECT COUNT(*) AS total_sellers FROM accounts WHERE user_type = 'seller'")
    total_sellers = cursor.fetchone()['total_sellers']

    cursor.execute("SELECT COUNT(*) AS total_products FROM products")
    total_products = cursor.fetchone()['total_products']

    cursor.execute("SELECT COUNT(*) AS total_orders FROM orders")
    total_orders = cursor.fetchone()['total_orders']

    cursor.close()
    db.close()

    return render_template(
        'admin_dashboard.html',
        total_users=total_users,
        total_sellers=total_sellers,
        total_products=total_products,
        total_orders=total_orders
    )




# ===============================
# ROUTES
# ===============================
@app.route('/')
def index():
    """Main entry point — show products for guests."""
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Fetch all products for recommended
    cursor.execute("SELECT * FROM products ORDER BY product_id DESC")
    recommended = cursor.fetchall()

    # Fetch only 10 newest products for New Arrivals
    cursor.execute("SELECT * FROM products ORDER BY created_at DESC LIMIT 10")
    new_arrivals = cursor.fetchall()

    cursor.close()
    db.close()

    # Redirect logged-in users to homepage
    if 'account_id' in session:
        return redirect(url_for('homepage'))

    return render_template(
        "index.html",
        products=new_arrivals,  # matches your template's "products[:10]"
        recommended=recommended
    )



@app.route("/homepage")
@login_required
def homepage():
    # Check user type from session
    user_type = session.get('user_type')

    if user_type == "buyer":
        # Buyer sees the homepage
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)

        # New Arrivals (scrollable, max 10)
        cursor.execute("SELECT * FROM products ORDER BY product_id DESC LIMIT 10")
        products = cursor.fetchall()

        # Recommended (everything, no limit)
        cursor.execute("SELECT * FROM products ORDER BY product_id DESC")
        recommended = cursor.fetchall()

        cursor.close()
        db.close()

        return render_template("homepage.html", products=products, recommended=recommended)

    elif user_type == "seller":
        # Seller sees their dashboard
        return redirect(url_for('seller_dashboard'))

    elif user_type == "admin":
        # Admin sees admin dashboard
        return redirect(url_for('admin_dashboard'))

    else:
        # Unknown type: force logout or redirect to index
        flash("Unauthorized access.", "danger")
        return redirect(url_for('index'))





@app.route('/reload')
def reload():
    """Reloads the appropriate page depending on login state."""
    if 'account_id' in session:
        return redirect(url_for('homepage'))
    else:
        return redirect(url_for('index'))


# ===============================
# LOGIN (PATCHED)
# ===============================
@app.route('/login', methods=['GET', 'POST'])
@guest_only
def login():
    if request.method == 'POST':
        email = request.form['email'].strip()
        password = request.form['password'].strip()

        try:
            db = get_db_connection()
            cursor = db.cursor(dictionary=True, buffered=True)
            cursor.execute("SELECT * FROM accounts WHERE email = %s", (email,))
            user = cursor.fetchone()

            if user and check_password_hash(user['account_password'], password):
                # ✅ Store as account_id (consistent with DB)
                session['account_id'] = user['account_id']
                session['first_name'] = user['first_name']
                session['last_name'] = user['last_name']
                session['email'] = user['email']
                session['user_type'] = user['user_type']
                session['profile_image'] = user['profile_image'] if user['profile_image'] else None

                print("✅ DEBUG: account_id stored in session =", session.get("account_id"))

                flash(f"Welcome back, {user['first_name']}!", "success")

                # Redirect by role
                if user['user_type'] == 'admin':
                    return redirect(url_for('admin_dashboard'))
                    
                elif user['user_type'] == 'seller':
                    flash(f"Welcome back, {user['first_name']}!", "success")
                    return redirect(url_for('seller_dashboard'))
                else:
                    return redirect(url_for('homepage'))

            flash("Invalid email or password. Please try again.", "error")
            return redirect(url_for('login'))

        except mysql.connector.Error as err:
            print("Database error:", err)
            flash("An internal error occurred. Please try again later.", "error")
            return redirect(url_for('login'))

        finally:
            cursor.close()
            db.close()

    return render_template('login.html')




# ==============================================================
# SIGNUP
# ==============================================================
@app.route('/signup', methods=['GET', 'POST'])
def signup():
    if request.method == 'POST':
        # 🧾 Get and sanitize form fields
        form = request.form
        first_name = form.get('first_name', '').strip()
        last_name = form.get('last_name', '').strip()
        email = form.get('email', '').strip()
        password = form.get('password', '')
        confirm_password = form.get('confirm_password', '')
        user_type = form.get('user_type', '')
        region = form.get('region_text', '')
        province = form.get('province_text', '')
        city = form.get('city_text', '')
        barangay = form.get('barangay_text', '')

        # 🔒 Basic validation
        if password != confirm_password:
            flash("Passwords do not match.", "error")
            return redirect(url_for('signup'))

        # ✅ Password strength check
        if len(password) < 8 \
           or not re.search(r"[A-Z]", password) \
           or not re.search(r"[0-9]", password) \
           or not re.search(r"[\W]", password):
            flash("Password too weak. Minimum 8 characters, include uppercase, number, and symbol.", "error")
            return redirect(url_for('signup'))

        hashed_password = generate_password_hash(password)

        try:
            db = get_db_connection()
            cursor = db.cursor()

            # Check if email exists
            cursor.execute("SELECT email FROM accounts WHERE email = %s", (email,))
            if cursor.fetchone():
                flash("Email already registered.", "warning")
                return redirect(url_for('login'))

            # Insert new account
            cursor.execute("""
                INSERT INTO accounts 
                (first_name, last_name, email, account_password, user_type, region, province, city, barangay)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (first_name, last_name, email, hashed_password, user_type,
                  region, province, city, barangay))
            db.commit()

            flash("Account created successfully! Please verify your email if required.", "success")
            return redirect(url_for('login'))

        except Exception as err:
            print("Database error:", err)
            flash("Error creating account. Please try again.", "error")

        finally:
            if 'cursor' in locals() and cursor:
                cursor.close()
            if 'db' in locals() and db:
                db.close()

    # 👇 Render signup page if GET or failed POST
    return render_template('signup.html')





# ===============================
# ✅ ADMIN DASHBOARD
# ===============================
@app.route('/admin')
@login_required
@admin_required
def admin():
    """Admin-only dashboard page."""
    try:
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT account_id, first_name, last_name, email, user_type, date_registered FROM accounts")
        users = cursor.fetchall()
    except mysql.connector.Error as err:
        print("Database error:", err)
        users = []
    finally:
        cursor.close()

    return render_template('admin.html', users=users)




# ===============================
# CART SYSTEM (Database-Connected)
# ===============================
@app.route("/add_to_cart", methods=["POST"])
@login_required
def add_to_cart():
    account_id = session.get("account_id")
    product_id = int(request.form["product_id"])
    quantity = int(request.form["quantity"])

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Fetch product info
    cursor.execute("SELECT * FROM products WHERE product_id = %s", (product_id,))
    product = cursor.fetchone()

    if not product:
        cursor.close()
        db.close()
        return "Product not found", 404

    # Check stock
    if quantity > product["stock_quantity"]:
       flash(
        "Not enough stock available",  # This is the message that will show in the notification
        "error"                        # The type used for your notification styling
       )
       cursor.close()
       db.close()
       return redirect(request.referrer or url_for("homepage"))

    # Find or create pending order
    cursor.execute("""
        SELECT * FROM orders
        WHERE account_id = %s AND order_status = 'pending'
        LIMIT 1
    """, (account_id,))
    order = cursor.fetchone()

    if not order:
        # Create a new pending order
        cursor.execute("""
            INSERT INTO orders (account_id, order_status, total_price)
            VALUES (%s, 'pending', 0)
        """, (account_id,))
        db.commit()
        order_id = cursor.lastrowid
    else:
        order_id = order["order_id"]

    # Check if product already in cart (order_items with this order_id)
    cursor.execute("""
        SELECT * FROM order_items
        WHERE order_id = %s AND product_id = %s
    """, (order_id, product_id))
    existing_item = cursor.fetchone()

    if existing_item:
        # Update quantity and subtotal
        new_qty = existing_item["quantity"] + quantity
        cursor.execute("""
            UPDATE order_items
            SET quantity = %s, price_each = %s, subtotal = %s
            WHERE item_id = %s
        """, (new_qty, product["price"], new_qty * product["price"], existing_item["item_id"]))
    else:
        # Add new item to cart
        cursor.execute("""
            INSERT INTO order_items (order_id, product_id, quantity, price_each, subtotal)
            VALUES (%s, %s, %s, %s, %s)
        """, (order_id, product_id, quantity, product["price"], quantity * product["price"]))

    db.commit()
    cursor.close()
    db.close()

    flash("Item added to cart!", "success")
    return redirect(request.referrer or url_for("homepage"))


# ===============================
# VIEW CART (Database-Based)
# ===============================
@app.route("/cart")
@login_required
def cart():
    account_id = session.get("account_id")

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Get pending order items
    cursor.execute("""
        SELECT o.order_id, oi.*, p.product_name, p.image
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE o.account_id = %s AND o.order_status = 'pending'
    """, (account_id,))
    items = cursor.fetchall()

    total = sum(item["subtotal"] for item in items) if items else 0

    cursor.close()
    db.close()

    return render_template("cart.html", cart=items, total=total)






# ===============================
# UPDATE CART QUANTITY (Refined)
# ===============================
@app.route("/update_cart", methods=["POST"])
@login_required
def update_cart():
    account_id = session.get("account_id")
    product_id = int(request.form["product_id"])
    action = request.form.get("action")  # 'increase', 'decrease', 'remove'

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # 1️⃣ Find the user's pending order
    cursor.execute("""
        SELECT order_id FROM orders
        WHERE account_id = %s AND order_status = 'pending'
    """, (account_id,))
    order = cursor.fetchone()
    if not order:
        flash("No pending order found.", "error")
        cursor.close()
        db.close()
        return redirect(url_for("cart"))

    order_id = order["order_id"]

    # 2️⃣ Get item details and stock
    cursor.execute("""
        SELECT oi.quantity, oi.price_each, p.stock_quantity
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        WHERE oi.order_id = %s AND oi.product_id = %s
    """, (order_id, product_id))
    item = cursor.fetchone()

    if not item:
        flash("Item not found in your cart.", "error")
        cursor.close()
        db.close()
        return redirect(url_for("cart"))

    new_quantity = item["quantity"]

    # 3️⃣ Determine the new quantity based on action
    if action == "increase":
        if new_quantity < item["stock_quantity"]:
            new_quantity += 1
        else:
            flash("Cannot add more. Stock limit reached.", "warning")
    elif action == "decrease":
        new_quantity -= 1
    elif action == "remove":
        new_quantity = 0

    # 4️⃣ Apply the update
    if new_quantity <= 0:
        cursor.execute("""
            DELETE FROM order_items
            WHERE order_id = %s AND product_id = %s
        """, (order_id, product_id))
        flash("Item removed from cart.", "info")
    else:
        cursor.execute("""
            UPDATE order_items
            SET quantity = %s, subtotal = %s * %s
            WHERE order_id = %s AND product_id = %s
        """, (new_quantity, new_quantity, item["price_each"], order_id, product_id))

    # 5️⃣ Update the order total
    cursor.execute("""
        UPDATE orders
        SET total_price = (
            SELECT IFNULL(SUM(subtotal), 0)
            FROM order_items WHERE order_id = %s
        )
        WHERE order_id = %s
    """, (order_id, order_id))

    db.commit()
    cursor.close()
    db.close()

    return redirect(url_for("cart"))

@app.route("/checkout", methods=["POST"])
@login_required
def checkout():
    account_id = session.get("account_id")
    if not account_id:
        flash("You must be logged in to checkout.", "warning")
        return redirect(url_for("cart"))

    # 1) Get selected items
    selected_ids = request.form.getlist("item_ids")
    if not selected_ids:
        raw = request.form.get("selected_items")
        if raw:
            try:
                selected_ids = json.loads(raw)
            except Exception:
                selected_ids = []
    if not selected_ids:
        flash("Please select at least one product to checkout.", "warning")
        return redirect(url_for("cart"))

    # 2) Delivery info
    latitude = request.form.get("latitude")
    longitude = request.form.get("longitude")
    delivery_address = request.form.get("delivery_address") or request.form.get("address") or ""

    # 3) Payment method
    payment_method = request.form.get("payment_method") or "cod"

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # 4) Fetch pending order
        cursor.execute("""
            SELECT * FROM orders
            WHERE account_id = %s AND order_status = 'pending'
            LIMIT 1
        """, (account_id,))
        pending = cursor.fetchone()
        if not pending:
            flash("No pending cart found.", "warning")
            return redirect(url_for("cart"))
        pending_order_id = pending["order_id"]

        # 5) Fetch selected items
        q_placeholders = ",".join(["%s"] * len(selected_ids))
        params = [*selected_ids, pending_order_id]
        cursor.execute(f"""
            SELECT oi.item_id, oi.order_id, oi.product_id, oi.quantity, oi.price_each, oi.subtotal,
                   p.product_name, p.seller_id, p.stock_quantity
            FROM order_items oi
            JOIN products p ON oi.product_id = p.product_id
            WHERE oi.item_id IN ({q_placeholders}) AND oi.order_id = %s
        """, params)
        selected_rows = cursor.fetchall()
        if not selected_rows:
            flash("Selected items were not found in your cart.", "danger")
            return redirect(url_for("cart"))

        # 6) Validate stock
        for r in selected_rows:
            if r["quantity"] > (r["stock_quantity"] or 0):
                flash(f"Not enough stock for '{r['product_name']}'.", "error")
                return redirect(url_for("cart"))

        # 7) Group by seller
        groups = defaultdict(list)
        for r in selected_rows:
            groups[r["seller_id"]].append(r)

        # 8) Process orders per seller
        for seller_id, items in groups.items():
            total_price = sum(float(it["price_each"]) * int(it["quantity"]) for it in items)
            delivery_fee = 0.00  # or compute dynamically

            # Determine payment_status and order_status
            if payment_method == "cod":
                payment_status = "unpaid"
                order_status = "processing"
            else:  # GCash, Credit Card, Bank
                payment_status = "pending"
                order_status = "pending_payment"

            # Insert order
            cursor.execute("""
                INSERT INTO orders (
                    account_id,
                    fulfillment_type,
                    payment_method,
                    payment_status,
                    order_status,
                    total_price,
                    delivery_fee,
                    address,
                    latitude,
                    longitude,
                    order_date
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
            """, (
                account_id,
                "standard",
                payment_method,
                payment_status,
                order_status,
                total_price,
                delivery_fee,
                delivery_address,
                latitude,
                longitude
            ))
            new_order_id = cursor.lastrowid

            # Insert order items & deduct stock
            for it in items:
                subtotal = float(it["price_each"]) * int(it["quantity"])
                cursor.execute("""
                    INSERT INTO order_items (order_id, product_id, quantity, price_each, subtotal)
                    VALUES (%s, %s, %s, %s, %s)
                """, (new_order_id, it["product_id"], it["quantity"], it["price_each"], subtotal))

                cursor.execute("""
                    UPDATE products
                    SET stock_quantity = stock_quantity - %s
                    WHERE product_id = %s
                """, (it["quantity"], it["product_id"]))

                # Notify seller
                message = f"New order #{new_order_id} includes your product '{it['product_name']}'"
                link = "/seller/orders"
                cursor.execute("""
                    INSERT INTO notifications (account_id, message, link, order_id, type)
                    VALUES (%s, %s, %s, %s, %s)
                """, (seller_id, message, link, new_order_id, "order_pending"))

            # Create initial delivery
            cursor.execute("""
                INSERT INTO deliveries (order_id, delivery_status, dest_lat, dest_lng, delivery_address)
                VALUES (%s, %s, %s, %s, %s)
            """, (new_order_id, "pending", latitude, longitude, delivery_address))

            # Insert into payments table (optional, academic)
            cursor.execute("""
                INSERT INTO payments (order_id, account_id, payment_method, payment_status, amount)
                VALUES (%s, %s, %s, %s, %s)
            """, (new_order_id, account_id, payment_method, payment_status, total_price))

        # 9) Remove processed items from original pending order
        cursor.execute(f"DELETE FROM order_items WHERE item_id IN ({q_placeholders}) AND order_id = %s", params)

        # 10) Delete original pending order if empty
        cursor.execute("SELECT COUNT(*) AS cnt FROM order_items WHERE order_id = %s", (pending_order_id,))
        remaining = cursor.fetchone()
        if remaining and remaining.get("cnt", 0) == 0:
            cursor.execute("DELETE FROM orders WHERE order_id = %s", (pending_order_id,))

        db.commit()
        flash("Checkout successful — selected items have been submitted as orders.", "success")

        # 11) Redirect to payment confirmation if not COD
        if payment_method == "cod":
            return redirect(url_for("orders"))
        else:
            return redirect(url_for("payment_confirmation", order_id=new_order_id))

    except Exception as e:
        db.rollback()
        flash(f"An error occurred during checkout: {str(e)}", "error")
        return redirect(url_for("cart"))
    finally:
        cursor.close()
        db.close()
@app.route("/payment_confirmation/<int:order_id>", methods=["GET", "POST"])
@login_required
def payment_confirmation(order_id):
    account_id = session.get("account_id")
    if not account_id:
        flash("You must be logged in to continue.", "warning")
        return redirect(url_for("cart"))

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # Fetch the payment record for this order
        cursor.execute("""
            SELECT p.*, o.order_status, o.total_price
            FROM payments p
            JOIN orders o ON p.order_id = o.order_id
            WHERE p.order_id = %s AND p.account_id = %s
            LIMIT 1
        """, (order_id, account_id))
        payment = cursor.fetchone()
        if not payment:
            flash("Payment record not found.", "danger")
            return redirect(url_for("orders"))

        if request.method == "POST":
            # For academic/demo purposes, just mark as paid
            reference = request.form.get("reference_number") or "demo_ref"
            cursor.execute("""
                UPDATE payments
                SET payment_status = 'paid', reference_number = %s
                WHERE payment_id = %s
            """, (reference, payment["payment_id"]))

            # Update order status to processing
            cursor.execute("""
                UPDATE orders
                SET payment_status = 'paid', order_status = 'processing'
                WHERE order_id = %s
            """, (order_id,))
            db.commit()

            flash("Payment confirmed successfully.", "success")
            return redirect(url_for("orders"))

        return render_template("payment_confirmation.html", payment=payment)

    except Exception as e:
        db.rollback()
        flash(f"Error in payment confirmation: {str(e)}", "error")
        return redirect(url_for("orders"))

    finally:
        cursor.close()
        db.close()


@app.route("/location_picker")
@login_required
def location_picker():
    return render_template("location_picker.html")


# ===============================
# ORDERS PAGE
# ===============================
@app.route("/orders")
@login_required
def orders():
    return render_template("orders.html")


# ===============================
# ORDERS DATA (AJAX / JSON)
# ===============================
@app.route("/orders_data")
@login_required
def orders_data():
    account_id = session.get("account_id")
    if not account_id:
        return jsonify([])

    status = request.args.get("status")  # e.g., ?status=cancelled

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # ✅ Dynamic query depending on status, exclude 'pending' orders (cart)
    if status and status != "all":
        cursor.execute("""
            SELECT *
            FROM orders
            WHERE account_id = %s 
              AND LOWER(order_status) = %s
              AND order_status != 'pending'
            ORDER BY order_date DESC
        """, (account_id, status.lower()))
    else:
        cursor.execute("""
            SELECT *
            FROM orders
            WHERE account_id = %s 
              AND order_status != 'pending'
            ORDER BY 
                CASE WHEN LOWER(order_status) = 'cancelled' THEN 1 ELSE 0 END ASC,
                order_date DESC
        """, (account_id,))

    orders = cursor.fetchall()

    # Attach order items for each order
    for order in orders:
        cursor.execute("""
            SELECT 
                oi.*,
                p.product_name,
                p.maker,
                p.description,
                p.image
            FROM order_items oi
            JOIN products p ON oi.product_id = p.product_id
            WHERE oi.order_id = %s
        """, (order['order_id'],))
        order_items = cursor.fetchall()
        order['order_products'] = order_items if order_items else []

    # 🧹 Filter out empty orders (optional safety)
    orders = [o for o in orders if o.get('order_products')]

    cursor.close()
    db.close()

    return jsonify(orders)





@app.route('/seller/orders_data')
@login_required
def seller_orders_data():
    seller_id = session.get('seller_id')
    if not seller_id:
        return jsonify([])

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
       SELECT 
            o.order_id,
            a.first_name AS buyer_name,
            a.last_name AS buyer_lastname,
            o.order_status,
            o.approval_status,
            o.payment_method,
            o.total_price,
            o.order_date,
            COUNT(oi.item_id) AS total_items
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        JOIN accounts a ON o.account_id = a.account_id
        WHERE p.seller_id = %s
        GROUP BY 
            o.order_id, a.first_name, a.last_name, o.order_status, 
            o.approval_status, o.payment_method, o.total_price, o.order_date
        ORDER BY 
            CASE WHEN LOWER(o.order_status) = 'cancelled' THEN 1 ELSE 0 END ASC,
            o.order_date DESC;
    """, (seller_id,))

    orders = cursor.fetchall()
    cursor.close()
    db.close()

    return jsonify(orders)

@app.route("/seller/orders/<int:order_id>/approve", methods=["POST"])
@login_required
def approve_order(order_id):
    seller_id = session.get("seller_id")
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # ✅ Update order approval_status
    cursor.execute("""
        UPDATE orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        SET o.approval_status='approved', o.order_status='processing'
        WHERE o.order_id=%s AND p.seller_id=%s
    """, (order_id, seller_id))

    # ✅ Get buyer location info for the delivery
    cursor.execute("SELECT latitude, longitude, address FROM orders WHERE order_id=%s", (order_id,))
    order = cursor.fetchone()

    # ✅ Simulate warehouse/pickup location (for now, fixed)
    pickup_lat, pickup_lng = 14.6760, 121.0437  # Quezon City default

    # ✅ Assign a random available rider
    cursor.execute("SELECT rider_id FROM riders WHERE status='available' ORDER BY RAND() LIMIT 1")
    rider = cursor.fetchone()

    # ✅ Create a new delivery entry
    cursor.execute("""
        INSERT INTO deliveries (
            order_id, rider_id, delivery_status,
            rider_lat, rider_lng, dest_lat, dest_lng, delivery_address, assigned_at
        ) VALUES (%s, %s, 'assigned', %s, %s, %s, %s, %s, NOW())
    """, (
        order_id,
        rider["rider_id"] if rider else None,
        pickup_lat, pickup_lng,
        order["latitude"], order["longitude"],
        order["address"]
    ))

    # ✅ Mark rider as delivering (if one was assigned)
    if rider:
        cursor.execute("UPDATE riders SET status='delivering' WHERE rider_id=%s", (rider["rider_id"],))

    # ✅ Notify buyer
    cursor.execute("""
        INSERT INTO notifications (account_id, message, link)
        SELECT o.account_id, CONCAT('Your order #', o.order_id, ' has been approved and is now being prepared!'), '/buyer/orders'
        FROM orders o
        WHERE o.order_id=%s
    """, (order_id,))

    db.commit()
    cursor.close()
    db.close()

    return jsonify({"success": True, "message": "Order approved and delivery initialized"})


@app.route("/seller/orders/<int:order_id>/reject", methods=["POST"])
@login_required
def reject_order(order_id):
    seller_id = session.get("seller_id")
    db = get_db_connection()
    cursor = db.cursor()

    cursor.execute("""
        UPDATE orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        SET o.approval_status='rejected', o.order_status='cancelled'
        WHERE o.order_id=%s AND p.seller_id=%s
    """, (order_id, seller_id))

    # Notify buyer
    cursor.execute("""
        INSERT INTO notifications (account_id, message, link)
        SELECT o.account_id, CONCAT('Your order #', o.order_id, ' has been rejected.'), '/buyer/orders'
        FROM orders o
        WHERE o.order_id=%s
    """, (order_id,))

    db.commit()
    cursor.close()
    db.close()
    return jsonify({"success": True})






@app.route("/cancel_order/<int:order_id>", methods=["POST"])
@login_required
def cancel_order(order_id):
    account_id = session.get("account_id")
    if not account_id:
        flash("You must be logged in to cancel an order.", "error")
        return redirect(url_for("login"))

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # ✅ 1. Verify ownership and cancelable status
    cursor.execute("""
        SELECT * FROM orders
        WHERE order_id = %s 
          AND account_id = %s 
          AND LOWER(order_status) IN ('pending', 'processing')
    """, (order_id, account_id))
    order = cursor.fetchone()

    if not order:
        cursor.close()
        db.close()
        flash("This order cannot be canceled.", "error")
        return redirect(url_for("orders"))

    # ✅ 2. Restore stock quantities
    cursor.execute("""
        SELECT product_id, quantity 
        FROM order_items 
        WHERE order_id = %s
    """, (order_id,))
    items = cursor.fetchall()

    for item in items:
        cursor.execute("""
            UPDATE products
            SET stock_quantity = stock_quantity + %s
            WHERE product_id = %s
        """, (item["quantity"], item["product_id"]))

    # ✅ 3. Update order status
    cursor.execute("""
        UPDATE orders
        SET order_status = 'Cancelled',
            updated_at = NOW()
        WHERE order_id = %s
    """, (order_id,))

    db.commit()
    cursor.close()
    db.close()

    flash("Order canceled successfully and stock restored.", "success")
    return redirect(url_for("orders"))


@app.route("/buyer/product_reviews/<int:product_id>")
@login_required
def get_product_reviews(product_id):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    cursor.execute("""
        SELECT r.rating, r.comment, r.created_at, a.first_name, a.last_name
        FROM product_reviews r
        JOIN accounts a ON r.buyer_id = a.account_id
        WHERE r.product_id = %s
        ORDER BY r.created_at DESC
    """, (product_id,))
    reviews = cursor.fetchall()
    db.close()
    return jsonify({"reviews": reviews})


@app.route("/buyer/add_review", methods=["POST"])
@login_required
def add_product_review():
    data = request.get_json()
    buyer_id = session.get("account_id")
    product_id = data.get("product_id")
    rating = data.get("rating")
    comment = data.get("comment")

    if not (product_id and rating and comment):
        return jsonify({"error": "Missing fields"}), 400

    db = get_db_connection()
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO product_reviews (product_id, buyer_id, rating, comment)
        VALUES (%s, %s, %s, %s)
    """, (product_id, buyer_id, rating, comment))
    db.commit()
    db.close()

    return jsonify({"success": True})

@app.route("/notifications")
@login_required
def get_notifications():
    account_id = session.get("account_id")
    user_type = session.get("user_type")  # 'buyer' or 'seller'

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Base query: get latest 10 notifications
    cursor.execute("""
        SELECT notification_id, message, link, is_read,
               order_id, type
        FROM notifications
        WHERE account_id = %s
        ORDER BY created_at DESC
        LIMIT 10
    """, (account_id,))
    notifications = cursor.fetchall()

    # Add a "user_type" field for the frontend to detect seller notifications
    for n in notifications:
        n['user_type'] = user_type  # 'seller' or 'buyer'

    cursor.close()
    db.close()

    return jsonify({"notifications": notifications})







# ===============================
# LOGOUT
# ===============================
@app.route('/logout' , methods=['POST'])
@login_required
def logout():
    session.clear()
    flash("You’ve been logged out successfully.", "info")
    return redirect(url_for('login'))



@app.route('/profile')
@login_required
def profile():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM accounts WHERE account_id = %s", (session['account_id'],))
    user = cursor.fetchone()
    cursor.close()
    return render_template('profile.html', user=user)

@app.route('/settings', methods=['GET', 'POST'])
@login_required
def settings():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    if request.method == 'POST':
        data = (
            request.form.get('first_name'),
            request.form.get('last_name'),
            request.form.get('email'),
            request.form.get('mobile_number'),
            request.form.get('home_number'),
            request.form.get('street'),
            request.form.get('barangay'),
            request.form.get('municipality'),
            request.form.get('city'),
            request.form.get('province'),
            request.form.get('zip_code'),
            session['account_id']
        )

        update_query = """
            UPDATE accounts
            SET first_name=%s, last_name=%s, email=%s, mobile_number=%s, home_number=%s,
                street=%s, barangay=%s, municipality=%s, city=%s, province=%s, zip_code=%s
            WHERE account_id=%s
        """
        cursor.execute(update_query, data)
        db.commit()

        # refresh session info
        session['first_name'] = request.form.get('first_name')
        session['last_name'] = request.form.get('last_name')
        session['email'] = request.form.get('email')

        flash("Your account settings have been updated successfully!", "success")
        return redirect(url_for('profile'))

    cursor.execute("SELECT * FROM accounts WHERE account_id = %s", (session['account_id'],))
    user = cursor.fetchone()
    cursor.close()
    return render_template('settings.html', user=user)


@app.route('/become_rider')
@login_required
def become_rider():
    account_id = session.get('account_id')

    # Generate verification token
    verification_token = secrets.token_urlsafe(32)

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Update user to rider and set email_status to unverified, store token
    cursor.execute("""
        UPDATE accounts
        SET user_type = 'rider', email_status = 'unverified', verification_token = %s
        WHERE account_id = %s
    """, (verification_token, account_id))
    db.commit()

    # Get user email
    cursor.execute("SELECT email, first_name FROM accounts WHERE account_id = %s", (account_id,))
    user = cursor.fetchone()
    cursor.close()
    db.close()

    if user:
        # Send verification email
        send_verification_email(user['email'], user['first_name'], verification_token)

    # Update session
    session['user_type'] = 'rider'

    flash("A verification email has been sent to your email address. Please verify your email to become a rider.", "info")
    return redirect(url_for('profile'))

@app.route('/rider_dashboard')
@login_required
def rider_dashboard():
    account_id = session.get('account_id')

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Fetch user_type from database
    cursor.execute("SELECT user_type FROM accounts WHERE account_id = %s", (account_id,))
    user = cursor.fetchone()

    if not user or user['user_type'] != 'rider':
        cursor.close()
        db.close()
        flash("Access denied: Only riders can view this page.", "error")
        return redirect(url_for('profile'))

    # Fetch orders for delivery (assuming riders can see pending orders)
    cursor.execute("SELECT * FROM orders WHERE order_status = 'processing' ORDER BY order_date DESC LIMIT 10", ())
    orders = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template(
        'riderdashboard.html',
        user=session,
        orders=orders
    )

def send_verification_email(email, first_name, token):
    sender_email = SENDER_EMAIL
    sender_password = SENDER_PASSWORD
    receiver_email = email

    message = MIMEMultipart("alternative")
    message["Subject"] = "Verify Your Email to Become a Seller"
    message["From"] = sender_email
    message["To"] = receiver_email

    # Create the plain-text and HTML version of your message
    text = f"""\
    Hi {first_name},

    Thank you for applying to become a seller on our platform.

    Please verify your email by clicking the link below:
    http://localhost:5000/verify_email/{token}

    If you did not request this, please ignore this email.

    Best regards,
    FoodTaxi Team
    """

    html = f"""\
    <html>
    <body>
        <p>Hi {first_name},</p>
        <p>Thank you for applying to become a seller on our platform.</p>
        <p>Please verify your email by clicking the link below:</p>
        <p><a href="http://localhost:5000/verify_email/{token}">Verify Email</a></p>
        <p>If you did not request this, please ignore this email.</p>
        <p>Best regards,<br>FoodTaxi Team</p>
    </body>
    </html>
    """

    # Turn these into plain/html MIMEText objects
    part1 = MIMEText(text, "plain")
    part2 = MIMEText(html, "html")

    # Add HTML/plain-text parts to MIMEMultipart message
    message.attach(part1)
    message.attach(part2)

    try:
        server = smtplib.SMTP_SSL("smtp.gmail.com", 465)
        server.login(sender_email, sender_password)
        server.sendmail(sender_email, receiver_email, message.as_string())
        server.quit()
        print("Verification email sent successfully")
    except Exception as e:
        print(f"Error sending email: {e}")

@app.route('/verify_email/<token>')
def verify_email(token):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Find user with this token
    cursor.execute("SELECT account_id FROM accounts WHERE verification_token = %s", (token,))
    user = cursor.fetchone()

    if user:
        # Update email_status to verified and clear token
        cursor.execute("""
            UPDATE accounts
            SET email_status = 'verified', verification_token = NULL
            WHERE account_id = %s
        """, (user['account_id'],))
        db.commit()
        cursor.close()
        db.close()

        flash("Your email has been verified! You are now a seller.", "success")
        return redirect(url_for('seller_dashboard'))
    else:
        cursor.close()
        db.close()
        flash("Invalid verification token.", "error")
        return redirect(url_for('profile'))

@app.route('/resend_verification')
@login_required
def resend_verification():
    account_id = session.get('account_id')

    # Generate new verification token
    verification_token = secrets.token_urlsafe(32)

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Update verification token
    cursor.execute("""
        UPDATE accounts
        SET verification_token = %s
        WHERE account_id = %s
    """, (verification_token, account_id))
    db.commit()

    # Get user email and first name
    cursor.execute("SELECT email, first_name FROM accounts WHERE account_id = %s", (account_id,))
    user = cursor.fetchone()
    cursor.close()
    db.close()

    if user:
        # Send verification email
        send_verification_email(user['email'], user['first_name'], verification_token)
        flash("A new verification email has been sent to your email address.", "info")
    else:
        flash("An error occurred. Please try again.", "error")

    return redirect(url_for('settings'))


@app.route('/buyer/products_data')
def buyer_products_data():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT product_name, price, image FROM products")
    products = cursor.fetchall()
    db.close()

    for p in products:
        p['image_url'] = url_for('static', filename='uploads/' + p['image'])
    return jsonify(products)



@app.route('/seller_dashboard')
@login_required
def seller_dashboard():
    account_id = session.get('account_id')

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Fetch user_type from database
    cursor.execute("SELECT user_type FROM accounts WHERE account_id = %s", (account_id,))
    user = cursor.fetchone()

    if not user or user['user_type'] != 'seller':
        cursor.close()
        db.close()
        flash("Access denied: Only sellers can view this page.", "error")
        return redirect(url_for('index'))

    # ✅ Set the seller_id in session if not already set
    session["seller_id"] = account_id

    cursor.close()
    db.close()

    

    return render_template(
        'seller_dashboard.html',
        user=session, )




@app.route("/seller/add_product", methods=["POST"])
@login_required
def add_product():
    seller_id = session.get("seller_id")
    if not seller_id:
        return jsonify({"error": "Unauthorized"}), 403

    data = request.form
    image = request.files.get("image")
    image_filename = None

    if image and image.filename != "":
        # Secure the filename and add timestamp to prevent duplicates
        filename = f"{int(time.time())}_{secure_filename(image.filename)}"
        save_path = os.path.join(app.root_path, "static", "uploads", filename)
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        save_path = os.path.normpath(save_path)
        image.save(save_path)
        image_filename = filename


    db = get_db_connection()
    cursor = db.cursor()

    cursor.execute("""
        INSERT INTO products (
            seller_id, product_name, maker, description, price, image, category, stock_quantity
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        seller_id,
        data["product_name"],
        data.get("maker"),
        data.get("description"),
        float(data["price"]),
        image_filename,
        data["category"],
        int(data.get("stock_quantity", 0) or 0)
    ))

    db.commit()
    cursor.close()
    db.close()

    return jsonify({"message": "✅ Product added successfully!"})



@app.route('/seller/products_data')
@login_required
def products_data():
    seller_id = session.get('seller_id')
    if not seller_id:
        return jsonify({"error": "Unauthorized"}), 403

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
        SELECT product_id, product_name, maker, description, price, image,
               category, stock_quantity
        FROM products
        WHERE seller_id=%s
        ORDER BY created_at DESC
    """, (seller_id,))
    products = cursor.fetchall()

    cursor.close()
    db.close()

    # fallback to placeholder if no image
    for p in products:
        if not p["image"]:
            p["image"] = None  # let JS handle placeholder

    return jsonify(products)

   



@app.route("/seller/get_product/<int:product_id>")
@login_required
def get_product(product_id):
    seller_id = session.get("seller_id")
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    cursor.execute("""
        SELECT * FROM products
        WHERE product_id = %s AND seller_id = %s
    """, (product_id, seller_id))
    product = cursor.fetchone()
    cursor.close()
    db.close()
    if not product:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(product)


@app.route("/seller/edit_product/<int:product_id>", methods=["POST"])
@login_required
def edit_product(product_id):
    seller_id = session.get("seller_id")
    if not seller_id:
        return jsonify({"error": "Unauthorized"}), 403

    data = request.form
    image = request.files.get("image")

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # fetch existing product
    cursor.execute("SELECT image FROM products WHERE product_id=%s AND seller_id=%s",
                   (product_id, seller_id))
    product = cursor.fetchone()
    if not product:
        cursor.close()
        db.close()
        return jsonify({"error": "Product not found"}), 404

    # default to old image if no new uploaded
    image_filename = product["image"]

    if image and image.filename != "":
        # Secure the filename and add timestamp to prevent duplicates
        filename = f"{int(time.time())}_{secure_filename(image.filename)}"
        save_path = os.path.join(app.root_path, "static", "uploads", filename)
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        save_path = os.path.normpath(save_path)
        image.save(save_path)
        image_filename = filename



    try:
        price = float(data["price"])
    except:
        price = 0.0

    try:
        stock_quantity = int(data.get("stock_quantity", 0) or 0)
    except:
        stock_quantity = 0

    cursor.execute("""
        UPDATE products
        SET product_name=%s, maker=%s, description=%s, price=%s,
            category=%s, stock_quantity=%s, image=%s
        WHERE product_id=%s AND seller_id=%s
    """, (
        data["product_name"],
        data.get("maker"),
        data.get("description"),
        price,
        data["category"],
        stock_quantity,
        image_filename,
        product_id,
        seller_id
    ))

    db.commit()
    cursor.close()
    db.close()

    return jsonify({"message": "✅ Product updated successfully!"})






# Increase stock
@app.route('/seller/product/increase/<int:product_id>', methods=['POST'])
def increase_product(product_id):
    db = get_db_connection()
    cursor = db.cursor()
    cursor.execute("UPDATE products SET stock_quantity = stock_quantity + 1 WHERE product_id = %s", (product_id,))
    db.commit()
    cursor.close()
    return redirect(url_for('seller_products'))

# Decrease stock
@app.route('/seller/product/decrease/<int:product_id>', methods=['POST'])
def decrease_product(product_id):
    db = get_db_connection()
    cursor = db.cursor()
    # Prevent negative stock
    cursor.execute("UPDATE products SET stock_quantity = GREATEST(stock_quantity - 1, 0) WHERE product_id = %s", (product_id,))
    db.commit()
    cursor.close()
    return redirect(url_for('seller_products'))

# Remove product
@app.route('/seller/product/remove/<int:product_id>', methods=['POST'])
def remove_product(product_id):
    db = get_db_connection()
    cursor = db.cursor()
    cursor.execute("DELETE FROM products WHERE product_id = %s", (product_id,))
    db.commit()
    cursor.close()
    return redirect(url_for('seller_dashboard'))

@app.route("/api/delivery_info/<int:order_id>")
@login_required
def get_delivery_info(order_id):
    

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
        SELECT 
            o.order_status, o.approval_status,
            d.delivery_id, d.order_id, d.delivery_status,
            d.rider_lat, d.rider_lng,
            d.dest_lat, d.dest_lng,
            d.picked_up_at, d.delivered_at,
            r.first_name AS rider_first, r.last_name AS rider_last
        FROM orders o
        LEFT JOIN deliveries d ON o.order_id = d.order_id
        LEFT JOIN riders r ON d.rider_id = r.rider_id
        WHERE o.order_id = %s
        LIMIT 1
    """, (order_id,))
    delivery = cursor.fetchone()
    cursor.close()
    db.close()

    if not delivery or delivery["approval_status"] != "approved":
        return jsonify({"error": "Order not approved yet or no delivery info"}), 403

    # Convert DECIMAL to float
    delivery["dest_lat"] = float(delivery["dest_lat"]) if delivery.get("dest_lat") else 14.5995
    delivery["dest_lng"] = float(delivery["dest_lng"]) if delivery.get("dest_lng") else 120.9842
    delivery["rider_lat"] = float(delivery["rider_lat"]) if delivery.get("rider_lat") else 14.6760
    delivery["rider_lng"] = float(delivery["rider_lng"]) if delivery.get("rider_lng") else 121.0437

    # Simulate movement
    speed_kph = 60
    speed_mps = speed_kph * 1000 / 3600
    seconds_passed = 5

    def move_toward(lat1, lon1, lat2, lon2, fraction):
        return (
            lat1 + (lat2 - lat1) * fraction,
            lon1 + (lon2 - lon1) * fraction
        )

    fraction = min(seconds_passed * speed_mps / 1000 / 10, 1)
    new_lat, new_lng = move_toward(
        delivery["rider_lat"], delivery["rider_lng"],
        delivery["dest_lat"], delivery["dest_lng"],
        fraction
    )

    delivery["rider_lat"] = new_lat
    delivery["rider_lng"] = new_lng

    if not delivery.get("picked_up_at"):
        delivery["picked_up_at"] = (datetime.now() - timedelta(minutes=15)).strftime("%Y-%m-%d %H:%M:%S")

    if abs(delivery["rider_lat"] - delivery["dest_lat"]) < 0.0005 and abs(delivery["rider_lng"] - delivery["dest_lng"]) < 0.0005:
        delivery["delivery_status"] = "delivered"
        delivery["delivered_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    return jsonify({
        "rider_lat": delivery["rider_lat"],
        "rider_lng": delivery["rider_lng"],
        "dest_lat": delivery["dest_lat"],
        "dest_lng": delivery["dest_lng"],
        "delivery_status": delivery.get("delivery_status", "in_transit"),
        "rider_first": delivery.get("rider_first"),
        "rider_last": delivery.get("rider_last"),
        "picked_up_at": delivery["picked_up_at"],
        "delivered_at": delivery.get("delivered_at"),
    })



@app.route('/seller/income')
def seller_income():
    seller_id = session.get('account_id')
    if not seller_id:
        flash("Please log in to continue.", "warning")
        return redirect(url_for('login'))

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # ✅ Total income from all orders (processing + delivered)
    cursor.execute("""
        SELECT IFNULL(SUM(oi.subtotal), 0) AS total_income
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        JOIN orders o ON oi.order_id = o.order_id
        WHERE p.seller_id = %s
    """, (seller_id,))
    total_income = cursor.fetchone()['total_income'] or 0.0

    # ✅ Delivered income (completed orders)
    cursor.execute("""
        SELECT IFNULL(SUM(oi.subtotal), 0) AS delivered_income
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        JOIN orders o ON oi.order_id = o.order_id
        WHERE p.seller_id = %s AND o.order_status = 'delivered'
    """, (seller_id,))
    delivered_income = cursor.fetchone()['delivered_income'] or 0.0

    # ✅ Pending income (processing or not yet delivered)
    pending_income = total_income - delivered_income

    # ✅ Recent orders
    cursor.execute("""
        SELECT o.order_id, o.order_status, o.order_date, p.product_name,
               oi.quantity, oi.price_each, oi.subtotal
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        JOIN orders o ON oi.order_id = o.order_id
        WHERE p.seller_id = %s
        ORDER BY o.order_date DESC
        LIMIT 10
    """, (seller_id,))
    recent_orders = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template(
        'seller_income.html',
        total_income=total_income,
        delivered_income=delivered_income,
        pending_income=pending_income,
        recent_orders=recent_orders
    )



@app.route('/update_profile_picture', methods=['POST'])
@login_required
def update_profile_picture():
    if 'profile_image' not in request.files:
        flash('No file part', 'error')
        return redirect(request.url)
    file = request.files['profile_image']
    if file.filename == '':
        flash('No selected file', 'error')
        return redirect(request.url)
    if file and allowed_file(file.filename):
        # Scramble the filename and add custom extension
        scrambled_name = secrets.token_hex(16) + '.ixia'
        encrypted_data = cipher.encrypt(file.read())
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], scrambled_name)
        with open(file_path, 'wb') as f:
            f.write(encrypted_data)

        # Update database
        db = get_db_connection()
        cursor = db.cursor()
        cursor.execute("UPDATE accounts SET profile_image = %s WHERE account_id = %s", (scrambled_name, session['account_id']))
        db.commit()
        cursor.close()
        db.close()

        # Update session
        session['profile_image'] = scrambled_name

        flash('Profile picture updated successfully!', 'success')
        return redirect(url_for('profile'))
    else:
        flash('Invalid file type', 'error')
        return redirect(request.url)

@app.route('/get_encrypted_image/<filename>')
@login_required
def get_encrypted_image(filename):
    # Ensure the filename belongs to the current user for security
    if filename != session.get('profile_image'):
        return 'Access denied', 403

    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if os.path.exists(file_path):
        with open(file_path, 'rb') as f:
            encrypted_data = f.read()
        decrypted_data = cipher.decrypt(encrypted_data)
        return decrypted_data, 200, {'Content-Type': 'image/jpeg'}  # Adjust content type as needed
    else:
        return 'File not found', 404

# ===============================
# RUN APP
# ===============================
if __name__ == '__main__':
    app.run(debug=True)
