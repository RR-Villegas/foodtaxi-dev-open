DROP DATABASE IF EXISTS foodtaxi_omega;
CREATE DATABASE foodtaxi_omega;
USE foodtaxi_omega;

-- 1. ACCOUNT Table (Core Identity)
CREATE TABLE account (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    firstname VARCHAR(100) NOT NULL,
    surname VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    
    -- Address
    home_address VARCHAR(255),
    street_address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    region VARCHAR(100),
    zip_code VARCHAR(10),
    
    phone_number VARCHAR(20) UNIQUE NOT NULL, 
    password_hash VARCHAR(255) NOT NULL,
    account_type ENUM('Buyer', 'Seller', 'Rider') NOT NULL DEFAULT 'Buyer',
    
    -- Verification status
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    
    date_created DATETIME DEFAULT CURRENT_TIMESTAMP,
    date_verified DATETIME
);
-- 2. PRODUCT Table (Inventory)
-- Reverting the PRODUCT Table to use the specified ENUM for Category
CREATE TABLE product (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Relationship to the Seller
    seller_account_id INT NOT NULL,
    
    -- CATEGORIZATION using the fixed ENUM list
    category ENUM(
        'Baking Supplies & Ingredients',
        'Coffee, Tea & Beverages',
        'Snacks & Candy',
        'Specialty Foods & International Cuisine',
        'Organic and Health Foods',
        'Meal Kits & Prepped Foods'
    ) NOT NULL,
    
    -- Core Details
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Sales & Inventory
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    sku VARCHAR(50) UNIQUE,
    
    -- Status & Visuals
    is_active BOOLEAN DEFAULT TRUE,
    main_image_url VARCHAR(255),
    
    -- Foreign Key Constraint
    FOREIGN KEY (seller_account_id) REFERENCES account(account_id)
);

-- 3. ORDERS Table (Transaction Header - PK renamed to order_id)
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT, -- Renamed from orders_id
    buyer_account_id INT NOT NULL, 
    
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Added separate status for payment vs. fulfillment
    payment_status ENUM('Pending', 'Paid', 'Failed', 'Refunded') NOT NULL DEFAULT 'Pending',
    status ENUM('Processing', 'Ready for Pickup', 'In Transit', 'Delivered', 'Cancelled') NOT NULL DEFAULT 'Processing',
    
    total_amount DECIMAL(10, 2) NOT NULL,
    shipping_fee DECIMAL(10, 2) DEFAULT 0.00,
    
    shipping_address_line VARCHAR(255),
    shipping_city VARCHAR(100),
    
    rider_account_id INT, 
    
    FOREIGN KEY (buyer_account_id) REFERENCES account(account_id),
    FOREIGN KEY (rider_account_id) REFERENCES account(account_id)
);

-- 4. ORDER_ITEMS Table (Transaction Line Items - PK renamed to order_item_id)
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    
    quantity INT NOT NULL,
    unit_price_at_sale DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    
    FOREIGN KEY (order_id) REFERENCES orders(order_id), -- Referenced renamed PK
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    
    UNIQUE KEY (order_id, product_id)
);

-- 5. SELLER_APPLICATION Table
CREATE TABLE seller_application (
    seller_app_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT UNIQUE NOT NULL, 
    
    business_name VARCHAR(255) NOT NULL,
    dti_registration_number VARCHAR(100),
    business_address VARCHAR(255),
    
    -- Document uploads
    documents_path JSON, -- Stores array of file paths {jpg, png, pdf}
    
    -- OTP verification
    otp_code VARCHAR(6),
    otp_expiry DATETIME,
    otp_verified BOOLEAN DEFAULT FALSE,
    otp_method ENUM('Email', 'SMS') DEFAULT 'Email',
    
    application_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending OTP', 'Pending Review', 'Approved', 'Rejected') NOT NULL DEFAULT 'Pending OTP',
    review_notes TEXT,
    date_approved DATETIME,
    
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);

-- 6. RIDER_APPLICATION Table
CREATE TABLE rider_application (
    rider_app_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT UNIQUE NOT NULL, 
    
    license_number VARCHAR(100) NOT NULL,
    vehicle_type ENUM('Motorcycle', 'Bicycle', 'Van') NOT NULL,
    plate_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Document uploads
    documents_path JSON, -- Stores array of file paths {license, vehicle_registration, etc}
    
    -- OTP verification
    otp_code VARCHAR(6),
    otp_expiry DATETIME,
    otp_verified BOOLEAN DEFAULT FALSE,
    otp_method ENUM('Email', 'SMS') DEFAULT 'Email',
    
    application_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending OTP', 'Pending Review', 'Approved', 'Rejected') NOT NULL DEFAULT 'Pending OTP',
    review_notes TEXT,
    date_approved DATETIME,
    
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);

