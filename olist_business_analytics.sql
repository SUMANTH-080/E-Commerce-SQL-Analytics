/* =========================================================================================
   PROJECT: Brazilian E-Commerce Analytics (Olist)
   DESCRIPTION: End-to-end data pipeline analyzing 100k+ orders to extract business 
                intelligence regarding shipping logistics and revenue seasonality.
   ========================================================================================= */

/* -----------------------------------------------------------------------------------------
   PART 1: DATABASE ARCHITECTURE (DDL)
   Building the relational schema with Primary and Foreign Key constraints.
   ----------------------------------------------------------------------------------------- */

-- Create Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

-- Create Orders Table
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Create Payments Table
CREATE TABLE order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value NUMERIC(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);


/* -----------------------------------------------------------------------------------------
   PART 2: BUSINESS INTELLIGENCE QUERIES
   Extracting insights using Joins, Date Math, CTEs, and Window Functions.
   ----------------------------------------------------------------------------------------- */

-- QUERY 1: Regional Order Volume
-- Objective: Identify which Brazilian states generate the highest volume of transactions.
SELECT 
    c.customer_state, 
    COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY total_orders DESC
LIMIT 10;

-- QUERY 2: Delivery Logistics & Latency
-- Objective: Calculate the average delivery time (in days) per state to identify bottlenecks.
SELECT 
    c.customer_state, 
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))/86400), 1) AS avg_delivery_days
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' 
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- QUERY 3: Seasonality & Month-over-Month (MoM) Growth
-- Objective: Track revenue growth and identify seasonal spikes (e.g., Black Friday).
WITH MonthlyOrders AS (
    SELECT 
        DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
        COUNT(order_id) AS total_orders
    FROM orders
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
)
SELECT 
    order_month,
    total_orders,
    LAG(total_orders) OVER (ORDER BY order_month) AS previous_month_orders,
    ROUND(
        (total_orders - LAG(total_orders) OVER (ORDER BY order_month))::numeric 
        / LAG(total_orders) OVER (ORDER BY order_month) * 100
    , 2) AS mom_growth_percentage
FROM MonthlyOrders
ORDER BY order_month;