# Online Retail II — SQL Time Analysis

**Nguyễn Anh Khoa · SQL Server / SSMS** · [Tiếng Việt](README.md)

I am learning basic SQL using Online Retail II sales data. My focus is understanding SELECT, WHERE, GROUP BY, ORDER BY, COUNT and SUM, then reading monthly, quarterly and country-level results. The reference Kaggle notebook inspired the workflow; I use a different dataset.

AI helped prepare the advanced CTE/window-function examples, Python/PowerShell scripts and automated checks. I keep these as learning material and do not claim independent proficiency in them. See [learning and contribution notes](docs/LEARNING_AND_CONTRIBUTIONS.md). Execution results below describe the checked project files, not a claim that I independently implemented every component.

Executed on SQL Server 2022: 17 result sets and all monthly/quarterly/time-comparison reconciliations passed. See the [execution receipt](outputs/sql_server/verification.json).

The workbook has 1,067,371 invoice lines across two sheets, spanning 1 December 2009 to 9 December 2011. Publisher: Chen, D. (2012), [UCI Online Retail II](https://doi.org/10.24432/C5CG6D), CC BY 4.0. UCI specifies sterling unit prices; the local file matches the published name, dimensions and date range, but was not byte-compared with a fresh download.

**SalesRevenue** is positive Quantity × UnitPrice on eligible invoice lines excluding C-prefixed invoices. **NetRecordedValue** preserves signed quantity on eligible priced rows. Missing customer IDs and apparent duplicate lines are retained intentionally. These are operational sample definitions, not reconciled accounting revenue or profit.

## Reproduce

1. Follow [data access](data/README.md), place the workbook in `data/raw/`, then run `python src/prepare_retail.py`.
2. In SSMS, run `sql/01_nhap_du_lieu.sql` after setting its CSV path to a server-accessible file. The dedicated database is `OnlineRetailII_Portfolio`; existing tables block reload.
3. Run `sql/02_thuc_hanh.sql`, then `sql/03_time_comparisons.sql`.
4. Review [validation](docs/VALIDATION.md) and compare actual results with the independently computed monthly/quarterly CSVs.

The advanced queries check calendar spacing before interpreting row offsets as months, exclude boundary-truncated periods from percentage comparisons, and return NULL for undefined denominators. Observed-year running totals do not imply full-year coverage. Raw workbook and processed row data are not bundled.

## Interpretation

Jan–Nov 2011 sales under this definition are about 1.80% higher than Jan–Nov 2010. December 2011 and Q4/2009 are incomplete boundary periods. No causal marketing effect, stable seasonality, inflation-adjusted growth or profit is inferred. See [method notes](docs/METHOD.md) and [upload/CV guide](docs/UPLOAD_AND_CV.md).
