-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.account (
  account_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  auth_id uuid NOT NULL UNIQUE,
  firstname text NOT NULL,
  surname text NOT NULL,
  email text NOT NULL UNIQUE,
  phone_number text UNIQUE,
  account_type text DEFAULT 'Buyer'::text CHECK (account_type = ANY (ARRAY['Buyer'::text, 'Seller'::text, 'Rider'::text])),
  is_email_verified boolean DEFAULT false,
  is_verified boolean DEFAULT false,
  date_created timestamp with time zone DEFAULT now(),
  date_verified timestamp with time zone,
  CONSTRAINT account_pkey PRIMARY KEY (account_id)
);
CREATE TABLE public.account_verification (
  verification_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  account_id uuid NOT NULL,
  verification_type text NOT NULL CHECK (verification_type = ANY (ARRAY['Buyer'::text, 'Seller'::text, 'Rider'::text])),
  otp_code text,
  otp_expiry timestamp with time zone,
  otp_verified boolean DEFAULT false,
  otp_method text DEFAULT 'Email'::text CHECK (otp_method = ANY (ARRAY['Email'::text, 'SMS'::text])),
  status text DEFAULT 'Pending OTP'::text CHECK (status = ANY (ARRAY['Pending OTP'::text, 'Pending Review'::text, 'Approved'::text, 'Rejected'::text])),
  submission_date timestamp with time zone DEFAULT now(),
  verification_date timestamp with time zone,
  review_notes text,
  CONSTRAINT account_verification_pkey PRIMARY KEY (verification_id),
  CONSTRAINT account_verification_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(account_id)
);
CREATE TABLE public.address (
  address_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  account_id uuid,
  province text NOT NULL,
  city text NOT NULL,
  barangay text NOT NULL,
  street text NOT NULL,
  house_number text,
  zip_code text,
  is_default boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT address_pkey PRIMARY KEY (address_id),
  CONSTRAINT address_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(account_id)
);
CREATE TABLE public.order_items (
  order_item_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid,
  product_id uuid,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price_at_sale numeric NOT NULL,
  subtotal numeric NOT NULL,
  CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id),
  CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(product_id)
);
CREATE TABLE public.orders (
  order_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  buyer_account_id uuid,
  seller_account_id uuid,
  order_date timestamp with time zone DEFAULT now(),
  payment_method text DEFAULT 'COD'::text CHECK (payment_method = ANY (ARRAY['COD'::text, 'Gcash'::text])),
  payment_status text DEFAULT 'Pending'::text CHECK (payment_status = ANY (ARRAY['Pending'::text, 'Paid'::text, 'Failed'::text, 'Refunded'::text])),
  order_status text DEFAULT 'Processing'::text CHECK (order_status = ANY (ARRAY['Processing'::text, 'Ready for Pickup'::text, 'In Transit'::text, 'Delivered'::text, 'Cancelled'::text])),
  total_amount numeric NOT NULL,
  shipping_fee numeric DEFAULT 0,
  address_id uuid,
  rider_account_id uuid,
  CONSTRAINT orders_pkey PRIMARY KEY (order_id),
  CONSTRAINT orders_buyer_account_id_fkey FOREIGN KEY (buyer_account_id) REFERENCES public.account(account_id),
  CONSTRAINT orders_seller_account_id_fkey FOREIGN KEY (seller_account_id) REFERENCES public.account(account_id),
  CONSTRAINT orders_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id),
  CONSTRAINT orders_rider_account_id_fkey FOREIGN KEY (rider_account_id) REFERENCES public.account(account_id)
);
CREATE TABLE public.product (
  product_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  store_id uuid,
  category text CHECK (category = ANY (ARRAY['Baking Supplies & Ingredients'::text, 'Coffee, Tea & Beverages'::text, 'Snacks & Candy'::text, 'Specialty Foods & International Cuisine'::text, 'Organic and Health Foods'::text, 'Meal Kits & Prepped Foods'::text])),
  name text NOT NULL,
  description text,
  price numeric NOT NULL CHECK (price >= 0::numeric),
  stock_quantity integer DEFAULT 0 CHECK (stock_quantity >= 0),
  sku text UNIQUE,
  is_active boolean DEFAULT true,
  main_image_url text,
  CONSTRAINT product_pkey PRIMARY KEY (product_id),
  CONSTRAINT product_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.store(store_id)
);
CREATE TABLE public.rider_application (
  rider_app_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  account_id uuid UNIQUE,
  license_number text NOT NULL,
  vehicle_type text CHECK (vehicle_type = ANY (ARRAY['Motorcycle'::text, 'Bicycle'::text, 'Van'::text])),
  plate_number text NOT NULL UNIQUE,
  documents_path jsonb,
  otp_code text,
  otp_expiry timestamp with time zone,
  otp_verified boolean DEFAULT false,
  otp_method text DEFAULT 'Email'::text CHECK (otp_method = ANY (ARRAY['Email'::text, 'SMS'::text])),
  application_date timestamp with time zone DEFAULT now(),
  status text DEFAULT 'Pending OTP'::text CHECK (status = ANY (ARRAY['Pending OTP'::text, 'Pending Review'::text, 'Approved'::text, 'Rejected'::text])),
  review_notes text,
  date_approved timestamp with time zone,
  CONSTRAINT rider_application_pkey PRIMARY KEY (rider_app_id),
  CONSTRAINT rider_application_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(account_id)
);
CREATE TABLE public.seller_application (
  application_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  account_id uuid UNIQUE,
  store_name text NOT NULL,
  store_description text,
  contact_phone text,
  province text NOT NULL,
  city text NOT NULL,
  barangay text NOT NULL,
  street text NOT NULL,
  house_number text,
  zip_code text,
  status text DEFAULT 'Pending OTP'::text CHECK (status = ANY (ARRAY['Pending OTP'::text, 'Pending Review'::text, 'Approved'::text, 'Rejected'::text])),
  otp_code text,
  otp_expiry timestamp with time zone,
  otp_verified boolean DEFAULT false,
  submission_date timestamp with time zone DEFAULT now(),
  review_notes text,
  date_approved timestamp with time zone,
  CONSTRAINT seller_application_pkey PRIMARY KEY (application_id),
  CONSTRAINT seller_application_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(account_id)
);
CREATE TABLE public.store (
  store_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  owner_account_id uuid UNIQUE,
  store_name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  province text,
  city text,
  barangay text,
  street text,
  house_number text,
  zip_code text,
  contact_phone text,
  is_open boolean DEFAULT true,
  date_opened timestamp with time zone DEFAULT now(),
  CONSTRAINT store_pkey PRIMARY KEY (store_id),
  CONSTRAINT store_owner_account_id_fkey FOREIGN KEY (owner_account_id) REFERENCES public.account(account_id)
);