#!/bin/bash
#===============================================================================
# Bilibili 录播自动上传工具 - 一键安装脚本
# 支持 Debian/Ubuntu/CentOS/RHEL/Fedora/Arch Linux
# 自包含版本 - 无需额外下载文件
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

# 下载源配置（可选）
# 如果通过 GitHub 下载，会自动检测并使用同一仓库
BILIBILI_UPLOADER_URL="${BILIBILI_UPLOADER_URL:-}"

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
        print_info "以 root 用户运行"
    else
        print_info "以普通用户运行"
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

create_requirements_file() {
    print_info "创建 requirements.txt..."

    cat > "$INSTALL_DIR/requirements.txt" <<'REQUIREMENTS_EOF'
questionary>=2.0.0
rich>=13.0.0
REQUIREMENTS_EOF

    print_success "requirements.txt 创建完成"
}

install_python_dependencies() {
    print_info "安装 Python 依赖..."

    cd "$INSTALL_DIR"

    # 创建 requirements.txt（自包含）
    create_requirements_file

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

create_shell_scripts() {
    print_info "创建辅助脚本..."

    cd "$INSTALL_DIR"

    # 创建 setup.sh
    cat > setup.sh <<'SETUP_EOF'
#!/bin/bash
#===============================================================================
# Bilibili 录播自动上传工具 - 配置向导
# 用于初次配置或重新配置 rclone 和 B站登录
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${CYAN}║  Bilibili 录播自动上传工具 - 配置向导                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    echo ""
    echo -e "${CYAN}请选择要配置的项目:${NC}"
    echo "  1) 配置 rclone 云盘"
    echo "  2) 登录 B站账号"
    echo "  3) 测试配置"
    echo "  4) 修改备份路径"
    echo "  5) 修改上传分区和标签"
    echo "  6) 全部重新配置"
    echo "  0) 退出"
    echo ""
    read -p "请输入选项 [0-6]: " choice

    case $choice in
        1) configure_rclone ;;
        2) configure_bilibili_login ;;
        3) test_configuration ;;
        4) modify_backup_path ;;
        5) modify_upload_settings ;;
        6) full_reconfigure ;;
        0) exit 0 ;;
        *) print_error "无效选项"; show_menu ;;
    esac
}

configure_rclone() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  配置 rclone 云盘${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # 检查是否已有 remote
    EXISTING_REMOTES=$(rclone listremotes 2>/dev/null | sed 's/:$//' || echo "")

    if [[ -n "$EXISTING_REMOTES" ]]; then
        print_info "检测到已有的 rclone remote:"
        echo "$EXISTING_REMOTES" | nl
        echo ""
        echo "  0) 创建新的 remote"
        echo ""

        read -p "请选择 remote (输入序号, 0=创建新的): " REMOTE_NUM

        if [[ "$REMOTE_NUM" == "0" ]]; then
            print_info "打开 rclone 配置界面..."
            rclone config
            # 重新获取列表
            EXISTING_REMOTES=$(rclone listremotes 2>/dev/null | sed 's/:$//' || echo "")
            if [[ -n "$EXISTING_REMOTES" ]]; then
                echo "请选择刚才配置的 remote:"
                echo "$EXISTING_REMOTES" | nl
                read -r REMOTE_NUM
            fi
        fi

        REMOTE_NAME=$(echo "$EXISTING_REMOTES" | sed -n "${REMOTE_NUM}p")

        if [[ -n "$REMOTE_NAME" ]]; then
            print_success "选择的 remote: $REMOTE_NAME"

            # 更新 config.json
            sed -i "s/\"remote\": \".*\"/\"remote\": \"$REMOTE_NAME\"/" "$SCRIPT_DIR/config.json"

            # 询问备份路径
            CURRENT_PATH=$(grep '"backup_path":' "$SCRIPT_DIR/config.json" | sed 's/.*"backup_path": "\(.*\)".*/\1/')
            read -p "请输入云盘中的备份路径 (当前: $CURRENT_PATH): " BACKUP_PATH
            BACKUP_PATH=${BACKUP_PATH:-$CURRENT_PATH}
            sed -i "s|\"backup_path\": \".*\"|\"backup_path\": \"$BACKUP_PATH\"|" "$SCRIPT_DIR/config.json"

            print_success "rclone 配置已更新"
        else
            print_warning "无效的选择"
        fi
    else
        print_info "未检测到 rclone remote，打开配置界面..."
        rclone config

        EXISTING_REMOTES=$(rclone listremotes 2>/dev/null | sed 's/:$//' || echo "")
        if [[ -n "$EXISTING_REMOTES" ]]; then
            print_info "请选择刚才配置的 remote:"
            echo "$EXISTING_REMOTES" | nl
            read -r REMOTE_NUM
            REMOTE_NAME=$(echo "$EXISTING_REMOTES" | sed -n "${REMOTE_NUM}p")

            if [[ -n "$REMOTE_NAME" ]]; then
                sed -i "s/\"remote\": \".*\"/\"remote\": \"$REMOTE_NAME\"/" "$SCRIPT_DIR/config.json"

                read -p "请输入云盘中的备份路径 (默认: backup): " BACKUP_PATH
                BACKUP_PATH=${BACKUP_PATH:-backup}
                sed -i "s|\"backup_path\": \".*\"|\"backup_path\": \"$BACKUP_PATH\"|" "$SCRIPT_DIR/config.json"

                print_success "rclone 配置已保存"
            fi
        fi
    fi

    show_menu
}

