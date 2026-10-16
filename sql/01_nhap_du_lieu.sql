/* SQL Server 2017+ / SSMS. Chay file nay truoc, sau do chay 02_thuc_hanh.sql.
   Sua DUONG DAN CSV o ben duoi. CSV duoc tao boi src/prepare_retail.py.
   Khong xoa database/bang cu. Neu bang da ton tai, script dung de tranh nap trung.
   Chay toan bo file; khong chay tiep cac batch sau neu batch truoc bao loi.
*/
USE master;
GO
IF DB_ID(N'OnlineRetailII_Portfolio') IS NULL
    EXEC(N'CREATE DATABASE OnlineRetailII_Portfolio');
GO
USE OnlineRetailII_Portfolio;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.RetailRaw', N'U') IS NOT NULL
    THROW 50001, 'RetailRaw da ton tai. Khong nap lai; hay chay file 02.', 1;

-- Duong dan tren MAY CHU SQL SERVER, khong phai may SSMS neu ket noi tu xa.
DECLARE @CsvPath nvarchar(4000) = N'C:\SQLData\retail_raw.csv';

BEGIN TRY
    BEGIN TRANSACTION;
    -- Giu tat ca gia tri nguon dang chuoi: khong mat ma, khong tu dien NULL = 0.
    CREATE TABLE dbo.RetailRaw (
        SourceSheet nvarchar(64) NOT NULL,
        SourceRow nvarchar(32) NOT NULL,
        Invoice nvarchar(128) NULL,
        StockCode nvarchar(128) NULL,
        Description nvarchar(1000) NULL,
        Quantity nvarchar(128) NULL,
        InvoiceDate nvarchar(64) NULL,
        Price nvarchar(128) NULL,
        CustomerID nvarchar(128) NULL,
        Country nvarchar(256) NULL
    );

    DECLARE @LoadSql nvarchar(max) =
        N'BULK INSERT dbo.RetailRaw FROM ''' + REPLACE(@CsvPath, '''', '''''') + N'''
          WITH (FORMAT = ''CSV'', FIRSTROW = 2, CODEPAGE = ''65001'',
                FIELDQUOTE = ''"'', FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'',
                TABLOCK, MAXERRORS = 0);';
    EXEC sys.sp_executesql @LoadSql;

    -- So dong ky vong tu workbook goc (khong tinh header).
    IF (SELECT COUNT_BIG(*) FROM dbo.RetailRaw) <> 1067371
        THROW 50002, 'So dong khong khop workbook. Da rollback; kiem tra CSV.', 1;
    IF (SELECT COUNT_BIG(*) FROM dbo.RetailRaw WHERE SourceSheet = N'Year 2009-2010') <> 525461
        THROW 50003, 'So dong sheet 2009-2010 khong khop.', 1;
    IF (SELECT COUNT_BIG(*) FROM dbo.RetailRaw WHERE SourceSheet = N'Year 2010-2011') <> 541910
        THROW 50004, 'So dong sheet 2010-2011 khong khop.', 1;
    IF EXISTS (
        SELECT SourceSheet, SourceRow FROM dbo.RetailRaw
        GROUP BY SourceSheet, SourceRow HAVING COUNT(*) > 1
    )
        THROW 50005, 'Trung vi tri dong nguon. Kiem tra quy trinh xuat CSV.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
SELECT SourceSheet, COUNT_BIG(*) AS ImportedRows
FROM dbo.RetailRaw GROUP BY SourceSheet;
