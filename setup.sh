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

# --- Module: Monitor & Workspace Monitor Rules ---
setup_monitors() {
    log_info "Bắt đầu cấu hình màn hình và gán workspace (Philip: Trái/Primary, AOC: Phải/Secondary)..."
    
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

# --- Module: Workspace Names on Bar Widget ---
setup_workspaces() {
    log_info "Bắt đầu cấu hình tên hiển thị cho các Workspace trên thanh bar..."
    local user="${USER:-$(id -un)}"
    local plugin_dir="${HOME}/.config/omarchy/plugins/${user}.workspaces"
    local source_qml="${CONFIGS_DIR}/omarchy/Workspaces.qml"
    
    if [ ! -f "$source_qml" ]; then
        log_error "Không tìm thấy file nguồn: ${source_qml}"
        return 1
    fi
    
    # Clone plugin nếu chưa tồn tại
    if [ ! -d "$plugin_dir" ]; then
        log_info "Đang clone omarchy.workspaces sang ${user}.workspaces..."
        omarchy plugin clone omarchy.workspaces
    fi
    
    # Cập nhật Workspaces.qml với tên người dùng tương ứng
    local target_qml="${plugin_dir}/Workspaces.qml"
    backup_file "$target_qml"
    
    sed "s/huybach02\.workspaces/${user}\.workspaces/g" "$source_qml" > "$target_qml"
    log_success "Đã cập nhật ${target_qml}"
    
    # Khởi động lại omarchy shell nếu đang chạy
    if pgrep quickshell &>/dev/null && command -v omarchy &>/dev/null; then
        log_info "Đang khởi động lại omarchy shell để áp dụng tên workspace..."
        omarchy restart shell
        log_success "Omarchy shell đã khởi động lại thành công!"
    fi
}

# --- Module: Keybindings ---
setup_keybindings() {
    log_info "Bắt đầu cấu hình phím tắt (Super+Shift+S: Chụp ảnh màn hình)..."
    
    local target_dir="${HOME}/.config/hypr"
    local target_file="${target_dir}/bindings.lua"
    local source_file="${CONFIGS_DIR}/hypr/bindings.lua"
    
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
        workspaces)
            setup_workspaces
            ;;
        keybindings)
            setup_keybindings
            ;;
        all)
            setup_monitors
            setup_workspaces
            setup_keybindings
            # Các module tiếp theo sẽ được gọi ở đây
            ;;
        *)
            echo "Cách sử dụng: $0 [all|monitors|workspaces|keybindings]"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}    Hoàn thành quá trình thiết lập!       ${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
}

main "$@"
