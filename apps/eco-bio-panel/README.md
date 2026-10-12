# Eco-Bio Panel

Bản MVP song ngữ cho website Eco-Bio Panel. Trang công khai giới thiệu dự án; nút Đăng nhập mở không gian thành viên với các mục riêng về sản phẩm, Eco Lab, Eco Impact, Eco-Passport và mạng lưới. Thành viên đăng nhập bằng email magic link; bất kỳ ai có email đều có thể tạo tài khoản. Quyền quản trị dữ liệu vẫn được cấp riêng.

## Chạy tại máy

1. Mở `supabase-config.js` và điền Project URL cùng **publishable key** của dự án Supabase.
2. Chạy máy chủ tĩnh trong thư mục này, ví dụ `python3 -m http.server 4173`.
3. Mở `http://localhost:4173`.

Chưa có thông tin kết nối thì website vẫn xem được, số liệu giữ dấu gạch ngang và biểu mẫu báo rõ chưa gửi. Dữ liệu không được giả lập trong dashboard.

## Supabase

1. Tạo dự án Supabase riêng cho Eco-Bio Panel, sau đó chạy `supabase/schema.sql` trong SQL Editor.
2. Nếu project mới không tự bật Data API cho bảng SQL, bật các bảng cần thiết trong API/Data API settings; migration đã cấp quyền bảng và cột tối thiểu, còn RLS giới hạn bản ghi.
3. Thêm URL và publishable key vào `supabase-config.js`. Chỉ publishable key được đưa vào trình duyệt; tuyệt đối không dùng `service_role` hoặc secret key ở đây.
4. Tạo tài khoản nhóm qua Supabase Auth. Cấp `app_metadata.role = "admin"` cho quản trị viên và `"operator"` cho người nhập/cập nhật dữ liệu bằng một bước quản trị đáng tin cậy (ví dụ Admin API ở backend). Không cho người dùng tự sửa `user_metadata` để cấp quyền.
5. Trong Auth URL Configuration, cho phép URL website và URL localhost dùng để nhận magic link. Nếu website được lưu trong thư mục con, cho phép đúng URL thư mục đó (ví dụ /apps/eco-bio-panel/) làm Redirect URL. Kiểm tra URL chuyển hướng phù hợp với domain triển khai.
6. Bật email provider và cấu hình SMTP gửi email phù hợp cho người dùng bên ngoài trước khi mở đăng ký công khai. Magic link tự tạo tài khoản mới theo mặc định.

Migration bật RLS trên mọi bảng `public`, cho khách công khai đọc các bản ghi được công bố, gửi yêu cầu hợp tác/quan tâm, và chỉ role trong `app_metadata` mới quản lý dữ liệu. `admin` có thể xóa; `operator` có thể đọc, thêm và cập nhật. Bảng liên hệ không cho khách xem. Eco Impact chỉ tổng hợp phiếu thu gom và lô sản xuất đã xác nhận, được phép công khai; chưa có dữ liệu thì hiển thị dấu gạch ngang. Không có phép quy đổi CO₂.

## Lưu ý nội dung

- `EBP-DEMO-001` là mẫu minh họa được ghi rõ là mẫu nghiên cứu, chưa gắn với lô thật.
- Panel ở hero và phần sản phẩm là hình minh họa dựng bằng CSS. Hãy thay bằng ảnh sản phẩm thật trước khi giới thiệu như hàng đã sản xuất.
- Website mô tả đăng ký quan tâm, không nhận thanh toán và không hứa ngày giao hàng.
- Chưa có số liệu thử nghiệm chính thức được điền sẵn.

## Đăng nhập và phân quyền

- Khách công khai gửi yêu cầu quan tâm hoặc hợp tác mà không cần tài khoản.
- Thành viên dùng email để đăng nhập hoặc tự tạo tài khoản; khu vực thành viên chỉ đọc dữ liệu đã công khai.
- Tài khoản mới không nhận quyền operator hay admin. Chỉ nhóm có thể cấp vai trò qua Supabase app_metadata.
- Trang admin riêng tại ?admin=1; trang thành viên tại ?portal=1.

## Phạm vi MVP

Trang giới thiệu, không gian thành viên, sản phẩm, Eco Lab, Eco Impact, tra cứu Eco-Passport, form đối tác/khách hàng và admin đăng nhập magic link. Giai đoạn này chưa có thanh toán, tài khoản chuyên biệt cho đối tác, tồn kho, lịch thu gom tự động hoặc nội dung đội ngũ chưa được xác nhận.
