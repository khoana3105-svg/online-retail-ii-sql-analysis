/* Thuc hanh SQL co ban: Online Retail II, SQL Server 2017+.
   Quy tac va cach doc ket qua: xem GIAI_THICH.md.
   Khong UPDATE/DELETE du lieu goc. Cac view co the tao lai an toan.
*/
USE OnlineRetailII_Portfolio;
GO

-- 1. Hieu du lieu: mot dong la mot dong hang, KHONG phai mot khach hang/don hang.
SELECT TOP (10) * FROM dbo.RetailRaw ORDER BY SourceSheet, TRY_CONVERT(int, SourceRow) OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
SELECT SourceSheet, COUNT_BIG(*) AS TotalRows
FROM dbo.RetailRaw GROUP BY SourceSheet OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
GO

-- 2. Chuan hoa chuoi va ep kieu; TRY_CONVERT tra NULL neu khong ep duoc.
CREATE OR ALTER VIEW dbo.v_RetailTyped AS
SELECT SourceSheet, TRY_CONVERT(int, SourceRow) AS SourceRow,
    NULLIF(LTRIM(RTRIM(Invoice)), N'') AS Invoice,
    NULLIF(LTRIM(RTRIM(StockCode)), N'') AS StockCode,
    NULLIF(LTRIM(RTRIM(Description)), N'') AS Description,
    TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(Quantity)), N'')) AS Quantity,
    TRY_CONVERT(datetime2(0), NULLIF(LTRIM(RTRIM(InvoiceDate)), N''), 126) AS InvoiceDate,
    TRY_CONVERT(decimal(19,6), NULLIF(LTRIM(RTRIM(Price)), N'')) AS UnitPrice,
    NULLIF(LTRIM(RTRIM(CustomerID)), N'') AS CustomerID,
    NULLIF(LTRIM(RTRIM(Country)), N'') AS Country
FROM dbo.RetailRaw;
GO

-- 3. EDA: thieu du lieu, mien gia tri, ngay va dong huy.
SELECT COUNT_BIG(*) AS TotalRows,
    MIN(InvoiceDate) AS FirstDate, MAX(InvoiceDate) AS LastDate,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS MissingCustomer,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS MissingDescription,
    SUM(CASE WHEN Invoice IS NULL THEN 1 ELSE 0 END) AS MissingInvoice,
    SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS MissingStockCode,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS MissingCountry,
    SUM(CASE WHEN Quantity IS NULL OR UnitPrice IS NULL OR InvoiceDate IS NULL THEN 1 ELSE 0 END) AS InvalidMeasures,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS NegativeQuantity,
    SUM(CASE WHEN Quantity = 0 THEN 1 ELSE 0 END) AS ZeroQuantity,
    SUM(CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END) AS NegativePrice,
    SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END) AS ZeroPrice,
    SUM(CASE WHEN UPPER(Invoice) LIKE N'C%' THEN 1 ELSE 0 END) AS CInvoices,
    SUM(CASE WHEN UPPER(Invoice) LIKE N'C%' AND Quantity > 0 THEN 1 ELSE 0 END) AS CWithPositiveQuantity
FROM dbo.v_RetailTyped OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

SELECT MIN(Quantity) AS MinQuantity, MAX(Quantity) AS MaxQuantity,
    AVG(CAST(Quantity AS decimal(19,6))) AS MeanQuantity,
    STDEV(CAST(Quantity AS float)) AS StdQuantity,
    MIN(UnitPrice) AS MinPrice, MAX(UnitPrice) AS MaxPrice,
    AVG(UnitPrice) AS MeanPrice, STDEV(CAST(UnitPrice AS float)) AS StdPrice
FROM dbo.v_RetailTyped OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- Thong ke TRUNG TOAN BO 8 cot nguon; khong xoa vi chua biet nguyen nhan.
-- SourceSheet/SourceRow la vi tri nguon nen khong nam trong nhom so sanh.
SELECT COUNT_BIG(*) AS DuplicateGroups, SUM(GroupRows - 1) AS ExtraDuplicateRows
FROM (
    SELECT COUNT_BIG(*) AS GroupRows
    FROM dbo.RetailRaw
    GROUP BY Invoice, StockCode, Description, Quantity, InvoiceDate, Price, CustomerID, Country
    HAVING COUNT_BIG(*) > 1
) AS Duplicates OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
GO

-- 4. Tap dong co the tinh gia tri: giu so luong am de theo doi dieu chinh.
-- Khong goi tat ca dong am la hang tra: chua doi soat hoa don goc.
CREATE OR ALTER VIEW dbo.v_RetailEligible AS
SELECT *, CAST(Quantity * UnitPrice AS decimal(28,6)) AS LineValue,
    CASE WHEN Quantity > 0 AND UPPER(Invoice) NOT LIKE N'C%' THEN 1 ELSE 0 END AS IsSale
FROM dbo.v_RetailTyped
WHERE Invoice IS NOT NULL AND StockCode IS NOT NULL AND InvoiceDate IS NOT NULL
    AND Quantity IS NOT NULL AND Quantity <> 0 AND UnitPrice > 0;
GO

-- 5. Doi soat: tong = giu lai + loai; tong co dau = duong + am.
SELECT (SELECT COUNT_BIG(*) FROM dbo.RetailRaw) AS RawRows,
    COUNT_BIG(*) AS EligibleRows,
    (SELECT COUNT_BIG(*) FROM dbo.RetailRaw) - COUNT_BIG(*) AS ExcludedRows,
    SUM(CASE WHEN IsSale = 1 THEN 1 ELSE 0 END) AS PositiveSaleRows,
    SUM(LineValue) AS NetRecordedValue,
    SUM(CASE WHEN LineValue > 0 THEN LineValue ELSE 0 END) AS PositiveRecordedValue,
    SUM(CASE WHEN LineValue < 0 THEN LineValue ELSE 0 END) AS NegativeRecordedValue,
    SUM(CASE WHEN IsSale = 1 THEN LineValue ELSE 0 END) AS SalesRevenue
