> Historical explanatory notes adapted from the source exercise. Use README and docs/VALIDATION.md for current portfolio status. SQL paths below are relative to the project root.

# Giải thích bài thực hành SQL: doanh thu theo tháng và quý

## 1. Mình đang trả lời câu hỏi gì?

Mục tiêu là mô tả: **giá trị bán hàng thay đổi thế nào qua các tháng và quý trong hai sheet?** Đây là descriptive analysis — phân tích mô tả những gì đã ghi nhận. Kết quả không chứng minh nguyên nhân tăng giảm và không dùng để dự báo.

Notebook mẫu chủ yếu gồm Markdown, câu SQL và ảnh kết quả, sử dụng cú pháp MySQL. Bài mới giữ cách làm từng bước nhưng chuyển thành file `.sql` chạy trong SSMS: `TOP` thay cho `LIMIT`, dùng `DATEPART(QUARTER, ...)` cho quý. Không sao chép những phân tích tuổi, giới tính, giá vốn vì dữ liệu này không có các trường đó.

## 2. Hiểu dữ liệu trước khi tính

**Grain** là ý nghĩa của một dòng: ở đây là một dòng hàng hoặc một dòng ghi nhận/điều chỉnh trên hóa đơn. Một hóa đơn thường có nhiều dòng. Vì vậy `COUNT(*)` đếm dòng, còn `COUNT(DISTINCT Invoice)` đếm mã hóa đơn.

| Cột gốc | Ý nghĩa dùng trong bài |
|---|---|
| `Invoice` | Mã hóa đơn; giữ dạng chuỗi, đánh dấu mã bắt đầu `C` để kiểm tra hủy |
| `StockCode` | Mã hàng; không ép thành số |
| `Description` | Mô tả hàng/dòng ghi nhận |
| `Quantity` | Số lượng, có thể âm |
| `InvoiceDate` | Thời điểm ghi nhận |
| `Price` | Giá mỗi đơn vị; đổi tên thành `UnitPrice` trong view |
| `Customer ID` | Mã khách hàng; thiếu không đồng nghĩa giao dịch bằng 0 |
| `Country` | Quốc gia được ghi trong dữ liệu |

CSV thêm `SourceSheet` và `SourceRow` để truy ngược Excel. Chúng là khóa vị trí nguồn, không phải khóa khách hàng. Không tạo `customer_id` mới bằng số thứ tự vì như vậy mỗi dòng hàng sẽ bị hiểu nhầm thành một khách hàng.

Hai sheet có **525.461** và **541.910** dòng, tổng **1.067.371** dòng dữ liệu, không tính header. Khoảng thời gian quan sát là **01/12/2009–09/12/2011**. Các ngày được giữ theo đồng hồ trong workbook; không có thông tin múi giờ để chuyển đổi.

## 3. EDA cho thấy điều gì và xử lý thế nào?

EDA (Exploratory Data Analysis) là bước khám phá chất lượng và đặc điểm dữ liệu trước khi phân tích.

| Kiểm tra trên workbook | Kết quả | Quyết định |
|---|---:|---|
| Thiếu mã khách hàng | 243.007 dòng | Giữ khi tính doanh thu; không dùng các dòng này để đếm khách hàng định danh |
| Thiếu mô tả | 4.382 dòng | Không loại chỉ vì thiếu mô tả; các điều kiện số lượng/giá quyết định khả năng tính giá trị |
| Số lượng âm | 22.950 dòng | Không xóa hàng loạt; kiểm tra cùng giá và hóa đơn |
| Số lượng bằng 0 | 0 dòng | Quy tắc vẫn loại khỏi tập tính giá trị nếu có trong lần chạy khác |
| Giá bằng 0 | 6.202 dòng | Giữ trong raw, không đưa vào KPI bán hàng có giá dương |
| Giá âm | 5 dòng | Giữ trong raw, loại khỏi KPI chính; cần đối soát nghiệp vụ riêng |
| Mã hóa đơn bắt đầu `C` | 19.494 dòng | Không coi là bán hàng thông thường |
| Mã `C` nhưng số lượng dương | 1 dòng | Tách khỏi `SalesRevenue`; vẫn hiện trong giá trị ghi nhận dương |
| Nhóm trùng toàn bộ 8 cột nguồn | 32.907 nhóm | Chưa đủ bằng chứng để tự xóa |
| Số dòng dư trong các nhóm trùng | 34.335 dòng | Giữ trong kết quả chính, có truy vấn đánh giá độ nhạy |

