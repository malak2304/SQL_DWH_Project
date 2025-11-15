/*
----------------Create Database and Schemas--------------------
Script Purpose:
This script creates a new database named 'DataWarehouse' after checking if it already exists.
If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas
within the database: 'bronze', 'silver', and 'gold'.

WARNING:[]
Running this script will drop the entire 'DataWarehouse' database if it exists.
All data in the database will be permanently deleted. Proceed with caution
and ensure you have proper backups before running this script.

*/
USE master;

-- Conditional check and drop/create the database is usually done like this for safety:
IF DB_ID('DataWarehouse') IS NOT NULL
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO

---

-- Creating the tables
-- checking if the tables exist before or not
-- U stands for user
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
	DROP TABLE bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info (
    cst_id INT,
    cst_key NVARCHAR(50),
    cst_firstname NVARCHAR(50),
    cst_lastname NVARCHAR(50),
    cst_material_status NVARCHAR(50),
    cst_gndr NVARCHAR(50),
    cst_create_date DATE
);

IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
	DROP TABLE bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info (
    prd_id INT,
    prd_key NVARCHAR(50),
    prd_nm NVARCHAR(50),
    prd_cost INT,
    prd_line NVARCHAR(50),
    prd_start_dt DATETIME,
    prd_end_dt DATETIME
);

IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
	DROP TABLE bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
    sls_ord_num NVARCHAR(50),
    sls_prd_key NVARCHAR(50),
    sls_cust_id INT,
    sls_order_dt INT,
    sls_ship_dt INT,
    sls_due_dt INT,
    sls_sales INT,
    sls_quantity INT,
    sls_price INT
);

---

IF OBJECT_ID('bronze.erp_CUST_AZ12', 'U') IS NOT NULL
	DROP TABLE bronze.erp_CUST_AZ12;
CREATE TABLE bronze.erp_CUST_AZ12 (
    CID NVARCHAR(50),
    BDATE DATE,
    GEN NVARCHAR(50)
);


IF OBJECT_ID('bronze.erp_LOC_A101', 'U') IS NOT NULL
	DROP TABLE bronze.erp_LOC_A101;
CREATE TABLE bronze.erp_LOC_A101 (
    CID NVARCHAR(50),
    CNTRY NVARCHAR(50)
);


IF OBJECT_ID('bronze.erp_PX_CAT_G1V2', 'U') IS NOT NULL
	DROP TABLE bronze.erp_PX_CAT_G1V2;
CREATE TABLE bronze.erp_PX_CAT_G1V2 (
    ID NVARCHAR(50),
    CAT NVARCHAR(50),
    SUBCAT NVARCHAR(50),
    MAINTENANCE NVARCHAR(50)
);

------------- BULK INSERT ----------------
--> is a method to insert all the data drom csv or txt file to the DB in one go

--save frequently used sql code in stored procedures in DB
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

    DECLARE @start_time DATETIME, @end_time DATETIME;
    DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;

    BEGIN TRY
        SET @batch_start_time = GETDATE();

        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.crm_cust_info;
        BULK INSERT bronze.crm_cust_info
        FROM 'D:\data_analysis_projects\project 5 (SQL DWH)\data\datasets\source_crm\cust_info.csv '
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK -- improves performance
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.crm_prd_info;
        BULK INSERT bronze.crm_prd_info
        FROM 'D:\data_analysis_projects\project 5 (SQL DWH)\data\datasets\source_crm\prd_info.csv '
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK -- improves performance
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.crm_sales_details;
        BULK INSERT bronze.crm_sales_details
        FROM 'D:\data_analysis_projects\project 5 (SQL DWH)\data\datasets\source_crm\sales_details.csv '
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK -- improves performance
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        ------------

        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.erp_CUST_AZ12;
        BULK INSERT bronze.erp_CUST_AZ12
        FROM 'D:\data_analysis_projects\project 5 (SQL DWH)\data\datasets\source_erp\CUST_AZ12.csv '
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK -- improves performance
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.erp_LOC_A101;
        BULK INSERT bronze.erp_LOC_A101
        FROM 'D:\data_analysis_projects\project 5 (SQL DWH)\data\datasets\source_erp\LOC_A101.csv '
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK -- improves performance
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.erp_PX_CAT_G1V2;
        BULK INSERT bronze.erp_PX_CAT_G1V2
        FROM 'D:\data_analysis_projects\project 5 (SQL DWH)\data\datasets\source_erp\PX_CAT_G1V2.csv '
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK -- improves performance
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @batch_end_time = GETDATE();
        PRINT '===========================================';
        PRINT '- total load duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' secs';
        PRINT '===========================================';
    END TRY
    BEGIN CATCH
        PRINT '=========================================';
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '=========================================';
    END CATCH

END
GO

-- Execute the stored procedure
EXEC bronze.load_bronze;
