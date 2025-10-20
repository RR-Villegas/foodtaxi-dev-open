from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, flash, session
from werkzeug.security import generate_password_hash, check_password_hash
import mysql.connector

app = Flask(__name__)
app.secret_key = 'your_secret_key_here'

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


# ✅ NEW — admin-only decorator
def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_type' not in session or session['user_type'] != 'admin':
            flash("Access denied: Admins only.", "danger")
            return redirect(url_for('homepage'))
        return f(*args, **kwargs)
    return decorated_function


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

                print("✅ DEBUG: account_id stored in session =", session.get("account_id"))

                flash(f"Welcome back, {user['first_name']}!", "success")

                # Redirect by role
                if user['user_type'] == 'admin':
                    return redirect(url_for('admin'))
                elif user['user_type'] == 'seller':
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





# ===============================
# SIGNUP
# ===============================
@app.route('/signup', methods=['GET', 'POST'])
@guest_only
def signup():
    if request.method == 'POST':
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        email = request.form['email']
        password = request.form['password']
        confirm_password = request.form['confirm_password']

        if password != confirm_password:
            flash("Passwords do not match. Please try again.", "error")
            return redirect(url_for('signup'))

        hashed_password = generate_password_hash(password)

        try:
            db = get_db_connection()
            cursor = db.cursor()
            cursor.execute("SELECT email FROM accounts WHERE email = %s", (email,))
            existing_user = cursor.fetchone()

            if existing_user:
                flash("Email already registered. Please log in instead.", "warning")
                return redirect(url_for('login'))

            insert_query = """
                INSERT INTO accounts (first_name, last_name, email, account_password)
                VALUES (%s, %s, %s, %s)
            """
            cursor.execute(insert_query, (first_name, last_name, email, hashed_password))
            db.commit()

            flash(f"Account created successfully! Welcome, {first_name}!", "success")
            return redirect(url_for('login'))

        except mysql.connector.Error as err:
            print("Database error:", err)
            flash("An error occurred while creating your account. Please try again.", "error")

        finally:
            cursor.close()

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
        cursor.close()
        db.close()
        return "Not enough stock available", 400

    # Check if the user already has a pending order
    cursor.execute("""
        SELECT order_id FROM orders 
        WHERE account_id = %s AND order_status = 'pending'
    """, (account_id,))
    order = cursor.fetchone()

    if order:
        order_id = order["order_id"]
    else:
        # Create new order for this user
        cursor.execute("""
            INSERT INTO orders (account_id, order_status, total_price)
            VALUES (%s, 'pending', 0.00)
        """, (account_id,))
        db.commit()
        order_id = cursor.lastrowid

    # Check if product already in order_items
    cursor.execute("""
        SELECT * FROM order_items
        WHERE order_id = %s AND product_id = %s
    """, (order_id, product_id))
    existing_item = cursor.fetchone()

    if existing_item:
        # Update quantity and price
        new_qty = existing_item["quantity"] + quantity
        cursor.execute("""
            UPDATE order_items
            SET quantity = %s, price_each = %s
            WHERE item_id = %s
        """, (new_qty, product["price"], existing_item["item_id"]))
    else:
        # Add new item
        cursor.execute("""
            INSERT INTO order_items (order_id, product_id, quantity, price_each)
            VALUES (%s, %s, %s, %s)
        """, (order_id, product_id, quantity, product["price"]))

    # Update order total
    cursor.execute("""
        UPDATE orders
        SET total_price = (
            SELECT SUM(subtotal)
            FROM order_items
            WHERE order_id = %s
        )
        WHERE order_id = %s
    """, (order_id, order_id))

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
# UPDATE CART QUANTITY
# ===============================
@app.route("/update_cart", methods=["POST"])
@login_required
def update_cart():
    account_id = session.get("account_id")
    product_id = int(request.form["product_id"])
    action = request.form.get("action")  # 'increase', 'decrease', 'remove'

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Get pending order
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

    # Get current quantity and stock
    cursor.execute("""
        SELECT oi.quantity, p.stock_quantity, oi.price_each
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        WHERE oi.order_id = %s AND oi.product_id = %s
    """, (order_id, product_id))
    item = cursor.fetchone()

    if not item:
        flash("Item not found in cart.", "error")
        cursor.close()
        db.close()
        return redirect(url_for("cart"))

    new_quantity = item["quantity"]

    if action == "increase":
        if new_quantity < item["stock_quantity"]:
            new_quantity += 1
        else:
            flash("Cannot add more. Stock limit reached.", "warning")
    elif action == "decrease":
        new_quantity -= 1
    elif action == "remove":
        new_quantity = 0  # triggers removal

    if new_quantity <= 0:
        # Remove item from order_items
        cursor.execute("""
            DELETE FROM order_items
            WHERE order_id = %s AND product_id = %s
        """, (order_id, product_id))
        flash("Item removed from cart.", "info")
    else:
        # Update quantity and subtotal
        cursor.execute("""
            UPDATE order_items
            SET quantity = %s, subtotal = %s * quantity
            WHERE order_id = %s AND product_id = %s
        """, (new_quantity, item["price_each"], order_id, product_id))

    # Update order total
    cursor.execute("""
        UPDATE orders
        SET total_price = (
            SELECT IFNULL(SUM(subtotal), 0)
            FROM order_items
            WHERE order_id = %s
        )
        WHERE order_id = %s
    """, (order_id, order_id))

    db.commit()
    cursor.close()
    db.close()

    return redirect(url_for("cart"))




