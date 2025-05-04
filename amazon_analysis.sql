-- ========================================
-- Amazon Project: Data Exploration & Cleaning
-- ========================================

-- ================
-- Initial Exploration
-- ================
SELECT * FROM category;
SELECT * FROM customer;
SELECT * FROM orders;
SELECT * FROM inventory;
SELECT * FROM product;
SELECT * FROM order_items;
SELECT * FROM payment;
SELECT * FROM shipping;

-- Check returned shipments
SELECT * FROM shipping 
WHERE return_date IS NOT NULL;

-- ========================================
-- 1. Top Selling Products
-- Objective: Identify top 10 products by total sales revenue
-- ========================================

-- Add new column for calculated revenue
ALTER TABLE order_items 
ADD COLUMN total_sale FLOAT;

-- Populate 'total_sale' column as quantity × price_per_unit
UPDATE order_items 
SET total_sale = quantity * price_per_unit;

-- Fetch top 10 selling products with total revenue and order count
SELECT 
    p.product_id,
    p.product_name,
    ROUND(SUM(oi.total_sale)::NUMERIC, 2) AS total_sale_revenue,
    COUNT(o.order_id) AS total_orders
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN product p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_sale_revenue DESC
LIMIT 10;

-- ========================================
-- 2. Revenue by Category
-- Objective: Revenue per product category and percentage contribution
-- ========================================
SELECT 
    c.category_id,
    c.category_name,
    ROUND(SUM(oi.total_sale)::NUMERIC, 2) AS total_revenue,
    ROUND(
        SUM(oi.total_sale)::NUMERIC / 
        (SELECT SUM(total_sale)::NUMERIC FROM order_items) * 100, 2
    ) AS percentage_contribution
FROM product p
JOIN order_items oi USING(product_id)
LEFT JOIN category c USING(category_id)
GROUP BY c.category_id, c.category_name;

-- ========================================
-- 3. Average Order Value (AOV)
-- Objective: Average customer spending (AOV), for customers with >5 orders
-- ========================================
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name,
    COUNT(o.order_id) AS no_of_orders,
    ROUND(AVG(total_sale)::NUMERIC, 2) AS average_spending
FROM orders o
JOIN order_items oi USING(order_id)
LEFT JOIN customer c USING(customer_id)
GROUP BY c.customer_id, full_name
HAVING COUNT(o.order_id) > 5
ORDER BY average_spending DESC;

-- ========================================
-- 4. Monthly Sales Trend
-- Objective: Compare monthly sales including previous month's sales
-- ========================================
SELECT   
    year,
    month,
    total_sale AS current_month_sale,
    LAG(total_sale, 1) OVER(ORDER BY year, month) AS prev_month_sale
FROM (
    SELECT 
        EXTRACT(YEAR FROM o.order_date) AS year,
        EXTRACT(MONTH FROM o.order_date) AS month,
        ROUND(SUM(oi.total_sale)::NUMERIC, 2) AS total_sale
    FROM orders o
    JOIN order_items oi USING(order_id)
    WHERE order_date >= CURRENT_DATE - INTERVAL '20 months'
    GROUP BY year, month
    ORDER BY year, month
) AS t1;

-- ========================================
-- 5. Customers with No Purchases
-- Objective: Identify customers who registered but never placed any orders
-- ========================================
SELECT *
FROM customer c
LEFT JOIN orders o USING(customer_id)
WHERE o.order_id IS NULL;
