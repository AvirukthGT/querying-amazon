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
-- Objective: Identifying top 10 products by total sales revenue
-- ========================================

-- Add new column for calculated revenue
ALTER TABLE order_items 
ADD COLUMN total_sale FLOAT;

-- Populate 'total_sale' column as quantity × price_per_unit
UPDATE order_items 
SET total_sale = quantity * price_per_unit;

-- Fetching top 10 selling products with total revenue and order count
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
-- Objective: Comparing monthly sales including previous month's sales
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
-- Objective: Identifying customers who registered but never placed any orders
-- ========================================
SELECT *
FROM customer c
LEFT JOIN orders o USING(customer_id)
WHERE o.order_id IS NULL;



-- ========================================
-- 6. Least-Selling Categories by State
-- Objective: For each state, find the product category with the lowest total sales.
-- ========================================
SELECT 
    state,
    category_name,
    total_sales
FROM (
    SELECT  
        c.state,
        ca.category_name,
        ROUND(SUM(oi.total_sale::NUMERIC), 2) AS total_sales,
        RANK() OVER(PARTITION BY c.state ORDER BY SUM(oi.total_sale)) AS rank
    FROM customer c
    JOIN orders o USING(customer_id)
    JOIN order_items oi USING(order_id)
    JOIN product p USING(product_id)
    JOIN category ca USING(category_id)
    GROUP BY c.state, ca.category_name
) AS t
WHERE rank = 1;


-- ========================================
-- 7. Customer Lifetime Value (CLTV)
-- Objective: Calculating lifetime value of each customer and rank them.
-- ========================================
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name,
    ROUND(SUM(oi.total_sale::NUMERIC), 2) AS total_sale,
    DENSE_RANK() OVER(ORDER BY SUM(oi.total_sale) DESC) AS rank
FROM customer c
JOIN orders o USING(customer_id)
JOIN order_items oi USING(order_id)
GROUP BY c.customer_id, full_name
ORDER BY rank;


-- ========================================
-- 8. Inventory Stock Alerts
-- Objective: Identify products with low stock (less than 10 units).
-- Include restock date and warehouse information.
-- ========================================

-- Using JOIN
SELECT *
FROM product p
JOIN inventory i USING(product_id)
WHERE i.stock < 10;

-- Alternative using subquery (no JOIN)
SELECT *
FROM product
WHERE product_id IN (
    SELECT product_id 
    FROM inventory 
    WHERE stock < 10
);


-- ========================================
-- 9. Shipping Delays
-- Objective: Finding orders where shipping was delayed more than 3 days.
-- Including customer name, order date, shipping provider, and delay duration.
-- ========================================
SELECT 
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name,
    o.order_date,
    s.shipping_date,
    s.shipping_providers,
    (s.shipping_date - o.order_date) AS shipped_after_days
FROM customer c
JOIN orders o USING(customer_id)
JOIN shipping s USING(order_id)
WHERE (s.shipping_date - o.order_date) > 3;


-- ========================================
-- 10. Payment Success Rate
-- Objective: Calculating the percentage of each payment status (e.g., success, failed, pending).
-- ========================================
SELECT 
    payment_status,
    COUNT(*) AS total_count,
    ROUND(
        COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM payment) * 100, 
        2
    ) AS percentage_breakdown
FROM payment
GROUP BY payment_status;



-- ========================================
-- 11. Top Performing Sellers
-- Objective: Find top 5 sellers based on total sales.
-- Including percentage breakdown of order status (excluding 'Inprogress' and 'Returned').
-- ========================================
WITH top_sellers AS (
    SELECT 
        s.seller_id,
        s.seller_name,
        ROUND(SUM(oi.total_sale)::NUMERIC, 2) AS total_sale
    FROM orders o 
    JOIN seller s USING(seller_id)
    JOIN order_items oi USING(order_id)
    GROUP BY s.seller_id, s.seller_name
    ORDER BY total_sale DESC
    LIMIT 5
),