configure_bilibili_login() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  登录 B站账号${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    cd "$SCRIPT_DIR"

    if [[ -f "cookies.json" ]]; then
        print_info "检测到已有登录信息"
        read -p "是否重新登录? (Y/n) " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
            print_info "保持现有登录"
            show_menu
            return 0
        fi

        # 备份旧的 cookies
        mv cookies.json cookies.json.bak
        print_info "已备份旧的登录信息到 cookies.json.bak"
    fi

    print_info "打开 biliup 登录界面..."
    print_info "推荐使用扫码登录"
    echo ""

    if /usr/local/bin/biliup login; then
        if [[ -f "cookies.json" ]]; then
            print_success "B站登录成功"
            rm -f cookies.json.bak
        else
            print_error "登录失败"
            if [[ -f "cookies.json.bak" ]]; then
                mv cookies.json.bak cookies.json
                print_info "已恢复旧的登录信息"
            fi
        fi
    else
        print_error "登录过程出错"
        if [[ -f "cookies.json.bak" ]]; then
            mv cookies.json.bak cookies.json
            print_info "已恢复旧的登录信息"
        fi
    fi

    show_menu
}

test_configuration() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  配置测试${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    cd "$SCRIPT_DIR"

    # 测试 rclone
    print_info "测试 rclone 连接..."
    REMOTE_NAME=$(grep '"remote":' config.json | sed 's/.*"remote": "\(.*\)".*/\1/')
    BACKUP_PATH=$(grep '"backup_path":' config.json | sed 's/.*"backup_path": "\(.*\)".*/\1/')

    if [[ "$REMOTE_NAME" == "your_remote_name" ]]; then
        print_warning "rclone remote 未配置"
    else
        echo "  Remote: $REMOTE_NAME:$BACKUP_PATH"
        if rclone lsd "${REMOTE_NAME}:${BACKUP_PATH}" --max-depth 1 2>/dev/null; then
            print_success "rclone 连接正常，文件夹列表:"
            rclone lsd "${REMOTE_NAME}:${BACKUP_PATH}" --max-depth 1 | tail -5
        else
            print_error "rclone 连接失败"
            print_info "请检查: 1) remote 是否正确 2) 备份路径是否存在 3) 网络连接"
        fi
    fi

    echo ""

    # 测试 B站登录
    print_info "测试 B站登录状态..."
    if [[ ! -f "cookies.json" ]]; then
        print_warning "未找到登录信息 (cookies.json)"
    else
        if /usr/local/bin/biliup -u "$SCRIPT_DIR/cookies.json" list --max-pages 1 2>/dev/null >/dev/null; then
            print_success "B站登录状态有效"
            print_info "最近投稿:"
            /usr/local/bin/biliup -u "$SCRIPT_DIR/cookies.json" list --max-pages 1 | head -10
        else
            print_error "B站登录状态无效"
            print_info "请重新登录"
        fi
    fi

    show_menu
}

