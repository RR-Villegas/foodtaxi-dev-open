-- ===================================
-- RESET DATABASE
-- ===================================
DROP DATABASE IF EXISTS foodweb_db;
CREATE DATABASE foodweb_db;
USE foodweb_db;

-- ===================================
-- ACCOUNTS TABLE
-- ===================================
CREATE TABLE accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    account_password VARCHAR(255) NOT NULL,
    user_type ENUM('buyer', 'seller', 'admin', 'rider') DEFAULT 'buyer',
    email_status ENUM('unverified', 'verified') DEFAULT 'unverified',
    verification_token VARCHAR(255) DEFAULT NULL,
    mobile_number VARCHAR(15),
    profile_image VARCHAR(255) DEFAULT NULL,

    -- Address fields
    home_number VARCHAR(20),
    street VARCHAR(100),
    barangay VARCHAR(100),
    municipality VARCHAR(100),
    city VARCHAR(100),
    province VARCHAR(100),
    zip_code VARCHAR(10),

    -- Timestamps
    date_registered DATETIME DEFAULT CURRENT_TIMESTAMP,
    account_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ===================================
-- PRODUCTS TABLE
-- ===================================
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    seller_id INT NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    maker VARCHAR(100),
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    image VARCHAR(255) DEFAULT NULL,
    gallery JSON DEFAULT NULL,
    size_type ENUM('weight', 'volume', 'count') DEFAULT 'weight',  -- e.g. 500g, 1L, 6pcs
    sizes JSON DEFAULT NULL,                                       -- ["250g", "500g", "1kg"]
    stock_quantity INT DEFAULT 0,
    category ENUM(
        'Baking Supplies & Ingredients',
        'Coffee, Tea & Beverages',
        'Snacks & Candy',
        'Specialty Foods & International Cuisine',
        'Organic and Health Foods',
        'Meal Kits & Prepped Foods'
    ) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_products_seller FOREIGN KEY (seller_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE
);

-- ===================================
-- ORDERS TABLE
-- ===================================
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    order_status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    payment_method ENUM('cod', 'gcash', 'card') DEFAULT 'cod',
    total_price DECIMAL(10,2) DEFAULT 0.00,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_orders_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE
);

-- ===================================
-- APPLICATIONS TABLE
-- ===================================
CREATE TABLE applications (
    application_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    application_type ENUM('seller', 'rider') NOT NULL,
    STATUS ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    application_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    reviewed_date DATETIME DEFAULT NULL,
    reviewed_by INT DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    store_name VARCHAR(100),
    store_description TEXT,
    business_address TEXT,
    business_permit VARCHAR(255),

    CONSTRAINT fk_applications_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_applications_reviewer FOREIGN KEY (reviewed_by)
        REFERENCES accounts(account_id)
        ON DELETE SET NULL
);

-- ===================================
-- SELLER STORES TABLE
-- ===================================
CREATE TABLE seller_stores (
    store_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL UNIQUE,
    store_name VARCHAR(100) NOT NULL,
    store_description TEXT,
    business_address TEXT,
    business_permit VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_seller_stores_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE
);

-- ===================================
-- ORDER ITEMS TABLE
-- ===================================
CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price_each DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantity * price_each) STORED,

    CONSTRAINT fk_items_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_items_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE CASCADE
);
