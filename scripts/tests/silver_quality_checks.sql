/*
--------------------------------------------------------------------------
-- Data Quality Checks and Exploration Queries for Silver Layer Loading
-- Source: bronze layer tables
-- Purpose: These queries were used during the development of the silver.load_silver
--          stored procedure to analyze data anomalies, enforce integrity,
--          and determine transformation rules (ETL logic).
--------------------------------------------------------------------------
*/

------------------------------------------------------------------------------
-- 1. CRM_CUST_INFO CHECKS
------------------------------------------------------------------------------

-- Check 1.1: Identify Nulls or Duplicates in Primary Key (cst_id)
SELECT cst_id, COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check 1.2: Example of duplicated records (used to determine deduplication logic)
-- Focusing on a specific duplicated ID, e.g., 29466
SELECT *
FROM bronze.crm_cust_info
WHERE cst_id = 29466;

-- Check 1.3: Preview the latest record selection logic using ROW_NUMBER
-- We choose the latest record based on cst_create_date
SELECT
    *,
    ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info
WHERE cst_id = 29466;

-- Check 1.4: Final Preview of the Deduplication Logic
-- Selects only the single, latest record for each non-null cst_id
SELECT *
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
) AS t
WHERE t.flag_last = 1;

-- Check 1.5: Verify Unwanted Spaces in cst_firstname
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Check 1.6: Verify Unwanted Spaces in cst_lastname
SELECT cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- Check 1.7: Final Customer Selection before Standardization Checks (Cleaned PK and TRIM applied)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) AS t
WHERE t.flag_last = 1;

-- Check 1.8: Preview Data Standardization for Low Cardinality Columns (Marital Status and Gender)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    CASE
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'n/a'
    END AS cst_material_status,
    CASE
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    cst_create_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) AS t
WHERE t.flag_last = 1;

------------------------------------------------------------------------------
--- 2. CRM_PRD_INFO CHECKS
------------------------------------------------------------------------------

-- Check 2.1: Identify Nulls or Duplicates in Primary Key (prd_id)
SELECT prd_id, COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) != 1 OR prd_id IS NULL;

-- Check 2.2: Preview Splitting the prd_key column into cat_id and cleaned prd_key
SELECT
    prd_id,
    prd_key,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key_cleaned,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
FROM bronze.crm_prd_info;

-- Check 2.3: Verify Unwanted Spaces in prd_nm
SELECT prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check 2.4: Identify Null or Negative Numbers in prd_cost
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Check 2.5: Preview handling NULL product cost (using ISNULL)
SELECT
    prd_id,
    prd_key,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key_cleaned,
    prd_nm,
    ISNULL(prd_cost, 0) AS prd_cost_cleaned,
    prd_line,
    prd_start_dt,
    prd_end_dt
FROM bronze.crm_prd_info;

-- Check 2.6: Identify Distinct Values in prd_line for Standardization
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;

-- Check 2.7: Preview Data Standardization for prd_line
SELECT
    prd_id,
    prd_key,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key_cleaned,
    prd_nm,
    ISNULL(prd_cost, 0) AS prd_cost_cleaned,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line_standardized,
    prd_start_dt,
    prd_end_dt
FROM bronze.crm_prd_info;

-- Check 2.8: Identify Invalid Date Orders (End Date before Start Date)
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


------------------------------------------------------------------------------
--- 3. CRM_SALES_DETAILS CHECKS
------------------------------------------------------------------------------

-- Check 3.1: Verify Unwanted Spaces in sls_ord_num
SELECT *
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num);

-- Check 3.2: Referential Integrity Check (Sales Product Key must exist in silver.crm_prd_info)
SELECT *
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

-- Check 3.3: Referential Integrity Check (Customer ID must exist in silver.crm_cust_info)
SELECT *
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- Check 3.4: Identify Invalid Dates (Negative or Zero values in date fields)
SELECT sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0;

-- Check 3.5: Preview Date Cleaning Logic (Replace 0s/Invalid lengths with NULL)
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE
        WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
    END AS sls_order_dt_cleaned,
    CASE
        WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
    END AS sls_ship_dt_cleaned,
    CASE
        WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
    END AS sls_due_dt_cleaned,
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details;

