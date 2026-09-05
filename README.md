# Omarchy Setup & Dotfiles

Script tự động hóa cấu hình và khôi phục môi trường cá nhân trên **OmarchyOS** (Arch Linux + Hyprland).

## Cấu trúc thư mục

```text
omarchy-setup/
├── configs/               # Lưu trữ các file cấu hình mẫu
│   ├── bin/
│   │   ├── omarchy-agent-usage-antigravity # Script thu thập quota/token Antigravity
│   │   ├── omarchy-agent-usage-update      # Wrapper cập nhật usage và trích xuất email
│   │   ├── omarchy-sysinfo                 # Thu thập thông số CPU, RAM, Disk, GPU cho bar
│   │   └── php-switch                      # Tiện ích chuyển đổi phiên bản PHP linh hoạt (alias: sphp)
│   ├── fcitx5/
│   │   ├── config         # Phím tắt chuyển bộ gõ (Alt+Shift_L)
│   │   └── profile        # Cấu hình bộ gõ tiếng Việt Fcitx5 Lotus
│   ├── hypr/
│   │   ├── autostart.lua  # Tự động mở các ứng dụng khi đăng nhập
│   │   ├── bindings.lua   # Phím tắt (Super+Shift+S, Super+V, Alt+Shift_L)
│   │   ├── looknfeel.lua  # Cấu hình giao diện, không viền trống (gaps = 0)
│   │   ├── monitors.lua   # 2 màn hình (Philip Trái/Primary, AOC Phải/Secondary)
│   │   └── windows.lua    # Window rules gán cửa sổ ứng dụng vào workspace
│   ├── omarchy/
│   │   ├── agents/
│   │   │   └── antigravity.json # Nhãn gói Antigravity
│   │   ├── plugins/
│   │   │   ├── agents/          # Plugin Agents tùy biến hiển thị email tài khoản
│   │   │   └── huybach02.tray/  # Plugin Tray tùy biến (luôn hiện đầy đủ icon, icon rõ nét)
│   │   ├── mimeapps.list        # Mẫu ứng dụng mặc định (Edge cho web, Sublime Text cho văn bản)
│   │   ├── shell.json           # Cấu hình thanh bar, layout widget và idle
│   │   └── Workspaces.qml       # Tên hiển thị các workspace trên thanh bar
│   └── systemd/
│       ├── omarchy-agent-antigravity.service # Service chạy collector định kỳ
│       ├── omarchy-agent-antigravity.timer   # Timer chạy mỗi 30 giây
│       └── user/
│           └── omarchy-fcitx5.service.d/
│               └── override.conf             # Kích hoạt StatusNotifierItem cho fcitx5
├── setup.sh               # Script chính để chạy cài đặt / áp dụng cấu hình
└── README.md
```

## Cách sử dụng

### 1. Áp dụng tất cả cấu hình
```bash
./setup.sh
# hoặc: ./setup.sh all
```

### 2. Áp dụng riêng từng phần
```bash
./setup.sh monitors     # Cấu hình 2 màn hình (Philip Trái, AOC Phải) & gán workspace
./setup.sh workspaces   # Cấu hình tên và vị trí các workspace trên bar
./setup.sh keybindings  # Cấu hình phím tắt (Super+Shift+S, Super+V, Alt+Shift_L)
./setup.sh packages     # Cài đặt ứng dụng (VSCode, Edge, Helium, AppImageLauncher, Sublime Text, GitHub CLI, LibreOffice) & đặt Edge/Sublime Text làm mặc định
./setup.sh browser      # Đặt Microsoft Edge đã cài làm trình duyệt mặc định (Omarchy, liên kết web, HTML)
./setup.sh apps         # Cấu hình workspace gán cho app và autostart
./setup.sh looknfeel    # Cấu hình khoảng cách cửa sổ (gaps = 0)
./setup.sh agent_quota  # Hiển thị quota thật Gemini và Claude/GPT trên widget Agents
./setup.sh sysinfo      # Cấu hình widget thông số máy tính (CPU, RAM, Disk, GPU) trên bar
./setup.sh vietnamese   # Cài đặt và cấu hình bộ gõ Fcitx5 Lotus (chuyển đổi Alt + Shift Trái)
./setup.sh php          # Cài đặt môi trường PHP (8.5 & 8.3), Composer, extensions & php-switch
./setup.sh node         # Cài đặt Node.js, trình quản lý fnm, Corepack (pnpm & yarn)
./setup.sh symfony      # Cài đặt Symfony CLI, kích hoạt iconv & bash completion
```

Lệnh `browser` ưu tiên Edge Stable, sau đó Beta và Dev nếu có. Bước này cũng tự chạy trong `packages` và `all`, cập nhật các liên kết web/HTML bằng XDG mà vẫn giữ các ứng dụng mặc định khác. Nếu chưa cài Edge, chạy `./setup.sh packages` trước.

### 3. Quản lý & Chuyển đổi phiên bản PHP (`php-switch` / `sphp`)
Môi trường PHP hỗ trợ chuyển đổi nhanh giữa các phiên bản (mặc định là PHP 8.5, kèm sẵn PHP 8.3):
```bash
# Xem danh sách phiên bản và phiên bản đang active
php-switch
# hoặc: sphp

# Chuyển sang PHP 8.3
sphp 8.3

# Chuyển về PHP 8.5
sphp 8.5

# Khởi động lại dịch vụ PHP-FPM tương ứng khi cần
sphp 8.3 --fpm
```
*Tất cả các extension cần thiết (mbstring, xml, curl, zip, bcmath, intl, mysql, pgsql, sqlite3, gd, soap, readline, opcache, redis, imagick) cùng Composer đã được kích hoạt đầy đủ trên cả hai phiên bản.*