FROM dbo.v_RetailEligible OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- Xem cac dong bi loai tru, thay vi am tham xoa chung.
SELECT TOP (50) * FROM dbo.v_RetailTyped
WHERE Invoice IS NULL OR StockCode IS NULL OR InvoiceDate IS NULL
    OR Quantity IS NULL OR Quantity = 0 OR UnitPrice IS NULL OR UnitPrice <= 0
ORDER BY SourceSheet, SourceRow OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 6. Loc du lieu co ban: mot thang, mot quoc gia, top dong ban hang.
SELECT TOP (20) Invoice, StockCode, InvoiceDate, Country, Quantity, UnitPrice, LineValue
FROM dbo.v_RetailEligible
WHERE InvoiceDate >= '20101101' AND InvoiceDate < '20101201'
    AND Country = N'United Kingdom' AND IsSale = 1
ORDER BY LineValue DESC, Invoice, StockCode OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 7. KPI toan ky: doanh thu ban duong, so hoa don, gia tri binh quan hoa don.
-- COUNT(DISTINCT Invoice): dem hoa don, khong dem dong hang.
SELECT SUM(LineValue) AS SalesRevenue,
    COUNT(DISTINCT Invoice) AS SaleInvoices,
    SUM(LineValue) / NULLIF(COUNT(DISTINCT Invoice), 0) AS RevenuePerInvoice,
    SUM(CAST(Quantity AS bigint)) AS UnitsSold
FROM dbo.v_RetailEligible WHERE IsSale = 1 OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 8. Doanh thu theo THANG: group ca nam va thang de khong gop nhieu nam.
SELECT YEAR(InvoiceDate) AS SalesYear, MONTH(InvoiceDate) AS SalesMonth,
    COUNT_BIG(*) AS EligibleRows,
    SUM(CASE WHEN IsSale = 1 THEN LineValue ELSE 0 END) AS SalesRevenue,
    COUNT(DISTINCT CASE WHEN IsSale = 1 THEN Invoice END) AS SaleInvoices,
    SUM(CASE WHEN LineValue > 0 THEN LineValue ELSE 0 END) AS PositiveRecordedValue,
    SUM(CASE WHEN LineValue < 0 THEN LineValue ELSE 0 END) AS NegativeRecordedValue,
    SUM(LineValue) AS NetRecordedValue,
    MIN(CAST(InvoiceDate AS date)) AS FirstObservedDate,
    MAX(CAST(InvoiceDate AS date)) AS LastObservedDate
FROM dbo.v_RetailEligible
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 9. Doanh thu theo QUY: Q1=1-3, Q2=4-6, Q3=7-9, Q4=10-12.
SELECT YEAR(InvoiceDate) AS SalesYear, DATEPART(QUARTER, InvoiceDate) AS SalesQuarter,
    COUNT_BIG(*) AS EligibleRows,
    SUM(CASE WHEN IsSale = 1 THEN LineValue ELSE 0 END) AS SalesRevenue,
    SUM(CASE WHEN LineValue > 0 THEN LineValue ELSE 0 END) AS PositiveRecordedValue,
    SUM(CASE WHEN LineValue < 0 THEN LineValue ELSE 0 END) AS NegativeRecordedValue,
    SUM(LineValue) AS NetRecordedValue,
    MIN(CAST(InvoiceDate AS date)) AS FirstObservedDate,
    MAX(CAST(InvoiceDate AS date)) AS LastObservedDate
FROM dbo.v_RetailEligible
GROUP BY YEAR(InvoiceDate), DATEPART(QUARTER, InvoiceDate)
ORDER BY SalesYear, SalesQuarter OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 10. Top 5 thang doanh thu cao: bo thang 12/2011 vi chi co mot phan thang.
SELECT TOP (5) YEAR(InvoiceDate) AS SalesYear, MONTH(InvoiceDate) AS SalesMonth,
    SUM(LineValue) AS SalesRevenue
FROM dbo.v_RetailEligible
WHERE IsSale = 1 AND InvoiceDate < '20111201'
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesRevenue DESC, SalesYear, SalesMonth OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 11. So sanh cung 11 thang: tranh so ca nam 2010 voi nam 2011 chua du.
SELECT YEAR(InvoiceDate) AS SalesYear, SUM(LineValue) AS JanToNovSalesRevenue
FROM dbo.v_RetailEligible
WHERE IsSale = 1 AND YEAR(InvoiceDate) IN (2010, 2011) AND MONTH(InvoiceDate) <= 11
GROUP BY YEAR(InvoiceDate) ORDER BY SalesYear OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);

-- 12. Do nhay voi dong trung: tong gia tri tren cac dong trung du thua.
-- Chi de danh gia tac dong; khong tu dong tru khoi KPI chinh.
SELECT SUM(CAST((GroupRows - 1) * Quantity * UnitPrice AS decimal(28,6))) AS DuplicateExtraSalesValue
FROM (
    SELECT Invoice, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country,
        COUNT_BIG(*) AS GroupRows
    FROM dbo.v_RetailEligible WHERE IsSale = 1
    GROUP BY Invoice, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country
    HAVING COUNT_BIG(*) > 1
) AS Duplicates OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
