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

# --- Sudo Keep-Alive Helper ---
start_sudo_keepalive() {
    if [ -z "${SUDO_LOOP_PID:-}" ]; then
        # Duy trì timestamp sudo trong background cho đến khi script hoàn tất
        while true; do
            sudo -n true
            sleep 45
            kill -0 "$$" || exit
        done 2>/dev/null &
        SUDO_LOOP_PID=$!
        trap 'kill -9 "$SUDO_LOOP_PID" 2>/dev/null || true' EXIT HUP INT TERM
    fi
}

init_sudo() {
    # Nếu đang chạy bằng root thì không cần làm gì
    [ "$EUID" -eq 0 ] && return 0

    # Nếu sudo đã được cấp quyền và còn hạn, khởi động keepalive ngay
    if sudo -n true 2>/dev/null; then
        start_sudo_keepalive
        return 0
    fi

    log_info "Yêu cầu quyền quản trị (sudo) - chỉ cần nhập mật khẩu 1 lần cho toàn bộ quá trình setup..."
    if sudo -v; then
        start_sudo_keepalive
        log_success "Đã xác thực quyền sudo thành công!"
    else
        log_error "Xác thực sudo thất bại! Vui lòng kiểm tra lại mật khẩu."
        exit 1
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

# --- Module: Nautilus Terminal Context Menu ---
setup_file_manager() {
    local missing=() pkg
    for pkg in nautilus-python xdg-terminal-exec; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        init_sudo
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
    local target_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/nautilus-python/extensions"
    local target="${target_dir}/open-terminal-here.py"
    mkdir -p "$target_dir"
    backup_file "$target"
    cp "${CONFIGS_DIR}/nautilus/extensions/open-terminal-here.py" "$target"
    log_success "Đã thêm Open Terminal Here cho thư mục trong Files."
    log_info "Đóng Files rồi chạy nautilus -q và mở lại để nạp menu mới."
}

# --- Module: Default Browser ---
setup_browser() {
    log_info "Thiết lập Microsoft Edge làm trình duyệt mặc định..."

    local desktop_id="" candidate data_dir
    local data_dirs=()
    IFS=: read -r -a data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    data_dirs=("${XDG_DATA_HOME:-${HOME}/.local/share}" "${data_dirs[@]}")
    for candidate in microsoft-edge.desktop microsoft-edge-beta.desktop microsoft-edge-dev.desktop; do
        for data_dir in "${data_dirs[@]}"; do
            if [ -f "${data_dir}/applications/${candidate}" ]; then
                desktop_id="$candidate"
                break 2
            fi
        done
    done

    if [ -z "$desktop_id" ]; then
        log_error "Chưa tìm thấy Microsoft Edge. Hãy chạy ./setup.sh packages để cài đặt trước."
        return 1
    fi
    if ! command -v xdg-settings &>/dev/null || ! command -v xdg-mime &>/dev/null; then
        log_error "Cần cài đặt xdg-utils để thiết lập trình duyệt mặc định."
        return 1
    fi

    local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}"
    mkdir -p "$config_dir"
    backup_file "${config_dir}/mimeapps.list"
    # Omarchy cũng đọc default-web-browser qua xdg-settings khi mở trình duyệt.
    env -u BROWSER xdg-settings set default-web-browser "$desktop_id"
    local mime
    for mime in text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https x-scheme-handler/about x-scheme-handler/unknown; do
        xdg-mime default "$desktop_id" "$mime"
    done

    log_success "Đã đặt Microsoft Edge (${desktop_id}) làm trình duyệt mặc định cho Omarchy, liên kết web và HTML!"
}

