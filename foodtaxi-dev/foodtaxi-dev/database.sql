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
    region VARCHAR(100),
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
-- ORDER_ITEMS TABLE
-- ===================================
CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price_each DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantity * price_each) STORED,

    CONSTRAINT fk_orderitems_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_orderitems_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
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



CREATE TABLE product_reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    buyer_id INT NOT NULL,
    rating TINYINT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_product FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_review_buyer FOREIGN KEY (buyer_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE

);
CREATE TABLE riders (
    rider_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    current_location VARCHAR(255), -- optional for map integration
    status ENUM('available', 'delivering', 'offline') DEFAULT 'available',
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
-- ===================================
-- ORDERS TABLE (with latitude & longitude)
-- ===================================
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,

    -- Buyer / customer
    account_id INT NOT NULL,

    -- Fulfillment type (standard = shipped, instant = food delivery)
    fulfillment_type ENUM('standard', 'instant') DEFAULT 'standard',

    -- Payment info
    payment_method ENUM('cod', 'gcash', 'credit_card', 'bank') DEFAULT 'cod',
    payment_status ENUM('unpaid', 'paid', 'refunded') DEFAULT 'unpaid',

    -- Order status flow
    order_status ENUM(
        'pending',
        'processing',
        'to_ship',
        'shipped',
        'out_for_delivery',
        'delivered',
        'cancelled'
    ) DEFAULT 'pending',

    -- Pricing details
    total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    grand_total DECIMAL(10,2) AS (total_price + delivery_fee) STORED,

    -- Address & coordinates
    address TEXT,
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(10),

    latitude DECIMAL(10, 7) DEFAULT NULL,   -- e.g., 14.1693
    longitude DECIMAL(10, 7) DEFAULT NULL,  -- e.g., 121.3400

    contact_number VARCHAR(20),

    -- Metadata
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Relationship
    CONSTRAINT fk_order_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
        ON DELETE CASCADE
);
-- ===================================
-- DELIVERIES TABLE
-- ===================================
CREATE TABLE deliveries (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,

    -- Linked to order
    order_id INT NOT NULL,
    rider_id INT DEFAULT NULL,  -- NULL until a rider is assigned

    -- Delivery progress
    delivery_status ENUM(
        'pending',          -- waiting for rider assignment
        'assigned',         -- rider accepted
        'picked_up',        -- picked up from seller
        'in_transit',       -- currently being delivered
        'arrived',          -- arrived near location
        'delivered',        -- completed
        'failed',           -- customer unreachable / failed delivery
        'cancelled'         -- cancelled by seller or rider
    ) DEFAULT 'pending',

    -- Timing info
    assigned_at DATETIME DEFAULT NULL,
    picked_up_at DATETIME DEFAULT NULL,
    delivered_at DATETIME DEFAULT NULL,

    -- Rider location (optional live tracking)
    rider_lat DECIMAL(10,7) DEFAULT NULL,
    rider_lng DECIMAL(10,7) DEFAULT NULL,

    -- Destination (copied from order for faster access)
    dest_lat DECIMAL(10,7) DEFAULT NULL,
    dest_lng DECIMAL(10,7) DEFAULT NULL,
    delivery_address TEXT,

    -- Estimated & actual distance/time
    estimated_distance_km DECIMAL(6,2) DEFAULT NULL,
    estimated_time_mins INT DEFAULT NULL,
    actual_distance_km DECIMAL(6,2) DEFAULT NULL,
    actual_time_mins INT DEFAULT NULL,

    -- Notes or issues
    notes TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Relationships
    CONSTRAINT fk_delivery_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_delivery_rider FOREIGN KEY (rider_id)
        REFERENCES riders(rider_id)
        ON DELETE SET NULL
);
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,

    order_id INT NOT NULL,
    account_id INT NOT NULL,

    payment_method ENUM('cod', 'gcash', 'credit_card', 'bank') NOT NULL,
    payment_status ENUM('unpaid', 'paid', 'pending', 'failed') DEFAULT 'unpaid',

    amount DECIMAL(10,2) NOT NULL,
    reference_number VARCHAR(255) DEFAULT NULL,   -- e.g. GCash Ref, mock card txn ID
    proof_image VARCHAR(255) DEFAULT NULL,        -- OPTIONAL: file upload for bank transfer

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE,

    CONSTRAINT fk_payments_account FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE
);
