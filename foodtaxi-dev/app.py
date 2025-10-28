from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, flash, session
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from cryptography.fernet import Fernet
import base64
import mysql.connector
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import secrets
import os

app = Flask(__name__)
app.secret_key = 'your_secret_key_here'

UPLOAD_FOLDER = os.path.join(app.root_path, 'static', 'images', 'product_images')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

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
UPLOAD_FOLDER = 'foodtaxi-dev/static/images/profile'
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
                session['profile_image'] = user['profile_image'] if user['profile_image'] else None

                print("✅ DEBUG: account_id stored in session =", session.get("account_id"))

                flash(f"Welcome back, {user['first_name']}!", "success")

                # Redirect by role
                if user['user_type'] == 'admin':
                    return redirect(url_for('admin_dashboard'))
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

    if quantity > product["stock_quantity"]:
        flash("Not enough stock available.", "error")
        cursor.close()
        db.close()
        return redirect(url_for("homepage"))

    # Check for existing pending order
    cursor.execute("""
        SELECT order_id FROM orders 
        WHERE account_id = %s AND order_status = 'pending'
    """, (account_id,))
    order = cursor.fetchone()

    if order:
        order_id = order["order_id"]
    else:
        # Create new pending order
        cursor.execute("""
            INSERT INTO orders (account_id, order_status, total_price)
            VALUES (%s, 'pending', 0.00)
        """, (account_id,))
        db.commit()
        order_id = cursor.lastrowid

    # Always insert new row (allow stacking)
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

@app.route("/orders")
@login_required
def orders():
    account_id = session.get("account_id")

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
        SELECT *
        FROM orders
        WHERE account_id = %s
        ORDER BY order_date DESC
    """, (account_id,))
    orders = cursor.fetchall()

    # Fetch all items for each order
    for order in orders:
        cursor.execute("""
            SELECT oi.*, p.product_name, p.maker, p.description, p.image
            FROM order_items oi
            JOIN products p ON oi.product_id = p.product_id
            WHERE oi.order_id = %s
        """, (order['order_id'],))
        order['order_products'] = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template("orders.html", orders=orders)

@app.route("/cancel_order/<int:order_id>", methods=["POST"])
@login_required
def cancel_order(order_id):
    account_id = session.get("account_id")

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Verify the order belongs to the user and is cancelable
    cursor.execute("""
        SELECT * FROM orders
        WHERE order_id = %s AND account_id = %s AND order_status IN ('pending', 'processing')
    """, (order_id, account_id))
    order = cursor.fetchone()

    if not order:
        flash("Order cannot be canceled.", "error")
        cursor.close()
        db.close()
        return redirect(url_for("orders"))

    # Return stock quantities
    cursor.execute("""
        SELECT product_id, quantity FROM order_items
        WHERE order_id = %s
    """, (order_id,))
    items = cursor.fetchall()
    for item in items:
        cursor.execute("""
            UPDATE products
            SET stock_quantity = stock_quantity + %s
            WHERE product_id = %s
        """, (item["quantity"], item["product_id"]))

    # Mark order as canceled
    cursor.execute("""
        UPDATE orders
        SET order_status = 'cancelled', last_updated = NOW()
        WHERE order_id = %s
    """, (order_id,))

    db.commit()
    cursor.close()
    db.close()

    flash("Order has been canceled and stock restored.", "success")
    return redirect(url_for("orders"))



@app.route("/checkout", methods=["POST"])
@login_required
def checkout():
    account_id = session.get("account_id")

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # Fetch pending order
        cursor.execute("""
            SELECT order_id, total_price
            FROM orders
            WHERE account_id = %s AND order_status = 'pending'
            ORDER BY order_date DESC
            LIMIT 1
        """, (account_id,))
        order = cursor.fetchone()

        if not order:
            flash("You have no items to checkout.", "error")
            return redirect(url_for("cart"))

        order_id = order["order_id"]

        # Check stock for all items
        cursor.execute("""
            SELECT oi.product_id, oi.quantity, p.stock_quantity
            FROM order_items oi
            JOIN products p ON oi.product_id = p.product_id
            WHERE oi.order_id = %s
        """, (order_id,))
        items = cursor.fetchall()
        for item in items:
            if item["quantity"] > item["stock_quantity"]:
                flash("Cannot checkout: some items exceed available stock.", "error")
                return redirect(url_for("cart"))

        # Update stock
        for item in items:
            cursor.execute("""
                UPDATE products
                SET stock_quantity = stock_quantity - %s
                WHERE product_id = %s
            """, (item["quantity"], item["product_id"]))

        # Mark order as processing
        cursor.execute("""
            UPDATE orders
            SET order_status = 'processing', last_updated = NOW()
            WHERE order_id = %s
        """, (order_id,))

        db.commit()
        flash("Checkout successful! Your order is now being processed.", "success")
        return redirect(url_for("orders"))

    except Exception as e:
        db.rollback()
        flash(f"Error during checkout: {e}", "error")
        return redirect(url_for("cart"))

    finally:
        cursor.close()
        db.close()






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

@app.route('/become_seller')
@login_required
def become_seller():
    account_id = session.get('account_id')

    # Generate verification token
    verification_token = secrets.token_urlsafe(32)

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Update user to seller and set email_status to unverified, store token
    cursor.execute("""
        UPDATE accounts
        SET user_type = 'seller', email_status = 'unverified', verification_token = %s
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
    session['user_type'] = 'seller'

    flash("A verification email has been sent to your email address. Please verify your email to become a seller.", "info")
    return redirect(url_for('profile'))

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
        return redirect(url_for('profile'))

    # Fetch only products belonging to this seller
    cursor.execute("SELECT * FROM products WHERE seller_id = %s ORDER BY product_id DESC LIMIT 10", (account_id,))
    products = cursor.fetchall()

    cursor.execute("SELECT * FROM products WHERE seller_id = %s ORDER BY product_id DESC", (account_id,))
    recommended = cursor.fetchall()

    cursor.close()
    db.close()

    return render_template(
        'seller_dashboard.html',
        user=session,
        products=products,
        recommended=recommended
    )

