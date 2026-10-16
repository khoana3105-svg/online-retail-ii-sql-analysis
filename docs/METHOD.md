# Cách mình xử lý bài / Method notes

## 1. Đi từ grain, không đi từ lệnh khó

Mình tổng hợp từ dòng hóa đơn lên **một dòng mỗi tháng** trước. CTE giúp tách các bước, không tự làm dữ liệu đúng hơn hoặc đảm bảo query nhanh hơn. Window functions bổ sung so sánh mà không làm mất dòng tháng.

Trong file 03, `LAG` lấy giá trị ở dòng trước. Mình kiểm tra `DATEDIFF` để không nhầm 12 dòng trước thành đúng 12 tháng trước khi dữ liệu có khoảng trống. Bản hiện tại có 25 tháng liên tiếp; nếu thay dữ liệu, cần xem lại coverage và định nghĩa tháng không có bản ghi.

## 2. Kỳ so sánh và mẫu số

- MoM = (giá trị tháng này − tháng trước) / tháng trước × 100; chỉ hiển thị nếu hai tháng kề lịch, nằm trọn trong khoảng quan sát và mẫu số khác 0.
- YoY tháng: tương tự với đúng tháng năm trước. Không dùng tổng cả năm 2010 để so với năm 2011 thiếu ngày cuối năm.
- Trung bình trượt 3 tháng: chỉ khi có đủ 3 tháng liền nhau, không có tháng biên bị cắt.
- ObservedYTD cộng dồn trong phần năm đã quan sát. Năm 2009 chỉ có tháng 12 nên không gọi là full-year YTD để so năm khác.
- Tỷ trọng quốc gia là tỷ trọng giá trị bán trong tập phân tích, không phải thị phần ngành.

`WithinObservedCoverage` chỉ kiểm tra ranh giới ngày đầu/cuối, **không chứng minh dữ liệu đầy đủ mọi ngày hoặc mọi giao dịch**. Nguồn không có bản ghi một ngày không đồng nghĩa doanh số ngày đó chắc chắn bằng 0.

## 3. Những bước không sao chép từ notebook mẫu

Không dùng MySQL `LIMIT`, `AUTO_INCREMENT` hay `CHANGE` trong SQL Server. Không gọi một mã hàng tạo bằng AUTO_INCREMENT là customer ID thật. Không dùng `COUNT(Cost)` như tổng chi phí. Không tự thay số lượng hoặc giá thiếu bằng 0 để dễ tính.

Notebook tham khảo: https://www.kaggle.com/code/emirakyer/sql-sales-data-analysis. Project dùng dữ liệu khác, KPI khác và cách kiểm tra riêng. Không đóng gói notebook/ảnh của tác giả tham khảo như kết quả của mình.

## 4. Kiểm tra trùng và bộ nhớ

Giữ các dòng có cùng 8 trường nguồn vì chưa có mã dòng giao dịch để chứng minh chúng là bản ghi nhập thừa. Báo cáo số nhóm và độ nhạy thay vì dùng DISTINCT che vấn đề.

Trong lần kiểm tra trên máy này, các SELECT tổng hợp gặp chờ `RESOURCE_SEMAPHORE`. Bản copy portfolio dùng `OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10)` ở các SELECT để giảm nhu cầu song song và giới hạn memory grant trên instance hiện tại. Không đổi cấu hình server; không khẳng định đây là tối ưu cho mọi máy. Trên dữ liệu/instance khác cần xem execution plan và tài nguyên, không thêm hint theo thói quen.

## English

Aggregate invoice lines to monthly grain before window calculations. Check calendar adjacency, incomplete boundary periods and denominator validity; retain duplicate-looking source rows unless their meaning is resolved. Source-span coverage is weaker than completeness. Portfolio SELECTs use serial execution and bounded query-level memory grants after observing RESOURCE_SEMAPHORE on this instance; this is a local execution accommodation, not a universal performance recommendation.

References: [UCI](https://archive.ics.uci.edu/dataset/502/online+retail+ii), [Microsoft LAG](https://learn.microsoft.com/en-us/sql/t-sql/functions/lag-transact-sql?view=sql-server-ver16), [query hints](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver16).
