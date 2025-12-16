# B站录播自动上传工具

## 项目概述

这是一个用于将 rclone 云盘中的直播录播视频自动上传到 B站 的命令行工具。支持批量上传、分P管理、大文件自动切割、断点续传等功能。

## 🚀 快速开始（一键安装）

### ✨ 真正的一键安装

install.sh 现已完全自包含！无需下载多个文件，一条命令即可完成安装。

**从 GitHub 安装（推荐）:**

```bash
curl -fsSL https://raw.githubusercontent.com/Shanoa2/biliup/main/install.sh | \
  GITHUB_REPO=Shanoa2/biliup bash
```

<details>
<summary>📖 点击查看详细说明</summary>

**完整示例:**
假设你的 GitHub 用户名是 `zhangsan`，仓库名是 `bilibili-uploader`：

```bash
curl -fsSL https://raw.githubusercontent.com/zhangsan/bilibili-uploader/main/install.sh | \
  GITHUB_REPO=zhangsan/bilibili-uploader bash
```

**工作原理:**
1. 从 GitHub 下载 install.sh
2. 通过 `GITHUB_REPO` 环境变量自动下载 bilibili_uploader.py
3. 安装所有依赖并配置环境
4. 引导完成 rclone 和 B站 配置

**GitHub 部署指南:** 查看 [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md) 了解如何将项目部署到 GitHub。
</details>

**从自托管服务器安装:**

```bash
# 使用你自己的域名（需要先部署到 VPS）
curl -fsSL https://biliup.yourdomain.com/install.sh | bash
```

**其他安装方式:**

```bash
# 自定义主程序来源
export BILIBILI_UPLOADER_URL=https://your-host.com/bilibili_uploader.py
curl -fsSL https://raw.githubusercontent.com/Shanoa2/biliup/main/install.sh | bash

# 使用 wget
wget -qO- https://raw.githubusercontent.com/Shanoa2/biliup/main/install.sh | \
  GITHUB_REPO=Shanoa2/biliup bash
```

### 本地安装（如果已有项目文件）

```bash
cd ~/biliup
chmod +x install.sh
./install.sh
```

安装脚本将自动完成：
- ✅ 检测系统类型并安装依赖（rclone, ffmpeg, biliup-rs）
- ✅ 配置 Python 环境
- ✅ **自动生成所有辅助脚本**（setup.sh, run.sh, uninstall.sh）
- ✅ **自动创建 requirements.txt**
- ✅ **智能下载 bilibili_uploader.py**（支持多源）
- ✅ 创建项目结构
- ✅ 交互式配置 rclone 云盘
- ✅ 引导登录 B站账号
- ✅ 设置 systemd 服务（可选）
- ✅ 创建快捷命令
- ✅ **完全支持 root 用户**（无警告）

### 支持的系统

- ✅ Debian / Ubuntu
- ✅ CentOS / RHEL / Fedora / Rocky / AlmaLinux
- ✅ Arch Linux / Manjaro
- ✅ Alpine Linux
- ✅ 其他 Linux 发行版（通用模式）

### 快速命令

安装完成后：

```bash
# 启动程序
biliup-start
# 或
cd ~/biliup && python3 bilibili_uploader.py

# 重新配置
cd ~/biliup && ./setup.sh

# 查看服务状态（如果设置了服务）
sudo systemctl status biliup-uploader

# 卸载
cd ~/biliup && ./uninstall.sh
```

### 🌐 托管到你自己的 VPS（推荐）

如果你有自己的 VPS 和域名，可以将安装脚本托管到自己的服务器上，实现真正的一键安装：

```bash
# 1. 在你的 VPS 上部署项目
cd /root/biliup
sudo ./deploy-to-hosting.sh

# 2. 在 NPM 中配置域名
#    Domain: biliup.yourdomain.com
#    Forward to: localhost:8088
#    启用 SSL

# 3. 其他用户就可以通过你的域名一键安装
curl -fsSL https://biliup.yourdomain.com/install.sh | bash
```

**优势:**
- ✅ 无需依赖 GitHub
- ✅ 更快的下载速度
- ✅ 完全控制安装源
- ✅ 可以自定义安装脚本

