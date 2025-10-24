# flutter_application_1

## Chuẩn bị

1. Mở File Explorer

2. Trên thanh địa chỉ (nơi hiển thị This PC, Downloads, …) → dán dòng này rồi Enter:

    ```
    %USERPROFILE%\.gradle
    ```

    Nó sẽ mở đúng thư mục .gradle của bạn (dù thư mục đó bị ẩn).

3. Nếu không thấy file nào tên gradle.properties →

    Chuột phải → New → Text Document
    Đặt tên là:

    ```
    gradle.properties
    ```

    **(Nếu Windows tự thêm .txt ở sau, thì bạn xóa phần .txt    đi để tên đúng là gradle.properties)**

4. Mở file đó (bằng Notepad), dán dòng sau vào:

    ```
    SDK_REGISTRY_TOKEN=sk.your_secret_mapbox_token
    ```

    Nhớ thay bằng token thực của bạn (bắt đầu bằng sk.).
    **Liên hệ Đức lấy xài cũng được**

5. Lưu lại, đóng file.

6. Chạy lại project Flutter:

    ```
    flutter clean
    flutter pub get
    flutter run
    ```

## Goong map key

- maptile key của Goong

**Nhắn Đức cũng được**