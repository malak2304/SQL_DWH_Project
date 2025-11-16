/*
--------------------------------------------------------------------------
-- Procedure: silver.load_silver
-- Purpose: Cleanses and transforms raw data from the bronze layer
--          and loads it into the staging/silver layer tables.
--------------------------------------------------------------------------
*/
EXEC silver.load_silver
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME;
    DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;

    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '=======================================';
        PRINT 'Loading Silver Layer Started';
        PRINT '=======================================';
        PRINT 'Loading CRM Tables...';
        PRINT '=======================================';

        ------------------------------------------------------------------------------
        --                             FIRST TABLE: crm_cust_info
        ------------------------------------------------------------------------------
        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        PRINT '>> Inserting Data into: silver.crm_cust_info';

        INSERT INTO silver.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date
        )
        SELECT
            t.cst_id,
            t.cst_key,
            TRIM(t.cst_firstname) AS cst_firstname,
            TRIM(t.cst_lastname) AS cst_lastname,
            CASE UPPER(TRIM(t.cst_material_status))
                WHEN 'S' THEN 'Single'
                WHEN 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status, -- Corrected column name to match the CASE expression
            CASE UPPER(TRIM(t.cst_gndr))
                WHEN 'F' THEN 'Female'
                WHEN 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            t.cst_create_date
        FROM (
            -- Handling duplicates in cst_id by selecting the latest record
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL -- Exclude records where the primary key is null
        ) AS t
        WHERE t.flag_last = 1;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration (crm_cust_info): ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------';

        ------------------------------------------------------------------------------
        --                             SECOND TABLE: crm_prd_info
        ------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info'; -- Corrected table name in print statement
        TRUNCATE TABLE silver.crm_prd_info;
        PRINT '>> Inserting Data into: silver.crm_prd_info'; -- Corrected table name in print statement

        INSERT INTO silver.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line,
            prd_start_dt, prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Splitting prd_key to get category ID
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,        -- Extracting the remaining part as prd_key
            TRIM(prd_nm) AS prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,                       -- Handling NULL product cost
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            -- Data Enrichment: Calculating prd_end_dt using LEAD window function
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
        FROM
            bronze.crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration (crm_prd_info): ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------';

        ------------------------------------------------------------------------------
        --                             THIRD TABLE: crm_sales_details
        ------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details'; -- Corrected table name in print statement
        TRUNCATE TABLE silver.crm_sales_details;
        PRINT '>> Inserting Data into: silver.crm_sales_details'; -- Corrected table name in print statement

        INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt,
            sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price
        )
        SELECT
            TRIM(sls_ord_num) AS sls_ord_num, -- Cleaning spaces
            sls_prd_key,
            sls_cust_id,
            -- Date Cleaning & Conversion (sls_order_dt)
            CASE
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            -- Date Cleaning & Conversion (sls_ship_dt)
            CASE
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            -- Date Cleaning & Conversion (sls_due_dt)
            CASE
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            -- Data Quality: Correcting sls_sales
            CASE
                WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_quantity * ABS(sls_price) THEN ABS(sls_price) * sls_quantity
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            -- Data Quality: Correcting sls_price
            CASE
                WHEN sls_price <= 0 OR sls_price IS NULL THEN sls_sales / NULLIF(sls_quantity, 0)
                WHEN sls_price < 0 THEN -sls_price -- Convert negative price to positive
                ELSE sls_price
            END AS sls_price
        FROM
            bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration (crm_sales_details): ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------';

        ------------------------------------------------------------------------------
        --                             FOURTH TABLE: erp_CUST_AZ12
        ------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_CUST_AZ12'; -- Corrected table name in print statement
        TRUNCATE TABLE silver.erp_CUST_AZ12;
        PRINT '>> Inserting Data into: silver.erp_CUST_AZ12'; -- Corrected table name in print statement

        INSERT INTO silver.erp_CUST_AZ12 (cid, bdate, gen)
        SELECT
            CASE
                WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID)) -- Extracting PK
                ELSE CID
            END AS CID,
            CASE
                WHEN BDATE > GETDATE() THEN NULL -- Handling future dates
                ELSE BDATE
            END AS BDATE,
            CASE
                WHEN UPPER(TRIM(GEN)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(GEN)) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS GEN -- Data Standardization
        FROM
            bronze.erp_CUST_AZ12;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration (erp_CUST_AZ12): ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------';

        ------------------------------------------------------------------------------
        --                             FIFTH TABLE: erp_LOC_A101
        ------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_LOC_A101'; -- Corrected table name in print statement
        TRUNCATE TABLE silver.erp_LOC_A101;
        PRINT '>> Inserting Data into: silver.erp_LOC_A101'; -- Corrected table name in print statement

        INSERT INTO silver.erp_LOC_A101 (cid, cntry)
        SELECT
            REPLACE(CID, '-', '') AS CID, -- PK cleaning
            CASE
                WHEN TRIM(CNTRY) = 'DE' THEN 'Germany'
                WHEN TRIM(CNTRY) IN ('USA', 'US') THEN 'United States'
                WHEN TRIM(CNTRY) = '' OR CNTRY IS NULL THEN 'n/a'
                ELSE TRIM(CNTRY)
            END AS CNTRY -- Data Standardization
        FROM
            bronze.erp_LOC_A101;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration (erp_LOC_A101): ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------';

        ------------------------------------------------------------------------------
        --                             SIXTH TABLE: erp_PX_CAT_G1V2
        ------------------------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_PX_CAT_G1V2'; -- Corrected table name in print statement
        TRUNCATE TABLE silver.erp_PX_CAT_G1V2;
        PRINT '>> Inserting Data into: silver.erp_PX_CAT_G1V2'; -- Corrected table name in print statement

        INSERT INTO silver.erp_PX_CAT_G1V2 (id, cat, subcat, maintenance)
        SELECT
            TRIM(ID) AS ID,
            TRIM(CAT) AS CAT,
            TRIM(SUBCAT) AS SUBCAT,
            TRIM(MAINTENANCE) AS MAINTENANCE
        FROM
            bronze.erp_PX_CAT_G1V2;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration (erp_PX_CAT_G1V2): ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-----------------------------------------';

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT '- total load duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' secs';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END
GO