modify_backup_path() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  修改备份路径${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    CURRENT_PATH=$(grep '"backup_path":' "$SCRIPT_DIR/config.json" | sed 's/.*"backup_path": "\(.*\)".*/\1/')
    print_info "当前备份路径: $CURRENT_PATH"

    read -p "请输入新的备份路径: " NEW_PATH

    if [[ -n "$NEW_PATH" ]]; then
        sed -i "s|\"backup_path\": \".*\"|\"backup_path\": \"$NEW_PATH\"|" "$SCRIPT_DIR/config.json"
        print_success "备份路径已更新为: $NEW_PATH"

        # 测试新路径
        REMOTE_NAME=$(grep '"remote":' "$SCRIPT_DIR/config.json" | sed 's/.*"remote": "\(.*\)".*/\1/')
        print_info "测试新路径..."
        if rclone lsd "${REMOTE_NAME}:${NEW_PATH}" --max-depth 1 >/dev/null 2>&1; then
            print_success "新路径连接成功"
        else
            print_warning "无法连接到新路径，请确认路径是否存在"
        fi
    else
        print_info "已取消"
    fi

    show_menu
}

modify_upload_settings() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  修改上传分区和标签${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    CURRENT_TID=$(grep '"default_tid":' "$SCRIPT_DIR/config.json" | sed 's/.*"default_tid": \(.*\),/\1/')
    print_info "当前默认分区: $CURRENT_TID"

    print_info "常用分区ID:"
    echo "  171 - 虚拟主播日常"
    echo "  17  - 单机游戏"
    echo "  65  - 网络游戏"
    echo "  136 - 生活·日常"
    echo "  27  - 综合"
    echo ""

    read -p "请输入新的分区ID (直接回车跳过): " NEW_TID

    if [[ -n "$NEW_TID" ]]; then
        sed -i "s/\"default_tid\": .*/\"default_tid\": $NEW_TID,/" "$SCRIPT_DIR/config.json"
        print_success "分区已更新为: $NEW_TID"
    fi

    read -p "是否修改默认标签? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "请输入标签 (逗号分隔，如: 录播,虚拟主播,游戏)"
        read -p "标签: " NEW_TAGS

        if [[ -n "$NEW_TAGS" ]]; then
            # 将逗号分隔的字符串转换为 JSON 数组
            TAG_ARRAY=$(echo "$NEW_TAGS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')
            sed -i "s/\"default_tags\": \[.*\]/\"default_tags\": [$TAG_ARRAY]/" "$SCRIPT_DIR/config.json"
            print_success "标签已更新"
        fi
    fi

    show_menu
}

full_reconfigure() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  全部重新配置${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    print_warning "这将重新配置所有设置"
    read -p "确定要继续吗? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        show_menu
        return 0
    fi

    configure_rclone
    configure_bilibili_login
    test_configuration
}

main() {
    print_header

    # 检查必要的命令
    for cmd in rclone; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd 未安装"
            print_info "请先运行 install.sh 安装"
            exit 1
        fi
    done

    if [[ ! -f "/usr/local/bin/biliup" ]]; then
        print_error "biliup 未安装"
        print_info "请先运行 install.sh 安装"
        exit 1
    fi

    # 检查配置文件
    if [[ ! -f "$SCRIPT_DIR/config.json" ]]; then
        print_error "配置文件不存在: config.json"
        exit 1
    fi

    show_menu
}

main "$@"
SETUP_EOF

    # 创建 run.sh
    cat > run.sh <<'RUN_EOF'
#!/bin/bash
#===============================================================================
# Bilibili 录播自动上传工具 - 快速启动脚本
#===============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    local missing_deps=()

    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi

    if ! command -v rclone &> /dev/null; then
        missing_deps+=("rclone")
    fi

    if ! command -v ffmpeg &> /dev/null; then
        missing_deps+=("ffmpeg")
    fi

    if [[ ! -f "/usr/local/bin/biliup" ]]; then
        missing_deps+=("biliup")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "缺少依赖: ${missing_deps[*]}"
        print_info "请先运行 install.sh 安装依赖"
        exit 1
    fi
}