Số lượng nằm trong khoảng **−80.995 đến 80.995**, giá trong khoảng **−53.594,36 đến 38.970**. Đây là các giá trị cần kiểm tra nghiệp vụ; lớn hoặc âm không tự động có nghĩa là nhập sai. Không cắt outlier theo IQR hoặc thay bằng trung bình vì có thể làm thay đổi tổng giá trị có thật. File SQL bổ sung `AVG` và `STDEV` để xem trung bình và độ phân tán; với phân phối lệch, trung bình không đại diện tốt cho một giao dịch điển hình.

Không tự xóa dòng trùng vì nguồn không có mã dòng giao dịch duy nhất. Hai dòng giống nhau có thể là nhập lặp hoặc hai dòng ghi nhận hợp lệ. Kết quả vì thế là **tổng theo bản ghi nguồn đang giữ**, còn rủi ro ghi nhận lặp chưa được giải quyết. Mục 12 trong SQL tính giá trị bán hàng nằm ở các dòng trùng dư để người học thấy độ nhạy nếu đổi chính sách. Thống kê trùng Python so sánh giá trị nguồn; SQL dùng quy tắc so sánh chuỗi theo collation của database nên có thể gộp thêm khác biệt chữ hoa/thường hoặc khoảng trắng cuối.

Các số đếm chất lượng có thể giao nhau. Ví dụ một dòng vừa thiếu mô tả vừa có giá 0; không cộng các cột lỗi để suy ra số dòng loại.

## 4. Quy tắc làm sạch và định nghĩa chỉ tiêu

Làm sạch qua **view**, là truy vấn lưu sẵn, không xóa/sửa bảng nguồn:

1. `RetailRaw`: dữ liệu nhập dạng chuỗi, giữ nguồn và vị trí dòng.
2. `v_RetailTyped`: bỏ khoảng trắng đầu/cuối, chuyển chuỗi rỗng thành `NULL`, ép kiểu số/ngày bằng `TRY_CONVERT`.
3. `v_RetailEligible`: chỉ giữ mã hóa đơn, mã hàng, ngày hợp lệ; số lượng khác 0 và giá dương.

`TRY_CONVERT` trả `NULL` nếu chuyển kiểu không thành công. Phải đếm các trường hợp này để không âm thầm mất dữ liệu khi lọc. Với workbook hiện tại, Python đọc được số lượng, giá, ngày cho toàn bộ dòng; kết quả ép kiểu T-SQL vẫn phải được kiểm tra khi chạy SSMS.

| Chỉ tiêu | Công thức / tập tính | Cách hiểu |
|---|---|---|
| `LineValue` | `Quantity * UnitPrice` trên dòng eligible | Giá trị của một dòng |
| `SalesRevenue` | Tổng `LineValue` với số lượng dương và mã hóa đơn không bắt đầu `C` | Chỉ tiêu chính: giá trị bán hàng dương theo quy tắc bài |
| `PositiveRecordedValue` | Tổng `LineValue > 0` trên mọi dòng eligible | Bao gồm cả dòng `C` bất thường có số lượng dương |
| `NegativeRecordedValue` | Tổng `LineValue < 0` trên mọi dòng eligible | Giá trị âm, giữ nguyên dấu; chưa khẳng định tất cả là hàng trả |
| `NetRecordedValue` | Tổng mọi `LineValue` eligible | Giá trị có dấu của tập đủ điều kiện; chưa phải doanh thu thuần kế toán đã đối soát |
| `SaleInvoices` | `COUNT(DISTINCT Invoice)` trên dòng `IsSale = 1` | Số mã hóa đơn có dòng bán đủ điều kiện |
| `RevenuePerInvoice` | `SalesRevenue / SaleInvoices` | Giá trị bán dương bình quân trên hóa đơn đủ điều kiện |

Phạm vi mặc định là cả hai sheet, giữ dòng trùng, không loại quốc gia hoặc khách hàng thiếu ID. Kỳ tính theo `InvoiceDate`. Đơn vị giữ nguyên theo workbook; **chưa xác minh đồng tiền**, không tự gắn nhãn VND/GBP. Không có cost nên không tính profit hoặc profit margin. Giá trị âm được ghi vào kỳ xuất hiện, không chuyển ngược về kỳ hóa đơn gốc khi chưa đối soát.

