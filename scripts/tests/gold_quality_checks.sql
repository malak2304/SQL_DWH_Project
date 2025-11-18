/*
--------------------------------------------------------------------------
-- Data Quality Checks and Exploration Queries for GOLD Layer Construction
-- Purpose: These queries were used to verify joins, check for data integrity
--          issues (duplicates, orphans), and confirm data standardization
--          before finalizing the Dimension and Fact Views.
--------------------------------------------------------------------------
*/

------------------------------------------------------------------------------
-- 1. CUSTOMER DIMENSION CHECKS (gold.dim_customers)
------------------------------------------------------------------------------

-- Check 1.1: Identify potential duplication in the final customer set
--            (Looking for duplicate cst_id after initial Silver Layer cleaning/deduplication)
SELECT cst_id, COUNT(*)
FROM
(
    SELECT
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_gndr,
        ci.cst_create_date,
        ca.BDATE,
        ca.GEN,
        la.CNTRY
    FROM
        silver.crm_cust_info ci
    LEFT JOIN
        silver.erp_CUST_AZ12 ca ON ci.cst_key = ca.CID
    LEFT JOIN
        silver.erp_LOC_A101 la ON ci.cst_key = la.CID
) t
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- Check 1.2: Verify Gender Data Consistency and Precedence Logic
--            (Examine the combination of CRM gender (master) and ERP gender)
SELECT DISTINCT
    ci.cst_gndr,
    ca.GEN
FROM
    silver.crm_cust_info ci
LEFT JOIN
    silver.erp_CUST_AZ12 ca ON ci.cst_key = ca.CID
LEFT JOIN
    silver.erp_LOC_A101 la ON ci.cst_key = la.CID
ORDER BY 1, 2;


-- Check 1.3: Preview Final Gender Derivation Logic
--            (Testing CASE/COALESCE logic before final view creation)
SELECT DISTINCT
    ci.cst_gndr,
    ca.GEN,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the master source
        ELSE COALESCE(ca.GEN, 'n/a')
    END AS new_gen
FROM
    silver.crm_cust_info ci
LEFT JOIN
    silver.erp_CUST_AZ12 ca ON ci.cst_key = ca.CID
LEFT JOIN
    silver.erp_LOC_A101 la ON ci.cst_key = la.CID
ORDER BY 1, 2;


-- Check 1.4: Final Preview of Customer Dimension structure (before adding ROW_NUMBER)
SELECT
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    ci.cst_marital_status AS marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.GEN, 'n/a')
    END AS gender,
    ci.cst_create_date AS create_date,
    ca.BDATE AS birthdate,
    la.CNTRY AS country
FROM
    silver.crm_cust_info ci
LEFT JOIN
    silver.erp_CUST_AZ12 ca ON ci.cst_key = ca.CID
LEFT JOIN
    silver.erp_LOC_A101 la ON ci.cst_key = la.CID;


------------------------------------------------------------------------------
-- 2. PRODUCT DIMENSION CHECKS (gold.dim_products)
------------------------------------------------------------------------------

-- Check 2.1: Preliminary Product Dimension Joins and Filtering
--            (Ensuring only current active products are considered)
SELECT
    pn.prd_id,
    pn.cat_id,
    pn.prd_key,
    pn.prd_nm,
    pn.prd_cost,
    pn.prd_line,
    pn.prd_start_dt,
    pc.CAT,
    pc.SUBCAT,
    pc.MAINTENANCE
FROM
    silver.crm_prd_info pn
LEFT JOIN
    silver.erp_PX_CAT_G1V2 pc ON pn.cat_id = pc.ID
WHERE
    prd_end_dt IS NULL; -- Filter out historical data (focus on current data)


-- Check 2.2: Verify Uniqueness of Natural Key (prd_key) in Current Data Set
--            (Ensure that after filtering historical data, the natural key is unique)
SELECT prd_key, COUNT(*)
FROM
(
    SELECT
        pn.prd_key
    FROM
        silver.crm_prd_info pn
    LEFT JOIN
        silver.erp_PX_CAT_G1V2 pc ON pn.cat_id = pc.ID
    WHERE
        prd_end_dt IS NULL
) t
GROUP BY prd_key
HAVING COUNT(*) > 1;


------------------------------------------------------------------------------
-- 3. FACT SALES CHECKS (gold.fact_sales)
------------------------------------------------------------------------------

-- Check 3.1: Foreign Key Integrity Check (Orphan Records in Fact Sales)
--            (Identify sales records that failed to match existing product keys)
--            Note: This query requires the DIM views to be created first for execution.
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL;
/*
Explanation of Check 3.1:
This query uses a LEFT JOIN to match the Fact Sales records to the Product Dimension.
The WHERE condition (p.product_key IS NULL) isolates any Fact record where the join failed.
A non-match indicates an Orphan Record, meaning the sls_prd_key in the sales table
did not successfully map to an active product_key in the dimension.
*/
