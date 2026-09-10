# Cấu hình ble.sh (Bash Line Editor) cho OmarchyOS

# 1. Bật tính năng tự động gợi ý lệnh (Auto-complete / Autosuggestions như Fish/Zsh)
bleopt complete_auto_complete=1
bleopt complete_auto_history=1
bleopt complete_auto_delay=1

# Màu sắc hiển thị chữ mờ gợi ý (dim/gray text)
ble-face -s auto_complete 'fg=244'

# 2. Sử dụng phím TAB để hoàn thành autocompletion khi có gợi ý xuất hiện
ble-bind -m auto_complete -f 'C-i' auto_complete/insert
ble-bind -m auto_complete -f 'TAB' auto_complete/insert

# 3. Điều hướng menu hoàn thành lệnh (menu-complete) bằng TAB và Shift+TAB
ble-bind -m menu_complete -f 'C-i' menu_complete/forward
ble-bind -m menu_complete -f 'TAB' menu_complete/forward
ble-bind -m menu_complete -f 'S-TAB' menu_complete/backward
ble-bind -m menu_complete -f 'C-p' menu_complete/backward

# 4. Tích hợp fzf cho tìm kiếm mờ nhanh chóng
if command -v fzf &>/dev/null; then
    ble-import -d integration/fzf-completion
    ble-import -d integration/fzf-key-bindings
fi

# 5. Luôn dùng Enter (RET / C-m) để thực thi lệnh (kể cả khi dán nhiều dòng / multiline)
function blerc/multiline-load-hook {
    ble-bind -m emacs -f 'RET' 'accept-line syntax'
    ble-bind -m emacs -f 'C-m' 'accept-line syntax'
    ble-bind -m emacs -f 'C-j' 'accept-line syntax'
}
blehook/eval-after-load keymap_emacs blerc/multiline-load-hook

function blerc/vi-multiline-load-hook {
    ble-bind -m vi_imap -f 'RET' 'accept-line syntax'
    ble-bind -m vi_imap -f 'C-m' 'accept-line syntax'
    ble-bind -m vi_imap -f 'C-j' 'accept-line syntax'
    ble-bind -m vi_nmap -f 'RET' 'accept-line syntax'
    ble-bind -m vi_nmap -f 'C-m' 'accept-line syntax'
    ble-bind -m vi_nmap -f 'C-j' 'accept-line syntax'
}
blehook/eval-after-load keymap_vi blerc/vi-multiline-load-hook
