-- ====================================
-- Amazon Project: Schema Definition
-- ====================================

-- =====================
-- DROP TABLES (if exist)
-- =====================
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS shipping;
DROP TABLE IF EXISTS payment;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS seller;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS category;

-- =====================
-- CATEGORY TABLE
-- =====================
CREATE TABLE category (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(20)
);

-- =====================
-- CUSTOMER TABLE
-- =====================
CREATE TABLE customer (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(30),
    last_name VARCHAR(20),
    state VARCHAR(20),
    address VARCHAR(5) DEFAULT 'xxxx'  -- Default placeholder address
);

-- =====================
-- SELLER TABLE
-- =====================
CREATE TABLE seller (
    seller_id INT PRIMARY KEY,
    seller_name VARCHAR(25),
    origin VARCHAR(20)  -- Country or region of the seller
);

-- =====================
-- PRODUCT TABLE
-- =====================
CREATE TABLE product (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(50),
    price FLOAT,             -- Selling price
    cogs FLOAT,              -- Cost of goods sold
    category_id INT,
    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES category(category_id)
);

-- =====================
-- ORDERS TABLE
-- =====================
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    order_date DATE,
    customer_id INT,
    seller_id INT,
    order_status VARCHAR(15),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id),
    CONSTRAINT fk_orders_seller
        FOREIGN KEY (seller_id)
        REFERENCES seller(seller_id)
);

-- ===========================
-- ORDER ITEMS TABLE
-- ===========================
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    price_per_unit FLOAT,
    CONSTRAINT fk_order_items_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES product(product_id)
);

-- =====================
-- PAYMENT TABLE
-- =====================
CREATE TABLE payment (
    payment_id INT PRIMARY KEY,
    order_id INT,
    payment_date DATE,
    payment_status VARCHAR(25),
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);

-- =====================
-- SHIPPING TABLE
-- =====================
CREATE TABLE shipping (
    shipping_id INT PRIMARY KEY,
    order_id INT,
    shipping_date DATE,
    return_date DATE,
    shipping_providers VARCHAR(15),
    delivery_status VARCHAR(15),
    CONSTRAINT fk_shipping_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);

-- =====================
-- INVENTORY TABLE
-- =====================
CREATE TABLE inventory (
    inventory_id INT PRIMARY KEY,
    product_id INT,
    stock INT,
    warehouse_id INT,
    last_stock_date DATE,
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id)
        REFERENCES product(product_id)
);