# ===============================
# LOGOUT
# ===============================
@app.route('/logout')
@login_required
def logout():
    session.clear()
    flash("You’ve been logged out successfully.", "info")
    return redirect(url_for('login'))


# ===============================
# BUYER DASHBOARD
# ===============================
@app.route('/buyer')
@login_required
def buyer_dashboard():
    return render_template('buyerdashboard.html')

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
            request.form.get('user_type'),
            session['account_id']
        )

        update_query = """
            UPDATE accounts 
            SET first_name=%s, last_name=%s, email=%s, mobile_number=%s, home_number=%s,
                street=%s, barangay=%s, municipality=%s, city=%s, province=%s, zip_code=%s, user_type=%s
            WHERE account_id=%s
        """
        cursor.execute(update_query, data)
        db.commit()

        # refresh session info
        session['first_name'] = request.form.get('first_name')
        session['last_name'] = request.form.get('last_name')
        session['email'] = request.form.get('email')
        session['user_type'] = request.form.get('user_type')

        flash("Your account settings have been updated successfully!", "success")
        return redirect(url_for('profile'))

    cursor.execute("SELECT * FROM accounts WHERE account_id = %s", (session['account_id'],))
    user = cursor.fetchone()
    cursor.close()
    return render_template('settings.html', user=user)

@app.route('/become_seller')
@login_required
def become_seller():
    db = get_db_connection()
    cursor = db.cursor()
    cursor.execute("UPDATE accounts SET user_type = 'seller' WHERE account_id = %s", (session['account_id'],))
    db.commit()
    cursor.close()

    # Update session
    session['user_type'] = 'seller'

    flash("You are now a seller! Redirecting to your dashboard...", "success")
    return redirect(url_for('seller_dashboard'))

@app.route('/seller_dashboard')
@login_required
def seller_dashboard():
    if session.get('user_type') != 'seller':
        flash("Access denied: Only sellers can view this page.", "error")
        return redirect(url_for('profile'))

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Show same data logic as homepage
    cursor.execute("SELECT * FROM products ORDER BY product_id DESC LIMIT 10")
    products = cursor.fetchall()

    cursor.execute("SELECT * FROM products ORDER BY product_id DESC")
    recommended = cursor.fetchall()

    cursor.close()
    db.close()

    # Use same display structure as homepage for now
    return render_template(
        'seller_dashboard.html',
        user=session,
        products=products,
        recommended=recommended
    )

# ===============================
# RUN APP
# ===============================
if __name__ == '__main__':
    app.run(debug=True)