seller_status AS (
    SELECT 
        ts.seller_id,
        ts.seller_name,
        o.order_status,
        COUNT(*) AS order_count
    FROM top_sellers ts
    JOIN orders o USING(seller_id)
    WHERE o.order_status NOT IN ('Inprogress', 'Returned')
    GROUP BY ts.seller_id, ts.seller_name, o.order_status
)

SELECT *,
    ROUND(
        order_count::NUMERIC / 
        (SUM(order_count) OVER (PARTITION BY seller_id)) * 100, 
        2
    ) AS percentage_contribution
FROM seller_status
ORDER BY seller_id;


-- ========================================
-- 12. Product Profit Margin
-- Objective: Calculating and rank products by profit margin.
-- Profit Margin = Total Revenue - Cost of Goods Sold
-- ========================================
SELECT 
    p.product_id,
    p.product_name,
    ROUND(SUM(oi.total_sale - (p.cogs * oi.quantity))::NUMERIC, 2) AS profit_margin,
    RANK() OVER (ORDER BY SUM(oi.total_sale - (p.cogs * oi.quantity)) DESC) AS rank
FROM orders o
JOIN order_items oi USING(order_id)
JOIN product p USING(product_id)
GROUP BY p.product_id, p.product_name;


-- ========================================
-- 13. Most Returned Products
-- Objective: Identifying top 10 products with the highest return counts.
-- Including return rate = (returned / total orders) %
-- ========================================
SELECT *,
    ROUND(total_returned::NUMERIC * 100 / total_orders::NUMERIC, 2) AS percentage_returned
FROM (
    SELECT 
        p.product_id,
        p.product_name,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) AS total_returned
    FROM product p
    JOIN order_items oi USING(product_id)
    JOIN orders o USING(order_id)
    GROUP BY p.product_id, p.product_name
) AS t
ORDER BY total_returned DESC
LIMIT 10;


-- ========================================
-- 14. Orders Pending Shipment
-- Objective: Identifying orders that have been paid successfully but are still in 'Inprogress' status.
-- Include customer details and payment date.
-- ========================================
SELECT 
    o.order_id,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name,
    p.payment_date,
    o.order_date,
    p.payment_status,
    o.order_status
FROM payment p
JOIN orders o USING(order_id)
JOIN customer c USING(customer_id)
WHERE 
    p.payment_status ILIKE 'Payment Successed'
    AND o.order_status ILIKE 'Inprogress';


-- ========================================
-- 15. Inactive Sellers
-- Objective: Finding sellers who made no sales in the last 14 months.
-- Displaying their past order details and sales, if any.
-- ========================================
WITH inactive_sellers AS (
    SELECT *
    FROM seller
    WHERE seller_id NOT IN (
        SELECT DISTINCT seller_id 
        FROM orders 
        WHERE order_date >= CURRENT_DATE - INTERVAL '14 month'
    )
)

-- Join to show their last known orders (if any in earlier periods)
SELECT *
FROM orders
JOIN inactive_sellers USING(seller_id)
JOIN order_items oi USING(order_id);

-- Note: If the result is empty, these sellers truly had no orders at all in that period.


-- ========================================
-- 16. Customer Identity: Returning vs New
-- Objective: Classifying customers as 'Frequently Returning' if they had >5 returns.
-- ========================================
SELECT *, 
    CASE 
        WHEN total_returns > 5 THEN 'Frequently Returning' 
        ELSE 'New'
    END AS cx_category
FROM (
    SELECT 
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        COUNT(o.order_id) AS total_orders,
        SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) AS total_returns
    FROM customer c 
    JOIN orders o USING(customer_id) 
    JOIN order_items oi USING(order_id)
    GROUP BY full_name
) AS t
ORDER BY total_returns DESC;


