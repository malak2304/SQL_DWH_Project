/*
------------------------------------------------------
-- DDL Script for Silver Layer Tables (Data Warehouse)
-- Purpose: Defines the structure for clean, staged tables
--          ready for transformation into the Gold layer.
------------------------------------------------------
*/

-- #################################################
-- 1. CRM Customer Information (silver.crm_cust_info)
-- #################################################
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
BEGIN
    DROP TABLE silver.crm_cust_info;
END
CREATE TABLE silver.crm_cust_info (
    cst_id                INT,
    cst_key               NVARCHAR(50),
    cst_firstname         NVARCHAR(50),
    cst_lastname          NVARCHAR(50),
    cst_material_status   NVARCHAR(50),
    cst_gndr              NVARCHAR(50),
    cst_create_date       DATE,
    dwh_create_time       DATETIME2 DEFAULT GETDATE()
);
GO

-- #################################################
-- 2. CRM Product Information (silver.crm_prd_info)
-- #################################################
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
BEGIN
    DROP TABLE silver.crm_prd_info;
END
CREATE TABLE silver.crm_prd_info (
    prd_id                INT,
    cat_id                NVARCHAR(50),
    prd_key               NVARCHAR(50),
    prd_nm                NVARCHAR(50),
    prd_cost              INT,
    prd_line              NVARCHAR(50),
    prd_start_dt          DATETIME,
    prd_end_dt            DATETIME,
    dwh_create_time       DATETIME2 DEFAULT GETDATE()
);
GO

-- #################################################
-- 3. CRM Sales Details (silver.crm_sales_details)
-- #################################################
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
BEGIN
    DROP TABLE silver.crm_sales_details;
END
CREATE TABLE silver.crm_sales_details (
    sls_ord_num           NVARCHAR(50),
    sls_prd_key           NVARCHAR(50),
    sls_cust_id           INT,
    sls_order_dt          DATE,
    sls_ship_dt           DATE,
    sls_due_dt            DATE,
    sls_sales             INT,
    sls_quantity          INT,
    sls_price             INT
    -- Note: dwh_create_time is often added here for consistency,
    -- but kept as per your original definition.
);
GO

------------------------------------------------------
-- ERP Source Tables
------------------------------------------------------

-- #################################################
-- 4. ERP Customer AZ12 (silver.erp_CUST_AZ12)
-- #################################################
IF OBJECT_ID('silver.erp_CUST_AZ12', 'U') IS NOT NULL
BEGIN
    DROP TABLE silver.erp_CUST_AZ12;
END
CREATE TABLE silver.erp_CUST_AZ12 (
    CID                   NVARCHAR(50),
    BDATE                 DATE,
    GEN                   NVARCHAR(50),
    dwh_create_time       DATETIME2 DEFAULT GETDATE()
);
GO

-- #################################################
-- 5. ERP Location A101 (silver.erp_LOC_A101)
-- #################################################
IF OBJECT_ID('silver.erp_LOC_A101', 'U') IS NOT NULL
BEGIN
    DROP TABLE silver.erp_LOC_A101;
END
CREATE TABLE silver.erp_LOC_A101 (
    CID                   NVARCHAR(50),
    CNTRY                 NVARCHAR(50),
    dwh_create_time       DATETIME2 DEFAULT GETDATE()
);
GO

-- #################################################
-- 6. ERP Product Category G1V2 (silver.erp_PX_CAT_G1V2)
-- #################################################
IF OBJECT_ID('silver.erp_PX_CAT_G1V2', 'U') IS NOT NULL
BEGIN
    DROP TABLE silver.erp_PX_CAT_G1V2;
END
CREATE TABLE silver.erp_PX_CAT_G1V2 (
    ID                    NVARCHAR(50),
    CAT                   NVARCHAR(50),
    SUBCAT                NVARCHAR(50),
    MAINTENANCE           NVARCHAR(50),
    dwh_create_time       DATETIME2 DEFAULT GETDATE()
);
GO