@app.route('/seller/products')
def seller_products():
    if 'account_id' not in session:
        return redirect(url_for('login'))

    seller_id = session['account_id']
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM products WHERE seller_id = %s", (seller_id,))
    products = cursor.fetchall()
    cursor.close()

    return render_template('seller_products.html', products=products)


@app.route('/seller/add-product', methods=['GET', 'POST'])
def add_product():
    if 'account_id' not in session:
        return redirect(url_for('login'))

    seller_id = session['account_id']

    if request.method == 'POST':
        product_name = request.form['product_name']
        maker = request.form.get('maker')
        description = request.form.get('description')
        price = request.form['price']
        category = request.form['category']
        stock_quantity = request.form['stock_quantity']
        image = request.files['image']

        if image:
         filename = secure_filename(image.filename)
         image.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
        else:
         filename = None
        db = get_db_connection()
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO products 
            (seller_id, product_name, maker, description, price, category, stock_quantity, image)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        """, (seller_id, product_name, maker, description, price, category, stock_quantity, filename))
        db.commit()
        cursor.close()

        flash("Product added successfully!", "success")
        return redirect(url_for('seller_products'))

    return render_template('add_product.html')

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
    return redirect(url_for('seller_products'))

# Edit product (redirect to your existing add/edit form)
@app.route('/seller/product/edit/<int:product_id>', methods=['GET', 'POST'])
def edit_product(product_id):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    
    if request.method == 'POST':
        product_name = request.form['product_name']
        maker = request.form.get('maker')
        description = request.form.get('description')
        price = request.form['price']
        category = request.form['category']
        stock_quantity = request.form['stock_quantity']
        
        # Handle new image upload if provided
        image_file = request.files.get('image')
        if image_file and image_file.filename:
            filename = secure_filename(image_file.filename)
            image_file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
            cursor.execute("""
                UPDATE products SET product_name=%s, maker=%s, description=%s, price=%s, category=%s,
                stock_quantity=%s, image=%s WHERE product_id=%s
            """, (product_name, maker, description, price, category, stock_quantity, filename, product_id))
        else:
            cursor.execute("""
                UPDATE products SET product_name=%s, maker=%s, description=%s, price=%s, category=%s,
                stock_quantity=%s WHERE product_id=%s
            """, (product_name, maker, description, price, category, stock_quantity, product_id))
        
        db.commit()
        cursor.close()
        flash("Product updated successfully!", "success")
        return redirect(url_for('seller_products'))
    
    # GET: show form with current product info
    cursor.execute("SELECT * FROM products WHERE product_id=%s", (product_id,))
    product = cursor.fetchone()
    cursor.close()
    return render_template('edit_product.html', product=product)

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