Ví dụ giả lập: bán 2 sản phẩm giá 10 có `LineValue = 20`; một dòng điều chỉnh −1 sản phẩm giá 10 có `LineValue = -10`. Khi đó giá trị dương 20, giá trị âm −10, giá trị có dấu 10. Đây chỉ là ví dụ minh họa, không phải hai dòng lấy từ workbook.

**Độ chính xác số:** SQL dùng `decimal`, không dùng `float` cho tiền. Giá làm tròn đến 6 chữ số thập phân. Có 112.879 giá lưu trong XML vượt 6 chữ số thập phân, nhiều giá có đuôi biểu diễn số của Excel; bài quy định làm tròn rõ ràng và Python đối chiếu cùng quy tắc. CSV giữ giá thập phân nguồn đầy đủ. Không làm tròn từng dòng về 2 chữ số vì workbook có giá ở mức 3 chữ số thập phân. Khi trình bày có thể làm tròn tổng về 2 chữ số nhưng khi đối chiếu vẫn dùng 6 chữ số.

## 5. Cách đọc từng phần trong file SQL

| Mục trong `02_thuc_hanh.sql` | Kiến thức / mục đích |
|---|---|
| 1 | `TOP`, `ORDER BY`, `COUNT_BIG`, kiểm tra dữ liệu đã nhập |
| 2 | `NULLIF`, `LTRIM/RTRIM`, `TRY_CONVERT`, tạo view có kiểu dữ liệu đúng |
| 3 | `MIN`, `MAX`, `AVG`, `STDEV`, `CASE`, `GROUP BY`, `HAVING` để khám phá dữ liệu |
| 4 | `WHERE` và `CASE` để tách tập đủ điều kiện và dòng bán hàng |
| 5 | Kiểm tra số dòng loại/giữ và tổng tiền; xem ví dụ dòng bị loại |
| 6 | Lọc khoảng ngày, quốc gia và sắp xếp giá trị giảm dần |
| 7 | Phân biệt dòng hàng, hóa đơn và bình quân hóa đơn |
| 8 | Nhóm doanh thu theo năm và tháng |
| 9 | Nhóm doanh thu theo năm và quý |
| 10 | `TOP (5)` các tháng có doanh thu lớn, bỏ tháng cuối chưa đủ |
| 11 | So sánh cùng phạm vi tháng 1–11 giữa hai năm |
| 12 | Kiểm tra giá trị bị ảnh hưởng nếu giả định dòng trùng dư phải loại |

Trong mục 6, dùng `>= '20101101' AND < '20101201'` để lấy trọn tháng 11, kể cả giao dịch cuối ngày 30/11. Dùng `<= '20101130'` với cột thời gian có thể bỏ các giao dịch sau 00:00 ngày đó.

`GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)` tách tháng của từng năm. Nếu chỉ `GROUP BY MONTH(...)`, tháng 1/2010 và tháng 1/2011 sẽ bị cộng chung. Tương tự, phải nhóm quý cùng năm. Không cộng các giá trị bình quân hoặc số hóa đơn distinct của từng tháng để thay thế việc tính lại KPI cho cả năm.

`NULLIF(..., 0)` ở mẫu số tránh lỗi chia cho 0. `SUM(Cost)` mới là cộng chi phí nếu có cột Cost; `COUNT(Cost)` chỉ đếm ô Cost không NULL, không phải tổng chi phí — đây là điểm cần sửa về tư duy so với một câu trong notebook mẫu.

## 6. Kết quả đối chiếu độc lập

Các số dưới đây được **chạy bằng Python trên workbook**, không phải ảnh/kết quả thực thi SSMS. Hai CSV trong `outputs/` có đầy đủ 25 tháng và 9 quý để đối chiếu với SQL sau khi chạy.

| Chỉ tiêu toàn kỳ | Kết quả |
|---|---:|
| Dòng nguồn | 1.067.371 |
| Dòng eligible | 1.061.164 |
| Dòng loại khỏi tập tính giá trị | 6.207 |
| Dòng bán hàng dương không mang mã `C` | 1.041.670 |
| `SalesRevenue` | 20.972.594,568000 |
| `PositiveRecordedValue` | 20.972.968,138000 |
| `NegativeRecordedValue` | −1.527.041,430000 |
| `NetRecordedValue` | 19.445.926,708000 |

