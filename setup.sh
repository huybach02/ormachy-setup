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
    
    # Cài đặt tiện ích omarchy-finder
    local source_finder="${CONFIGS_DIR}/bin/omarchy-finder"
    local target_finder="${HOME}/.local/bin/omarchy-finder"
    if [ -f "$source_finder" ]; then
        mkdir -p "${HOME}/.local/bin"
        backup_file "$target_finder"
        cp "$source_finder" "$target_finder"
        chmod +x "$target_finder"
        log_success "Đã cài đặt tiện ích tìm kiếm ${target_finder}"
    fi
    
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

    if command -v omarchy &>/dev/null; then
        omarchy default browser edge &>/dev/null || true
    fi

    # Cấu hình BROWSER trong ~/.bashrc
    if [ -f "${HOME}/.bashrc" ] && ! grep -q 'export BROWSER=' "${HOME}/.bashrc"; then
        if grep -q 'export EDITOR=' "${HOME}/.bashrc"; then
            sed -i '/export EDITOR=/a export BROWSER="microsoft-edge"' "${HOME}/.bashrc"
        else
            sed -i '1i export BROWSER="microsoft-edge"' "${HOME}/.bashrc"
        fi
    fi

    log_success "Đã đặt Microsoft Edge (${desktop_id}) làm trình duyệt mặc định cho Omarchy, liên kết web và HTML!"
}

