#!/bin/bash
#===============================================================================
# Bilibili 录播自动上传工具 - 一键安装脚本
# 支持 Debian/Ubuntu/CentOS/RHEL/Fedora/Arch Linux
#===============================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="${HOME}/biliup"
BILIUP_VERSION="v0.2.4"
PYTHON_MIN_VERSION="3.8"

#===============================================================================
# 工具函数
#===============================================================================

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Bilibili 录播自动上传工具 - 一键安装程序               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "检测到以 root 用户运行"
        print_warning "建议使用普通用户运行此脚本"
        read -p "是否继续? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_os() {
    print_info "检测操作系统..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        VER=$(uname -r)
    fi

    print_success "检测到系统: $OS $VER"
}

detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            BILIUP_ARCH="x86_64"
            ;;
        aarch64)
            BILIUP_ARCH="aarch64"
            ;;
        *)
            print_error "不支持的架构: $ARCH"
            print_info "支持的架构: x86_64, aarch64"
            exit 1
            ;;
    esac
    print_success "检测到架构: $ARCH"
}

check_network() {
    print_info "检查网络连接..."
    if ping -c 1 -W 3 github.com >/dev/null 2>&1; then
        print_success "网络连接正常"
        return 0
    elif ping -c 1 -W 3 baidu.com >/dev/null 2>&1; then
        print_warning "无法访问 GitHub，但网络连接正常"
        print_warning "部分功能可能需要代理才能使用"
        return 0
    else
        print_error "网络连接失败"
        return 1
    fi
}

check_python_version() {
    print_info "检查 Python 版本..."

    if ! command -v python3 &> /dev/null; then
        print_error "未找到 python3"
        return 1
    fi

    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')

    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        print_success "Python 版本: $PYTHON_VERSION (满足要求)"
        return 0
    else
        print_error "Python 版本过低: $PYTHON_VERSION (需要 >= $PYTHON_MIN_VERSION)"
        return 1
    fi
}

#===============================================================================
# 安装依赖
#===============================================================================

install_dependencies() {
    print_info "开始安装系统依赖..."

    case $OS in
        debian|ubuntu|linuxmint)
            install_dependencies_debian
            ;;
        centos|rhel|fedora|rocky|almalinux)
            install_dependencies_redhat
            ;;
        arch|manjaro)
            install_dependencies_arch
            ;;
        alpine)
            install_dependencies_alpine
            ;;
        *)
            print_warning "未知系统类型: $OS"
            print_info "尝试通用安装方式..."
            install_dependencies_generic
            ;;
    esac
}

install_dependencies_debian() {
    print_info "使用 apt 安装依赖..."

    sudo apt-get update
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        ffmpeg \
        curl \
        wget \
        fuse \
        unzip \
        tar

    # 安装 rclone
    if ! command -v rclone &> /dev/null; then
        print_info "安装 rclone..."
        curl https://rclone.org/install.sh | sudo bash || {
            print_warning "rclone 官方脚本安装失败，尝试使用 apt..."
            sudo apt-get install -y rclone
        }
    else
        print_success "rclone 已安装"
    fi
}

install_dependencies_redhat() {
    print_info "使用 yum/dnf 安装依赖..."

    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi

    sudo $PKG_MANAGER install -y \
        python3 \
        python3-pip \
        ffmpeg \
        curl \
        wget \
        fuse \
        unzip \
        tar

    # 安装 rclone
    if ! command -v rclone &> /dev/null; then
        print_info "安装 rclone..."
        curl https://rclone.org/install.sh | sudo bash
    else
        print_success "rclone 已安装"
    fi
}

install_dependencies_arch() {
    print_info "使用 pacman 安装依赖..."

    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm \
        python \
        python-pip \
        ffmpeg \
        rclone \
        curl \
        wget \
        fuse2 \
        unzip \
        tar
}

install_dependencies_alpine() {
    print_info "使用 apk 安装依赖..."

    sudo apk update
    sudo apk add \
        python3 \
        py3-pip \
        ffmpeg \
        rclone \
        curl \
        wget \
        fuse \
        unzip \
        tar \
        bash
}

