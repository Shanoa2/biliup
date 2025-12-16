# 🚀 GitHub 一键部署指南

## 目标

通过 GitHub 托管项目，让任何人可以通过**一条命令**在新 VPS 上部署运行。

## 📦 准备工作

### 1. 需要上传到 GitHub 的文件

将以下文件上传到你的 GitHub 仓库：

```
your-repo/
├── install.sh                # 自包含安装脚本（必需）
├── bilibili_uploader.py      # 主程序（必需）
├── README.md                 # 项目说明（推荐）
├── config.json.template      # 配置模板（可选）
└── *.md                      # 其他文档（可选）
```

**最少只需要 2 个文件:**
- ✅ `install.sh` - 自包含安装脚本
- ✅ `bilibili_uploader.py` - 主程序

## 🌐 部署到 GitHub

### 方法 1: 通过 Web 界面上传

1. 在 GitHub 创建新仓库（例如: `your-username/biliup`）
2. 点击 "Add file" → "Upload files"
3. 上传 `install.sh` 和 `bilibili_uploader.py`
4. 提交更改

### 方法 2: 通过 Git 命令

```bash
# 在项目目录中
cd /root/biliup

# 初始化 Git（如果还没有）
git init

# 添加远程仓库
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 添加必要文件
git add install.sh bilibili_uploader.py README.md

# 提交
git commit -m "Initial commit: 添加一键安装脚本"

# 推送到 GitHub
git branch -M main
git push -u origin main
```

## 🎯 使用方法

部署完成后，用户可以通过以下方式安装：

### 方法 1: 完全自动（推荐）

```bash
# 将 YOUR_USERNAME/YOUR_REPO 替换为你的实际仓库名
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

**工作原理:**
- 下载 install.sh 并执行
- `GITHUB_REPO` 环境变量告诉脚本从哪里下载 bilibili_uploader.py
- 自动完成所有依赖和配置

### 方法 2: 分步安装

```bash
# 1. 设置仓库环境变量
export GITHUB_REPO=YOUR_USERNAME/YOUR_REPO

# 2. 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash
```

### 方法 3: 本地下载后安装

```bash
# 1. 下载安装脚本
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh

# 2. 设置权限
chmod +x install.sh

# 3. 运行（会自动提示如何下载 bilibili_uploader.py）
./install.sh

# 4. 如果需要，手动下载主程序
cd ~/biliup
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bilibili_uploader.py
```

## 📝 完整示例

假设你的 GitHub 用户名是 `zhangsan`，仓库名是 `bilibili-uploader`：

### 1. 创建 GitHub 仓库

- 访问 https://github.com/new
- Repository name: `bilibili-uploader`
- Public（公开）
- 创建仓库

### 2. 上传文件

```bash
cd /root/biliup

# 初始化并推送
git init
git add install.sh bilibili_uploader.py README.md
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/zhangsan/bilibili-uploader.git
git push -u origin main
```

### 3. 用户一键安装

其他用户现在可以通过以下命令安装：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangsan/bilibili-uploader/main/install.sh | \
  GITHUB_REPO=zhangsan/bilibili-uploader bash
```

## 🔧 高级用法

### 自定义分支

如果你使用 `master` 分支而不是 `main`：

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/master/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

### 指定特定版本/标签

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/v1.0.0/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

### 自定义安装目录

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO \
  INSTALL_DIR=/opt/biliup \
  bash
```

## 📚 在 README 中提供安装说明

在你的 `README.md` 中添加：

```markdown
## 🚀 快速安装

在新 VPS 上一键安装：

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
\`\`\`

安装完成后：

\`\`\`bash
# 配置
cd ~/biliup
./setup.sh

# 运行
./run.sh
# 或
python3 bilibili_uploader.py
\`\`\`

## 系统要求

- Linux 系统（Debian/Ubuntu/CentOS/Arch 等）
- Python 3.8+
- 网络连接
```

## 🎨 美化你的安装命令

### 短链接版本

使用 GitHub 的短链接或者自定义域名：

```bash
# 使用 git.io 短链接（GitHub 官方）
curl -L https://git.io/your-short-link | bash

# 或使用自己的域名
curl -fsSL https://install.yourdomain.com/biliup.sh | bash
```

### 创建安装脚本包装器

创建一个简短的包装脚本 `quick-install.sh`：

```bash
#!/bin/bash
export GITHUB_REPO=YOUR_USERNAME/YOUR_REPO
curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash
```

用户只需要：
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/quick-install.sh | bash
```

## ✅ 测试部署

在部署到 GitHub 后，在一台新的 VPS 上测试：

```bash
# 1. 连接到测试 VPS
ssh root@test-vps-ip

# 2. 运行一键安装命令
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash

# 3. 验证安装
cd ~/biliup
ls -la
# 应该看到所有必要文件

# 4. 测试运行
./setup.sh  # 配置
./run.sh    # 运行（会提示配置）
```

## 🔒 私有仓库支持

如果你的仓库是私有的，需要使用 Personal Access Token：

```bash
# 1. 在 GitHub 创建 Personal Access Token
#    Settings → Developer settings → Personal access tokens → Generate new token
#    至少需要 'repo' 权限

# 2. 使用 token 下载
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO \
  GITHUB_TOKEN=YOUR_GITHUB_TOKEN \
  bash
```

## 📊 优缺点对比

### GitHub 托管

**优点:**
- ✅ 免费
- ✅ 全球 CDN 加速
- ✅ 版本控制
- ✅ 无需自己的服务器
- ✅ 社区可见性高

**缺点:**
- ❌ 需要 GitHub 账号
- ❌ 公开仓库所有人可见
- ❌ raw.githubusercontent.com 在某些地区可能较慢

### 自托管（VPS）

**优点:**
- ✅ 完全控制
- ✅ 可以是私有的
- ✅ 可能更快（如果服务器位置好）
- ✅ 可以自定义域名

**缺点:**
- ❌ 需要维护服务器
- ❌ 有成本
- ❌ 需要配置 Web 服务器

### 推荐策略

**最佳实践:**
1. ✅ **GitHub 作为主要源** - 方便、免费、版本控制
2. ✅ **自托管作为备选** - 提供更快的国内访问
3. ✅ **支持两种方式** - 给用户选择权

## 🌟 最终用户体验

用户在新 VPS 上的完整操作流程：

```bash
# 1. SSH 连接到 VPS
ssh root@vps-ip

# 2. 一键安装（5-10 分钟）
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash

# 3. 配置（2-3 分钟）
cd ~/biliup
./setup.sh
# 选择: 配置 rclone → 登录 B站

# 4. 运行
./run.sh
# 或设置为服务
sudo systemctl start biliup-uploader

# 完成！
```

**总时间:** 10-15 分钟（大部分时间是自动的）

## 🎯 总结

### 需要做的事情

1. ✅ 将 `install.sh` 和 `bilibili_uploader.py` 上传到 GitHub
2. ✅ 在 README 中提供一键安装命令
3. ✅ 测试安装流程

### 用户只需要做的事情

```bash
# 复制粘贴这一条命令
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

就这么简单！🎉