# --- Module: Helium Browser Hardware Acceleration ---
setup_helium() {
    log_info "Cấu hình Hardware Video Acceleration cho Helium Browser..."

    local source_flags="${CONFIGS_DIR}/helium/helium-browser-flags.conf"
    local target_flags="${HOME}/.config/helium-browser-flags.conf"

    if [ -f "$source_flags" ]; then
        backup_file "$target_flags"
        cp "$source_flags" "$target_flags"
        log_success "Đã cập nhật ${target_flags} (kích hoạt giải mã phần cứng VA-API trên NVIDIA/Wayland)!"
    else
        log_warn "Không tìm thấy ${source_flags}"
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
    setup_helium

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
    
    # Cấu hình font size terminal
    setup_terminal

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

# --- Module: Terminal Appearance & Font Size ---
setup_terminal() {
    log_info "Bắt đầu cấu hình font chữ terminal (JetBrainsMono Nerd Font size = 12)..."

    local font_size=12

    # 1. Cấu hình Foot terminal
    local foot_dir="${HOME}/.config/foot"
    local target_foot="${foot_dir}/foot.ini"
    local source_foot="${CONFIGS_DIR}/foot/foot.ini"
    mkdir -p "$foot_dir"
    if [ -f "$source_foot" ]; then
        backup_file "$target_foot"
        cp "$source_foot" "$target_foot"
        log_success "Đã đồng bộ ${target_foot} (font size ${font_size})!"
    elif [ -f "$target_foot" ]; then
        backup_file "$target_foot"
        sed -i -E "s/^(font=.*:size=)[0-9]+/\\1${font_size}/" "$target_foot"
        log_success "Đã cập nhật font size ${font_size} trong ${target_foot}"
    fi

    # 2. Cập nhật các terminal khác nếu có (Alacritty, Kitty, Ghostty)
    local alacritty_cfg="${HOME}/.config/alacritty/alacritty.toml"
    local kitty_cfg="${HOME}/.config/kitty/kitty.conf"
    local ghostty_cfg="${HOME}/.config/ghostty/config"

    if [ -f "$alacritty_cfg" ]; then
        backup_file "$alacritty_cfg"
        sed -i -E "s/^(size = )[0-9]+/\\1${font_size}/" "$alacritty_cfg"
    fi

    if [ -f "$kitty_cfg" ]; then
        backup_file "$kitty_cfg"
        sed -i -E "s/^(font_size[[:space:]]+)[0-9]+(\.[0-9]+)?/\\1${font_size}.0/" "$kitty_cfg"
    fi

    if [ -f "$ghostty_cfg" ]; then
        backup_file "$ghostty_cfg"
        sed -i -E "s/^(font-size = )[0-9]+/\\1${font_size}/" "$ghostty_cfg"
    fi

    # 3. Reload terminal nếu đang chạy
    if command -v omarchy &>/dev/null; then
        omarchy restart terminal &>/dev/null || true
    fi
    killall -SIGUSR1 foot 2>/dev/null || true

    log_success "Đã thiết lập font size ${font_size} cho terminal hoàn tất!"
}

# --- Module: Branding & Pixel Logo (B&T Logo & Fastfetch) ---
setup_branding() {
    log_info "Bắt đầu cấu hình branding (logo B&T pixel và Fastfetch)..."

    local branding_src="${CONFIGS_DIR}/omarchy/branding"
    local branding_target="${HOME}/.config/omarchy/branding"
    local fastfetch_src="${CONFIGS_DIR}/fastfetch/config.jsonc"
    local fastfetch_target="${HOME}/.config/fastfetch/config.jsonc"

    # 1. Cấu hình about.txt và screensaver.txt
    mkdir -p "$branding_target"
    if [ -f "${branding_src}/about.txt" ]; then
        backup_file "${branding_target}/about.txt"
        cp "${branding_src}/about.txt" "${branding_target}/about.txt"
        log_success "Đã đồng bộ ${branding_target}/about.txt"
    fi

    if [ -f "${branding_src}/screensaver.txt" ]; then
        backup_file "${branding_target}/screensaver.txt"
        cp "${branding_src}/screensaver.txt" "${branding_target}/screensaver.txt"
        log_success "Đã đồng bộ ${branding_target}/screensaver.txt"
    fi

    # 2. Cấu hình Fastfetch
    mkdir -p "${HOME}/.config/fastfetch"
    if [ -f "$fastfetch_src" ]; then
        backup_file "$fastfetch_target"
        cp "$fastfetch_src" "$fastfetch_target"
        log_success "Đã đồng bộ ${fastfetch_target}"
    fi

    log_success "Đã thiết lập branding logo B&T pixel (màu xanh dương) thành công!"
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

# --- Module: Sound Wave Visualizer Bar Widget (MPRIS Media) ---
setup_media() {
    log_info "Bắt đầu cấu hình widget sóng nhạc động (Sound Wave Visualizer) trên thanh bar..."
    
    local user="${USER:-$(id -un)}"
    local plugin_dir="${HOME}/.config/omarchy/plugins/${user}.media"
    local source_plugin="${CONFIGS_DIR}/omarchy/plugins/media"
    
    # 1. Clone và đồng bộ plugin media tùy biến
    if [ -d "$source_plugin" ]; then
        if [ ! -d "$plugin_dir" ]; then
            log_info "Đang clone omarchy.media sang ${user}.media..."
            omarchy plugin clone omarchy.media &>/dev/null || true
        fi
        mkdir -p "$plugin_dir"
        local plugin_file
        for plugin_file in BarWidget.qml manifest.json MediaModel.js Service.qml; do
            backup_file "${plugin_dir}/${plugin_file}"
        done
        cp -r "${source_plugin}/"* "$plugin_dir/"
        # Đảm bảo manifest và BarWidget có đúng tên user
        sed -i "s/\"id\": \"huybach02\.media\"/\"id\": \"${user}\.media\"/g" "${plugin_dir}/manifest.json" 2>/dev/null || true
        sed -i "s/moduleName: \"huybach02\.media\"/moduleName: \"${user}\.media\"/g" "${plugin_dir}/BarWidget.qml" 2>/dev/null || true
        sed -i "s/\"huybach02\.media\"/\"${user}\.media\"/g" "${plugin_dir}/BarWidget.qml" 2>/dev/null || true
        log_success "Đã đồng bộ giao diện sóng nhạc cho ${user}.media!"
    fi

    # 2. Cập nhật cấu hình shell.json
    local omarchy_conf_dir="${HOME}/.config/omarchy"
    local target_shell="${omarchy_conf_dir}/shell.json"
    local source_shell="${CONFIGS_DIR}/omarchy/shell.json"
    if [ -f "$source_shell" ]; then
        backup_file "$target_shell"
        sed "s/huybach02/${user}/g" "$source_shell" > "$target_shell"
        log_success "Đã cập nhật ${target_shell}"
    fi

    # 3. Khởi động lại omarchy shell nếu đang chạy
    if pgrep quickshell &>/dev/null && command -v omarchy &>/dev/null; then
        log_info "Đang khởi động lại omarchy shell để áp dụng widget sóng nhạc..."
        omarchy restart shell &>/dev/null || true
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

# --- Module: Automount Storage Partitions ---
setup_automount() {
    log_info "Bắt đầu cấu hình tự động mount phân vùng ổ đĩa (/dev/sda5 - UUID=8E3A42193A41FEA9)..."

    local current_user="${SUDO_USER:-$USER}"
    local current_uid
    local current_gid
    current_uid="$(id -u "$current_user" 2>/dev/null || echo 1000)"
    current_gid="$(id -g "$current_user" 2>/dev/null || echo 1000)"

    local partition_uuid="8E3A42193A41FEA9"
    local mount_point="/run/media/${current_user}/${partition_uuid}"
    local fstab_entry="UUID=${partition_uuid}  ${mount_point}  ntfs3  defaults,uid=${current_uid},gid=${current_gid},dmask=022,fmask=133,iocharset=utf8,windows_names,nofail,x-systemd.device-timeout=10s  0  0"

    init_sudo

    # 1. Cấu hình tmpfiles.d để tự động tạo thư mục /run/media/<user> sau mỗi lần boot
    local tmpfiles_conf="/etc/tmpfiles.d/omarchy-media.conf"
    local tmpfiles_source="${CONFIGS_DIR}/systemd/tmpfiles.d/omarchy-media.conf"

    if [ ! -f "$tmpfiles_conf" ] || ! grep -q "/run/media/${current_user}" "$tmpfiles_conf" 2>/dev/null; then
        log_info "Tạo cấu hình ${tmpfiles_conf}..."
        {
            echo "d /run/media 0755 root root -"
            echo "d /run/media/${current_user} 0750 ${current_user} ${current_user} -"
        } | sudo tee "$tmpfiles_conf" >/dev/null
        sudo systemd-tmpfiles --create "$tmpfiles_conf" 2>/dev/null || true
        log_success "Đã tạo cấu hình tmpfiles.d tại ${tmpfiles_conf}."
    else
        log_info "Cấu hình ${tmpfiles_conf} đã sẵn sàng."
    fi

    # Đảm bảo mount point tồn tại
    sudo mkdir -p "$mount_point"
    sudo chown "${current_user}:${current_user}" "$mount_point" 2>/dev/null || true

    # 2. Cập nhật /etc/fstab nếu chưa có
    if grep -q "UUID=${partition_uuid}" /etc/fstab; then
        log_info "Mục mount UUID=${partition_uuid} đã có trong /etc/fstab."
    else
        log_info "Thêm mục mount UUID=${partition_uuid} vào /etc/fstab..."
        backup_file "/etc/fstab"
        echo -e "\n# Automount NTFS Data partition (/dev/sda5) for ${current_user}\n${fstab_entry}" | sudo tee -a /etc/fstab >/dev/null
        log_success "Đã thêm cấu hình tự động mount vào /etc/fstab!"
    fi

    # 3. Reload systemd daemon và kích hoạt mount nếu chưa mount
    sudo systemctl daemon-reload
    if ! findmnt -M "$mount_point" &>/dev/null; then
        log_info "Tiến hành mount ${mount_point}..."
        if sudo mount "$mount_point" 2>/dev/null; then
            log_success "Đã mount thành công ổ đĩa tại ${mount_point}!"
        else
            log_warn "Không thể mount ngay (có thể thiết bị không sẵn sàng). Hệ thống sẽ tự động mount khi khởi động."
        fi
    else
        log_success "Ổ đĩa đã được mount và sẵn sàng tại ${mount_point}!"
    fi
}

# --- Module: Terminal Autocompletion & Autosuggestions (ble.sh) ---
setup_autocompletion() {
    log_info "Bắt đầu cài đặt và cấu hình autocompletion cho terminal (ble.sh + Tab)..."

    local blesh_dir="${HOME}/.local/share/blesh"
    local blesh_script="${blesh_dir}/ble.sh"

    # 1. Cài đặt ble.sh nếu chưa có
    if [ -f "$blesh_script" ] || [ -f "/usr/share/blesh/ble.sh" ]; then
        log_info "ble.sh đã được cài đặt trên hệ thống."
    else
        log_info "Đang tải và cài đặt ble.sh (Bash Line Editor)..."
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        if curl -fsSL "https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz" | tar -xJf - -C "$tmp_dir"; then
            mkdir -p "${HOME}/.local/share"
            bash "${tmp_dir}/ble-nightly/ble.sh" --install "${HOME}/.local/share"
            rm -rf "$tmp_dir"
            log_success "Đã cài đặt ble.sh vào ${blesh_dir} thành công!"
        else
            rm -rf "$tmp_dir"
            log_error "Không thể tải ble.sh từ GitHub release!"
            return 1
        fi
    fi

    # 2. Cài đặt file cấu hình ~/.config/blesh/init.sh
    local config_dir="${HOME}/.config/blesh"
    local config_file="${config_dir}/init.sh"
    local source_config="${CONFIGS_DIR}/blesh/init.sh"

    mkdir -p "$config_dir"
    if [ -f "$source_config" ]; then
        backup_file "$config_file"
        cp "$source_config" "$config_file"
        log_success "Đã cài đặt cấu hình ble.sh tại ${config_file}!"
    fi

    # 3. Cấu hình ~/.bashrc để nạp ble.sh
    local bashrc="${HOME}/.bashrc"
    if [ -f "$bashrc" ]; then
        # Đảm bảo nạp ble.sh --attach=none sau non-interactive guard
        if ! grep -q 'blesh/ble.sh' "$bashrc"; then
            log_info "Thêm ble.sh khởi tạo vào ~/.bashrc..."
            backup_file "$bashrc"
            sed -i '/\[\[ \$- != \*i\* \]\] && return/a \
\
# ble.sh (Bash Line Editor) - Khởi tạo autocompletion & autosuggestions\
[[ $- == *i* ]] && [ -f "$HOME/.local/share/blesh/ble.sh" ] && source "$HOME/.local/share/blesh/ble.sh" --attach=none' "$bashrc"
        fi

        # Đảm bảo ble-attach ở cuối ~/.bashrc
        if ! grep -q 'ble-attach' "$bashrc"; then
            log_info "Thêm ble-attach vào cuối ~/.bashrc..."
            echo -e '\n# ble.sh attach\n[[ ! ${BLE_VERSION-} ]] || ble-attach' >> "$bashrc"
        fi
        log_success "Đã cấu hình ~/.bashrc hỗ trợ autocompletion hoàn tất!"
    fi

    log_success "Hoàn tất thiết lập autocompletion! Mở terminal mới hoặc gõ lệnh để trải nghiệm."
}

# --- Module: Flutter Mobile Development Environment ---
setup_flutter() {
    log_info "Bắt đầu cài đặt & cấu hình môi trường Flutter Mobile (Android SDK, Android Studio, Emulator)..."

    # 1. Cài đặt và cấu hình Java 17 via mise
    if command -v mise &>/dev/null; then
        if ! mise ls java 2>/dev/null | grep -q "17"; then
            log_info "Đang cài đặt OpenJDK 17 thông qua mise..."
            mise install java@temurin-17.0.20+101
        fi
        mise use -g java@temurin-17.0.20+101
        log_success "Đã cấu hình Java 17 (Temurin) qua mise thành công!"
    else
        log_warn "Không tìm thấy mise trên hệ thống, kiểm tra Java hiện tại..."
        if ! command -v java &>/dev/null; then
            log_error "Vui lòng cài đặt Java 17 (JDK) trước khi tiếp tục."
            return 1
        fi
    fi

    # 2. Cài đặt Flutter SDK vào ~/development/flutter
    local flutter_dir="${HOME}/development/flutter"
    if [ -d "${flutter_dir}/.git" ]; then
        log_info "Flutter SDK đã tồn tại tại ${flutter_dir}."
    else
        log_info "Đang tải Flutter SDK (channel stable) vào ${flutter_dir}..."
        mkdir -p "${HOME}/development"
        git clone -b stable https://github.com/flutter/flutter.git "${flutter_dir}"
        log_success "Đã clone Flutter SDK thành công!"
    fi
    export PATH="${flutter_dir}/bin:${PATH}"

    # 3. Cài đặt Android Studio vào ~/.local/share/android-studio
    local studio_dir="${HOME}/.local/share/android-studio"
    if [ -f "${studio_dir}/bin/studio.sh" ]; then
        log_info "Android Studio đã được cài đặt tại ${studio_dir}."
    else
        log_info "Đang tải và giải nén Android Studio vào ${studio_dir}..."
        mkdir -p "${HOME}/.local/share"
        curl -L "https://dl.google.com/dl/android/studio/ide-zips/2026.1.4.7/android-studio-quail4-linux.tar.gz" | tar -xz -C "${HOME}/.local/share/"
        log_success "Đã cài đặt Android Studio vào ${studio_dir}!"
    fi

    # Tạo symlink android-studio vào ~/.local/bin
    mkdir -p "${HOME}/.local/bin"
    ln -sf "${studio_dir}/bin/studio.sh" "${HOME}/.local/bin/android-studio"

    # Tạo desktop launcher cho Android Studio
    local apps_dir="${HOME}/.local/share/applications"
    mkdir -p "$apps_dir"
    cat << EOF > "${apps_dir}/android-studio.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Exec=env "QT_QPA_PLATFORM=wayland;xcb" "${studio_dir}/bin/studio.sh" %f
Icon=${studio_dir}/bin/studio.png
Comment=The official Android IDE
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-studio
MimeType=application/x-extension-iml;
EOF
    update-desktop-database "$apps_dir" 2>/dev/null || true
    log_success "Đã tạo shortcut và lệnh android-studio."

    # 4. Cài đặt Android Command-line Tools & SDK Packages
    local android_home="${HOME}/Android/Sdk"
    mkdir -p "$android_home"

    if [ ! -f "${android_home}/cmdline-tools/latest/bin/sdkmanager" ]; then
        log_info "Đang tải Android Command-line Tools..."
        local tmp_zip="/tmp/cmdline-tools.zip"
        local tmp_dir="/tmp/cmdline-tools-extract"
        rm -rf "$tmp_zip" "$tmp_dir"
        curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o "$tmp_zip"
        unzip -q "$tmp_zip" -d "$tmp_dir"
        mkdir -p "${android_home}/cmdline-tools/latest"
        cp -r "${tmp_dir}/cmdline-tools/"* "${android_home}/cmdline-tools/latest/"
        rm -rf "$tmp_dir" "$tmp_zip"
        log_success "Đã cài đặt cmdline-tools vào ${android_home}/cmdline-tools/latest!"
    fi

    export ANDROID_HOME="${android_home}"
    export PATH="${android_home}/cmdline-tools/latest/bin:${android_home}/platform-tools:${android_home}/emulator:${PATH}"

    # Cấu hình Flutter trỏ tới Android SDK và Android Studio
    flutter config --android-sdk="${android_home}" >/dev/null 2>&1 || true
    flutter config --android-studio-dir="${studio_dir}" >/dev/null 2>&1 || true

    # Cài đặt các gói SDK cần thiết
    log_info "Kiểm tra và cài đặt các gói Android SDK (platform-tools, build-tools 36, platforms 36, emulator, system-image 34)..."
    yes | sdkmanager --licenses >/dev/null 2>&1 || true
    sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36" "emulator" "system-images;android-34;google_apis;x86_64"
    yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
    log_success "Đã cài đặt và chấp nhận licenses Android SDK thành công!"

    # 5. Cấu hình máy ảo Pixel 7 (AVD) và tối ưu GPU
    mkdir -p "${HOME}/.android" "${HOME}/.config/.android/avd"
    if [ ! -e "${HOME}/.android/avd" ]; then
        ln -sf "${HOME}/.config/.android/avd" "${HOME}/.android/avd"
    fi
    export ANDROID_AVD_HOME="${HOME}/.android/avd"

    if ! emulator -list-avds 2>/dev/null | grep -q "^Pixel_7_API_34$"; then
        log_info "Đang khởi tạo máy ảo Pixel_7_API_34..."
        echo "no" | avdmanager create avd -n Pixel_7_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_7" --force
    fi

    # Tối ưu cấu hình phần cứng AVD (GPU Host, 4 Cores, 3GB RAM, 512MB Heap)
    local avd_config="${HOME}/.config/.android/avd/Pixel_7_API_34.avd/config.ini"
    if [ -f "$avd_config" ]; then
        log_info "Tối ưu hóa phần cứng máy ảo (GPU Host, 4 nhân CPU, 3GB RAM)..."
        sed -i 's/^hw.gpu.enabled = no/hw.gpu.enabled = yes/' "$avd_config"
        sed -i 's/^hw.gpu.mode = .*/hw.gpu.mode = host/' "$avd_config"
        sed -i 's/^hw.cpu.ncore = .*/hw.cpu.ncore = 4/' "$avd_config"
        sed -i 's/^hw.ramSize = .*/hw.ramSize = 3072M/' "$avd_config"
        sed -i 's/^vm.heapSize = .*/vm.heapSize = 512M/' "$avd_config"
        log_success "Đã cấu hình tối ưu máy ảo tại ${avd_config}!"
    fi

    # 6. Cấu hình Window Rule Hyprland để máy ảo tự động mở dạng Floating
    local target_windows="${HOME}/.config/hypr/windows.lua"
    if [ -f "$target_windows" ]; then
        if ! grep -q 'class.*Emulator' "$target_windows" && ! grep -q '\[eE\]mulator' "$target_windows"; then
            log_info "Thêm window rule floating cho Android Emulator trong Hyprland..."
            cat << 'EOF' >> "$target_windows"

-- Android Emulator: Float to keep phone aspect ratio and avoid empty side areas
o.window("^([eE]mulator|qemu-system-x86_64)$", {
  float = true,
})
EOF
            if [ "${HYPRLAND_INSTANCE_SIGNATURE:-}" != "" ] && command -v hyprctl &>/dev/null; then
                hyprctl reload 2>/dev/null || true
            fi
            log_success "Đã cập nhật window rule cho Hyprland!"
        fi
    fi

    # 7. Cấu hình tích hợp VS Code
    if command -v code &>/dev/null; then
        log_info "Cấu hình extension và đường dẫn Flutter SDK cho VS Code..."
        code --install-extension Dart-Code.flutter >/dev/null 2>&1 || true

        local vscode_settings="${HOME}/.config/Code/User/settings.json"
        if [ -f "$vscode_settings" ]; then
            if ! grep -q "dart.flutterSdkPath" "$vscode_settings"; then
                python3 -c "
path = '$vscode_settings'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

idx = content.rfind('}')
if idx != -1:
    new_content = content[:idx].rstrip()
    if not new_content.endswith(','):
        new_content += ','
    new_content += '\n  \"dart.flutterSdkPath\": \"$HOME/development/flutter\"\n}\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
" 2>/dev/null || true
                log_success "Đã thêm dart.flutterSdkPath vào VS Code settings.json!"
            fi
        fi
    fi

    # 8. Cấu hình biến môi trường vào ~/.bashrc
    local bashrc="${HOME}/.bashrc"
    if [ -f "$bashrc" ]; then
        if ! grep -q "development/flutter/bin" "$bashrc"; then
            log_info "Bổ sung biến môi trường Flutter & Android SDK vào ~/.bashrc..."
            backup_file "$bashrc"
            sed -i '/export BROWSER=/a \
\
# Flutter & Android SDK\
export PATH="$HOME/development/flutter/bin:$PATH"\
export ANDROID_HOME="$HOME/Android/Sdk"\
export ANDROID_AVD_HOME="$HOME/.android/avd"\
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"' "$bashrc"
            log_success "Đã thêm biến môi trường Flutter vào ~/.bashrc!"
        fi
    fi

    log_success "Hoàn tất cài đặt môi trường Flutter Mobile!"
    log_info "Bạn có thể kiểm tra môi trường bằng lệnh: flutter doctor"
    log_info "Khởi động máy ảo Android: flutter emulators --launch Pixel_7_API_34"
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
        helium|helium-browser)
            setup_helium
            ;;
        apps)
            setup_apps
            ;;
        looknfeel)
            setup_looknfeel
            ;;
        terminal)
            setup_terminal
            ;;
        branding|logo)
            setup_branding
            ;;
        agent_quota)
            setup_agent_quota
            ;;
        sysinfo)
            setup_sysinfo
            ;;
        media|visualizer|soundwave)
            setup_media
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
        automount|disks)
            setup_automount
            ;;
        autocompletion|autocomplete|completion)
            setup_autocompletion
            ;;
        flutter)
            setup_flutter
            ;;
        all)
            setup_monitors
            setup_workspaces
            setup_keybindings
            setup_packages
            setup_file_manager
            setup_apps
            setup_looknfeel
            setup_branding
            setup_agent_quota
            setup_sysinfo
            setup_media
            setup_vietnamese_input
            setup_php
            setup_nodejs
            setup_symfony
            setup_automount
            setup_autocompletion
            # Lưu ý: flutter KHÔNG tự động cài đặt khi chạy all (chạy riêng: ./setup.sh flutter)
            ;;
        *)
            echo "Cách sử dụng: $0 [all|monitors|workspaces|keybindings|packages|browser|helium|file_manager|apps|looknfeel|terminal|branding|agent_quota|sysinfo|media|vietnamese|php|node|symfony|automount|autocompletion|flutter]"
            exit 1
            ;;
    esac
    
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}    Hoàn thành quá trình thiết lập!       ${COLOR_RESET}"
    echo -e "${COLOR_SUCCESS}==========================================${COLOR_RESET}"
}

main "$@"
