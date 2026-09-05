# Omarchy Setup & Dotfiles

Script tự động hóa cấu hình và khôi phục môi trường cá nhân trên **OmarchyOS** (Arch Linux + Hyprland).

## Cấu trúc thư mục

```text
omarchy-setup/
├── configs/               # Lưu trữ các file cấu hình mẫu
│   ├── bin/
│   │   └── omarchy-agent-usage-antigravity # Script thu thập quota/token Antigravity
│   ├── hypr/
│   │   ├── autostart.lua  # Tự động mở các ứng dụng khi đăng nhập
│   │   ├── bindings.lua   # Phím tắt (Super+Shift+S, Super+V)
│   │   ├── looknfeel.lua  # Cấu hình giao diện, không viền trống (gaps = 0)
│   │   ├── monitors.lua   # 2 màn hình (Philip Trái/Primary, AOC Phải/Secondary)
│   │   └── windows.lua    # Window rules gán cửa sổ ứng dụng vào workspace
│   ├── omarchy/
│   │   ├── agents/
│   │   │   └── antigravity.json # Cấu hình ngưỡng quota Gemini & Claude
│   │   └── Workspaces.qml       # Tên hiển thị các workspace trên thanh bar
│   └── systemd/
│       ├── omarchy-agent-antigravity.service # Service chạy collector định kỳ
│       └── omarchy-agent-antigravity.timer   # Timer chạy mỗi 2 phút
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
./setup.sh keybindings  # Cấu hình phím tắt (Super+Shift+S, Super+V)
./setup.sh packages     # Tự động cài đặt phần mềm (VSCode, Edge, Helium, AppImageLauncher)
./setup.sh apps         # Cấu hình workspace gán cho app và autostart
./setup.sh looknfeel    # Cấu hình khoảng cách cửa sổ (gaps = 0)
./setup.sh agent_quota  # Tích hợp hiển thị quota Antigravity trên widget Agents
```

## Lưu ý an toàn
* Script luôn tự động sao lưu (`.bak.<timestamp>`) các file cấu hình cũ trước khi ghi đè.
* Tự động reload Hyprland và kiểm tra lỗi cú pháp sau khi cập nhật.
* Bạn có thể đưa thư mục này lên GitHub cá nhân (hoặc GitLab) để sau này cài mới máy chỉ cần:
  ```bash
  git clone <link-repo> ~/omarchy-setup
  cd ~/omarchy-setup
  ./setup.sh
  ```
