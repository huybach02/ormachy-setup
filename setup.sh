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

# --- Module: Packages & Applications ---
setup_packages() {
    log_info "Bắt đầu kiểm tra và cài đặt các ứng dụng cần thiết..."
    
    # Danh sách phần mềm yêu cầu:
    # 1. Visual Studio Code (visual-studio-code-bin)
    # 2. Microsoft Edge (microsoft-edge-stable-bin)
    # 3. Helium Browser (helium-browser-bin)
    # 4. AppImageLauncher (appimagelauncher-beta-bin)
    local pkgs_to_install=()
    
    # 1. VS Code
    if pacman -Q visual-studio-code-bin &>/dev/null || pacman -Q code &>/dev/null; then
        log_info "VSCode đã được cài đặt."
    else
        log_warn "VSCode chưa được cài đặt."
        pkgs_to_install+=("visual-studio-code-bin")
    fi
    
    # 2. Microsoft Edge
    if pacman -Q microsoft-edge-stable-bin &>/dev/null || pacman -Q microsoft-edge-dev-bin &>/dev/null || pacman -Q microsoft-edge-beta-bin &>/dev/null; then
        log_info "Microsoft Edge đã được cài đặt."
    else
        log_warn "Microsoft Edge chưa được cài đặt."
        pkgs_to_install+=("microsoft-edge-stable-bin")
    fi
    
    # 3. Helium Browser
    if pacman -Q helium-browser-bin &>/dev/null || pacman -Q helium-browser-beta-bin &>/dev/null; then
        log_info "Helium Browser đã được cài đặt."
    else
        log_warn "Helium Browser chưa được cài đặt."
        pkgs_to_install+=("helium-browser-bin")
    fi
    
    # 4. AppImageLauncher
    if pacman -Q appimagelauncher &>/dev/null || pacman -Q appimagelauncher-beta-bin &>/dev/null || pacman -Q appimagelauncher-bin &>/dev/null; then
        log_info "AppImageLauncher đã được cài đặt."
    else
        log_warn "AppImageLauncher chưa được cài đặt."
        pkgs_to_install+=("appimagelauncher-beta-bin")
    fi
    
    if [ ${#pkgs_to_install[@]} -eq 0 ]; then
        log_success "Tất cả các phần mềm yêu cầu (VSCode, Edge, Helium, AppImageLauncher) đều đã có trên hệ thống!"
        return 0
    fi
    
    log_info "Tiến hành cài đặt các gói còn thiếu: ${pkgs_to_install[*]}..."
    
    if command -v yay &>/dev/null; then
        yay -S --needed --noconfirm "${pkgs_to_install[@]}"
    elif command -v omarchy &>/dev/null; then
        omarchy pkg aur add "${pkgs_to_install[@]}"
    else
        log_error "Không tìm thấy yay hoặc omarchy để cài đặt gói AUR!"
        return 1
    fi
    
    log_success "Đã cài đặt xong tất cả phần mềm!"
}

# --- Module: App Window Rules & Autostart ---
setup_apps() {
    log_info "Bắt đầu cấu hình window rules và autostart cho các ứng dụng..."
    
    local hypr_dir="${HOME}/.config/hypr"
    mkdir -p "$hypr_dir"
    
    # 1. Cập nhật windows.lua
    local target_windows="${hypr_dir}/windows.lua"
    local source_windows="${CONFIGS_DIR}/hypr/windows.lua"
    if [ -f "$source_windows" ]; then
        backup_file "$target_windows"
        cp "$source_windows" "$target_windows"
        log_success "Đã cập nhật ${target_windows}"
    fi
    
    # 2. Đảm bảo hyprland.lua có require("hypr.windows")
    local hyprland_main="${hypr_dir}/hyprland.lua"
    if [ -f "$hyprland_main" ]; then
        if ! grep -q 'require("hypr.windows")' "$hyprland_main"; then
            log_info "Thêm require(\"hypr.windows\") vào hyprland.lua..."
            backup_file "$hyprland_main"
            sed -i '/require("hypr.autostart")/i require("hypr.windows")' "$hyprland_main"
        fi
    fi
    
    # 3. Cập nhật autostart.lua
    local target_autostart="${hypr_dir}/autostart.lua"
    local source_autostart="${CONFIGS_DIR}/hypr/autostart.lua"
    if [ -f "$source_autostart" ]; then
        backup_file "$target_autostart"
        cp "$source_autostart" "$target_autostart"
        log_success "Đã cập nhật ${target_autostart}"
    fi
    
    # 4. Reload Hyprland nếu đang chạy
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

# --- Module: Look and Feel (Gaps, Borders, etc.) ---
setup_looknfeel() {
    log_info "Bắt đầu cấu hình giao diện & khoảng cách cửa sổ (Gaps = 0)..."
    
    local hypr_dir="${HOME}/.config/hypr"
    local target_looknfeel="${hypr_dir}/looknfeel.lua"
    local source_looknfeel="${CONFIGS_DIR}/hypr/looknfeel.lua"
    
    if [ ! -f "$source_looknfeel" ]; then
        log_error "Không tìm thấy file nguồn: ${source_looknfeel}"
        return 1
    fi
    
    mkdir -p "$hypr_dir"
    backup_file "$target_looknfeel"
    
    cp "$source_looknfeel" "$target_looknfeel"
    log_success "Đã cập nhật ${target_looknfeel}"
    
    # Reload Hyprland nếu đang chạy
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
        packages)
            setup_packages
            ;;
        apps)
            setup_apps
            ;;
        looknfeel)
            setup_looknfeel
            ;;
        all)
            setup_monitors
            setup_workspaces
            setup_keybindings
            setup_packages
            setup_apps
            setup_looknfeel
            ;;
        *)
            echo "Cách sử dụng: $0 [all|monitors|workspaces|keybindings|packages|apps|looknfeel]"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}    Hoàn thành quá trình thiết lập!       ${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
}

main "$@"