-- Check 3.6: Identify Invalid Date Order (Order Date after Ship/Due Date)
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Check 3.7: Identify Data Consistency Violations (Sales != Quantity * Price OR negative/null values)
-- Business Rule Check: Sales must be positive and equal to Quantity * Price.
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE
    sls_sales != sls_quantity * sls_price
    OR sls_sales <= 0 OR sls_price <= 0 OR sls_quantity <= 0
    OR sls_sales IS NULL OR sls_price IS NULL OR sls_quantity IS NULL;


------------------------------------------------------------------------------
--- 4. ERP_CUST_AZ12 CHECKS
------------------------------------------------------------------------------

-- Check 4.1: Preview Primary Key Extraction (Removing 'NAS' prefix)
SELECT
    CASE WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID)) ELSE CID END AS CID_cleaned,
    BDATE,
    GEN
FROM bronze.erp_CUST_AZ12;

-- Check 4.2: Identify Invalid Birthdates (Too old or in the future)
SELECT DISTINCT BDATE
FROM bronze.erp_CUST_AZ12
WHERE BDATE < '1924-01-01' OR BDATE > GETDATE(); -- 1924 is used as a generic extreme limit

-- Check 4.3: Preview Birthdate Cleaning (NULLIFY future dates)
SELECT
    CASE WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID)) ELSE CID END AS CID_cleaned,
    CASE WHEN BDATE > GETDATE() THEN NULL ELSE BDATE END AS BDATE_cleaned,
    GEN
FROM bronze.erp_CUST_AZ12;

-- Check 4.4: Identify Distinct Values in Gender (GEN) for Standardization
SELECT DISTINCT GEN
FROM bronze.erp_CUST_AZ12;

-- Check 4.5: Preview Data Standardization for Gender (Standardize to 'Female'/'Male'/'n/a')
SELECT
    CASE WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID)) ELSE CID END AS CID_cleaned,
    CASE WHEN BDATE > GETDATE() THEN NULL ELSE BDATE END AS BDATE_cleaned,
    CASE
        WHEN UPPER(TRIM(GEN)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(GEN)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS GEN_standardized
FROM bronze.erp_CUST_AZ12;


------------------------------------------------------------------------------
--- 5. ERP_LOC_A101 CHECKS
------------------------------------------------------------------------------

-- Check 5.1: Preview Primary Key Cleaning (Removing dashes from CID)
SELECT REPLACE(CID, '-', '') AS CID_cleaned, CNTRY
FROM bronze.erp_LOC_A101;

-- Check 5.2: Identify Distinct Values in Country (CNTRY) for Standardization
SELECT DISTINCT CNTRY
FROM bronze.erp_LOC_A101
ORDER BY CNTRY;

-- Check 5.3: Preview Data Standardization for Country (Standardize country codes/variants)
SELECT
    REPLACE(CID, '-', '') AS CID_cleaned,
    CASE
        WHEN TRIM(CNTRY) = 'DE' THEN 'Germany'
        WHEN TRIM(CNTRY) IN ('USA', 'US') THEN 'United States'
        WHEN TRIM(CNTRY) = '' OR CNTRY IS NULL THEN 'n/a'
        ELSE TRIM(CNTRY)
    END AS CNTRY_standardized
FROM bronze.erp_LOC_A101;


------------------------------------------------------------------------------
--- 6. ERP_PX_CAT_G1V2 CHECKS
------------------------------------------------------------------------------

-- Check 6.1: Verify Unwanted Spaces in Category Columns
SELECT *
FROM bronze.erp_PX_CAT_G1V2
WHERE CAT != TRIM(CAT) OR SUBCAT != TRIM(SUBCAT) OR MAINTENANCE != TRIM(MAINTENANCE);

-- Check 6.2: Identify Distinct Values in CAT for inspection
SELECT DISTINCT CAT
FROM bronze.erp_PX_CAT_G1V2;

-- Check 6.3: Identify Distinct Values in SUBCAT for inspection
SELECT DISTINCT SUBCAT
FROM bronze.erp_PX_CAT_G1V2;

-- Check 6.4: Identify Distinct Values in MAINTENANCE for inspection
SELECT DISTINCT MAINTENANCE
FROM bronze.erp_PX_CAT_G1V2;
