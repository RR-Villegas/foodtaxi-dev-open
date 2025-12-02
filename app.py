# app.py
import os
import datetime
import json
import random
import string
from functools import wraps

from flask import Flask, request, jsonify, g, send_from_directory, render_template, session, redirect, url_for, abort, flash
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

import mysql.connector
from mysql.connector import pooling

# -----------------------
# CONFIGURATION
# -----------------------
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "",
    "database": "foodtaxi_omega",
    "port": 3306,
    "raise_on_warnings": True,
}

POOL_NAME = "mypool"
POOL_SIZE = 5

BASE_STATIC_DIR = os.path.join(os.path.abspath(os.path.dirname(__file__)), "static")

# Define specific upload folders
PRODUCT_IMAGE_FOLDER = os.path.join(BASE_STATIC_DIR, "images", "product_images")
PROFILE_IMAGE_FOLDER = os.path.join(BASE_STATIC_DIR, "images", "profile_photos")
DOCUMENT_FOLDER = os.path.join(BASE_STATIC_DIR, "docs") # Example for other files

# Create the directories if they don't exist
os.makedirs(PRODUCT_IMAGE_FOLDER, exist_ok=True)
os.makedirs(PROFILE_IMAGE_FOLDER, exist_ok=True)
os.makedirs(DOCUMENT_FOLDER, exist_ok=True)

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "pdf"}

app = Flask(__name__)
app.config['SECRET_KEY'] = 'a_very_secret_key'
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB
app.config['UPLOAD_FOLDERS'] = {    
    'product': PRODUCT_IMAGE_FOLDER,
    'profile': PROFILE_IMAGE_FOLDER,
    'doc': DOCUMENT_FOLDER,
}
app.config['ALLOWED_EXTENSIONS'] = ALLOWED_EXTENSIONS
# -----------------------
# DB POOL INITIALIZATION
# -----------------------
db_pool = mysql.connector.pooling.MySQLConnectionPool(
    pool_name=POOL_NAME,
    pool_size=POOL_SIZE,
    **DB_CONFIG
)

class DB:
    def query(self, sql, params=None):
        conn, cur = get_db_conn()
        cur.execute(sql, params or ())
        return cur.fetchall()

    def query_one(self, sql, params=None):
        conn, cur = get_db_conn()
        cur.execute(sql, params or ())
        return cur.fetchone()

db = DB()


# -----------------------
# HELPERS
# -----------------------
# app.py (Confirm your get_db_conn function matches this)

def get_db_conn():
    """
    Returns the database connection and cursor, retrieving them from 
    Flask's request-local global object 'g' or creating them if necessary.
    """
    if 'db_conn' not in g:
        # 1. Get connection from the pool and store it on g
        g.db_conn = db_pool.get_connection()
        
        # 2. Create the cursor and store it on g
        # Using dictionary=True makes results easier to work with (e.g., row['column_name'])
        g.db_cursor = g.db_conn.cursor(dictionary=True) 
        
    return g.db_conn, g.db_cursor

def create_slug(text):
    """Converts text into a URL-friendly slug."""
    text = text.lower()
    # Replace non-alphanumeric characters (except space/hyphen) with nothing
    text = ''.join(c if c.isalnum() or c in ' -' else '' for c in text)
    # Replace spaces and multiple hyphens with a single hyphen
    text = '-'.join(text.split())
    return text

def get_session_cart_count():
    """Calculates the total quantity of items in the session-based cart."""
    # Session cart is stored as: {'product_id_1': quantity_1, 'product_id_2': quantity_2, ...}
    session_cart = session.get('guest_cart', {})
    
    # Sum all quantities in the cart
    return sum(session_cart.values())

