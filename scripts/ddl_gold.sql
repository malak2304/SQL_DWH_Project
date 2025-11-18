/*
--------------------------------------------------------------------------
-- DDL Script for GOLD Layer Views (Data Mart)
-- Purpose: Defines the star schema structure (Dimensions and Facts)
--          by selecting and joining cleansed data from the Silver Layer.
--------------------------------------------------------------------------
*/
GO

-- #################################################
-- 1. DIMENSION: gold.dim_customers
-- Purpose: Represents a customer entity, consolidating data from multiple
--          source systems (CRM for demographics, ERP for location/birthdate).
-- Key Logic: Prioritizes CRM gender data (ci.cst_gndr) and uses COALESCE
--          to fall back to ERP gender (ca.GEN) if CRM data is 'n/a'.
-- #################################################
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
BEGIN
    DROP VIEW gold.dim_customers;
END
GO
CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key, -- Surrogate Key Generation
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    la.CNTRY AS country,
    ci.cst_marital_status AS marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr         -- Master Source (CRM) Priority
        ELSE COALESCE(ca.GEN, 'n/a')
    END AS gender,
    ca.BDATE AS birthdate,
    ci.cst_create_date AS create_date
FROM
    silver.crm_cust_info ci
LEFT JOIN
    silver.erp_CUST_AZ12 ca ON ci.cst_key = ca.CID
LEFT JOIN
    silver.erp_LOC_A101 la ON ci.cst_key = la.CID;
GO

------------------------------------------------------------------------------
-- #################################################
-- 2. DIMENSION: gold.dim_products
-- Purpose: Represents the product entity, combining cleaned product details
--          with category details from ERP sources.
-- Key Logic: Filters to include only the CURRENTLY ACTIVE version of the product
--          (prd_end_dt IS NULL) to ensure the dimensional integrity.
-- #################################################
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
BEGIN
    DROP VIEW gold.dim_products;
END
GO
CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key, -- Surrogate Key Generation
    pn.prd_id AS product_id,
    pn.prd_key AS product_number,
    pn.prd_nm AS product_name,
    pn.cat_id AS category_id,
    pc.CAT AS category,
    pc.SUBCAT AS subcategory,
    pc.MAINTENANCE,
    pn.prd_cost AS cost,
    pn.prd_line AS product_line,
    pn.prd_start_dt AS start_date
FROM
    silver.crm_prd_info pn
LEFT JOIN
    silver.erp_PX_CAT_G1V2 pc ON pn.cat_id = pc.ID
WHERE
    prd_end_dt IS NULL; -- Filter for Current Active Record only
GO

------------------------------------------------------------------------------
-- #################################################
-- 3. FACT TABLE: gold.fact_sales
-- Purpose: Contains the measurable sales data, joined to the newly created
--          Dimension Views using the Surrogate Keys.
-- Key Logic: Joins sales details with dimensions to replace natural keys
--          (sls_prd_key, sls_cust_id) with stable Surrogate Keys
--          (product_key, customer_key). Uses LEFT JOIN to preserve all sales records.
-- #################################################
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
BEGIN
    DROP VIEW gold.fact_sales;
END
GO
CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num AS order_number,
    pr.product_key,                 -- Linking Sales to Product Dimension via Surrogate Key
    cu.customer_key,                -- Linking Sales to Customer Dimension via Surrogate Key
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM
    silver.crm_sales_details sd
LEFT JOIN
    gold.dim_products pr ON sd.sls_prd_key = pr.product_number
LEFT JOIN
    gold.dim_customers cu ON sd.sls_cust_id = cu.customer_id;
GO