### 4. Quản lý & Chuyển đổi phiên bản Node.js (`fnm`)
Hệ thống sử dụng **fnm (Fast Node Manager)** viết bằng Rust siêu nhanh, hỗ trợ tự động nhận diện version theo thư mục (`.node-version`, `.nvmrc`):
```bash
# Xem danh sách phiên bản Node đã cài đặt
fnm ls

# Cài đặt phiên bản Node mới (ví dụ LTS hoặc version cụ thể)
fnm install --lts
fnm install 22
fnm install 24
fnm install 26

# Chuyển đổi phiên bản Node cho session hiện tại
fnm use 22
fnm use 24
fnm use 26

# Đặt phiên bản mặc định
fnm default 24

# Corepack đã được kích hoạt sẵn để dùng pnpm và yarn:
pnpm -v
yarn -v
```

### 5. Phát triển ứng dụng Symfony (`symfony-cli`)
Symfony CLI đã được tích hợp sẵn với đầy đủ bash completion và kiểm tra tương thích:
```bash
# Kiểm tra sự sẵn sàng của môi trường hệ thống cho Symfony:
symfony check:requirements

# Tạo dự án Symfony mới:
symfony new my_project_directory --version="lts"
# hoặc tạo web app đầy đủ:
symfony new my_project_directory --webapp

# Khởi động local web server cho dự án:
cd my_project_directory
symfony server:start
```

## Lưu ý an toàn
* **Xác thực 1 lần (Sudo Keep-Alive)**: Script chỉ yêu cầu nhập mật khẩu root/sudo đúng 1 lần ở đầu phiên chạy và tự động duy trì quyền hạn trong nền (tự huỷ ngay khi script kết thúc), không hỏi lại mật khẩu nhiều lần. Các tác vụ không yêu cầu quyền root (monitors, keybindings, looknfeel, sysinfo, workspaces) sẽ hoàn toàn không hỏi mật khẩu.
* Script luôn tự động sao lưu (`.bak.<timestamp>`) các file cấu hình cũ trước khi ghi đè.
* Tự động reload Hyprland và kiểm tra lỗi cú pháp sau khi cập nhật.
* Bạn có thể đưa thư mục này lên GitHub cá nhân (hoặc GitLab) để sau này cài mới máy chỉ cần:
  ```bash
  git clone <link-repo> ~/omarchy-setup
  cd ~/omarchy-setup
  ./setup.sh
  ```

### Quota Antigravity
Collector gọi `agy --print /usage --output-format json` để đọc quota thật của tài khoản đã đăng nhập, không chạy lượt chat. Popup hiển thị hai nhóm **Gemini** và **Claude / GPT**, mỗi nhóm có hạn mức **5 giờ** và **tuần**, kèm thời điểm reset từ Antigravity. Phần trăm trên thanh là **đã dùng** (`1 - remaining_fraction`), không phải phần trăm còn lại.

Timer cập nhật mỗi 30 giây. Cần cài CLI `agy` và đăng nhập trước. Nếu không lấy được dữ liệu (mất mạng, hết phiên đăng nhập hoặc CLI thay đổi định dạng), collector hiển thị `—` cùng thông báo; không thay bằng số prompt hoặc quota cũ. Các ngưỡng `gemini_limit` / `claude_limit` trước đây không còn được sử dụng. Thống kê token lấy từ `gen_metadata` trong database hội thoại Antigravity: tổng input, output, cache read và cache write; output đã gồm thinking nên không cộng thinking lần nữa. Thống kê ngày dùng múi giờ máy, thống kê model dùng tên model trong bản ghi. Chỉ bao gồm dữ liệu còn lưu trên máy; bản ghi không đọc được được đếm trong `tokenStatsSkipped`. Popup tự tăng chiều cao theo nội dung, không cuộn dọc; nội dung vượt màn hình sẽ được thu nhỏ để vừa.

Nút **Refresh** trong popup cập nhật ngay dữ liệu các agent; nút hiện **Refreshing…** trong khi đang chạy. Phím **R** vẫn dùng được.

### Áp dụng các cập nhật trình duyệt và widget Agents
```bash
./setup.sh browser      # Microsoft Edge mặc định
./setup.sh agent_quota  # Quota thật, token từ database, timer 30s, nút Refresh, popup không cuộn
```
`agent_quota` sao lưu các file sẽ cập nhật, khởi động lại timer để áp dụng chu kỳ mới và khởi động lại Omarchy shell để nạp giao diện mới. `./setup.sh all` cũng bao gồm hai phần này. Không cần chép cấu hình thủ công.

Kiểm tra collector:
```bash
python3 -m unittest discover -s tests -v
```

### Open Terminal Here trong Files
```bash
./setup.sh file_manager
```
Thêm menu **Open Terminal Here** khi bấm chuột phải nền thư mục hoặc một thư mục được chọn. Terminal mặc định mở đúng thư mục đó; hỗ trợ đường dẫn có dấu và khoảng trắng. Sau cài đặt, đóng Files, chạy `nautilus -q` rồi mở lại. Module này cũng được chạy trong `all`.