# 检查配置
check_config() {
    if [[ ! -f "$SCRIPT_DIR/config.json" ]]; then
        print_error "配置文件不存在: config.json"
        print_info "请先运行 setup.sh 进行配置"
        exit 1
    fi

    # 检查是否已配置 remote
    REMOTE_NAME=$(grep '"remote":' "$SCRIPT_DIR/config.json" | sed 's/.*"remote": "\(.*\)".*/\1/')
    if [[ "$REMOTE_NAME" == "your_remote_name" ]]; then
        print_error "rclone remote 未配置"
        print_info "请先运行 setup.sh 进行配置"
        exit 1
    fi

    # 检查是否已登录 B站
    if [[ ! -f "$SCRIPT_DIR/cookies.json" ]]; then
        print_error "未找到 B站 登录信息"
        print_info "请先运行 setup.sh 登录 B站账号"
        exit 1
    fi
}

# 主函数
main() {
    cd "$SCRIPT_DIR"

    print_info "启动 Bilibili 录播自动上传工具..."

    # 检查
    check_dependencies
    check_config

    print_success "环境检查通过"

    # 启动主程序
    python3 bilibili_uploader.py
}

main "$@"
RUN_EOF

    # 创建 uninstall.sh
    cat > uninstall.sh <<'UNINSTALL_EOF'
#!/bin/bash
#===============================================================================
# Bilibili 录播自动上传工具 - 卸载脚本
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${CYAN}║  Bilibili 录播自动上传工具 - 卸载程序                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

confirm_uninstall() {
    echo -e "${YELLOW}警告: 这将卸载 Bilibili 录播自动上传工具${NC}\n"

    echo "将执行以下操作:"
    echo "  - 停止并删除 systemd 服务（如果存在）"
    echo "  - 删除快捷命令"
    echo "  - 删除项目文件（可选）"
    echo ""

    read -p "确定要继续吗? (yes/NO) " -r
    echo

    if [[ ! $REPLY == "yes" ]]; then
        print_info "已取消卸载"
        exit 0
    fi
}

stop_service() {
    print_info "停止 systemd 服务..."

    if systemctl is-active --quiet biliup-uploader 2>/dev/null; then
        sudo systemctl stop biliup-uploader
        print_success "服务已停止"
    fi

    if systemctl is-enabled --quiet biliup-uploader 2>/dev/null; then
        sudo systemctl disable biliup-uploader
        print_success "已禁用开机自启"
    fi

    if [[ -f "/etc/systemd/system/biliup-uploader.service" ]]; then
        sudo rm /etc/systemd/system/biliup-uploader.service
        sudo systemctl daemon-reload
        print_success "服务文件已删除"
    fi
}

remove_shortcuts() {
    print_info "删除快捷命令..."

    for bin_dir in "$HOME/.local/bin" "$HOME/bin"; do
        if [[ -L "$bin_dir/biliup-start" ]]; then
            rm "$bin_dir/biliup-start"
            print_success "已删除: $bin_dir/biliup-start"
        fi
    done
}

remove_biliup() {
    read -p "是否卸载 biliup-rs? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f "/usr/local/bin/biliup" ]]; then
            sudo rm /usr/local/bin/biliup
            print_success "biliup-rs 已卸载"
        fi
    else
        print_info "保留 biliup-rs"
    fi
}

remove_system_deps() {
    read -p "是否卸载系统依赖 (rclone, ffmpeg)? (y/N) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "请根据你的系统类型手动卸载:"
        echo "  Debian/Ubuntu: sudo apt-get remove rclone ffmpeg"
        echo "  CentOS/RHEL:   sudo yum remove rclone ffmpeg"
        echo "  Arch Linux:    sudo pacman -R rclone ffmpeg"
    else
        print_info "保留系统依赖"
    fi
}

