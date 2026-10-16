# Kiểm chứng / Validation

**Kết quả cuối: PASS.** Đã chạy 17 result sets trên SQL Server 2022 (16.0.1000.6) trong `OnlineRetailII_Portfolio`, đối chiếu tổng tháng/quý, phân kỳ, MoM/YoY, observed YTD, moving average và quốc gia bằng Decimal. [Receipt cuối](../outputs/sql_server/verification.json), [execution metadata](../outputs/sql_server/execution.json). Trạng thái lịch sử chưa thực thi trong các JSON nguồn không thay thế kết quả cuối này.

## Đã thực hiện trong bản portfolio

- Đối chiếu workbook, CSV đầu vào và các bảng monthly/quarterly từ bài nguồn. Workbook và SQL bài gốc không bị sửa.
- Tạo database **OnlineRetailII_Portfolio** riêng và nạp 1.067.371 dòng; kết quả import theo sheet nằm trong `outputs/sql_server/01_nhap_du_lieu_01.csv`.
- Phân tích cú pháp cả 3 file SQL bằng Microsoft ScriptDom: 0 lỗi; [syntax_validation.json](../outputs/syntax_validation.json). Syntax pass không thay thế thực thi engine.
- Có script đối chiếu độc lập bằng Decimal: monthly, quarterly, MoM/YoY, observed YTD, moving average, tỷ trọng quốc gia và kỳ biên. `outputs/time_reference.csv` là tính toán Python từ monthly reference, không giả làm kết quả SQL.
- Kết quả chạy SQL và receipt đối chiếu cuối (nếu hoàn tất) nằm tại `outputs/sql_server/`; trạng thái cũ trong `outputs/verification.json` là lịch sử bài nguồn, không phải receipt mới.

## Tài nguyên và giới hạn

Các SELECT tổng hợp ban đầu gặp chờ `RESOURCE_SEMAPHORE`. Đã thử query-level MAXDOP 1 và memory grant cap; không đổi cấu hình SQL Server. Truy vấn trên hơn một triệu dòng chuỗi có thể chạy lâu hoặc spill ra tempdb. Xem `METHOD.md`; không suy ra đây là tối ưu hiệu năng chung.

Nếu chưa có `outputs/sql_server/verification.json` với status passed, chưa coi bước đối chiếu end-to-end là hoàn tất. Chạy `src/run_sql_server.ps1` trên database đã nạp, rồi `python src/verify_sql_server.py`. Không chạy loader lại khi đã có bảng.

Chưa so byte với bản workbook mới từ UCI, chưa đối soát kế toán, chưa chứng minh đầy đủ mọi ngày từ min/max date. Các mô tả GBP và CC BY 4.0 được đối chiếu từ trang UCI; workbook cục bộ có tên/quy mô/khoảng ngày phù hợp nhưng không tuyên bố source identity vượt quá checksum đã ghi.

## English

Final status: PASS. Executed 17 result sets and reconciled monthly/quarterly totals, MoM/YoY, observed YTD, moving average, boundary NULLs and country shares against independent Decimal expectations. The receipt is `outputs/sql_server/verification.json`. RESOURCE_SEMAPHORE waits were observed before the successful serial/bounded-grant run; no server settings were changed. No accounting, source-download byte comparison or completeness certification is claimed.
