# Online Retail II — SQL Time Analysis

**Nguyễn Anh Khoa · SQL Server / SSMS · Bài thực hành SQL cơ bản**

Mình làm bài này để luyện SQL với dữ liệu bán hàng Online Retail II. Mục tiêu của mình là đọc hiểu dữ liệu, kiểm tra những dòng cần lưu ý và tổng hợp giá trị bán theo tháng, quý, quốc gia. Mình ưu tiên hiểu từng câu lệnh trước khi học thêm phần khó hơn.

Đây là bản portfolio được hoàn thiện với AI hỗ trợ từ bài thực hành và dữ liệu mình cung cấp. Notebook Kaggle chỉ được dùng để tham khảo trình tự; mình không dùng bộ sales của notebook đó hoặc coi code tham khảo là đóng góp riêng. [English version](README.en.md).

## Phần mình học và phần được hỗ trợ

Mình đang học SQL cơ bản. Phần chính mình tập trung là `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `COUNT` và `SUM` trong file 02. Các câu hỏi, dữ liệu và kết quả của bài được ghi lại để mình có thể chạy lại trong SSMS.

Phần CTE, window functions trong file 03, script Python/PowerShell, kiểm tra tự động và xử lý kỹ thuật do AI hỗ trợ. Mình giữ các phần này làm tài liệu học thêm, chưa xem đây là kỹ năng mình đã tự làm thành thạo. Chi tiết và thứ tự học ở [hướng dẫn đọc bài](docs/LEARNING_AND_CONTRIBUTIONS.md).

**Đã chạy và đối chiếu trên SQL Server 2022:** 17 result sets, 25 kỳ tháng, tổng quý và các phép so sánh thời gian đều đạt. Xem [receipt](outputs/sql_server/verification.json).

## Câu hỏi mình phân tích

1. Giá trị bán hàng thay đổi như thế nào theo tháng/quý?
2. Nếu chỉ so cùng tháng 1–11, năm 2011 khác năm 2010 bao nhiêu?
3. Tháng nào chưa đủ dữ liệu để so sánh? Phần mở rộng có minh họa MoM, YoY và trung bình trượt.
4. Các quốc gia đóng góp bao nhiêu vào tổng giá trị bán trong mẫu?

## Dữ liệu và định nghĩa

- Workbook có **1.067.371 dòng hàng**, hai sheet, khoảng quan sát 01/12/2009–09/12/2011.
- Nguồn xuất bản đối chiếu: Chen, D. (2012), [Online Retail II, UCI](https://doi.org/10.24432/C5CG6D), CC BY 4.0. Theo từ điển UCI, giá tính bằng bảng Anh (GBP). Workbook cục bộ khớp tên, quy mô và khoảng ngày; chưa so bytes với bản tải mới từ UCI.
- Một dòng là một dòng hàng trên hóa đơn, không phải một khách hàng hoặc một đơn.
- **SalesRevenue:** tổng Quantity × UnitPrice trên dòng có mã hóa đơn/sản phẩm, ngày và số lượng hợp lệ, UnitPrice > 0, Quantity > 0, hóa đơn không bắt đầu bằng C.
- **NetRecordedValue:** tổng có dấu trên tập đủ điều kiện; giữ số lượng âm. Không gọi mọi dòng âm là hàng trả đã xác minh.
- Giữ dòng trùng và khách thiếu ID vì chưa đủ bằng chứng để xóa. Không tự đổi missing thành 0.

## Mở file nào?

| File | Vai trò |
|---|---|
| [sql/01_nhap_du_lieu.sql](sql/01_nhap_du_lieu.sql) | Tạo database riêng và nhập CSV; chặn nạp trùng |
| [sql/02_thuc_hanh.sql](sql/02_thuc_hanh.sql) | Kiểm tra dữ liệu và tạo view phân tích |
| [sql/03_time_comparisons.sql](sql/03_time_comparisons.sql) | CTE, MoM/YoY, observed YTD, trung bình trượt, xếp hạng quốc gia |
| [docs/METHOD.md](docs/METHOD.md) | Giải thích lựa chọn phương pháp và điểm dễ sai |
| [data/README.md](data/README.md) | Nguồn và cách tải workbook |
| [outputs/monthly_expected.csv](outputs/monthly_expected.csv) | Tổng tháng đối chiếu độc lập bằng Python |
| [outputs/quarterly_expected.csv](outputs/quarterly_expected.csv) | Tổng quý đối chiếu độc lập bằng Python |
| [docs/VALIDATION.md](docs/VALIDATION.md) | Phạm vi kiểm tra và giới hạn |

## Chạy trong SSMS

1. Có SQL Server 2017+, kết nối bằng tài khoản của bạn. SSMS là giao diện, không thay thế SQL Server Database Engine.
2. Tải workbook theo `data/README.md`, đặt ở `data/raw/online_retail_II.xlsx`.
3. Chạy `python src/prepare_retail.py` để xuất CSV và các bảng đối chiếu; chỉ cần Python standard library.
4. Mở file 01 trong SSMS, sửa `@CsvPath` tới CSV trên **máy chạy SQL Server**, chạy toàn bộ file. Database là **OnlineRetailII_Portfolio**, tách khỏi bài thực hành cũ.
5. Chạy file 02, rồi file 03. Không chạy file 01 lần nữa nếu đã có bảng.
6. Đối chiếu kết quả với các CSV và ghi nhận trong `docs/VALIDATION.md`.

Không sửa hay xóa workbook gốc. Mọi output sinh lại nằm riêng trong `data/processed/` và `outputs/`. Các lệnh CREATE/ALTER chỉ áp dụng cho database portfolio được nêu trong file; không chạy trên production.

## Kết quả cần đọc đúng

Theo đối chiếu độc lập đã có, SalesRevenue tháng 11/2011 là **1.509.496,33**, cao nhất trong các tháng đủ phạm vi đang xét. Tổng tháng 1–11/2011 khoảng **9.204.145,724**, so với **9.041.353,614** cùng kỳ năm 2010, tăng khoảng **1,80%** theo định nghĩa của bài.

Đây không phải lợi nhuận, không điều chỉnh lạm phát và chưa đối soát sổ kế toán. Chưa đủ bằng chứng để quy mức tăng cho marketing hoặc kết luận mùa vụ ổn định từ khoảng hai năm dữ liệu.

Tháng 12/2011 chỉ có đến ngày 09 nên MoM/YoY/trung bình trượt liên quan kỳ này được để NULL trong file 03. Q4/2009 chỉ có tháng 12; `ObservedYTD` năm 2009 là tổng phần đã quan sát, không phải đủ năm.

## Đưa lên GitHub

Upload README, sql/, src/, docs/, data/README.md và các output tổng hợp đã rà soát. Không upload workbook, ZIP hoặc `data/processed/retail_raw.csv`. Các thư mục dữ liệu chỉ cần `.gitkeep`; `.gitignore` không chặn upload thủ công. Xem [hướng dẫn portfolio](docs/UPLOAD_AND_CV.md).