-- ========================================
-- 17. Top 5 Customers by Orders in Each State
-- Objective: Identifying the top 5 customers (by order count) per state.
-- ========================================
WITH cte AS (
    SELECT 
        c.state,
        CONCAT(c.first_name, ' ', c.last_name) AS full_name,
        COUNT(o.order_id) AS total_orders,
        SUM(oi.total_sale) AS total_sale,
        DENSE_RANK() OVER(PARTITION BY c.state ORDER BY COUNT(o.order_id) DESC) AS rank
    FROM orders o 
    JOIN order_items oi USING(order_id) 
    JOIN customer c USING(customer_id)
    GROUP BY c.state, full_name
)
SELECT *
FROM cte
WHERE rank <= 5;


-- ========================================
-- 18. Revenue by Shipping Provider
-- Objective: Calculating total revenue, orders handled, and delivery metrics per provider.
-- ========================================
SELECT 
    s.shipping_providers,
    COUNT(o.order_id) AS orders_handled,
    SUM(oi.total_sale) AS total_revenue
FROM shipping s 
JOIN orders o USING(order_id) 
JOIN order_items oi USING(order_id)
GROUP BY s.shipping_providers;


-- ========================================
-- 19. Top 10 Products with Highest Revenue Drop (2022 vs 2023)
-- Objective: Comparing 2022 vs 2023 sales and calculate decrease ratio.
-- ========================================
WITH last_year AS (
    SELECT 
        p.product_id,
        p.product_name,
        SUM(oi.total_sale) AS total_sale_2022
    FROM product p 
    JOIN order_items oi USING(product_id) 
    JOIN orders o USING(order_id)
    WHERE EXTRACT(YEAR FROM o.order_date) = 2022
    GROUP BY p.product_id, p.product_name
),
current_year AS (
    SELECT 
        p.product_id,
        p.product_name,
        SUM(oi.total_sale) AS total_sale_2023
    FROM product p 
    JOIN order_items oi USING(product_id) 
    JOIN orders o USING(order_id)
    WHERE EXTRACT(YEAR FROM o.order_date) = 2023
    GROUP BY p.product_id, p.product_name
)
SELECT 
    cy.product_id,
    cy.product_name,
    ly.total_sale_2022,
    cy.total_sale_2023,
    ROUND(((cy.total_sale_2023 - ly.total_sale_2022)::NUMERIC / ly.total_sale_2022) * 100, 2) AS decrease_ratio_percent
FROM last_year ly 
JOIN current_year cy USING(product_id)
ORDER BY decrease_ratio_percent ASC
LIMIT 10;


-- ========================================
-- FINAL TASK: Create Procedure to Add Order & Update Inventory
-- Objective: Inserting order & item records, update inventory accordingly.
-- ========================================
CREATE OR REPLACE PROCEDURE add_order (
    p_order_id INT,
    p_customer_id INT,
    p_seller_id INT,
    p_order_item_id INT,
    p_product_id INT,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
    v_price FLOAT;
BEGIN
    -- Get price of product
    SELECT price INTO v_price 
    FROM product 
    WHERE product_id = p_product_id;

    -- Check if inventory has enough stock
    SELECT COUNT(*) INTO v_count 
    FROM inventory
    WHERE product_id = p_product_id 
      AND stock >= p_quantity;

    IF v_count > 0 THEN
        -- Insert into orders table
        INSERT INTO orders(order_id, order_date, customer_id, seller_id)
        VALUES (p_order_id, CURRENT_DATE, p_customer_id, p_seller_id);

        -- Insert into order_items table
        INSERT INTO order_items(order_item_id, order_id, product_id, quantity, price_per_unit, total_sale)
        VALUES (p_order_item_id, p_order_id, p_product_id, p_quantity, v_price, v_price * p_quantity);

        -- Update inventory to reduce stock
        UPDATE inventory
        SET stock = stock - p_quantity
        WHERE product_id = p_product_id;

        RAISE NOTICE 'Thank you, Order for product: % has been placed!', p_product_id;
    ELSE
        RAISE NOTICE 'Product: % not available in requested quantity.', p_product_id;
    END IF;
END
$$;

-- Example Call
CALL add_order(
    25000,  -- order_id
    2,      -- customer_id
    5,      -- seller_id
    25001,  -- order_item_id
    1,      -- product_id
    40      -- quantity
);