Kiểm tra bắt buộc:

```text
1.067.371 = 1.061.164 + 6.207
19.445.926,708000 = 20.972.968,138000 - 1.527.041,430000
Tổng từng chỉ tiêu theo tháng = tổng cùng chỉ tiêu theo quý = tổng toàn kỳ
```

**Không** lấy `SalesRevenue + NegativeRecordedValue` để đối chiếu net một cách máy móc: workbook có một dòng `C` số lượng dương trị giá **373,57**, nằm trong `PositiveRecordedValue` nhưng không nằm trong `SalesRevenue`.

| Tháng doanh thu bán hàng cao nhất | `SalesRevenue` |
|---|---:|
| 11/2011 | 1.509.496,330000 |
| 11/2010 | 1.470.272,482000 |
| 12/2010 | 1.262.598,790000 |
| 10/2010 | 1.165.483,910000 |
| 10/2011 | 1.154.979,300000 |

Tháng 11 đứng cao ở cả hai năm quan sát. Đây là dấu hiệu mô tả về mức bán hàng tăng vào cuối năm, chưa đủ để kết luận mùa vụ ổn định hoặc nguyên nhân từ chiến dịch marketing.

Năm 2010, `SalesRevenue` theo quý tăng từ **2.039.618,369** ở Q1 lên **3.898.355,182** ở Q4. So sánh tháng 1–11 cùng phạm vi: năm 2010 là **9.041.353,614**, năm 2011 là **9.204.145,724**, tăng khoảng **1,80%** theo quy tắc đang dùng. Mức tăng này chưa điều chỉnh lạm phát, thay đổi tập hàng/khách, dòng trùng hoặc các nghiệp vụ đặc biệt.

## 7. Giới hạn quan trọng khi đọc xu hướng

- **Q4/2009 chỉ có tháng 12.** Không so trực tiếp với Q4/2010 đầy đủ.
- **Tháng 12/2011 chỉ có đến ngày 09/12**, nên Q4/2011 cũng chưa đầy đủ. Không kết luận doanh thu cả tháng/quý giảm từ tổng chưa đủ kỳ.
- Ngày đầu/cuối trong bảng tháng/quý giúp phát hiện kỳ biên thiếu; có giao dịch ở đầu/cuối kỳ không chứng minh dữ liệu đã bao phủ mọi ngày hoặc mọi giao dịch.
- Bài giữ các dòng có giá dương, kể cả mã dòng đặc biệt hoặc khoản phí. Vì chưa có bảng ánh xạ nghiệp vụ, không gọi toàn bộ kết quả là doanh thu hàng hóa thuần túy.
- Không tự coi mọi số lượng âm là hàng trả. Muốn tính return rate chính xác phải định nghĩa trả hàng, kiểm tra hóa đơn gốc, số lượng và thời điểm tương ứng.
- Khách hàng thiếu ID và dòng trùng được giữ có chủ đích; tổng phản ánh bản ghi nguồn theo chính sách này. Nếu cần số liệu tài chính chính thức phải đối soát nguồn kế toán.

## 8. Trạng thái chạy và bước thực hành của bạn

Đã xuất hai sheet, đọc lại toàn bộ CSV để kiểm tra số cột/số dòng, thống kê dữ liệu và đối chiếu tổng tháng/quý. File nguồn được giữ nguyên, có SHA-256 trong `outputs/data_profile.json`.

**Chưa kiểm thử thực thi T-SQL trên SQL Server:** phiên tự động gặp lỗi `Cannot generate SSPI context` khi kết nối Windows Authentication. Vì vậy chưa khẳng định import, ép kiểu hoặc truy vấn đã chạy thành công trong SSMS của bạn. Cách xác nhận là chạy file 01, xem đủ số dòng, chạy file 02 và đối chiếu mục 5/8/9 với các kết quả kỳ vọng.

Sau khi chạy được, bạn thử đổi truy vấn tháng để chỉ lấy `United Kingdom`, rồi giải thích vì sao cần áp dụng cùng bộ lọc quốc gia khi so sánh hai năm. Đây là bài tập chuyển giao nhỏ để kiểm tra bạn hiểu phạm vi KPI.