# --- Module: Packages & Applications ---
setup_packages() {
    log_info "Bắt đầu kiểm tra và cài đặt các ứng dụng cần thiết..."
    
    # Danh sách phần mềm yêu cầu:
    # 1. Visual Studio Code (visual-studio-code-bin)
    # 2. Microsoft Edge (microsoft-edge-stable-bin)
    # 3. Helium Browser (helium-browser-bin)
    # 4. AppImageLauncher (appimagelauncher-beta-bin)
    # 5. Sublime Text (sublime-text-4)
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

    # 5. Sublime Text
    if pacman -Q sublime-text-4 &>/dev/null; then
        log_info "Sublime Text đã được cài đặt."
    else
        log_warn "Sublime Text chưa được cài đặt."
        pkgs_to_install+=("sublime-text-4")
    fi

    # 6. GitHub CLI (gh)
    if pacman -Q github-cli &>/dev/null; then
        log_info "GitHub CLI (gh) đã được cài đặt."
    else
        log_warn "GitHub CLI (gh) chưa được cài đặt."
        pkgs_to_install+=("github-cli")
    fi
    
    # 7. LibreOffice
    if pacman -Q libreoffice-fresh &>/dev/null || pacman -Q libreoffice-still &>/dev/null; then
        log_info "LibreOffice đã được cài đặt."
    else
        log_warn "LibreOffice chưa được cài đặt."
        pkgs_to_install+=("libreoffice-fresh")
    fi

    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        init_sudo
        log_info "Tiến hành cài đặt các gói còn thiếu: ${pkgs_to_install[*]}..."
        if command -v yay &>/dev/null; then
            yay -S --needed --noconfirm --sudoloop "${pkgs_to_install[@]}"
        elif command -v omarchy &>/dev/null; then
            omarchy pkg aur add "${pkgs_to_install[@]}"
        else
            log_error "Không tìm thấy yay hoặc omarchy để cài đặt gói!"
            return 1
        fi
        log_success "Đã cài đặt xong tất cả phần mềm!"
    else
        log_success "Tất cả các phần mềm yêu cầu (VSCode, Edge, Helium, AppImageLauncher, Sublime Text, GitHub CLI, LibreOffice) đều đã có trên hệ thống!"
    fi

    setup_browser

    # Cấu hình Sublime Text làm trình soạn thảo văn bản mặc định
    if pacman -Q sublime-text-4 &>/dev/null; then
        log_info "Thiết lập Sublime Text làm trình soạn thảo văn bản mặc định..."
        local defaults_dir="${HOME}/.local/state/omarchy/defaults"
        mkdir -p "$defaults_dir"
        printf '%s\n' "subl" > "${defaults_dir}/editor"

        local text_mimes=(
            "text/plain"
            "text/markdown"
            "text/x-markdown"
            "text/x-log"
            "text/x-sh"
            "text/x-shellscript"
            "text/x-c"
            "text/x-c++"
            "text/x-chdr"
            "text/x-csrc"
            "text/x-python"
            "text/x-yaml"
            "application/x-yaml"
            "text/x-php"
            "application/x-php"
            "text/x-lua"
            "text/x-sql"
            "text/css"
            "text/csv"
            "application/json"
            "application/xml"
            "text/xml"
            "application/x-zerosize"
            "application/x-desktop"
            "text/x-makefile"
            "application/toml"
        )
        for mime in "${text_mimes[@]}"; do
            xdg-mime default sublime_text.desktop "$mime" 2>/dev/null || true
        done

        # Đặt trước interactive-shell guard; thay cả cấu hình editor cũ.
        backup_file "${HOME}/.bashrc"
        touch "${HOME}/.bashrc"
        sed -i -E '/^[[:space:]]*export (VISUAL|EDITOR)=/d' "${HOME}/.bashrc"
        sed -i '1i export VISUAL="subl"\nexport EDITOR="subl -w"' "${HOME}/.bashrc"

        log_success "Đã thiết lập Sublime Text làm trình soạn thảo mặc định (Omarchy defaults, XDG MIME, VISUAL/EDITOR)!"
    fi
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

# --- Module: Agent Quota & Usage (Antigravity & Codex) ---
setup_agent_quota() {
    log_info "Bắt đầu cấu hình theo dõi Quota & User Email cho các AI Agents (Antigravity, Codex,...)..."
    
    local user="${USER:-$(id -un)}"
    local bin_dir="${HOME}/.local/bin"
    local systemd_dir="${HOME}/.config/systemd/user"
    mkdir -p "$bin_dir" "$systemd_dir"
    
    # 1. Cài đặt script collector & update wrapper
    local source_collector="${CONFIGS_DIR}/bin/omarchy-agent-usage-antigravity"
    local target_collector="${bin_dir}/omarchy-agent-usage-antigravity"
    if [ -f "$source_collector" ]; then
        backup_file "$target_collector"
        cp "$source_collector" "$target_collector"
        chmod +x "$target_collector"
        log_success "Đã cập nhật ${target_collector}"
    fi

    local source_updater="${CONFIGS_DIR}/bin/omarchy-agent-usage-update"
    local target_updater="${bin_dir}/omarchy-agent-usage-update"
    if [ -f "$source_updater" ]; then
        backup_file "$target_updater"
        cp "$source_updater" "$target_updater"
        chmod +x "$target_updater"
        log_success "Đã cập nhật ${target_updater}"
    fi
    
    # 2. Cài đặt nhãn gói (quota thật được đọc qua agy /usage)
    local config_dir="${HOME}/.config/omarchy/agents"
    local target_conf="${config_dir}/antigravity.json"
    local source_conf="${CONFIGS_DIR}/omarchy/agents/antigravity.json"
    mkdir -p "$config_dir"
    if [ ! -f "$target_conf" ] && [ -f "$source_conf" ]; then
        cp "$source_conf" "$target_conf"
        log_success "Đã tạo cấu hình quota tại ${target_conf}"
    fi

    # 3. Tùy biến plugin Agents hiển thị email tài khoản
    local plugin_dir="${HOME}/.config/omarchy/plugins/${user}.agents"
    local source_plugin="${CONFIGS_DIR}/omarchy/plugins/agents"
    if [ -d "$source_plugin" ]; then
        if [ ! -d "$plugin_dir" ]; then
            log_info "Đang clone omarchy.agents sang ${user}.agents..."
            omarchy plugin clone omarchy.agents &>/dev/null || true
        fi
        mkdir -p "$plugin_dir"
        local plugin_file
        for plugin_file in Main.qml Panel.qml Agent.qml manifest.json; do
            backup_file "${plugin_dir}/${plugin_file}"
        done
        cp -r "${source_plugin}/"* "$plugin_dir/"
        # Đảm bảo manifest có đúng tên user
        sed -i "s/\"id\": \"huybach02\.agents\"/\"id\": \"${user}\.agents\"/g" "${plugin_dir}/manifest.json" 2>/dev/null || true
        log_success "Đã đồng bộ giao diện hiển thị email cho ${user}.agents!"
    fi

    # 4. Cài đặt systemd user service và timer
    local target_service="${systemd_dir}/omarchy-agent-antigravity.service"
    local source_service="${CONFIGS_DIR}/systemd/omarchy-agent-antigravity.service"
    local target_timer="${systemd_dir}/omarchy-agent-antigravity.timer"
    local source_timer="${CONFIGS_DIR}/systemd/omarchy-agent-antigravity.timer"
    
    if [ -f "$source_service" ] && [ -f "$source_timer" ]; then
        backup_file "$target_service"
        backup_file "$target_timer"
        cp "$source_service" "$target_service"
        cp "$source_timer" "$target_timer"
        
        systemctl --user daemon-reload
        systemctl --user enable omarchy-agent-antigravity.timer
        systemctl --user restart omarchy-agent-antigravity.timer
        log_success "Đã kích hoạt timer cập nhật quota và token Antigravity mỗi 30 giây!"
    fi
    
    # 5. Chạy cập nhật dữ liệu ngay
    if [ -x "$target_updater" ]; then
        log_info "Đang thu thập và cập nhật dữ liệu quota & email cho tất cả agent..."
        "$target_updater"
    fi
    
    # 6. Nạp lại QML để nút Refresh và popup không cuộn được áp dụng ngay
    if command -v omarchy-shell &>/dev/null && pgrep quickshell &>/dev/null; then
        omarchy restart shell
        log_success "Đã nạp lại widget Agents: Refresh, quota thật và popup không cuộn!"
    fi
}

# --- Module: System Stats Bar Widgets (CPU, RAM, Disk, GPU) ---
setup_sysinfo() {
    log_info "Bắt đầu cấu hình widget hiển thị thông số hệ thống (CPU, RAM, Disk, GPU) trên thanh bar..."
    
    local user="${USER:-$(id -un)}"
    local bin_dir="${HOME}/.local/bin"
    local omarchy_conf_dir="${HOME}/.config/omarchy"
    mkdir -p "$bin_dir" "$omarchy_conf_dir"
    
    # 1. Cài đặt script omarchy-sysinfo
    local source_script="${CONFIGS_DIR}/bin/omarchy-sysinfo"
    local target_script="${bin_dir}/omarchy-sysinfo"
    if [ -f "$source_script" ]; then
        cp "$source_script" "$target_script"
        chmod +x "$target_script"
        log_success "Đã cập nhật ${target_script}"
    fi

    # 2. Cập nhật cấu hình shell.json
    local target_shell="${omarchy_conf_dir}/shell.json"
    local source_shell="${CONFIGS_DIR}/omarchy/shell.json"
    if [ -f "$source_shell" ]; then
        backup_file "$target_shell"
        sed "s/huybach02/${user}/g" "$source_shell" > "$target_shell"
        log_success "Đã cập nhật ${target_shell}"
    fi

    # 3. Khởi động lại omarchy shell nếu đang chạy
    if pgrep quickshell &>/dev/null && command -v omarchy &>/dev/null; then
        log_info "Đang khởi động lại omarchy shell để áp dụng widget thông số hệ thống..."
        omarchy restart shell
        log_success "Omarchy shell đã khởi động lại thành công!"
    fi
}

# --- Module: Vietnamese Input Method (Fcitx5 + Lotus) ---
setup_vietnamese_input() {
    log_info "Bắt đầu cấu hình bộ gõ tiếng Việt Fcitx5 Lotus và phím tắt Alt + Left Shift..."
    
    local user="${USER:-$(id -un)}"
    local fcitx_dir="${HOME}/.config/fcitx5"
    local hypr_dir="${HOME}/.config/hypr"
    mkdir -p "$fcitx_dir" "$hypr_dir"

    # 1. Cài đặt fcitx5-lotus-bin nếu chưa có
    if ! pacman -Q fcitx5-lotus &>/dev/null && ! pacman -Q fcitx5-lotus-bin &>/dev/null; then
        init_sudo
        log_info "Đang cài đặt fcitx5-lotus-bin..."
        if command -v yay &>/dev/null; then
            yay -S --needed --noconfirm --sudoloop fcitx5-lotus-bin
        elif command -v omarchy &>/dev/null; then
            omarchy pkg aur add fcitx5-lotus-bin
        fi
    else
        log_info "fcitx5-lotus đã được cài đặt."
    fi

    # 2. Kích hoạt và chạy service fcitx5-lotus-server@<user>
    if ! systemctl is-active --quiet "fcitx5-lotus-server@${user}.service"; then
        init_sudo
        log_info "Kích hoạt systemd service fcitx5-lotus-server@${user}..."
        sudo systemctl enable --now "fcitx5-lotus-server@${user}.service"
        log_success "Đã kích hoạt fcitx5-lotus-server@${user}.service"
    fi

    # 3. Đồng bộ file profile & config cho fcitx5
    local source_profile="${CONFIGS_DIR}/fcitx5/profile"
    local target_profile="${fcitx_dir}/profile"
    if [ -f "$source_profile" ]; then
        backup_file "$target_profile"
        cp "$source_profile" "$target_profile"
        log_success "Đã cập nhật ${target_profile}"
    fi

    local source_config="${CONFIGS_DIR}/fcitx5/config"
    local target_config="${fcitx_dir}/config"
    if [ -f "$source_config" ]; then
        backup_file "$target_config"
        cp "$source_config" "$target_config"
        log_success "Đã cập nhật ${target_config}"
    fi

    # 4. Cập nhật phím tắt Alt + Shift_L trong bindings.lua
    local source_bindings="${CONFIGS_DIR}/hypr/bindings.lua"
    local target_bindings="${hypr_dir}/bindings.lua"
    if [ -f "$source_bindings" ]; then
        backup_file "$target_bindings"
        cp "$source_bindings" "$target_bindings"
        log_success "Đã cập nhật ${target_bindings}"
    fi

    # 5. Cấu hình systemd override để bật icon khay hệ thống (StatusNotifierItem) cho fcitx5
    local systemd_override_dir="${HOME}/.config/systemd/user/omarchy-fcitx5.service.d"
    local source_override="${CONFIGS_DIR}/systemd/user/omarchy-fcitx5.service.d/override.conf"
    local target_override="${systemd_override_dir}/override.conf"
    if [ -f "$source_override" ]; then
        mkdir -p "$systemd_override_dir"
        backup_file "$target_override"
        cp "$source_override" "$target_override"
        systemctl --user daemon-reload
        log_success "Đã cập nhật systemd override cho fcitx5: ${target_override}"
    fi

    # 6. Đồng bộ plugin tray tùy biến (huybach02.tray) và shell.json
    local source_tray="${CONFIGS_DIR}/omarchy/plugins/huybach02.tray"
    local target_tray="${HOME}/.config/omarchy/plugins/huybach02.tray"
    if [ -d "$source_tray" ]; then
        mkdir -p "$target_tray"
        cp -r "$source_tray"/* "$target_tray"/
        log_success "Đã cập nhật plugin khay hệ thống: ${target_tray}"
    fi

    local source_shell="${CONFIGS_DIR}/omarchy/shell.json"
    local target_shell="${HOME}/.config/omarchy/shell.json"
    if [ -f "$source_shell" ]; then
        backup_file "$target_shell"
        cp "$source_shell" "$target_shell"
        log_success "Đã cập nhật cấu hình thanh bar: ${target_shell}"
    fi

    # 7. Reload Hyprland
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

    # 8. Khởi động lại service fcitx5 và shell
    log_info "Đang khởi động lại dịch vụ fcitx5..."
    pkill -x fcitx5 2>/dev/null || true
    systemctl --user restart omarchy-fcitx5.service 2>/dev/null || true
    log_success "Dịch vụ fcitx5 đã được khởi động lại thành công!"

    if command -v omarchy &>/dev/null; then
        log_info "Đang làm mới omarchy shell..."
        omarchy restart shell &>/dev/null || true
        log_success "Omarchy shell đã được khởi động lại thành công!"
    fi
}

# --- Module: PHP Development Environment & Version Switcher ---
setup_php() {
    log_info "Bắt đầu cài đặt môi trường PHP (8.5 mặc định, 8.3 legacy) và công cụ php-switch..."

    local pkgs_to_install=()
    local php_packages=(
        # PHP 8.5 (Default)
        "php"
        "php-fpm"
        "php-gd"
        "php-sqlite"
        "php-pgsql"
        "php-redis"
        "php-imagick"
        "composer"

        # PHP 8.3 (Legacy / Alternative)
        "php-legacy"
        "php-legacy-fpm"
        "php-legacy-gd"
        "php-legacy-sqlite"
        "php-legacy-pgsql"
        "php-legacy-redis"
        "php-legacy-imagick"
    )

    for pkg in "${php_packages[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            log_info "Gói ${pkg} đã được cài đặt."
        else
            log_warn "Gói ${pkg} chưa được cài đặt."
            pkgs_to_install+=("$pkg")
        fi
    done

    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        init_sudo
        log_info "Tiến hành cài đặt các gói PHP còn thiếu: ${pkgs_to_install[*]}..."
        if command -v yay &>/dev/null; then
            yay -S --needed --noconfirm --sudoloop "${pkgs_to_install[@]}"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm "${pkgs_to_install[@]}"
        fi
    fi

    # Cấu hình extensions cho PHP 8.5
    local exts=(bcmath curl gd intl mysqli pdo_mysql pdo_pgsql pdo_sqlite pgsql soap sqlite3 zip iconv)
    if [ -f "/etc/php/php.ini" ]; then
        local need_update_85=0
        for ext in "${exts[@]}"; do
            if ! grep -q "^extension=${ext}$" /etc/php/php.ini; then
                need_update_85=1
                break
            fi
        done
        if [ "$need_update_85" -eq 1 ]; then
            init_sudo
            log_info "Đang kích hoạt extensions cho PHP 8.5 trong /etc/php/php.ini..."
            for ext in "${exts[@]}"; do
                sudo sed -i -E "s/^;[[:space:]]*extension[[:space:]]*=[[:space:]]*${ext}$/extension=${ext}/g" /etc/php/php.ini
            done
        fi
    fi

    # Cấu hình extensions cho PHP 8.3 (php-legacy)
    if [ -f "/etc/php-legacy/php.ini" ]; then
        local need_update_83=0
        for ext in "${exts[@]}"; do
            if ! grep -q "^extension=${ext}$" /etc/php-legacy/php.ini; then
                need_update_83=1
                break
            fi
        done
        if ! grep -q "^zend_extension=opcache" /etc/php-legacy/php.ini; then
            need_update_83=1
        fi
        if [ "$need_update_83" -eq 1 ]; then
            init_sudo
            log_info "Đang kích hoạt extensions cho PHP 8.3 trong /etc/php-legacy/php.ini..."
            for ext in "${exts[@]}"; do
                sudo sed -i -E "s/^;[[:space:]]*extension[[:space:]]*=[[:space:]]*${ext}$/extension=${ext}/g" /etc/php-legacy/php.ini
            done
            sudo sed -i -E "s/^;[[:space:]]*zend_extension[[:space:]]*=[[:space:]]*opcache/zend_extension=opcache/g" /etc/php-legacy/php.ini
        fi
    fi

    # Cài đặt php-switch và symlink sphp vào ~/.local/bin
    local bin_dir="${HOME}/.local/bin"
    mkdir -p "$bin_dir"
    local source_switch="${CONFIGS_DIR}/bin/php-switch"
    local target_switch="${bin_dir}/php-switch"

    if [ -f "$source_switch" ]; then
        backup_file "$target_switch"
        cp "$source_switch" "$target_switch"
        chmod +x "$target_switch"
        ln -sfn php-switch "${bin_dir}/sphp"
        log_success "Đã cài đặt php-switch và alias sphp tại ${bin_dir}"
    fi

    # Thiết lập PHP 8.5 làm phiên bản mặc định
    log_info "Thiết lập PHP 8.5 làm phiên bản mặc định..."
    "${bin_dir}/php-switch" 8.5

    log_success "Hoàn tất cài đặt môi trường PHP và php-switch!"
}

# --- Module: Node.js & Fast Node Manager (fnm) ---
setup_nodejs() {
    log_info "Bắt đầu cài đặt Node.js và trình quản lý phiên bản fnm (Fast Node Manager)..."

    # 1. Kiểm tra và cài đặt fnm
    if pacman -Q fnm &>/dev/null; then
        log_info "Gói fnm đã được cài đặt."
    else
        init_sudo
        log_warn "Gói fnm chưa được cài đặt, tiến hành cài đặt..."
        if command -v yay &>/dev/null; then
            yay -S --needed --noconfirm --sudoloop fnm
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm fnm
        fi
    fi

    # 2. Cấu hình tích hợp fnm vào ~/.bashrc
    if ! grep -q "fnm env" "${HOME}/.bashrc"; then
        log_info "Thêm cấu hình fnm vào ~/.bashrc..."
        backup_file "${HOME}/.bashrc"
        if grep -q "env-bootstrap" "${HOME}/.bashrc"; then
            sed -i '/env-bootstrap/a \
\
# fnm (Fast Node Manager)\
if command -v fnm &>/dev/null; then\
  eval "$(fnm env --use-on-cd --corepack-enabled --shell bash)"\
fi' "${HOME}/.bashrc"
        else
            cat << 'EOF' >> "${HOME}/.bashrc"

# fnm (Fast Node Manager)
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --corepack-enabled --shell bash)"
fi
EOF
        fi
        log_success "Đã tích hợp fnm vào ~/.bashrc!"
    else
        log_info "fnm đã được tích hợp sẵn trong ~/.bashrc."
    fi

    # 3. Tạo shell completion cho fnm
    local completion_dir="${HOME}/.local/share/bash-completion/completions"
    mkdir -p "$completion_dir"
    if command -v fnm &>/dev/null; then
        fnm completions --shell bash > "${completion_dir}/fnm" 2>/dev/null || true
        log_success "Đã tạo bash completion cho fnm tại ${completion_dir}/fnm"
    fi

    # 4. Kích hoạt môi trường fnm trong shell hiện tại
    eval "$(fnm env --use-on-cd --corepack-enabled --shell bash)"

    # Cài đặt Node LTS nếu chưa có
    if ! fnm ls 2>/dev/null | grep -q "lts-latest"; then
        log_info "Đang tải và cài đặt Node.js phiên bản LTS..."
        fnm install --lts
    fi

    # Thiết lập default sang lts-latest
    fnm default lts-latest 2>/dev/null || fnm default 24 2>/dev/null || true
    fnm use default 2>/dev/null || true

    # Kích hoạt Corepack cho pnpm và yarn
    if command -v corepack &>/dev/null; then
        log_info "Kích hoạt Corepack (pnpm & yarn)..."
        corepack enable 2>/dev/null || true
    fi

    local current_node
    current_node="$(node -v 2>/dev/null || echo 'none')"
    local current_npm
    current_npm="$(npm -v 2>/dev/null || echo 'none')"

    log_success "Hoàn tất thiết lập Node.js! Node: ${current_node}, npm: ${current_npm}"
}

# --- Module: Symfony CLI ---
setup_symfony() {
    log_info "Bắt đầu cài đặt Symfony CLI và cấu hình môi trường..."

    # 1. Cài đặt symfony-cli
    if pacman -Q symfony-cli &>/dev/null; then
        log_info "Gói symfony-cli đã được cài đặt."
    else
        init_sudo
        log_warn "Gói symfony-cli chưa được cài đặt, tiến hành cài đặt..."
        if command -v yay &>/dev/null; then
            yay -S --needed --noconfirm --sudoloop symfony-cli
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm symfony-cli
        fi
    fi

    # 2. Đảm bảo iconv đã được kích hoạt trong php.ini (bắt buộc cho Symfony)
    for ini in /etc/php/php.ini /etc/php-legacy/php.ini; do
        if [ -f "$ini" ] && ! grep -q "^extension=iconv" "$ini"; then
            init_sudo
            log_info "Kích hoạt extension iconv trong $ini..."
            sudo sed -i -E 's/^;[[:space:]]*extension[[:space:]]*=[[:space:]]*iconv/extension=iconv/' "$ini"
        fi
    done

    # 3. Tạo bash completion cho Symfony CLI
    local completion_dir="${HOME}/.local/share/bash-completion/completions"
    mkdir -p "$completion_dir"
    if command -v symfony &>/dev/null; then
        symfony completion bash > "${completion_dir}/symfony" 2>/dev/null || true
        log_success "Đã tạo bash completion cho symfony tại ${completion_dir}/symfony"
    fi

    local symfony_ver
    symfony_ver="$(symfony version 2>/dev/null || echo 'none')"
    log_success "Hoàn tất cài đặt Symfony CLI! Phiên bản: ${symfony_ver}"
}

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
        file_manager)
            setup_file_manager
            ;;
        browser)
            setup_browser
            ;;
        apps)
            setup_apps
            ;;
        looknfeel)
            setup_looknfeel
            ;;
        agent_quota)
            setup_agent_quota
            ;;
        sysinfo)
            setup_sysinfo
            ;;
        vietnamese|input)
            setup_vietnamese_input
            ;;
        php)
            setup_php
            ;;
        node|nodejs)
            setup_nodejs
            ;;
        symfony)
            setup_symfony
            ;;
        all)
            setup_monitors
            setup_workspaces
            setup_keybindings
            setup_packages
            setup_file_manager
            setup_apps
            setup_looknfeel
            setup_agent_quota
            setup_sysinfo
            setup_vietnamese_input
            setup_php
            setup_nodejs
            setup_symfony
            ;;
        *)
            echo "Cách sử dụng: $0 [all|monitors|workspaces|keybindings|packages|browser|file_manager|apps|looknfeel|agent_quota|sysinfo|vietnamese|php|node|symfony]"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}    Hoàn thành quá trình thiết lập!       ${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
}

main "$@"
