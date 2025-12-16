# ⚡ 快速开始指南

## 🎯 30 秒快速部署

### 步骤 1: 上传到 GitHub

将以下文件上传到你的 GitHub 仓库：

```
✅ install.sh           (必需)
✅ bilibili_uploader.py (必需)
📄 README.md            (推荐)
```

### 步骤 2: 用户一键安装

用户在新 VPS 上运行：

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

### 步骤 3: 配置和运行

```bash
cd ~/biliup
./setup.sh    # 配置 rclone 和 B站
./run.sh      # 启动程序
```

完成！🎉

---

## 📋 详细步骤

### 对于项目维护者

#### 1. 准备文件

```bash
cd /root/biliup

# 确保这些文件存在
ls -lh install.sh bilibili_uploader.py
```

#### 2. 上传到 GitHub

**方法 A: Web 界面**
1. 访问 https://github.com/new 创建新仓库
2. 点击 "Add file" → "Upload files"
3. 上传 `install.sh` 和 `bilibili_uploader.py`
4. 提交

**方法 B: Git 命令**
```bash
git init
git add install.sh bilibili_uploader.py README.md
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

#### 3. 更新 README

在 README.md 中添加：

```markdown
## 快速安装

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
\`\`\`
```

#### 4. 测试

在测试 VPS 上验证：

```bash
ssh root@test-vps
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

---

### 对于最终用户

#### 1. 一键安装

```bash
# SSH 连接到你的 VPS
ssh root@your-vps-ip

# 运行安装命令（复制粘贴整段）
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash
```

**等待 5-10 分钟** 自动完成：
- ✅ 安装系统依赖
- ✅ 安装 Python 包
- ✅ 下载主程序
- ✅ 创建辅助脚本

#### 2. 配置

```bash
cd ~/biliup
./setup.sh
```

按提示完成：
1. 配置 rclone 云盘
2. 登录 B站账号
3. 测试连接

#### 3. 运行

**交互式运行:**
```bash
./run.sh
# 或
python3 bilibili_uploader.py
```

**后台服务:**
```bash
sudo systemctl start biliup-uploader
sudo systemctl status biliup-uploader
```

---

## 🔧 常用命令

```bash
# 启动程序
cd ~/biliup && ./run.sh

# 重新配置
cd ~/biliup && ./setup.sh

# 查看日志
tail -f ~/biliup/upload.log

# 查看服务状态
sudo systemctl status biliup-uploader

# 卸载
cd ~/biliup && ./uninstall.sh
```

---

## 💡 常见场景

### 场景 1: 新 VPS 完全自动部署

```bash
# 1. SSH 连接
ssh root@vps-ip

# 2. 一键安装
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO bash

# 3. 配置
cd ~/biliup && ./setup.sh

# 4. 运行
./run.sh
```

### 场景 2: 使用自己的托管服务器

```bash
# 如果你已将文件托管到自己的域名
curl -fsSL https://biliup.yourdomain.com/install.sh | bash
```

### 场景 3: 自定义安装目录

```bash
# 安装到 /opt/biliup
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | \
  GITHUB_REPO=YOUR_USERNAME/YOUR_REPO \
  INSTALL_DIR=/opt/biliup \
  bash
```

---

## ❓ 故障排查

### 问题 1: bilibili_uploader.py 下载失败

**解决方法:**

```bash
# 手动下载后重新运行
cd ~/biliup
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/bilibili_uploader.py
./install.sh
```

### 问题 2: 权限错误

```bash
# 使用 root 用户
sudo su
# 然后重新运行安装命令
```

### 问题 3: Python 依赖安装失败

```bash
cd ~/biliup
pip3 install -r requirements.txt --break-system-packages
# 或
pip3 install --user -r requirements.txt
```

---

## 📚 完整文档

- **GITHUB_DEPLOYMENT.md** - GitHub 部署详细指南
- **SELF_CONTAINED_INSTALL.md** - 自包含安装技术说明
- **ROOT_USER_GUIDE.md** - Root 用户指南
- **HOSTING_SETUP.md** - 自托管服务器设置

---

## 🎉 成功标志

安装成功后你应该看到：

```
╔════════════════════════════════════════════════════════════╗
║                  安装完成！                               ║
╚════════════════════════════════════════════════════════════╝

项目目录: /root/biliup
使用说明:
  1. 运行程序: cd /root/biliup && python3 bilibili_uploader.py
  2. 或使用快捷命令: biliup-start
  3. 重新配置: cd /root/biliup && ./setup.sh
  4. 卸载: cd /root/biliup && ./uninstall.sh
```

然后运行 `cd ~/biliup && ls -la` 应该看到：

```
-rwxr-xr-x  bilibili_uploader.py
-rw-r--r--  config.json
-rwxr-xr-x  install.sh
-rw-r--r--  requirements.txt
-rwxr-xr-x  run.sh
-rwxr-xr-x  setup.sh
-rwxr-xr-x  uninstall.sh
drwxr-xr-x  temp/
```

完成！现在可以使用 `./setup.sh` 进行配置了。🚀