remove_project_files() {
    echo ""
    print_warning "项目文件位于: $SCRIPT_DIR"

    echo ""
    echo "文件删除选项:"
    echo "  1) 删除所有文件（包括配置和历史记录）"
    echo "  2) 仅删除程序文件，保留配置和历史记录"
    echo "  3) 不删除任何文件"
    echo ""

    read -p "请选择 [1-3]: " -n 1 -r
    echo

    case $REPLY in
        1)
            print_warning "即将删除所有文件，包括:"
            echo "  - config.json (配置文件)"
            echo "  - cookies.json (B站登录信息)"
            echo "  - upload_history.json (上传历史)"
            echo "  - failed_uploads.json (失败记录)"
            echo "  - upload.log (日志文件)"
            echo ""

            read -p "确认删除所有文件? (yes/NO) " -r
            echo

            if [[ $REPLY == "yes" ]]; then
                cd "$HOME"
                rm -rf "$SCRIPT_DIR"
                print_success "所有文件已删除"
            else
                print_info "已取消删除"
            fi
            ;;
        2)
            print_info "保留配置和历史记录，删除程序文件..."

            # 备份重要文件
            mkdir -p "$SCRIPT_DIR.backup"
            for file in config.json cookies.json upload_history.json failed_uploads.json upload.log; do
                if [[ -f "$SCRIPT_DIR/$file" ]]; then
                    mv "$SCRIPT_DIR/$file" "$SCRIPT_DIR.backup/"
                fi
            done

            # 删除项目目录
            rm -rf "$SCRIPT_DIR"

            # 恢复备份文件
            mv "$SCRIPT_DIR.backup" "$SCRIPT_DIR"

            print_success "程序文件已删除，配置和历史已保留在: $SCRIPT_DIR"
            ;;
        3)
            print_info "保留所有文件"
            ;;
        *)
            print_info "无效选项，保留所有文件"
            ;;
    esac
}

main() {
    print_header

    confirm_uninstall

    # 停止服务
    stop_service

    # 删除快捷命令
    remove_shortcuts

    # 卸载 biliup
    remove_biliup

    # 卸载系统依赖
    remove_system_deps

    # 删除项目文件
    remove_project_files

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  卸载完成！                               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ -d "$SCRIPT_DIR" ]]; then
        print_info "保留的文件位于: $SCRIPT_DIR"
    fi
}

main "$@"
UNINSTALL_EOF

    # 设置执行权限
    chmod +x setup.sh run.sh uninstall.sh

    print_success "辅助脚本创建完成"
}

detect_github_source() {
    # 检测脚本是否从 GitHub 下载
    # 通过检查环境变量或者进程信息来判断

    # 方法 1: 检查 DOWNLOAD_URL 环境变量（curl 设置）
    if [[ -n "$DOWNLOAD_URL" ]] && [[ "$DOWNLOAD_URL" == *"github"* ]]; then
        echo "$DOWNLOAD_URL"
        return 0
    fi

    # 方法 2: 检查 curl 的 User-Agent 或 Referer
    # 这个方法在 curl | bash 时不太可靠，但可以作为备选

    # 方法 3: 让用户通过环境变量指定
    if [[ -n "$GITHUB_REPO" ]]; then
        echo "https://raw.githubusercontent.com/${GITHUB_REPO}/main/bilibili_uploader.py"
        return 0
    fi

    return 1
}