def auto_approve_seller(account_id, firstname, surname):
    """
    Creates a boilerplate SELLER_APPLICATION (approved) and STORE entry 
    for a newly verified Seller account.
    """
    conn, cur = get_db_conn()
    now = datetime.datetime.now()
    store_name = f"{firstname}'s {surname} Shop"
    # Create a URL-friendly slug (e.g., 'firstnames-surname-shop')
    slug = store_name.lower().replace(" ", "-").replace("'", "")
    
    try:
        # 1. Check if seller_application already exists
        cur.execute("SELECT account_id FROM seller_application WHERE account_id = %s", (account_id,))
        if cur.fetchone():
            # Check if store exists (if application exists, store should exist, but check for safety)
            cur.execute("SELECT owner_account_id FROM store WHERE owner_account_id = %s", (account_id,))
            if cur.fetchone():
                return "Seller application and store already exist."
            
        # 2. Create SELLER_APPLICATION entry (Pre-approved for testing)
        if not cur.fetchone():
            app_sql = """
            INSERT INTO seller_application (
                account_id, business_name, business_address, 
                application_date, status, review_notes, date_approved,
                otp_verified
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            app_values = (
                account_id, store_name, "Seller Default Address",
                now, 'Approved', 'Auto-approved on login for testing.', now,
                True
            )
            cur.execute(app_sql, app_values)
            # conn.commit() is done at the end of the entire function

        # 3. Create STORE entry (Links product functionality)
        store_sql = """
        INSERT INTO store (
            owner_account_id, store_name, slug, address_line, city, is_open
        ) VALUES (%s, %s, %s, %s, %s, %s)
        """
        store_values = (
            account_id, store_name, slug, "Seller Default Address", "Default City", True
        )
        cur.execute(store_sql, store_values)
        
        conn.commit()
        return f"Seller store '{store_name}' created successfully."

    except mysql.connector.Error as err:
        conn.rollback()
        print(f"Auto-approve Seller Error: {err}")
        return f"Failed to auto-approve seller: {err.msg}"

@app.teardown_appcontext
def close_db_conn(exception):
    db_conn = g.pop('db_conn', None)
    db_cursor = g.pop('db_cursor', None)
    if db_cursor:
        try: db_cursor.close()
        except: pass
    if db_conn:
        try: db_conn.close()
        except: pass
        

@app.route('/static/<path:path>')
def send_static(path):
    return send_from_directory(os.path.join(os.path.dirname(__file__), 'static'), path)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def require_json(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not request.is_json:
            return jsonify({"message": "Request content-type must be application/json"}), 400
        return f(*args, **kwargs)
    return wrapper

def require_seller(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        user = session.get('user')
        if not user:
            return jsonify({"message": "Unauthorized"}), 401
        if user.get('account_type') != 'Seller':
            return jsonify({"message": "Forbidden"}), 403
        return f(*args, **kwargs)
    return wrapper

def get_cart_count():
    cart = session.get("cart", [])
    return len(cart)

# -----------------------
# STANDARD PAGE ROUTES
# -----------------------
# app.py

@app.route('/')
def index():
    """
    Renders the homepage, fetches the latest products for the carousel,
    and handles global context variables, including the cart item count.
    """
    
    # ------------------
    # 1. User Context Logic
    # ------------------
    current_user = session.get('user', {'is_authenticated': False})
    
    # Check if 'user' data is present in the session (assuming successful login stores data)
    if 'id' in current_user and current_user['id']:
        current_user['is_authenticated'] = True
        user_account_id = current_user['id'] # Assuming the account ID is stored as 'id'
    else:
        current_user['is_authenticated'] = False
        user_account_id = None
        
    # ------------------
    # 2. Database Fetch Logic (Products Carousel)
    # ------------------
    product_sql = """
    SELECT
        p.product_id AS id,
        p.name,
        p.price,
        p.main_image_url AS image_url,
        s.store_name
    FROM
        product p
    JOIN
        store s ON p.seller_account_id = s.owner_account_id
    WHERE
        p.is_active = 1
    ORDER BY
        p.product_id DESC
    LIMIT 20;
    """
    
    carousel_items = []
    try:
        carousel_items = db.query(product_sql)
    except Exception as e:
        print(f"Error loading featured products: {e}")
        flash('Could not load featured products at this time.', 'error')

    # ------------------
    # 3. Cart Count Logic (New Implementation)
    # ------------------
    cart_item_count = 0
    
    if user_account_id:
        # SQL to join cart and cart_item tables and sum the quantities
        cart_count_sql = """
        SELECT
            SUM(ci.quantity) AS cart_count
        FROM
            cart_item ci
        JOIN
            cart c ON ci.cart_id = c.cart_id
        WHERE
            c.buyer_account_id = %s AND c.status = 'Active';
        """
        try:
            # Use query_one as we only expect a single aggregate result
            result = db.query_one(cart_count_sql, (user_account_id,))
            
            # The result will be a dictionary like {'cart_count': 17} or {'cart_count': None}
            if result and result.get('cart_count') is not None:
                cart_item_count = int(result['cart_count'])
                
        except Exception as e:
            # Log the error but continue rendering the page
            print(f"Error fetching cart count for user {user_account_id}: {e}")

    # ------------------
    # 4. Render Template
    # ------------------
    return render_template(
        'index.html',
        # Variables for the carousel
        items=carousel_items,
        carousel_id='featured-products',
        
        # Other content (empty lists for now)
        trending_items=[], 
        random_items=[],
        
        # Global context variables
        now=datetime.datetime.now(),
        current_user=current_user,
        cart_item_count=cart_item_count # The actual fetched count
    )

# In app.py
@app.route('/search')
def search():
    # 1. Get parameters from the request
    query = request.args.get('q', '')
    page = request.args.get('page', 1, type=int)
    
    # Filters: request.args.getlist handles multiple checkboxes with the same name
    category_filter = request.args.getlist('category')
    # Use .get(..., type=float) to safely convert input to a number or return None
    min_price = request.args.get('min_price', type=float)
    max_price = request.args.get('max_price', type=float)
    
    items_per_page = 12
    offset = (page - 1) * items_per_page
    
    # 2. Build the SQL Query dynamically
    
    # Base queries
    sql_base = """
        SELECT 
            p.product_id, p.name, p.price, p.main_image_url, p.description, 
            p.product_slug, 
            s.slug AS store_slug,   -- Must fetch the store's slug and alias it
            s.store_name            -- Also good to fetch the store name
        FROM product p
        JOIN store s ON p.seller_account_id = s.owner_account_id 
        WHERE p.is_active = TRUE
    """
    count_base = "SELECT COUNT(product_id) AS total_count FROM product WHERE is_active = TRUE"
    
    conditions = []
    params = []

    # A. Search Term (q)
    if query:
        # Search name OR description
        conditions.append("(name LIKE %s OR description LIKE %s)")
        # Use LIKE %% for partial matching (SQL safe)
        params.extend([f"%{query}%", f"%{query}%"])

    # B. Category Filter
    if category_filter:
        # Map simplified URL values (from HTML form) to Database ENUM values (from your SQL schema)
        category_map = {
            'baking': 'Baking Supplies & Ingredients',
            'coffee': 'Coffee, Tea & Beverages',
            'snacks': 'Snacks & Candy',
            
            # --- NEW MAPPINGS ADDED HERE ---
            'specialty': 'Specialty Foods & International Cuisine',
            'organic': 'Organic and Health Foods',
            'mealkits': 'Meal Kits & Prepped Foods'
            # --------------------------------
        }
        
        # Filter down to only valid ENUM values
        valid_categories = [category_map[c] for c in category_filter if c in category_map]
        
        if valid_categories:
            # Create a placeholder string for the SQL IN clause (e.g., "%s, %s")
            placeholders = ', '.join(['%s'] * len(valid_categories))
            conditions.append(f"category IN ({placeholders})")
            params.extend(valid_categories)
            
    # C. Price Filters
    if min_price is not None and min_price >= 0:
        conditions.append("price >= %s")
        params.append(min_price)
        
    if max_price is not None and max_price >= 0:
        conditions.append("price <= %s")
        params.append(max_price)

    # Combine all conditions into the WHERE clause
    if conditions:
        where_clause = " AND " + " AND ".join(conditions)
        sql_base += where_clause
        count_base += where_clause

    # 3. Add Ordering and Pagination
    sql_final = sql_base + " ORDER BY name ASC LIMIT %s OFFSET %s"
    
    # The parameters for the count query are the same as the final query, 
    # excluding the LIMIT and OFFSET parameters.
    count_params = params[:]
    
    params.extend([items_per_page, offset])

    # 4. Execute Queries
    conn, cur = get_db_conn()
    
    # Get total count (FIXED: Call fetchone() only once to avoid NoneType error)
    cur.execute(count_base, count_params) 
    count_row = cur.fetchone()
    
    if count_row:
        total_count = count_row['total_count']
    else:
        total_count = 0 # Safety default

    # Get search results
    cur.execute(sql_final, params)
    results = cur.fetchall()
    
    cur.close()
    conn.close()

    # 5. Prepare context variables
    current_user = session.get('user', {'is_authenticated': False})
    if current_user != {'is_authenticated': False}:
        current_user['is_authenticated'] = True
        
    # Determine pagination links
    has_next_page = total_count > (page * items_per_page)
    has_prev_page = page > 1
    
    return render_template(
        'search_results.html',
        query=query,
        results=results,
        page=page,
        total_count=total_count,
        has_next_page=has_next_page,
        has_prev_page=has_prev_page,
        
        # Variables required by base.html/footer.html/navbar.html
        now=datetime.datetime.now(), 
        current_user=current_user,
        cart_item_count=0, # Replace with actual cart item count logic
        
        # Pass filters back to template for form state retention
        category_filter=category_filter,
        min_price=min_price,
        max_price=max_price,
    )

@app.route('/seller-application')
def seller_application():
    return render_template('_partials/auth_modal.html')

@app.route('/rider-application')
def rider_application():
    return render_template('_partials/auth_modal.html')

@app.route('/shop')
def shop():
    return "All Products Page Placeholder"

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

@app.route('/process_order', methods=['POST'])
def process_order():
    """
    Handles checkout form submission, moves items from cart to orders,
    and records the transaction.
    """
    user_info = session.get('user')
    if not user_info or user_info.get('account_type') != 'Buyer':
        flash('Please log in as a Buyer to complete your order.', 'danger')
        return redirect(url_for('login'))
        
    buyer_account_id = user_info['account_id']
    
    # 1. Get data from the HTML form
    payment_method = request.form.get('payment_method')
    # Use float conversion for financial data
    try:
        total_amount = float(request.form.get('total_amount'))
        shipping_fee = float(request.form.get('shipping_fee'))
    except (ValueError, TypeError):
        flash('Invalid total or shipping amount.', 'danger')
        return redirect(url_for('cart'))

    payment_reference = request.form.get('payment_reference') # Used for GCash
    
    # 2. Determine initial payment status and reference
    # For simplicity, COD is Pending, GCash is Paid if reference provided
    payment_status = 'Pending'
    transaction_reference = payment_reference
    
    if payment_method == 'GCash' and transaction_reference:
        payment_status = 'Paid' # Assuming instant verification for this demo
    elif payment_method == 'Cash on Delivery':
        # Ensure COD doesn't get a reference number in the DB
        transaction_reference = None 
    
    conn, cur = get_db_conn()
    
    try:
        # A. Find the active cart and its items
        cur.execute("SELECT cart_id FROM cart WHERE buyer_account_id = %s AND status = 'Active'", (buyer_account_id,))
        cart_row = cur.fetchone()
        
        if not cart_row:
            flash('Your cart is empty or expired.', 'danger')
            return redirect(url_for('cart'))
            
        cart_id = cart_row['cart_id']
        
        cur.execute("""
            SELECT ci.product_id, ci.quantity, (p.price * ci.quantity) AS subtotal_item
            FROM cart_item ci
            JOIN product p ON ci.product_id = p.product_id
            WHERE ci.cart_id = %s
        """, (cart_id,))
        cart_items = cur.fetchall()
        
        if not cart_items:
            flash('Your cart is empty.', 'danger')
            return redirect(url_for('cart'))
            
        # B. Insert into ORDERS table
        now = datetime.datetime.now()
        order_insert_sql = """
        INSERT INTO orders (
            buyer_account_id, total_amount, shipping_fee, payment_method, 
            payment_status, order_date, status
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        order_values = (
            buyer_account_id, total_amount, shipping_fee, payment_method, 
            payment_status, now, 'Processing' # Initial order status
        )
        cur.execute(order_insert_sql, order_values)
        order_id = cur.lastrowid
        
        # C. Insert into ORDER_ITEMS table
        order_item_list = []
        for item in cart_items:
            # (order_id, product_id, quantity, subtotal)
            order_item_list.append((order_id, item['product_id'], item['quantity'], float(item['subtotal_item'])))
            
        order_item_sql = "INSERT INTO order_items (order_id, product_id, quantity, subtotal) VALUES (%s, %s, %s, %s)"
        cur.executemany(order_item_sql, order_item_list)
        
        # D. Insert into TRANSACTION table
        transaction_sql = """
        INSERT INTO transaction (
            order_id, transaction_date, amount, payment_method, reference_number, status
        ) VALUES (%s, %s, %s, %s, %s, %s)
        """
        transaction_values = (
            order_id, now, total_amount, payment_method, transaction_reference, payment_status
        )
        cur.execute(transaction_sql, transaction_values)
        
        # E. Update CART status to 'Placed'
        cur.execute("UPDATE cart SET status = 'Placed', date_placed = %s WHERE cart_id = %s", (now, cart_id))
        
        conn.commit()
        flash(f'Order #{order_id} placed successfully! You will receive a confirmation shortly.', 'success')
        return redirect(url_for('index')) # Redirect to the homepage or a dedicated success page
        
    except Exception as e:
        conn.rollback()
        print(f"Database error during process_order: {e}")
        flash('A critical database error occurred while processing your order.', 'danger')
        return redirect(url_for('cart'))

@app.route('/order_confirmation/<int:order_id>')
def order_confirmation(order_id):
    """Placeholder for a simple order confirmation page."""
    
    user_info = session.get('user')
    if not user_info:
        return redirect(url_for('login'))
        
    conn, cur = get_db_conn()
    # Basic check to ensure the order belongs to the user
    cur.execute("SELECT order_id FROM orders WHERE order_id = %s AND buyer_account_id = %s", 
                (order_id, user_info['account_id']))
    order = cur.fetchone()
    
    if not order:
        abort(404)
        
    # In a real app, you would fetch full order details here
    return render_template('_partials/order_confirmation.html', order_id=order_id)

@app.route('/account')
def account():
    return "Account Dashboard Placeholder"


# --- 1. CART COUNT HELPER (Requires get_db_conn) ---
def get_cart_item_count(buyer_account_id):
    """Calculates the total quantity of items in the buyer's active cart."""
    conn, cur = get_db_conn()
    try:
        cur.execute("""
            SELECT SUM(ci.quantity) AS count
            FROM cart_item ci
            JOIN cart c ON ci.cart_id = c.cart_id
            WHERE c.buyer_account_id = %s AND c.status = 'Active'
        """, (buyer_account_id,))
        count = cur.fetchone()['count']
        return int(count) if count else 0
    except Exception as e:
        print(f"Error fetching cart count: {e}")
        return 0

# --- 2. CONTEXT PROCESSOR (Injects count for navbar) ---
@app.context_processor
def inject_user():
    """Injects user and cart_item_count into all templates."""
    current_user = session.get('user', {'is_authenticated': False})
    if current_user != {'is_authenticated': False}:
        current_user['is_authenticated'] = True
    
    cart_item_count = 0
    if current_user.get('is_authenticated') and current_user.get('account_type') == 'Buyer':
        cart_item_count = get_cart_item_count(current_user['account_id'])
        
    return dict(current_user=current_user, cart_item_count=cart_item_count)

# --- 3. VIEW CART ROUTE (Replaces the simple render) ---
@app.route('/cart')
def cart():
    """Fetches cart items and calculates the total price for rendering cart.html."""
    user_info = session.get('user')
    
    if not user_info or user_info.get('account_type') != 'Buyer':
        flash('Please log in as a Buyer to view your cart.', 'warning')
        return redirect(url_for('login'))
        
    buyer_account_id = user_info['account_id']
    conn, cur = get_db_conn()
    cart_items = []
    total_price = 0.0
    
    try:
        sql = """
            SELECT
                ci.cart_item_id AS id,
                ci.quantity,
                p.product_id,
                p.name,
                p.price,
                p.main_image_url AS image_url,
                (p.price * ci.quantity) AS subtotal
            FROM cart_item ci
            JOIN cart c ON ci.cart_id = c.cart_id
            JOIN product p ON ci.product_id = p.product_id
            WHERE c.buyer_account_id = %s AND c.status = 'Active'
        """
        cur.execute(sql, (buyer_account_id,))
        fetched_items = cur.fetchall()
        
        for item in fetched_items:
            subtotal_val = float(item['subtotal'])
            total_price += subtotal_val 
            
            # Format price for display
            item['price'] = f"{float(item['price']):.2f}"
            item['subtotal'] = f"{subtotal_val:.2f}"
            cart_items.append(item)
            
        total_price = f"{total_price:.2f}"

    except Exception as e:
        print(f"Error fetching cart data: {e}")
        flash('Could not retrieve cart data due to a server error.', 'danger')

    # Ensure your template is named 'cart.html' (or '_partials/cart.html' as you specified)
    return render_template('_partials/cart.html',
        cart_items=cart_items,
        total_price=total_price
    )

# ----------------------------------------------------------------------
# --- 4. DATA MANIPULATION ROUTES (User-provided, simplified) ---

@app.route('/cart/add', methods=['POST'])
def add_to_cart():
    user_info = session.get('user')
    if not user_info or user_info.get('account_type') != 'Buyer':
        flash('You must be logged in as a buyer to add items to the cart.', 'danger')
        return redirect(url_for('login'))
    
    buyer_account_id = user_info['account_id']
    product_id = request.form.get('product_id', type=int)
    quantity = request.form.get('quantity', 1, type=int) 
    
    if not product_id or quantity < 1:
        flash('Invalid product or quantity specified.', 'warning')
        return redirect(request.referrer or url_for('shop'))

    conn, cur = get_db_conn()
    
    try:
        # A. Get current stock
        cur.execute("SELECT stock_quantity, name FROM product WHERE product_id = %s", (product_id,))
        product_row = cur.fetchone()
        
        if not product_row:
            flash("Error: Product not found.", 'danger')
            return redirect(request.referrer or url_for('shop'))

        available_stock = product_row['stock_quantity']
        product_name = product_row['name']
        
        # B. Find or Create Cart
        cur.execute("SELECT cart_id FROM cart WHERE buyer_account_id = %s AND status = 'Active'", (buyer_account_id,))
        cart_row = cur.fetchone()
        
        if cart_row:
            cart_id = cart_row['cart_id']
        else:
            cur.execute("INSERT INTO cart (buyer_account_id) VALUES (%s)", (buyer_account_id,))
            cart_id = cur.lastrowid
        
        # C. Find or Update Cart Item
        cur.execute("SELECT cart_item_id, quantity FROM cart_item WHERE cart_id = %s AND product_id = %s", (cart_id, product_id))
        item_row = cur.fetchone()
        
        old_quantity = item_row['quantity'] if item_row else 0
        new_quantity = old_quantity + quantity
        
        # D. Stock Check Logic
        if new_quantity > (old_quantity + available_stock):
            flash(f"Insufficient stock for {product_name}. Only {available_stock} units remaining.", 'danger')
            return redirect(request.referrer or url_for('shop'))

        # E. Perform Cart Update
        if item_row:
            # Update existing cart item
            cur.execute("UPDATE cart_item SET quantity = %s WHERE cart_item_id = %s", (new_quantity, item_row['cart_item_id']))
            flash(f"Updated **{new_quantity}** units of {product_name} in your cart.", 'success')
        else:
            # Insert new cart item
            cur.execute("INSERT INTO cart_item (cart_id, product_id, quantity) VALUES (%s, %s, %s)", (cart_id, product_id, quantity))
            flash(f"Added **{quantity}** unit(s) of {product_name} to your cart.", 'success')

        # F. DEDUCT STOCK
        cur.execute("UPDATE product SET stock_quantity = stock_quantity - %s WHERE product_id = %s", (quantity, product_id))

        conn.commit()
        
    except Exception as e:
        conn.rollback()
        print(f"Database error during add_to_cart: {e}")
        flash('A database error occurred. Could not add item to cart.', 'danger')
        
    # Redirect to the previous page or the cart view
    return redirect(request.referrer or url_for('cart'))

@app.route('/cart/remove/<int:item_id>', methods=['POST'])
def remove_from_cart(item_id):
    user_info = session.get('user')
    if not user_info or user_info.get('account_type') != 'Buyer':
        flash('Authentication required to perform this action.', 'danger')
        return redirect(url_for('login'))
    
    buyer_account_id = user_info['account_id']
    conn, cur = get_db_conn()
    
    try:
        # A. GET QUANTITY AND PRODUCT_ID BEFORE DELETION
        cur.execute("""
            SELECT ci.quantity, ci.product_id
            FROM cart_item ci
            JOIN cart c ON ci.cart_id = c.cart_id
            WHERE ci.cart_item_id = %s AND c.buyer_account_id = %s
        """, (item_id, buyer_account_id))
        item_info = cur.fetchone()
        
        if not item_info:
            flash("Error: Cart item not found or does not belong to your account.", 'warning')
            return redirect(url_for('cart'))

        quantity_to_return = item_info['quantity']
        product_id = item_info['product_id']
        
        # B. DELETE ITEM
        cur.execute("""
            DELETE ci FROM cart_item ci
            JOIN cart c ON ci.cart_id = c.cart_id
            WHERE ci.cart_item_id = %s AND c.buyer_account_id = %s
        """, (item_id, buyer_account_id))
        
        if cur.rowcount > 0:
            # C. ADD STOCK BACK (Reverse the deduction)
            cur.execute("UPDATE product SET stock_quantity = stock_quantity + %s WHERE product_id = %s", (quantity_to_return, product_id))
            flash("Item successfully removed from your cart.", 'success')
        else:
            flash("Error: Cart item not found or does not belong to your account.", 'warning')
            
        conn.commit()
        
    except Exception as e:
        conn.rollback()
        print(f"Database error during remove_from_cart: {e}")
        flash('A database error occurred. Could not remove item from cart.', 'danger')
        
    return redirect(url_for('cart'))

@app.route('/cart/update/<int:item_id>', methods=['POST'])
def update_cart_quantity(item_id):
    user_info = session.get('user')
    if not user_info or user_info.get('account_type') != 'Buyer':
        flash('Authentication required to perform this action.', 'danger')
        return redirect(url_for('login'))
    
    buyer_account_id = user_info['account_id']
    new_quantity = request.form.get('quantity', type=int)
    
    if new_quantity is None:
        flash('Missing quantity data.', 'warning')
        return redirect(url_for('cart'))
    
    conn, cur = get_db_conn()
    
    try:
        # A. GET OLD QUANTITY, PRODUCT_ID, AND CURRENT STOCK
        cur.execute("""
            SELECT ci.quantity AS old_quantity, ci.product_id, p.stock_quantity AS available_stock, p.name
            FROM cart_item ci
            JOIN cart c ON ci.cart_id = c.cart_id
            JOIN product p ON ci.product_id = p.product_id
            WHERE ci.cart_item_id = %s AND c.buyer_account_id = %s AND c.status = 'Active'
        """, (item_id, buyer_account_id))
        item_info = cur.fetchone()
        
        if not item_info:
            flash("Error: Item not found in your active cart.", 'warning')
            return redirect(url_for('cart'))

        old_quantity = item_info['old_quantity']
        product_id = item_info['product_id']
        available_stock = item_info['available_stock']
        product_name = item_info['name']
        
        # B. Handle Delete (Quantity <= 0)
        if new_quantity <= 0:
            # Delete logic (same as remove_from_cart)
            cur.execute("DELETE ci FROM cart_item ci JOIN cart c ON ci.cart_id = c.cart_id WHERE ci.cart_item_id = %s AND c.buyer_account_id = %s", (item_id, buyer_account_id))
            
            if cur.rowcount > 0:
                # Add the old quantity back to stock
                cur.execute("UPDATE product SET stock_quantity = stock_quantity + %s WHERE product_id = %s", (old_quantity, product_id))
                flash(f"Item {product_name} successfully removed from your cart.", 'success')
            
        # C. Handle Update (Quantity > 0)
        else:
            quantity_change = new_quantity - old_quantity # Positive if increasing, negative if decreasing
            stock_needed = quantity_change
            
            # Check if increasing quantity exceeds stock
            if stock_needed > 0 and stock_needed > available_stock:
                flash(f"Insufficient stock for {product_name}. Cannot increase quantity. Only {available_stock} more units are available.", 'danger')
                return redirect(url_for('cart'))
            
            # Update quantity in cart
            cur.execute("UPDATE cart_item SET quantity = %s WHERE cart_item_id = %s", (new_quantity, item_id))

            if cur.rowcount > 0:
                # D. ADJUST STOCK
                # If quantity_change is +5, stock decreases by 5. If quantity_change is -2, stock increases by 2.
                # So we update stock by the negative of the change (or simply: -quantity_change)
                cur.execute("UPDATE product SET stock_quantity = stock_quantity - %s WHERE product_id = %s", (quantity_change, product_id))
                flash(f"Quantity for {product_name} updated to **{new_quantity}**.", 'success')
            else:
                flash("Error: Could not update item quantity.", 'warning')
                
        conn.commit()
        
    except Exception as e:
        conn.rollback()
        print(f"Database error during update_cart_quantity: {e}")
        flash('A database error occurred. Could not update cart item.', 'danger')

    return redirect(url_for('cart'))

@app.route('/login')
def login():
    return render_template('_partials/auth_modal.html')

@app.route('/faq')
def faq():
    return "FAQ Page Placeholder"

@app.route('/contact')
def contact():
    return "Contact Page Placeholder"

@app.route('/shipping')
def shipping():
    return "Shipping Policy Placeholder"

@app.route('/privacy')
def privacy():
    return "Privacy Policy Placeholder"

# --- NEW ROUTE FOR INDIVIDUAL PRODUCT DETAILS ---
@app.route('/product/<int:product_id>')
def view_product(product_id):
    """
    Fetches and displays the details for a single product.
    This function corresponds to the 'view_product' endpoint used in url_for().
    """
    conn, cur = get_db_conn()
    
    # 1. Fetch the product details
    cur.execute("""
        SELECT 
            p.*, 
            s.store_name 
        FROM product p
        JOIN store s ON p.seller_account_id = s.owner_account_id
        WHERE p.product_id = %s AND p.is_active = TRUE
    """, (product_id,))
    product = cur.fetchone()
    
    cur.close()
    conn.close()
    
    # 2. Handle 404 (Not Found) if the product doesn't exist or isn't active
    if not product:
        # You need to import 'abort' from flask: from flask import abort
        abort(404)
        
    # 3. Render the product details page
    current_user = session.get('user', {'is_authenticated': False})
    
    return render_template(
        'product_detail_page.html', 
        product=product,
        now=datetime.datetime.now(),
        current_user=current_user,
        cart_item_count=0, # Placeholder
    )

# app.py (Around Line 323, replacing the old view_product route)

# --- NEW ROUTE FOR INDIVIDUAL PRODUCT DETAILS USING SLUGS ---
@app.route('/store/<store_slug>/product/<product_slug>')
def fetch_product(store_slug, product_slug): # <-- RENAMED FUNCTION
    """
    Fetches and displays the details for a single product using both store and product slugs.
    """
    conn, cur = get_db_conn()
    
    # 1. Fetch the product and store details by joining the tables and filtering by BOTH slugs
    cur.execute("""
        SELECT 
            p.*, 
            s.store_name,
            s.slug AS store_slug  
        FROM product p
        JOIN store s ON p.seller_account_id = s.owner_account_id
        WHERE s.slug = %s AND p.product_slug = %s AND p.is_active = TRUE
    """, (store_slug, product_slug))
    
    product = cur.fetchone()
    
    cur.close()
    conn.close()
    
    # 2. Handle 404 (Not Found)
    if not product:
        # You need to import 'abort' from flask: from flask import abort
        abort(404)
        
    # 3. Render the product details page
    current_user = session.get('user', {'is_authenticated': False})
    
    return render_template(
        'product_detail_page.html', 
        product=product,
        now=datetime.datetime.now(),
        current_user=current_user,
        cart_item_count=0, # Placeholder
    )



# -----------------------
# AUTH API
# -----------------------
@app.route('/api/register', methods=['POST'])
def api_register():
    is_json = request.is_json
    data = request.get_json() if is_json else request.form.to_dict()

    firstname = data.get('firstname')
    surname = data.get('surname')
    email = data.get('email')
    phone_number = data.get('phone_number')
    password = data.get('password')
    account_type = data.get('account_type', 'Buyer') or 'Buyer'

    if not all([firstname, surname, email, phone_number, password]):
        return jsonify({'message': 'Missing required fields'}), 400

    conn, cur = get_db_conn()

    cur.execute("SELECT account_id FROM account WHERE email = %s OR phone_number = %s",
                (email, phone_number))
    if cur.fetchone():
        return jsonify({'message': 'Email or phone number already registered'}), 409

    password_hash = generate_password_hash(password)
    now = datetime.datetime.now()

    insert_sql = """
    INSERT INTO account (
        firstname, surname, email, phone_number, password_hash, account_type,
        home_address, street_address, city, province, region, zip_code,
        is_email_verified, is_verified, date_created
    ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """

    values = (
        firstname, surname, email, phone_number, password_hash, account_type,
        data.get('home_address'), data.get('street_address'),
        data.get('city') or data.get('city_or_municipality'),
        data.get('province'), data.get('region'), data.get('zip_code'),
        True, True, now
    )

    try:
        cur.execute(insert_sql, values)
        conn.commit()
        account_id = cur.lastrowid
    except:
        conn.rollback()
        return jsonify({'message': 'Failed to create account'}), 500

    return jsonify({
        'message': 'Account created successfully.',
        'account_id': account_id
    }), 201


# ... (Lines 1-525: All existing code remains the same) ...

# -----------------------
# AUTH API
# -----------------------

# ... (api_register remains the same) ...

def auto_approve_seller(account_id, firstname, surname):
    """
    Creates a boilerplate SELLER_APPLICATION (approved) and STORE entry 
    for a newly verified Seller account.
    """
    conn, cur = get_db_conn()
    now = datetime.datetime.now()
    store_name = f"{firstname}'s {surname} Shop"
    # Create a URL-friendly slug (e.g., 'firstnames-surname-shop')
    slug = store_name.lower().replace(" ", "-").replace("'", "")
    
    try:
        # 1. Check if seller_application already exists
        cur.execute("SELECT account_id FROM seller_application WHERE account_id = %s", (account_id,))
        if cur.fetchone():
            # Check if store exists (if application exists, store should exist, but check for safety)
            cur.execute("SELECT owner_account_id FROM store WHERE owner_account_id = %s", (account_id,))
            if cur.fetchone():
                return "Seller application and store already exist."
            
        # 2. Create SELLER_APPLICATION entry (Pre-approved for testing)
        if not cur.fetchone():
            app_sql = """
            INSERT INTO seller_application (
                account_id, business_name, business_address, 
                application_date, status, review_notes, date_approved,
                otp_verified
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            app_values = (
                account_id, store_name, "Seller Default Address",
                now, 'Approved', 'Auto-approved on login for testing.', now,
                True
            )
            cur.execute(app_sql, app_values)
            # conn.commit() is done at the end of the entire function

        # 3. Create STORE entry (Links product functionality)
        store_sql = """
        INSERT INTO store (
            owner_account_id, store_name, slug, address_line, city, is_open
        ) VALUES (%s, %s, %s, %s, %s, %s)
        """
        store_values = (
            account_id, store_name, slug, "Seller Default Address", "Default City", True
        )
        cur.execute(store_sql, store_values)
        
        conn.commit()
        return f"Seller store '{store_name}' created successfully."

    except mysql.connector.Error as err:
        conn.rollback()
        print(f"Auto-approve Seller Error: {err}")
        return f"Failed to auto-approve seller: {err.msg}"


@app.route('/api/login', methods=['POST'])
@require_json
def api_login():
    data = request.get_json()
    email = data.get('email')
    phone = data.get('phone_number')
    password = data.get('password')

    if not password or (not email and not phone):
        return jsonify({'message': 'Missing login fields'}), 400

    conn, cur = get_db_conn()

    if email:
        cur.execute("SELECT * FROM account WHERE email = %s", (email,))
    else:
        cur.execute("SELECT * FROM account WHERE phone_number = %s", (phone,))

    user = cur.fetchone()
    if not user:
        return jsonify({'message': 'User not found'}), 404

    if not check_password_hash(user['password_hash'], password):
        return jsonify({'message': 'Invalid credentials'}), 401

    # --- NEW LOGIC START ---
    # Auto-create application and store if the user is a Seller
    if user['account_type'] == 'Seller':
        # This function handles the insertion into seller_application and store tables
        result = auto_approve_seller(user['account_id'], user['firstname'], user['surname'])
        print(result) # Log the result of the auto-approval

    session['user'] = {
        'account_id': user['account_id'],
        'firstname': user['firstname'],
        'surname': user['surname'],
        'email': user['email'],
        'phone_number': user['phone_number'],
        'account_type': user['account_type'],
        'is_authenticated': True
    }
    # --- NEW LOGIC END ---

    token = ''.join(random.choices(string.ascii_letters + string.digits, k=48))

    return jsonify({
        'message': 'Login successful',
        'account': {
            'account_id': user['account_id'],
            'firstname': user['firstname'],
            'surname': user['surname'],
            'email': user['email'],
            'phone_number': user['phone_number'],
            'account_type': user['account_type'],
            'is_email_verified': bool(user['is_email_verified']),
            'is_verified': bool(user['is_verified'])
        },
        'session_token': token
    }), 200

# ... (Remaining code from Line 600 to end remains the same) ...

# SELLER DASHBOARD

@app.route('/seller/dashboard')
@require_seller
def seller_dashboard():
    """Renders the main seller dashboard container."""
    # Ensure you have 'seller_dashboard.html' in your 'templates' folder
    return render_template('sellers_dashboard.html', current_user=session['user'])

@app.route('/seller/partial/<view_name>')
@require_seller
def seller_partial_view(view_name):
    """Dynamically serves the HTML partials for the dashboard content."""
    
    if view_name == 'products':
        # This renders the _product_crud.html containing the product list container AND the form template
        return render_template('_partials/_product_crud.html')
    
    # Placeholder returns for other views (Keep these for completeness)
    if view_name == 'orders':
        return '<h3>Orders Management</h3><p>Orders listing table and status updates will go here.</p>'
    if view_name == 'sales':
        return '<h3>Sales & Analytics</h3><p>Monthly sales graph and summary statistics will go here.</p><div id="sales-chart"></div>'
    if view_name == 'reviews':
        return '<h3>Review Management</h3><p>Product and Seller reviews table will go here.</p>'
    
    return jsonify({"message": "View not found"}), 404


# -----------------------
# SELLER API (With Dashboard)
# -----------------------

# app.py (Around Line 605)

# Use folder_key='product' to specify the target folder
def handle_image_upload(file, product_name, folder_key='product'): # <-- ADDED folder_key
    """Helper to save a file and return its path relative to /uploads/"""
    
    # 1. Get the target folder path
    target_folder = app.config['UPLOAD_FOLDERS'].get(folder_key)
    if not target_folder:
        # Raise an error or handle it gracefully if the folder key is wrong
        print(f"Error: Invalid upload folder key: {folder_key}")
        return None
        
    if file and allowed_file(file.filename):
        # Create a unique, secure filename
        base, ext = os.path.splitext(secure_filename(file.filename))
        unique_filename = f"{product_name.replace(' ', '_')}_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}{ext.lower()}"
        
        # 2. Save to the correct folder
        file.save(os.path.join(target_folder, unique_filename))
        return unique_filename # Returns filename only
    return None

@app.route('/api/seller/<int:seller_id>/products', methods=['GET'])
@require_seller
def api_seller_products(seller_id):
    user = session['user']
    if user['account_id'] != seller_id:
        return jsonify({"message": "Forbidden"}), 403

    product_id = request.args.get('product_id', type=int)
    conn, cur = get_db_conn()

    if product_id:
        # READ ONE Product
        cur.execute("SELECT * FROM product WHERE seller_account_id = %s AND product_id = %s", (seller_id, product_id))
        product = cur.fetchone()
        if not product:
            return jsonify({"message": "Product not found"}), 404
        return jsonify(product)
    else:
        # READ ALL Products
        cur.execute("SELECT * FROM product WHERE seller_account_id = %s", (seller_id,))
        return jsonify(cur.fetchall())


@app.route('/api/seller/<int:seller_id>/product', methods=['POST'])
@require_seller
def api_seller_product_create(seller_id):
    """API to ADD a new product (handles both JSON and form data including files)"""
    user = session['user']
    if user['account_id'] != seller_id:
        return jsonify({"message": "Forbidden"}), 403

    # Use request.form for fields and request.files for file uploads
    data = request.form.to_dict()

    name = data.get('name')
    category = data.get('category')
    price = data.get('price')
    stock_quantity = data.get('stock_quantity')
    description = data.get('description')
    
    if not all([name, category, price, stock_quantity]):
        return jsonify({'message': 'Missing required product fields (name, category, price, stock_quantity)'}), 400

    # FIX: Generate the product slug
    product_slug = create_slug(name) 

    main_image_url = None
    if 'main_image' in request.files:
        file = request.files['main_image']
        # Pass the folder_key='product'
        main_image_url = handle_image_upload(file, name, folder_key='product')

    insert_sql = """
    INSERT INTO product (
        seller_account_id, name, description, category, price, stock_quantity, 
        is_active, main_image_url, product_slug 
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    values = (
        seller_id, 
        name, 
        description, 
        category, 
        float(price), 
        int(stock_quantity), 
        data.get('is_active', True), 
        main_image_url, 
        product_slug # Correctly placed as the last value
    )
    
    conn, cur = get_db_conn()
    try:
        cur.execute(insert_sql, values)
        conn.commit()
        return jsonify({
            'message': 'Product created successfully',
            'product_id': cur.lastrowid,
            'image_url': main_image_url
        }), 201
    except mysql.connector.Error as err:
        conn.rollback()
        # In a production app, handle specific errors (e.g., integrity constraint on category)
        print(f"Database Error: {err}") 
        return jsonify({'message': f'Failed to create product: {err.msg}'}), 500

@app.route('/api/seller/<int:seller_id>/product/<int:product_id>', methods=['PUT', 'DELETE'])
@require_seller
def api_seller_product_modify(seller_id, product_id):
    user = session['user']
    if user['account_id'] != seller_id:
        return jsonify({"message": "Forbidden"}), 403

    conn, cur = get_db_conn()
    
    # Check if product exists and belongs to the seller
    cur.execute("SELECT * FROM product WHERE product_id = %s AND seller_account_id = %s", (product_id, seller_id))
    product_exists = cur.fetchone()
    if not product_exists:
        return jsonify({"message": "Product not found or does not belong to this seller"}), 404

    if request.method == 'DELETE':
        # DELETE Product
        try:
            cur.execute("DELETE FROM product WHERE product_id = %s", (product_id,))
            conn.commit()
            return jsonify({'message': f'Product {product_id} deleted successfully'}), 200
        except Exception as e:
            conn.rollback()
            return jsonify({'message': f'Failed to delete product: {str(e)}'}), 500

    elif request.method == 'PUT':
        # EDIT Product
        data = request.form.to_dict()
        updates = []
        values = []

        # Define fields and their required type casting
        field_converters = {
            'name': str, 'description': str, 'category': str, 
            'price': float, 'stock_quantity': int, 'is_active': int
        }
        
        for field, converter in field_converters.items():
            if field in data:
                try:
                    # Cast value to the correct type for SQL
                    updates.append(f"{field} = %s")
                    values.append(converter(data[field]))
                except ValueError:
                    return jsonify({'message': f'Invalid value provided for {field}'}), 400

        # Handle image update
        old_image_filename = product_exists.get('main_image_url') # <-- 1. STORE OLD FILENAME
        new_image_url = None # Initialize new URL
        
        if 'main_image' in request.files:
            file = request.files['main_image']
            
            # Only upload if a file is actually selected (size > 0)
            if file and file.filename:
                # Upload the new image using the corrected helper function
                new_image_url = handle_image_upload(file, data.get('name', product_exists['name']), folder_key='product') 
                
                if new_image_url:
                    
                    # 2. DELETE OLD IMAGE if a new one was successfully saved
                    if old_image_filename:
                        delete_old_image(old_image_filename, folder_key='product') 
                    
                    # Update the database field to the new URL
                    updates.append("main_image_url = %s")
                    values.append(new_image_url) # Use new_image_url for DB update

        if not updates:
            return jsonify({'message': 'No fields provided for update'}), 400

        values.append(product_id)
        
        update_sql = f"UPDATE product SET {', '.join(updates)} WHERE product_id = %s"


        try:
            cur.execute(update_sql, tuple(values))
            conn.commit()
            return jsonify({
                'message': f'Product {product_id} updated successfully',
                'image_url': new_image_url if new_image_url else old_image_filename
            }), 200
        except mysql.connector.Error as err:
            conn.rollback()
            return jsonify({'message': f'Failed to update product: {err.msg}'}), 500


@app.route('/api/seller/<int:seller_id>/sales/monthly', methods=['GET'])
@require_seller
def api_seller_monthly_sales(seller_id):
    """API to retrieve monthly sales data for a graph."""
    user = session['user']
    if user['account_id'] != seller_id:
        return jsonify({"message": "Forbidden"}), 403

    conn, cur = get_db_conn()
    
    # SQL to aggregate sales by month/year for the given seller
    cur.execute("""
        SELECT 
            YEAR(o.order_date) AS year,
            MONTH(o.order_date) AS month,
            SUM(oi.subtotal) AS monthly_sales
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN product p ON oi.product_id = p.product_id
        WHERE p.seller_account_id = %s
        AND o.payment_status = 'Paid'
        GROUP BY year, month
        ORDER BY year DESC, month DESC
    """, (seller_id,))

    monthly_data = cur.fetchall()

    # Format data for the graph (optional: fill in zero sales months)
    formatted_data = [
        {
            "year": row['year'],
            "month": row['month'],
            "label": datetime.date(row['year'], row['month'], 1).strftime('%b %Y'), # e.g., 'Jan 2025'
            "sales": float(row['monthly_sales'] or 0)
        }
        for row in monthly_data
    ]

    return jsonify(formatted_data)

@app.route('/api/seller/<int:seller_id>/sales', methods=['GET'])
@require_seller
def api_seller_sales(seller_id):
    # Existing total sales/orders summary (kept for completeness)
    user = session['user']
    if user['account_id'] != seller_id:
        return jsonify({"message": "Forbidden"}), 403

    conn, cur = get_db_conn()
    cur.execute("""
        SELECT 
            SUM(oi.subtotal) AS total_sales,
            COUNT(DISTINCT o.order_id) AS total_orders,
            AVG(o.total_amount) AS average_order_value
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN product p ON oi.product_id = p.product_id
        WHERE p.seller_account_id = %s
        AND o.payment_status = 'Paid'
    """, (seller_id,))

    row = cur.fetchone()

    return jsonify({
        "total_sales": float(row["total_sales"] or 0),
        "total_orders": row["total_orders"] or 0,
        "average_order_value": float(row["average_order_value"] or 0)
    })

# -----------------------
# FILE ROUTES
# -----------------------
@app.route('/uploads/<folder>/<filename>') # <-- NEW ROUTE
def uploaded_file(folder, filename):
    """Serves files from specific subdirectories based on the URL structure."""
    
    # Map the URL 'folder' segment to the actual disk path using UPLOAD_FOLDERS
    base_dir = app.config['UPLOAD_FOLDERS'].get(folder)
    
    if not base_dir:
        # Prevent accessing files outside of defined upload folders
        abort(404) 
        
    # Serve the file from the calculated full path
    return send_from_directory(base_dir, filename)

def delete_old_image(filename, folder_key='product'):
    """Deletes an image file from the specified upload folder."""
    
    if not filename:
        return # Nothing to delete
        
    # FIX: Use the 'app' instance defined globally in app.py
    target_folder = app.config['UPLOAD_FOLDERS'].get(folder_key)
    
    if not target_folder:
        # Log this error or handle it as appropriate
        print(f"Error: Invalid folder key '{folder_key}' provided for deletion.")
        return
        
    file_path = os.path.join(target_folder, filename)
    
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f"Successfully deleted old file: {file_path}")
        else:
            # This is okay, maybe the file was already deleted or never existed
            print(f"Warning: File not found for deletion: {file_path}")
    except Exception as e:
        print(f"Error deleting file {file_path}: {e}")



# -----------------------
# RUN
# -----------------------
if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)