install_dependencies_generic() {
    print_info "尝试通用方式安装依赖..."
    print_warning "请确保以下工具已安装: python3, pip, ffmpeg, rclone, curl, wget"

    # 只尝试安装 rclone
    if ! command -v rclone &> /dev/null; then
        print_info "安装 rclone..."
        curl https://rclone.org/install.sh | sudo bash || {
            print_error "rclone 安装失败，请手动安装"
            print_info "访问: https://rclone.org/downloads/"
        }
    fi
}

install_biliup() {
    print_info "安装 biliup-rs..."

    BILIUP_URL="https://github.com/ForgQi/biliup-rs/releases/download/${BILIUP_VERSION}/biliupR-${BILIUP_VERSION}-${BILIUP_ARCH}-linux.tar.xz"
    TEMP_DIR=$(mktemp -d)

    print_info "下载 biliup-rs ${BILIUP_VERSION} (${BILIUP_ARCH})..."
    if curl -fsSL "$BILIUP_URL" -o "$TEMP_DIR/biliup.tar.xz"; then
        print_info "解压文件..."
        tar -xf "$TEMP_DIR/biliup.tar.xz" -C "$TEMP_DIR"

        print_info "安装到 /usr/local/bin/biliup..."
        sudo install -m755 "$TEMP_DIR/biliupR-${BILIUP_VERSION}-${BILIUP_ARCH}-linux/biliup" /usr/local/bin/biliup

        rm -rf "$TEMP_DIR"
        print_success "biliup-rs 安装成功"
    else
        print_error "下载 biliup-rs 失败"
        print_info "请检查网络连接或手动下载安装"
        print_info "下载地址: $BILIUP_URL"
        return 1
    fi
}

install_python_dependencies() {
    print_info "安装 Python 依赖..."

    cd "$INSTALL_DIR"

    # 尝试使用 --break-system-packages
    if python3 -m pip install -r requirements.txt --break-system-packages 2>/dev/null; then
        print_success "Python 依赖安装成功"
    else
        # 失败则尝试用户安装
        print_warning "使用用户模式安装 Python 依赖..."
        if python3 -m pip install --user -r requirements.txt; then
            print_success "Python 依赖安装成功"
        else
            print_error "Python 依赖安装失败"
            print_info "请手动运行: pip3 install -r requirements.txt"
            return 1
        fi
    fi
}

#===============================================================================
# 创建项目结构
#===============================================================================

