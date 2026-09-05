#!/usr/bin/env bash
# ==============================================================================
# OmarchyOS Post-Install & Personal Setup Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="${SCRIPT_DIR}/configs"

# --- Styling & Helpers ---
COLOR_RESET="\033[0m"
COLOR_INFO="\033[38;5;39m"
COLOR_SUCCESS="\033[38;5;82m"
COLOR_WARN="\033[38;5;214m"
COLOR_ERROR="\033[38;5;196m"

log_info() {
    echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_SUCCESS}[SUCCESS]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_WARN}[WARN]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $*" >&2
}

backup_file() {
    local target="$1"
    if [ -f "$target" ]; then
        local timestamp
        timestamp="$(date +%Y%m%d_%H%M%S)"
        local backup="${target}.bak.${timestamp}"
        log_info "Tạo bản sao lưu: ${backup}"
        cp "$target" "$backup"
    fi
}

# --- Module: Monitor Setup ---
setup_monitors() {
    log_info "Bắt đầu cấu hình màn hình (Philip: Trái/Primary, AOC: Phải/Secondary)..."
    
    local target_dir="${HOME}/.config/hypr"
    local target_file="${target_dir}/monitors.lua"
    local source_file="${CONFIGS_DIR}/hypr/monitors.lua"
    
    if [ ! -f "$source_file" ]; then
        log_error "Không tìm thấy file nguồn: ${source_file}"
        return 1
    fi
    
    mkdir -p "$target_dir"
    backup_file "$target_file"
    
    cp "$source_file" "$target_file"
    log_success "Đã cập nhật ${target_file}"
    
    # Reload Hyprland nếu đang chạy trong session Hyprland
    if [ "${HYPRLAND_INSTANCE_SIGNATURE:-}" != "" ] && command -v hyprctl &>/dev/null; then
        log_info "Đang reload cấu hình Hyprland..."
        hyprctl reload
        local errors
        errors="$(hyprctl configerrors 2>&1 || true)"
        if [ -n "$errors" ] && [ "$errors" != "ok" ]; then
            log_warn "Hyprland cảnh báo lỗi cấu hình:\n${errors}"
        else
            log_success "Hyprland đã reload thành công mà không có lỗi!"
        fi
    fi
}

# --- Placeholder cho các bước setup sắp tới ---
# setup_vietnamese_input() { ... }
# setup_keybindings() { ... }
# setup_looknfeel() { ... }
# setup_packages() { ... }

# --- Main Dispatcher ---
main() {
    echo -e "${COLOR_INFO}==========================================${COLOR_RESET}"
    echo -e "${COLOR_INFO}    OmarchyOS Automated Setup Script     ${COLOR_RESET}"
    echo -e "${COLOR_INFO}==========================================${COLOR_RESET}"
    
    local target="${1:-all}"
    
    case "$target" in
        monitors)
            setup_monitors
            ;;
        all)
            setup_monitors
            # Các module tiếp theo sẽ được gọi ở đây
            ;;
        *)
            echo "Cách sử dụng: $0 [all|monitors]"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}    Hoàn thành quá trình thiết lập!       ${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
}

main "$@"
