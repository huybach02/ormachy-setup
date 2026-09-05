# Omarchy Setup & Dotfiles

Script tự động hóa cấu hình và khôi phục môi trường cá nhân trên **OmarchyOS** (Arch Linux + Hyprland).

## Cấu trúc thư mục

```text
omarchy-setup/
├── configs/               # Lưu trữ các file cấu hình mẫu
│   └── hypr/
│       └── monitors.lua   # Cấu hình 2 màn hình (Philip Trái/Primary, AOC Phải/Secondary)
├── setup.sh               # Script chính để chạy cài đặt/áp dụng cấu hình
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
./setup.sh monitors     # Cấu hình 2 màn hình (Philip Trái, AOC Phải)
./setup.sh workspaces   # Cấu hình tên và vị trí các workspace trên bar
./setup.sh keybindings  # Cấu hình phím tắt (Super+Shift+S, Super+V)
./setup.sh packages     # Tự động cài đặt phần mềm (VSCode, Edge, Helium, AppImageLauncher)
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
