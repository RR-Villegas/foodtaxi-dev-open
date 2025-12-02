# app.py
import os
import datetime
import json
import random
import string
from functools import wraps

from flask import Flask, request, jsonify, g, send_from_directory, render_template, session, redirect, url_for, abort
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
def get_db_conn():
    if 'db_conn' not in g:
        g.db_conn = db_pool.get_connection()
        g.db_cursor = g.db_conn.cursor(dictionary=True)
    return g.db_conn, g.db_cursor

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


# -----------------------
# STANDARD PAGE ROUTES
# -----------------------
@app.route('/')
def index():
    current_user = session.get('user', {'is_authenticated': False})
    if current_user != {'is_authenticated': False}:
        current_user['is_authenticated'] = True

    return render_template(
        'index.html',
        trending_items=[],
        random_items=[],
        now=datetime.datetime.now(),
        current_user=current_user,
        cart_item_count=0
    )

@app.context_processor
def inject_user():
    current_user = session.get('user', {'is_authenticated': False})
    if current_user != {'is_authenticated': False}:
        current_user['is_authenticated'] = True
    return dict(current_user=current_user)


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
    sql_base = "SELECT product_id, name, price, main_image_url, description FROM product WHERE is_active = TRUE"
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
    return "Seller Application Form Placeholder"

@app.route('/rider-application')
def rider_application():
    return "Rider Application Form Placeholder"

@app.route('/shop')
def shop():
    return "All Products Page Placeholder"

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

@app.route('/account')
def account():
    return "Account Dashboard Placeholder"

@app.route('/cart')
def cart():
    return render_template("_partials/cart.html")

# In app.py, place this with your other simple routes or API routes:

@app.route('/cart/add', methods=['POST'])
def add_to_cart():
    """
    Handles adding a product to the user's shopping cart (stored in the session).
    This function must be named 'add_to_cart' to match the url_for() call.
    """
    
    # 1. Get product_id from the form submission
    product_id = request.form.get('product_id', type=int)
    
    if not product_id:
        # Handle case where product ID is missing
        return redirect(url_for('shop')) # Redirect to a safe page

    # Initialize cart in session if it doesn't exist: {product_id: quantity}
    if 'cart' not in session:
        session['cart'] = {}
        
    cart = session['cart']
    
    # Simple logic: Add 1 to the quantity, or set to 1 if new
    cart[product_id] = cart.get(product_id, 0) + 1
    
    # Important: Flask sessions sometimes require modification flag for complex objects
    session.modified = True
    
    # 2. Redirect the user back to the cart or the search results page
    # It's better UX to redirect to the cart or the page they were on.
    
    # Get the URL of the previous page (referrer)
    next_url = request.referrer or url_for('cart')
    
    return redirect(next_url)

# Note: The endpoint is 'add_to_cart' but the URL is '/cart/add'.


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

    session['user'] = {
        'account_id': user['account_id'],
        'firstname': user['firstname'],
        'surname': user['surname'],
        'email': user['email'],
        'phone_number': user['phone_number'],
        'account_type': user['account_type'],
        'is_authenticated': True
    }

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

    # app.py (Around Line 646)

    # ... (omitted previous lines) ...
    main_image_url = None
    if 'main_image' in request.files:
        file = request.files['main_image']
        # FIX: Pass the folder_key='product'
        main_image_url = handle_image_upload(file, name, folder_key='product') 

    insert_sql = """
    INSERT INTO product (
        seller_account_id, name, description, category, price, stock_quantity, 
        is_active, main_image_url
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """

    values = (
        seller_id, name, description, category, float(price), int(stock_quantity),
        data.get('is_active', True), main_image_url
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