create_project_structure() {
    print_info "创建项目目录结构..."

    # 如果安装目录不是当前目录，则创建并复制文件
    if [[ "$PWD" != "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"

        # 复制所有文件
        print_info "复制项目文件到 $INSTALL_DIR..."
        cp -r ./* "$INSTALL_DIR/" 2>/dev/null || true
    fi

    cd "$INSTALL_DIR"

    # 创建必要的目录
    mkdir -p temp/downloads
    mkdir -p temp/covers
    mkdir -p temp/splits

    # 生成配置文件（如果不存在）
    if [[ ! -f "config.json" ]]; then
        print_info "生成默认配置文件..."
        cat > config.json <<'EOF'
{
  "rclone": {
    "remote": "your_remote_name",
    "backup_path": "backup",
    "mount_point": "/tmp/bili_rclone_mount"
  },
  "bilibili": {
    "default_tid": 171,
    "default_tags": [
      "录播",
      "虚拟主播"
    ],
    "source_template": "https://live.bilibili.com/{room_id}",
    "desc_template": "{streamer_name}的直播录播\n录制时间：{date}\n\n本视频由自动化工具上传"
  },
  "upload": {
    "max_file_size_gb": 15,
    "split_margin_gb": 14.5,
    "retry_times": 3,
    "local_cache_path": "${INSTALL_DIR}/temp",
    "min_free_space_gb": 5
  },
  "cover": {
    "extract_time_sec": 1,
    "output_format": "jpg",
    "quality": 85
  },
  "biliup_cli": {
    "executable": "/usr/local/bin/biliup",
    "cookie_file": "${INSTALL_DIR}/cookies.json",
    "default_submit": "client",
    "proxy": null
  }
}
EOF
        # 替换实际路径
        sed -i "s|\${INSTALL_DIR}|${INSTALL_DIR}|g" config.json
    fi

    # 创建空的历史文件（如果不存在）
    [[ ! -f "upload_history.json" ]] && echo "[]" > upload_history.json
    [[ ! -f "failed_uploads.json" ]] && echo "[]" > failed_uploads.json

    print_success "项目结构创建完成"
}

#===============================================================================
# 配置向导
#===============================================================================

run_configuration_wizard() {
    print_header
    echo -e "${CYAN}开始配置向导...${NC}\n"

    # 配置 rclone
    configure_rclone

    # 配置 B站登录
    configure_bilibili_login

    # 测试配置
    test_configuration
}

configure_rclone() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  步骤 1/2: 配置 rclone 云盘${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # 检查是否已有 remote
    EXISTING_REMOTES=$(rclone listremotes 2>/dev/null | sed 's/:$//' || echo "")

    if [[ -n "$EXISTING_REMOTES" ]]; then
        print_info "检测到已有的 rclone remote:"
        echo "$EXISTING_REMOTES" | nl
        echo ""

        read -p "是否使用现有的 remote? (Y/n) " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            echo "请选择要使用的 remote (输入序号):"
            read -r REMOTE_NUM
            REMOTE_NAME=$(echo "$EXISTING_REMOTES" | sed -n "${REMOTE_NUM}p")

            if [[ -n "$REMOTE_NAME" ]]; then
                print_success "选择的 remote: $REMOTE_NAME"

                # 更新 config.json
                sed -i "s/\"remote\": \".*\"/\"remote\": \"$REMOTE_NAME\"/" "$INSTALL_DIR/config.json"

                # 询问备份路径
                read -p "请输入云盘中的备份路径 (默认: backup): " BACKUP_PATH
                BACKUP_PATH=${BACKUP_PATH:-backup}
                sed -i "s|\"backup_path\": \".*\"|\"backup_path\": \"$BACKUP_PATH\"|" "$INSTALL_DIR/config.json"

                return 0
            else
                print_warning "无效的选择，将创建新的 remote"
            fi
        fi
    fi

    # 创建新的 remote
    print_info "即将打开 rclone 配置界面..."
    print_info "常用云盘类型:"
    echo "  - 阿里云盘: 选择 WebDAV"
    echo "  - OneDrive: 选择 OneDrive"
    echo "  - Google Drive: 选择 Google Drive"
    echo "  - Dropbox: 选择 Dropbox"
    echo ""
    read -p "按 Enter 继续..."

    rclone config

    # 获取新创建的 remote
    EXISTING_REMOTES=$(rclone listremotes 2>/dev/null | sed 's/:$//' || echo "")
    if [[ -n "$EXISTING_REMOTES" ]]; then
        print_info "请选择刚才配置的 remote:"
        echo "$EXISTING_REMOTES" | nl
        read -r REMOTE_NUM
        REMOTE_NAME=$(echo "$EXISTING_REMOTES" | sed -n "${REMOTE_NUM}p")

        if [[ -n "$REMOTE_NAME" ]]; then
            print_success "选择的 remote: $REMOTE_NAME"
            sed -i "s/\"remote\": \".*\"/\"remote\": \"$REMOTE_NAME\"/" "$INSTALL_DIR/config.json"

            read -p "请输入云盘中的备份路径 (默认: backup): " BACKUP_PATH
            BACKUP_PATH=${BACKUP_PATH:-backup}
            sed -i "s|\"backup_path\": \".*\"|\"backup_path\": \"$BACKUP_PATH\"|" "$INSTALL_DIR/config.json"
        fi
    else
        print_warning "未检测到 remote，请稍后手动配置"
    fi
}

configure_bilibili_login() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  步骤 2/2: 登录 B站账号${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    cd "$INSTALL_DIR"

    # 检查是否已有 cookies.json
    if [[ -f "cookies.json" ]]; then
        print_info "检测到已有登录信息"
        read -p "是否重新登录? (y/N) " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过登录配置"
            return 0
        fi
    fi

    print_info "即将打开 biliup 登录界面..."
    print_info "推荐使用扫码登录（最简单安全）"
    echo ""
    read -p "按 Enter 继续..."

    /usr/local/bin/biliup login

    if [[ -f "cookies.json" ]]; then
        print_success "B站登录成功"
    else
        print_warning "未检测到登录信息，请稍后手动登录"
    fi
}

test_configuration() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  配置测试${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    cd "$INSTALL_DIR"

    # 测试 rclone
    print_info "测试 rclone 连接..."
    REMOTE_NAME=$(grep '"remote":' config.json | sed 's/.*"remote": "\(.*\)".*/\1/')
    BACKUP_PATH=$(grep '"backup_path":' config.json | sed 's/.*"backup_path": "\(.*\)".*/\1/')

    if rclone lsd "${REMOTE_NAME}:${BACKUP_PATH}" --max-depth 1 >/dev/null 2>&1; then
        print_success "rclone 连接测试成功"
    else
        print_warning "rclone 连接测试失败，请检查配置"
    fi

    # 测试 B站登录
    print_info "测试 B站登录状态..."
    if /usr/local/bin/biliup -u "$INSTALL_DIR/cookies.json" list --max-pages 1 >/dev/null 2>&1; then
        print_success "B站登录状态有效"
    else
        print_warning "B站登录状态无效，请重新登录"
    fi
}

#===============================================================================
# 设置服务
#===============================================================================

setup_systemd_service() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  systemd 服务配置${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    read -p "是否将工具设置为 systemd 服务? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "跳过服务配置"
        return 0
    fi

    print_info "创建 systemd 服务文件..."

    # 创建服务文件
    sudo tee /etc/systemd/system/biliup-uploader.service > /dev/null <<EOF
[Unit]
Description=Bilibili Uploader Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/bilibili_uploader.py
Restart=on-failure
RestartSec=10
StandardOutput=append:${INSTALL_DIR}/upload.log
StandardError=append:${INSTALL_DIR}/upload.log

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd
    sudo systemctl daemon-reload

    print_success "服务文件创建成功"

    # 询问是否启用开机自启
    read -p "是否启用开机自启动? (Y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        sudo systemctl enable biliup-uploader
        print_success "已启用开机自启动"
    fi

    print_info "服务管理命令:"
    echo "  启动服务: sudo systemctl start biliup-uploader"
    echo "  停止服务: sudo systemctl stop biliup-uploader"
    echo "  查看状态: sudo systemctl status biliup-uploader"
    echo "  查看日志: tail -f ${INSTALL_DIR}/upload.log"
}

#===============================================================================
# 创建便捷脚本
#===============================================================================

create_convenience_scripts() {
    print_info "创建便捷命令..."

    # 确保脚本可执行
    chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

    # 创建符号链接到 PATH
    if [[ -d "$HOME/.local/bin" ]]; then
        BIN_DIR="$HOME/.local/bin"
    elif [[ -d "$HOME/bin" ]]; then
        BIN_DIR="$HOME/bin"
    else
        BIN_DIR="$HOME/.local/bin"
        mkdir -p "$BIN_DIR"
    fi

    # 添加到 PATH（如果需要）
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$HOME/.bashrc"
        export PATH="$PATH:$BIN_DIR"
    fi

    # 创建快捷命令
    ln -sf "$INSTALL_DIR/run.sh" "$BIN_DIR/biliup-start" 2>/dev/null || true

    print_success "便捷命令创建完成"
    print_info "可以使用 'biliup-start' 命令启动程序"
}

#===============================================================================
# 主安装流程
#===============================================================================

main() {
    print_header

    # 检查
    check_root
    detect_os
    detect_arch
    check_network

    # 安装依赖
    print_info "开始安装..."
    install_dependencies

    if ! check_python_version; then
        print_error "Python 版本不满足要求，请升级 Python"
        exit 1
    fi

    install_biliup

    # 创建项目
    create_project_structure
    install_python_dependencies

    # 配置向导
    echo ""
    read -p "是否运行配置向导? (Y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        run_configuration_wizard
    else
        print_info "跳过配置向导，请稍后手动配置"
        print_info "运行 './setup.sh' 可重新配置"
    fi

    # 设置服务
    setup_systemd_service

    # 创建便捷脚本
    create_convenience_scripts

    # 完成
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  安装完成！                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_success "项目目录: $INSTALL_DIR"
    print_info "使用说明:"
    echo "  1. 运行程序: cd $INSTALL_DIR && python3 bilibili_uploader.py"
    echo "  2. 或使用快捷命令: biliup-start"
    echo "  3. 重新配置: cd $INSTALL_DIR && ./setup.sh"
    echo "  4. 卸载: cd $INSTALL_DIR && ./uninstall.sh"
    echo ""
    print_info "更多信息请查看: $INSTALL_DIR/README.md"
    echo ""
}

# 执行主函数
main "$@"