CREATE TABLE buyer_verification (
    verification_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Links to the buyer account
    account_id INT UNIQUE NOT NULL, 
    
    -- OTP verification
    otp_code VARCHAR(6),
    otp_expiry DATETIME,
    otp_verified BOOLEAN DEFAULT FALSE,
    otp_method ENUM('Email', 'SMS') DEFAULT 'Email',
    
    -- Status of the verification
    status ENUM('Pending OTP', 'Verified', 'Rejected') NOT NULL DEFAULT 'Pending OTP',
    
    -- When the request was submitted and finalized
    submission_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    verification_date DATETIME, 
    
    -- Admin notes on the decision
    review_notes TEXT,
    
    -- Foreign Key Constraint
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);

CREATE TABLE product_review (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Relationship to the Subject of the Review
    product_id INT NOT NULL,
    
    -- Relationship to the Author of the Review
    reviewer_account_id INT NOT NULL,
    
    -- Ensuring only purchased items can be reviewed (optional but recommended)
    order_item_id INT UNIQUE, -- Ensures a buyer can only review a specific line item once
    
    -- Feedback Content
    rating TINYINT NOT NULL CHECK (rating >= 1 AND rating <= 5), -- Rating from 1 to 5
    comment TEXT,
    
    -- Metadata
    review_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_approved BOOLEAN DEFAULT TRUE, -- For review moderation
    
    -- Foreign Key Constraints
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    FOREIGN KEY (reviewer_account_id) REFERENCES account(account_id),
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
);

CREATE TABLE seller_rating (
    seller_rating_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Subject and Author of the Rating
    seller_account_id INT NOT NULL, 
    rater_account_id INT NOT NULL, 
    
    -- Link to the Order (Proof of purchase)
    order_id INT UNIQUE NOT NULL, -- Ensures a buyer can only rate the seller once per order
    
    -- Feedback Content
    rating TINYINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    
    -- Metadata
    rating_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (seller_account_id) REFERENCES account(account_id),
    FOREIGN KEY (rater_account_id) REFERENCES account(account_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE transaction (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Relationship to the Business Logic
    order_id INT UNIQUE NOT NULL, -- One successful payment per order
    
    -- Financial Details
    amount DECIMAL(10, 2) NOT NULL,
    gateway_fee DECIMAL(10, 2) DEFAULT 0.00, -- Fee charged by the payment processor
    payment_method VARCHAR(50), -- e.g., 'Credit Card', 'GCash', 'Cash on Delivery'
    
    -- External Gateway Reference
    gateway_tx_id VARCHAR(255) UNIQUE NOT NULL, -- The unique ID provided by the payment processor (e.g., Stripe, PayMongo)
    
    -- Status and Timing
    status ENUM('Success', 'Failed', 'Pending', 'Refunded') NOT NULL,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraint
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE store (
    store_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Unique link to the owner's account. 
    -- This key serves as the check that the seller_application was approved.
    owner_account_id INT UNIQUE NOT NULL, 
    
    -- Public-Facing Store Details
    store_name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL, -- URL-friendly identifier (e.g., foodtaxi.com/stores/store-name)
    description TEXT,
    
    -- Location/Address Details (Where orders are prepared)
    address_line VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    
    -- Contact and Status
    contact_phone VARCHAR(20),
    is_open BOOLEAN DEFAULT TRUE, -- Flag to quickly open/close the store for business
    
    -- Metadata
    date_opened DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraint
    FOREIGN KEY (owner_account_id) REFERENCES account(account_id)
);

CREATE TABLE rider_rating (
    rider_rating_id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Subject and Author of the Rating
    rider_account_id INT NOT NULL, 
    rater_account_id INT NOT NULL, 
    
    -- Link to the Delivery Event (Proof of service)
    order_id INT UNIQUE NOT NULL, -- Ensures a buyer can only rate the rider once per order
    
    -- Feedback Content
    rating TINYINT NOT NULL CHECK (rating >= 1 AND rating <= 5), -- Rating from 1 to 5
    comment TEXT,
    
    -- Metadata
    rating_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (rider_account_id) REFERENCES account(account_id),
    FOREIGN KEY (rater_account_id) REFERENCES account(account_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE product_click (
    click_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    
    -- When the click/view occurred (crucial for time-based carousels)
    click_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Which product was viewed/clicked
    product_id INT NOT NULL,
    
    -- Who did the clicking (can be NULL for anonymous users)
    account_id INT NULL, 
    
    -- Where the click came from (useful for optimizing traffic sources)
    source_page VARCHAR(100), -- e.g., 'Homepage', 'Search Results', 'Category Page', 'Carousel'
    
    -- Session details (to link multiple clicks within a single visit)
    session_id VARCHAR(255),
    
    -- Foreign Key Constraints
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    FOREIGN KEY (account_id) REFERENCES account(account_id)
);