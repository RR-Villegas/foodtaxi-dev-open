"""Helper utilities (stubs) to collect common functions.

Move functions like `create_slug`, `allowed_file`, and `get_db_conn`
here in small steps. Keeping them in one module improves discoverability.
"""
import re
import unicodedata
import os
import datetime
from flask import current_app, session
from werkzeug.utils import secure_filename

from foodtaxi.db import get_db_conn


def create_slug(text: str) -> str:
    """Convert a string into a URL-friendly slug.

    This is a simple implementation. Replace with the project's
    exact logic when migrating.
    """
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^a-zA-Z0-9-\s]", "", text).strip().lower()
    return re.sub(r"[\s]+", "-", text)


def allowed_file(filename: str, allowed_extensions=None) -> bool:
    if allowed_extensions is None:
        allowed_extensions = {"png", "jpg", "jpeg", "pdf"}
    return "." in filename and filename.rsplit(".", 1)[1].lower() in allowed_extensions


def get_session_cart_count():
    """Calculates the total quantity of items in the session-based cart."""
    session_cart = session.get('guest_cart', {})
    return sum(session_cart.values())


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
    except Exception:
        return 0


def auto_approve_seller(account_id, firstname, surname):
    """Auto-create a seller_application and store for a verified seller."""
    conn, cur = get_db_conn()
    now = datetime.datetime.now()
    store_name = f"{firstname}'s {surname} Shop"
    slug = store_name.lower().replace(" ", "-").replace("'", "")

    try:
        cur.execute("SELECT account_id FROM seller_application WHERE account_id = %s", (account_id,))
        if cur.fetchone():
            cur.execute("SELECT owner_account_id FROM store WHERE owner_account_id = %s", (account_id,))
            if cur.fetchone():
                return "Seller application and store already exist."

        cur.execute("SELECT account_id FROM seller_application WHERE account_id = %s", (account_id,))
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

    except Exception as err:
        conn.rollback()
        return f"Failed to auto-approve seller: {err}"


def handle_image_upload(file, product_name, folder_key='product'):
    """Save uploaded file into configured upload folder and return filename."""
    target_folder = current_app.config['UPLOAD_FOLDERS'].get(folder_key)
    if not target_folder:
        return None

    if file and allowed_file(file.filename, current_app.config.get('ALLOWED_EXTENSIONS')):
        base, ext = os.path.splitext(secure_filename(file.filename))
        unique_filename = f"{product_name.replace(' ', '_')}_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}{ext.lower()}"
        file.save(os.path.join(target_folder, unique_filename))
        return unique_filename
    return None


def delete_old_image(filename, folder_key='product'):
    if not filename:
        return
    target_folder = current_app.config['UPLOAD_FOLDERS'].get(folder_key)
    if not target_folder:
        return
    file_path = os.path.join(target_folder, filename)
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
    except Exception:
        pass