详细托管配置请参考: [HOSTING_SETUP.md](HOSTING_SETUP.md) 和 [QUICK_HOSTING_REFERENCE.md](QUICK_HOSTING_REFERENCE.md)

### 📝 自包含安装说明

install.sh 现已完全自包含，内部嵌入了所有必要的辅助脚本：

- ✅ **requirements.txt** - 自动生成 Python 依赖列表
- ✅ **setup.sh** - 完整的配置向导（350+ 行）
- ✅ **run.sh** - 快速启动脚本
- ✅ **uninstall.sh** - 完整的卸载程序（210+ 行）
- ✅ **config.json** - 默认配置模板

**bilibili_uploader.py 智能下载:**
- 优先从环境变量 `BILIBILI_UPLOADER_URL` 下载
- 自动检测并从同源服务器下载
- 如果本地已有则保留使用
- 下载失败会提供详细的手动安装说明

详细说明请参考: [SELF_CONTAINED_INSTALL.md](SELF_CONTAINED_INSTALL.md)

## 功能特性

- ✅ 交互式可视化终端界面
- ✅ 支持浏览云盘文件夹和视频列表
- ✅ 支持上传新视频或为现有视频添加分P
- ✅ 支持单个/批量/全部上传
- ✅ 自动提取视频第一帧作为封面
- ✅ 超过15GB的视频自动切割
- ✅ 智能空间管理（本地硬盘空间不足时自动下载-上传-删除）
- ✅ 上传记录和详细日志
- ✅ 断点续传和失败重试机制
- ✅ 依赖自动检查和安装

## 系统要求

- Python 3.8+
- rclone（已配置好云盘）
- biliup CLI（/usr/local/bin/biliup，已完成登录）
- ffmpeg（视频处理）
- 足够的本地硬盘空间（建议至少20GB）

## 项目结构

```
/root/biliup/
├── README.md                    # 项目文档
├── bilibili_uploader.py         # 主脚本
├── config.json                  # 配置文件
├── upload_history.json          # 上传历史记录
├── failed_uploads.json          # 失败记录
├── upload.log                   # 详细日志
└── temp/                        # 临时文件目录
    ├── downloads/               # 视频下载缓存
    └── covers/                  # 封面图片缓存
```

## 配置说明

`config.json` 配置文件示例：

```json
{
  "rclone": {
    "remote": "lubo",
    "backup_path": "backup",
    "mount_point": "/tmp/bili_rclone_mount"
  },
  "bilibili": {
    "default_tid": 171,
    "default_tags": ["录播", "虚拟主播"],
    "source_template": "https://live.bilibili.com/{streamer_id}",
    "desc_template": "{streamer_name}的直播录播\\n录制时间：{date}\\n\\n本视频由自动化工具上传"
  },
  "upload": {
    "max_file_size_gb": 15,
    "retry_times": 3,
    "local_cache_path": "/root/biliup/temp",
    "min_free_space_gb": 5
  },
  "cover": {
    "extract_time_sec": 1,
    "output_format": "jpg",
    "quality": 85
  },
  "biliup_cli": {
    "executable": "/usr/local/bin/biliup",
    "cookie_file": "/root/biliup/cookies.json",
    "default_submit": "client",
    "proxy": null
  }
}
```

## 使用流程

### 1. 启动脚本

```bash
python3 bilibili_uploader.py
```

### 2. 选择操作模式

- **配置网络代理**：设置/清除 HTTP、SOCKS5 代理（支持输入用户名/密码），提高跨区上传稳定性
- **上传新视频**：创建新的B站投稿
- **添加分P**：为现有视频添加新的分P
- **校验上传记录**：检查历史 BV 号是否有效，移除失败记录，便于重新上传
- **登录B站账号**：通过 biliup CLI 完成登录/刷新 cookie

### 3. 选择主播文件夹

- 显示云盘中所有主播文件夹
- 显示每个文件夹的视频数量和总大小
- 支持搜索和筛选

### 4. 选择上传方式

- **上传全部视频**：上传该文件夹下所有 .flv 视频
- **选择特定视频**：手动选择要上传的视频（支持多选）

### 5. 确认上传

- 显示待上传视频列表
- 显示预估上传时间和所需空间
- 确认后开始上传

### 6. 上传过程

- 实时显示上传进度
- 自动处理大文件切割
- 自动提取封面
- 失败自动重试

