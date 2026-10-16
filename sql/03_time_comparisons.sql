/* Phan tich thoi gian: CTE + LAG + SUM/AVG OVER.
   Chi chay sau file 01 va 02. Khong thay doi du lieu goc.
   GBP theo mo ta UCI; chua phai doanh thu ke toan doi soat.
*/
USE OnlineRetailII_Portfolio;
GO

-- 01. Tong hop THANG truoc, roi moi dung window functions.
-- LAG la dong truoc: kiem tra khoang cach lich, khong mac dinh la thang truoc.
;WITH Monthly AS (
    SELECT DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1) AS MonthStart,
        SUM(CASE WHEN IsSale = 1 THEN LineValue ELSE 0 END) AS SalesRevenue,
        SUM(LineValue) AS NetRecordedValue,
        COUNT(DISTINCT CASE WHEN IsSale = 1 THEN Invoice END) AS SaleInvoices
    FROM dbo.v_RetailEligible
    GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
), Coverage AS (
    SELECT MIN(CAST(InvoiceDate AS date)) AS FirstObservedDate,
        MAX(CAST(InvoiceDate AS date)) AS LastObservedDate
    FROM dbo.v_RetailEligible
), Prepared AS (
    SELECT m.*,
        CASE WHEN m.MonthStart < c.FirstObservedDate OR EOMONTH(m.MonthStart) > c.LastObservedDate
            THEN 0 ELSE 1 END AS WithinObservedCoverage
    FROM Monthly AS m CROSS JOIN Coverage AS c
), Compared AS (
    SELECT *,
        LAG(MonthStart) OVER (ORDER BY MonthStart) AS PreviousMonth,
        LAG(SalesRevenue) OVER (ORDER BY MonthStart) AS PreviousSalesRevenue,
        LAG(WithinObservedCoverage) OVER (ORDER BY MonthStart) AS PreviousCoverage,
        LAG(MonthStart, 12) OVER (ORDER BY MonthStart) AS PriorYearMonth,
        LAG(SalesRevenue, 12) OVER (ORDER BY MonthStart) AS PriorYearSalesRevenue,
        LAG(WithinObservedCoverage, 12) OVER (ORDER BY MonthStart) AS PriorYearCoverage,
        LAG(MonthStart, 2) OVER (ORDER BY MonthStart) AS TwoRowsBackMonth,
        SUM(SalesRevenue) OVER (PARTITION BY YEAR(MonthStart) ORDER BY MonthStart
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ObservedYTD,
        AVG(SalesRevenue) OVER (ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeRowMean,
        COUNT(*) OVER (ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeRowCount,
        MIN(WithinObservedCoverage) OVER (ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeRowCoverage
    FROM Prepared
)
SELECT MonthStart, SalesRevenue, NetRecordedValue, SaleInvoices, WithinObservedCoverage,
    CASE WHEN DATEDIFF(MONTH, PreviousMonth, MonthStart) = 1
        AND WithinObservedCoverage = 1 AND PreviousCoverage = 1
        THEN CAST(100.0 * (SalesRevenue - PreviousSalesRevenue) / NULLIF(PreviousSalesRevenue, 0) AS decimal(19,6)) END AS MoMPercent,
    CASE WHEN DATEDIFF(MONTH, PriorYearMonth, MonthStart) = 12
        AND WithinObservedCoverage = 1 AND PriorYearCoverage = 1
        THEN CAST(100.0 * (SalesRevenue - PriorYearSalesRevenue) / NULLIF(PriorYearSalesRevenue, 0) AS decimal(19,6)) END AS YoYPercent,
    ObservedYTD,
    CASE WHEN ThreeRowCount = 3 AND ThreeRowCoverage = 1
        AND DATEDIFF(MONTH, TwoRowsBackMonth, MonthStart) = 2
        THEN CAST(ThreeRowMean AS decimal(28,6)) END AS MovingAverage3Months
FROM Compared ORDER BY MonthStart OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
GO

-- 02. Cung ky: chi so sanh thang 1-11/2010 va 1-11/2011.
;WITH SamePeriod AS (
    SELECT YEAR(InvoiceDate) AS SalesYear, SUM(LineValue) AS JanToNovSalesRevenue
    FROM dbo.v_RetailEligible
    WHERE IsSale = 1 AND InvoiceDate >= '20100101' AND InvoiceDate < '20111201'
        AND MONTH(InvoiceDate) <= 11
    GROUP BY YEAR(InvoiceDate)
), Comparison AS (
    SELECT *, LAG(JanToNovSalesRevenue) OVER (ORDER BY SalesYear) AS PreviousYear
    FROM SamePeriod
)
SELECT SalesYear, JanToNovSalesRevenue,
    CAST(100.0 * (JanToNovSalesRevenue - PreviousYear) / NULLIF(PreviousYear, 0) AS decimal(19,6)) AS SamePeriodGrowthPercent
FROM Comparison ORDER BY SalesYear OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
GO

-- 03. Ty trong theo QUOC GIA: gia tri ban duong, khong phai thi phan thi truong.
;WITH CountrySales AS (
    SELECT COALESCE(Country, N'Unknown') AS Country, SUM(LineValue) AS SalesRevenue
    FROM dbo.v_RetailEligible WHERE IsSale = 1 GROUP BY Country
)
SELECT Country, SalesRevenue,
    CAST(100.0 * SalesRevenue / NULLIF(SUM(SalesRevenue) OVER (), 0) AS decimal(19,6)) AS SampleSalesSharePercent,
    DENSE_RANK() OVER (ORDER BY SalesRevenue DESC) AS SalesRank
FROM CountrySales ORDER BY SalesRevenue DESC, Country OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10);
GO