create_bilibili_uploader() {
    print_info "创建主程序 bilibili_uploader.py..."

    cd "$INSTALL_DIR"

    # 如果当前目录已有 bilibili_uploader.py，保留它
    if [[ -f "bilibili_uploader.py" ]]; then
        print_success "检测到现有的 bilibili_uploader.py，保留使用"
        return 0
    fi

    # 尝试从多个源下载
    local download_success=false
    local download_urls=()

    # 1. 优先使用用户指定的 URL
    if [[ -n "$BILIBILI_UPLOADER_URL" ]]; then
        print_info "使用自定义 URL: $BILIBILI_UPLOADER_URL"
        download_urls+=("$BILIBILI_UPLOADER_URL")
    fi

    # 2. 检测 GitHub 源
    local github_url=$(detect_github_source)
    if [[ -n "$github_url" ]]; then
        print_info "检测到 GitHub 源"
        download_urls+=("$github_url")
    fi

    # 3. 如果设置了 GITHUB_REPO 环境变量
    if [[ -n "$GITHUB_REPO" ]]; then
        download_urls+=("https://raw.githubusercontent.com/${GITHUB_REPO}/main/bilibili_uploader.py")
        download_urls+=("https://raw.githubusercontent.com/${GITHUB_REPO}/master/bilibili_uploader.py")
    fi

    # 4. 如果设置了 BILIUP_HOST（自托管）
    if [[ -n "$BILIUP_HOST" ]]; then
        download_urls+=("${BILIUP_HOST}/bilibili_uploader.py")
    fi

    # 如果没有任何下载源，提示用户
    if [[ ${#download_urls[@]} -eq 0 ]]; then
        print_warning "未检测到 bilibili_uploader.py 下载源"
        print_info "请选择以下方法之一:"
        echo ""
        echo "  方法 1: 设置 GitHub 仓库（推荐）"
        echo "    export GITHUB_REPO=your-username/your-repo"
        echo "    然后重新运行 install.sh"
        echo ""
        echo "  方法 2: 直接指定下载 URL"
        echo "    export BILIBILI_UPLOADER_URL=https://your-url.com/bilibili_uploader.py"
        echo "    然后重新运行 install.sh"
        echo ""
        echo "  方法 3: 手动下载后放置"
        echo "    将 bilibili_uploader.py 复制到: $INSTALL_DIR/"
        echo "    然后重新运行 install.sh"
        echo ""
        echo "  方法 4: 从 GitHub 一键安装（推荐）"
        echo "    curl -fsSL https://raw.githubusercontent.com/your-username/your-repo/main/install.sh | GITHUB_REPO=your-username/your-repo bash"
        echo ""
        return 0
    fi

    # 尝试每个 URL
    for url in "${download_urls[@]}"; do
        print_info "尝试从 $url 下载..."
        if curl -fsSL "$url" -o bilibili_uploader.py 2>/dev/null; then
            # 验证文件是否有效（至少包含 Python 关键字）
            if head -100 bilibili_uploader.py | grep -q "import\|def\|class" 2>/dev/null; then
                # 进一步验证文件大小（应该大于 10KB）
                local file_size=$(wc -c < bilibili_uploader.py)
                if [[ $file_size -gt 10000 ]]; then
                    print_success "bilibili_uploader.py 下载成功 ($(numfmt --to=iec $file_size))"
                    download_success=true
                    break
                else
                    print_warning "下载的文件过小 ($file_size bytes)，可能不是有效的 Python 文件"
                    rm -f bilibili_uploader.py
                fi
            else
                print_warning "下载的文件不是有效的 Python 文件，尝试下一个源..."
                rm -f bilibili_uploader.py
            fi
        else
            print_warning "下载失败，尝试下一个源..."
        fi
    done

    if [[ "$download_success" == "false" ]]; then
        print_error "bilibili_uploader.py 自动下载失败"
        echo ""
        print_info "尝试的 URL:"
        for url in "${download_urls[@]}"; do
            echo "  - $url"
        done
        echo ""
        print_info "解决方法:"
        echo ""
        echo "  1. 确认你的 GitHub 仓库中包含 bilibili_uploader.py"
        echo "  2. 使用正确的仓库名重试:"
        echo "     curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash"
        echo ""
        echo "  3. 或者手动下载后继续:"
        echo "     cd $INSTALL_DIR"
        echo "     curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bilibili_uploader.py"
        echo ""

        # 不失败，让用户可以稍后手动添加
        return 0
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
    create_shell_scripts
    create_bilibili_uploader
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