## 核心功能说明

### 视频切割逻辑

对于超过15GB的视频：
1. 计算需要切割的段数：`段数 = ceil(文件大小 / 14.5GB)`
2. 计算每段时长：`每段时长 = 总时长 / 段数`
3. 使用 ffmpeg 按时间切割（避免重新编码）

### 空间管理策略

1. 检查本地可用空间
2. 如果视频 ≤ 15GB 且挂载点可用，尝试直接从挂载点上传
3. 如果需要下载：
   - 检查空间是否足够（视频大小 + 5GB 余量）
   - 不足则提示用户清理空间或跳过
4. 上传完成后立即删除本地缓存

### 断点续传机制

- 每次成功上传后立即写入 `upload_history.json`
- 记录格式：
  ```json
  {
    "file_path": "backup/主播名/视频文件.flv",
    "bvid": "BV1xxxxxxxxx",
    "upload_time": "2025-10-28 15:30:00",
    "file_size": 8670013105,
    "is_split": false,
    "parts": []
  }
  ```

### 失败重试机制

- 每个视频最多重试3次
- 失败后记录到 `failed_uploads.json`
- 可选择稍后重新上传失败的视频

## 文件命名解析

录播文件命名格式：`录制-{主播ID}-{日期}-{时间}-{序号}-{标题}.flv`

示例：`录制-1896165591-20251027-225956-152-【3D.cos】孤独摇滚 山田凉COS.flv`

解析结果：
- 主播ID：1896165591
- 日期：2025-10-27
- 时间：22:59:56
- 标题：【3D.cos】孤独摇滚 山田凉COS

## 上传参数

默认上传参数：
- **分区(tid)**：171（虚拟主播日常）
- **标签(tag)**：主播名称 + 录播 + 虚拟主播
- **转载来源**：https://live.bilibili.com/{主播ID}
- **标题**：视频文件中的标题部分
- **描述**：根据模板自动生成
- **封面**：自动提取视频第一帧

## 日志查看

```bash
# 查看详细日志
tail -f /root/biliup/upload.log

# 查看上传历史
cat /root/biliup/upload_history.json

# 查看失败记录
cat /root/biliup/failed_uploads.json
```

## 常见问题

### Q: 上传失败怎么办？
A: 脚本会自动重试3次，如果仍然失败会记录到 `failed_uploads.json`，可以稍后重新运行脚本选择重试失败的上传。

### Q: 如何跳过已上传的视频？
A: 脚本会自动检查 `upload_history.json`，已上传的视频会自动跳过。

### Q: 之前使用 bilitool 失败的稿件如何重新上传？
A: 在主菜单选择“校验上传记录”即可清理失效的历史记录（会检测 BV 号是否仍存在）。被移除的项目会写入 `failed_uploads.json`，随后再次执行上传流程即可重新提交。

### Q: 如何配置代理提升上传速度？
A: 主菜单选择“配置网络代理”可设置或清除 HTTP/SOCKS5 代理，支持输入 `host:port` 或带用户名/密码的完整 URL。配置会写入 `config.json` 的 `biliup_cli.proxy` 字段，后续所有上传命令都会自动带上 `-p` 参数。

### Q: 硬盘空间不足怎么办？
A: 脚本会自动检测，如果空间不足会提示你清理空间或跳过当前视频。

### Q: 如何修改默认上传参数？
A: 编辑 `config.json` 文件中的 `bilibili` 配置项。

### Q: 可以中断上传吗？
A: 可以使用 Ctrl+C 中断，下次运行时会从断点继续（已上传的视频不会重复上传）。

## 注意事项

1. 请确保 biliup CLI 已经登录（运行 `/usr/local/bin/biliup login` 完成授权，可用 `/usr/local/bin/biliup list --max-pages 1` 验证）
2. 请确保 rclone 已正确配置云盘
3. 首次运行会自动安装依赖，需要网络连接
4. 上传大文件可能需要较长时间，请保持网络稳定
5. 请勿随意修改 `upload_history.json`，否则可能导致重复上传

## 更新日志

### v1.0.0 (2025-10-28)
- 初始版本发布
- 支持基本的上传和分P功能
- 支持大文件自动切割
- 支持断点续传
