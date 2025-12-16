#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
B站录播自动上传工具
支持批量上传、分P管理、大文件切割、断点续传等功能
"""

import os
import sys
import json
import re
import subprocess
import shutil
import time
import logging
import platform
import tempfile
import tarfile
import zipfile
import urllib.request
import urllib.error
import stat
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional, Tuple
import math

# ============================================================================
# 依赖检查和自动安装
# ============================================================================

def check_and_install_dependencies():
    """检查并自动安装Python依赖"""
    required_packages = {
        'questionary': 'questionary',
        'rich': 'rich'
    }

    missing_packages = []

    for module_name, pip_name in required_packages.items():
        try:
            __import__(module_name)
        except ImportError:
            missing_packages.append(pip_name)

    if missing_packages:
        print(f"检测到缺失的依赖包: {', '.join(missing_packages)}")
        print("正在自动安装...")
        try:
            # 尝试使用 --break-system-packages（适用于某些 Linux 发行版）
            subprocess.check_call([
                sys.executable, '-m', 'pip', 'install', '--quiet', '--break-system-packages'
            ] + missing_packages)
            print("依赖安装成功！")
        except subprocess.CalledProcessError as e:
            print(f"依赖安装失败: {e}")
            print("请手动运行以下命令之一:")
            print(f"  1. pip3 install --break-system-packages " + ' '.join(missing_packages))
            print(f"  2. python3 -m pip install --user " + ' '.join(missing_packages))
            print(f"  3. 创建虚拟环境: python3 -m venv venv && source venv/bin/activate && pip install " + ' '.join(missing_packages))
            sys.exit(1)

# 首先检查依赖
check_and_install_dependencies()

# 导入第三方库
import questionary
from questionary import Style
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeRemainingColumn
from rich.panel import Panel
from rich.layout import Layout
from rich import box

# ============================================================================
# 全局配置和日志
# ============================================================================

# 获取脚本所在目录
SCRIPT_DIR = Path(__file__).parent.absolute()
CONFIG_FILE = SCRIPT_DIR / 'config.json'
HISTORY_FILE = SCRIPT_DIR / 'upload_history.json'
FAILED_FILE = SCRIPT_DIR / 'failed_uploads.json'
LOG_FILE = SCRIPT_DIR / 'upload.log'
BILIUP_DEFAULT_EXECUTABLE = Path('/usr/local/bin/biliup')
BILIUP_DEFAULT_COOKIE = SCRIPT_DIR / 'cookies.json'
BILIUP_DEFAULT_VERSION = 'v0.2.4'
ANSI_ESCAPE_PATTERN = re.compile(r'\x1b\[[0-9;]*m')

# 创建控制台对象
console = Console()

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 自定义questionary样式
custom_style = Style([
    ('qmark', 'fg:#673ab7 bold'),
    ('question', 'bold'),
    ('answer', 'fg:#f44336 bold'),
    ('pointer', 'fg:#673ab7 bold'),
    ('highlighted', 'fg:#673ab7 bold'),
    ('selected', 'fg:#cc5454'),
    ('separator', 'fg:#cc5454'),
    ('instruction', ''),
    ('text', ''),
    ('disabled', 'fg:#858585 italic')
])

# ============================================================================
# 配置管理
# ============================================================================

class Config:
    """配置管理类"""

    def __init__(self, config_file: Path):
        self.config_file = config_file
        self.config = self._load_config()

    def _load_config(self) -> dict:
        """加载配置文件"""
        if not self.config_file.exists():
            logger.error(f"配置文件不存在: {self.config_file}")
            sys.exit(1)

        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"加载配置文件失败: {e}")
            sys.exit(1)

    def get(self, *keys, default=None):
        """获取配置值"""
        value = self.config
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        return value

    def set(self, value, *keys):
        """设置配置值"""
        if not keys:
            raise ValueError("必须提供至少一个键")
        data = self.config
        for key in keys[:-1]:
            if key not in data or not isinstance(data[key], dict):
                data[key] = {}
            data = data[key]
        data[keys[-1]] = value

    def save(self):
        """保存配置文件"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
                f.write('\n')
        except Exception as e:
            logger.error(f"保存配置文件失败: {e}")

# ============================================================================
# 工具函数
# ============================================================================

def format_size(size_bytes: int) -> str:
    """格式化文件大小"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"

def get_disk_usage(path: str = '/') -> Tuple[int, int, int]:
    """获取磁盘使用情况 (总空间, 已用空间, 可用空间) 单位: 字节"""
    stat = shutil.disk_usage(path)
    return stat.total, stat.used, stat.free

def check_command_exists(command: str) -> bool:
    """检查命令是否存在"""
    return shutil.which(command) is not None

def run_command(cmd: list, capture_output=True, check=True) -> subprocess.CompletedProcess:
    """运行命令"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture_output,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        logger.error(f"命令执行失败: {' '.join(cmd)}")
        logger.error(f"错误信息: {e.stderr}")
        raise

def ensure_biliup_cli(cli_path: Path, version: str = BILIUP_DEFAULT_VERSION):
    """确保 biliup CLI 已安装（根据系统架构自动下载）"""
    cli_path = cli_path.expanduser()

    if cli_path.exists() and os.access(cli_path, os.X_OK):
        return

    system = platform.system().lower()
    machine = platform.machine().lower()

    arch_aliases = {
        'amd64': 'x86_64',
        'x86_64': 'x86_64',
        'x64': 'x86_64',
        'aarch64': 'aarch64',
        'arm64': 'aarch64',
        'armv7l': 'arm',
        'armv6l': 'arm',
    }

    machine = arch_aliases.get(machine, machine)

    asset_name = None
    if system == 'linux':
        if machine == 'x86_64':
            asset_name = f"biliupR-{version}-x86_64-linux.tar.xz"
        elif machine == 'aarch64':
            asset_name = f"biliupR-{version}-aarch64-linux.tar.xz"
        elif machine == 'arm':
            asset_name = f"biliupR-{version}-arm-linux.tar.xz"
    elif system == 'darwin':
        if machine == 'x86_64':
            asset_name = f"biliupR-{version}-x86_64-macos.tar.xz"
        elif machine == 'aarch64':
            asset_name = f"biliupR-{version}-aarch64-macos.tar.xz"
    elif system == 'windows':
        if machine in ('x86_64', 'amd64'):
            asset_name = f"biliupR-{version}-x86_64-windows.zip"

    if not asset_name:
        logger.error(f"暂不支持平台自动安装 biliup CLI: {system} / {machine}")
        logger.error("请参考 https://github.com/ForgQi/biliup-rs/releases 手动安装。")
        sys.exit(1)

    download_url = f"https://github.com/ForgQi/biliup-rs/releases/download/{version}/{asset_name}"
    tmp_dir = Path(tempfile.mkdtemp(prefix='biliup_cli_'))

    try:
        archive_path = tmp_dir / asset_name
        logger.info(f"正在下载 biliup CLI: {download_url}")

        with urllib.request.urlopen(download_url) as response, open(archive_path, 'wb') as f:
            shutil.copyfileobj(response, f)

        if asset_name.endswith('.tar.xz'):
            with tarfile.open(archive_path, 'r:xz') as tar:
                tar.extractall(tmp_dir)
        elif asset_name.endswith('.zip'):
            with zipfile.ZipFile(archive_path) as zf:
                zf.extractall(tmp_dir)
        else:
            raise RuntimeError(f"无法解析的安装包格式: {asset_name}")

        candidate = None
        for path in tmp_dir.rglob('biliup'):
            if path.is_file():
                candidate = path
                break
        if candidate is None:
            for path in tmp_dir.rglob('biliup.exe'):
                if path.is_file():
                    candidate = path
                    break

        if candidate is None:
            raise FileNotFoundError("未在安装包中找到 biliup 可执行文件")

        cli_path.parent.mkdir(parents=True, exist_ok=True)

        shutil.move(str(candidate), str(cli_path))
        cli_path.chmod(cli_path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        logger.info(f"biliup CLI 已安装至: {cli_path}")
    except urllib.error.URLError as e:
        logger.error(f"下载 biliup CLI 失败: {e}")
        logger.error("请检查网络连接，或手动安装 CLI。")
        sys.exit(1)
    except PermissionError:
        logger.error(f"没有权限写入 {cli_path}。请以 root 权限运行或手动安装 biliup CLI。")
        sys.exit(1)
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

# ============================================================================
# 视频信息类
# ============================================================================

class VideoInfo:
    """视频信息类，用于解析录播文件名"""

    # 文件名格式: 录制-{主播ID}-{日期}-{时间}-{序号}-{标题}.flv
    FILENAME_PATTERN = re.compile(
        r'录制-(\d+)-(\d{8})-(\d{6})-(\d+)-(.+)\.flv$'
    )

    def __init__(self, file_path: str, room_id: str):
        self.file_path = file_path
        self.room_id = room_id  # 直播间ID（从文件夹名称提取）
        self.filename = os.path.basename(file_path)
        self.size = 0

        # 解析文件名
        self._parse_filename()

    def _parse_filename(self):
        """解析文件名"""
        match = self.FILENAME_PATTERN.match(self.filename)
        if match:
            self.streamer_id = match.group(1)
            self.date_str = match.group(2)  # YYYYMMDD
            self.time_str = match.group(3)  # HHMMSS
            self.sequence = match.group(4)
            self.title = match.group(5)

            # 格式化日期
            try:
                dt = datetime.strptime(f"{self.date_str}{self.time_str}", "%Y%m%d%H%M%S")
                self.datetime = dt
                self.formatted_date = dt.strftime("%Y-%m-%d %H:%M:%S")
            except ValueError:
                self.datetime = None
                self.formatted_date = "未知"
        else:
            # 如果文件名不匹配，使用默认值
            self.streamer_id = "unknown"
            self.date_str = ""
            self.time_str = ""
            self.sequence = "0"
            self.title = self.filename.replace('.flv', '')
            self.datetime = None
            self.formatted_date = "未知"

    def get_upload_title(self) -> str:
        """获取上传标题"""
        return self.title

    def get_description(self, template: str, streamer_name: str) -> str:
        """获取视频描述"""
        return template.format(
            streamer_name=streamer_name,
            date=self.formatted_date
        )

    def __repr__(self):
        return f"VideoInfo(title={self.title}, date={self.formatted_date}, size={format_size(self.size)})"

# ============================================================================
# Rclone 管理类
# ============================================================================

class RcloneManager:
    """Rclone 操作管理类"""

    def __init__(self, config: Config):
        self.config = config
        self.remote = config.get('rclone', 'remote')
        self.backup_path = config.get('rclone', 'backup_path')
        self.mount_point = Path(config.get('rclone', 'mount_point'))
        self.is_mounted = False

        # 检查rclone是否安装
        if not check_command_exists('rclone'):
            logger.error("rclone 未安装或不在PATH中")
            sys.exit(1)

    def get_remote_path(self, sub_path: str = "") -> str:
        """获取远程路径"""
        if sub_path:
            return f"{self.remote}:{self.backup_path}/{sub_path}"
        return f"{self.remote}:{self.backup_path}"

    def list_folders(self) -> List[Dict[str, str]]:
        """列出所有主播文件夹"""
        try:
            result = run_command([
                'rclone', 'lsd', self.get_remote_path()
            ])

            folders = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    # 解析输出: "0 2025-09-27 06:31:34        -1 backup"
                    parts = line.split()
                    if len(parts) >= 4:
                        folder_name = ' '.join(parts[4:])
                        folders.append({'name': folder_name})

            return folders
        except Exception as e:
            logger.error(f"列出文件夹失败: {e}")
            return []

    def list_videos(self, folder_name: str) -> List[str]:
        """列出文件夹中的所有.flv视频文件"""
        try:
            result = run_command([
                'rclone', 'lsf', '--files-only', '--include', '*.flv',
                self.get_remote_path(folder_name)
            ])

            videos = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
            return sorted(videos)  # 按文件名排序（时间顺序）
        except Exception as e:
            logger.error(f"列出视频文件失败: {e}")
            return []

    def get_file_size(self, folder_name: str, filename: str) -> int:
        """获取文件大小（字节）"""
        try:
            result = run_command([
                'rclone', 'size', '--json',
                self.get_remote_path(f"{folder_name}/{filename}")
            ])
            data = json.loads(result.stdout)
            return data.get('bytes', 0)
        except Exception as e:
            logger.error(f"获取文件大小失败: {e}")
            return 0

    def get_all_file_sizes(self, folder_name: str) -> Dict[str, int]:
        """批量获取文件夹中所有文件的大小（优化性能）"""
        try:
            result = run_command([
                'rclone', 'ls',
                self.get_remote_path(folder_name)
            ])

            sizes = {}
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    # 格式: "8670013105 录制-xxx.flv"
                    parts = line.strip().split(None, 1)
                    if len(parts) == 2:
                        size = int(parts[0])
                        filename = parts[1]
                        sizes[filename] = size

            return sizes
        except Exception as e:
            logger.error(f"批量获取文件大小失败: {e}")
            return {}

    def get_folder_stats(self, folder_name: str) -> Dict:
        """获取文件夹统计信息"""
        try:
            result = run_command([
                'rclone', 'size', '--json',
                self.get_remote_path(folder_name)
            ])
            data = json.loads(result.stdout)

            videos = self.list_videos(folder_name)

            return {
                'total_size': data.get('bytes', 0),
                'video_count': len(videos),
                'videos': videos
            }
        except Exception as e:
            logger.error(f"获取文件夹统计失败: {e}")
            return {'total_size': 0, 'video_count': 0, 'videos': []}

    def mount(self) -> bool:
        """挂载云盘"""
        if self.is_mounted:
            return True

        try:
            # 创建挂载点
            self.mount_point.mkdir(parents=True, exist_ok=True)

            # 挂载
            subprocess.Popen([
                'rclone', 'mount',
                self.get_remote_path(),
                str(self.mount_point),
                '--daemon',
                '--vfs-cache-mode', 'writes',
                '--allow-other'
            ])

            # 等待挂载完成
            time.sleep(3)

            # 检查挂载是否成功
            if any(self.mount_point.iterdir()):
                self.is_mounted = True
                logger.info(f"云盘已挂载到: {self.mount_point}")
                return True
            else:
                logger.warning("挂载可能未成功")
                return False
        except Exception as e:
            logger.error(f"挂载失败: {e}")
            return False

    def unmount(self):
        """卸载云盘"""
        if not self.is_mounted:
            return

        try:
            run_command(['fusermount', '-u', str(self.mount_point)], check=False)
            self.is_mounted = False
            logger.info("云盘已卸载")
        except Exception as e:
            logger.warning(f"卸载失败: {e}")

    def download_file(self, remote_file_path: str, local_path: str) -> bool:
        """下载文件到本地"""
        try:
            console.print(f"\n[bold cyan]正在从云盘下载文件...[/bold cyan]")
            console.print(f"[yellow]文件: {remote_file_path}[/yellow]")
            logger.info(f"开始下载: {remote_file_path}")

            # 确保本地目录存在
            Path(local_path).parent.mkdir(parents=True, exist_ok=True)

            # 下载文件（实时显示进度）
            process = subprocess.Popen([
                'rclone', 'copy',
                self.get_remote_path(remote_file_path),
                str(Path(local_path).parent),
                '--progress',
                '--stats', '1s'
            ],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )

            # 实时显示下载进度
            for line in process.stdout:
                if line.strip():
                    print(line, end='')
                    sys.stdout.flush()

            process.wait()

            if process.returncode != 0:
                raise Exception(f"下载命令返回错误代码: {process.returncode}")

            console.print(f"\n[green]✓ 下载完成: {local_path}[/green]\n")
            logger.info(f"下载完成: {local_path}")
            return True
        except Exception as e:
            logger.error(f"下载失败: {e}")
            console.print(f"[red]✗ 下载失败: {e}[/red]")
            return False

    def get_mounted_path(self, folder_name: str, filename: str) -> Optional[str]:
        """获取挂载点中的文件路径"""
        if not self.is_mounted:
            return None

        file_path = self.mount_point / folder_name / filename
        if file_path.exists():
            return str(file_path)
        return None

    def list_all_remotes(self) -> List[str]:
        """列出所有已配置的 rclone remote"""
        try:
            result = run_command(['rclone', 'listremotes'])
            remotes = [line.strip().rstrip(':') for line in result.stdout.strip().split('\n') if line.strip()]
            return remotes
        except Exception as e:
            logger.error(f"列出 remote 失败: {e}")
            return []

    def test_connection(self, remote: Optional[str] = None) -> bool:
        """测试 remote 连接"""
        test_remote = remote or self.remote
        try:
            console.print(f"[cyan]正在测试连接: {test_remote}[/cyan]")
            result = run_command([
                'rclone', 'lsd', f"{test_remote}:{self.backup_path}", '--max-depth', '1'
            ], check=False)

            if result.returncode == 0:
                console.print(f"[green]✓ 连接成功: {test_remote}[/green]")
                return True
            else:
                console.print(f"[red]✗ 连接失败: {test_remote}[/red]")
                return False
        except Exception as e:
            logger.error(f"测试连接失败: {e}")
            console.print(f"[red]✗ 测试连接失败: {e}[/red]")
            return False

    def switch_remote(self, new_remote: str):
        """切换到新的 remote"""
        self.remote = new_remote
        self.config.set(new_remote, 'rclone', 'remote')
        self.config.save()
        logger.info(f"已切换 remote 到: {new_remote}")

# ============================================================================
# 视频处理类
# ============================================================================

class VideoProcessor:
    """视频处理类，负责封面提取和视频切割"""

    def __init__(self, config: Config):
        self.config = config
        self.cover_time = config.get('cover', 'extract_time_sec', default=1)
        self.cover_format = config.get('cover', 'output_format', default='jpg')
        self.cover_quality = config.get('cover', 'quality', default=85)

        # 检查ffmpeg是否安装
        if not check_command_exists('ffmpeg'):
            logger.error("ffmpeg 未安装或不在PATH中")
            sys.exit(1)

    def extract_cover(self, video_path: str, output_path: str) -> bool:
        """提取视频封面（第1秒）"""
        try:
            console.print(f"[cyan]正在提取封面...[/cyan]")
            logger.info(f"提取封面: {video_path}")

            # 确保输出目录存在
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)

            # 提取封面
            result = subprocess.run([
                'ffmpeg', '-y',
                '-ss', str(self.cover_time),
                '-i', video_path,
                '-vframes', '1',
                '-q:v', str(self.cover_quality),
                output_path
            ], capture_output=True, text=True)

            if result.returncode != 0:
                logger.warning(f"ffmpeg 警告: {result.stderr}")

            if Path(output_path).exists():
                console.print(f"[green]✓ 封面提取成功[/green]")
                logger.info(f"封面提取成功: {output_path}")
                return True
            else:
                logger.error("封面文件未生成")
                console.print(f"[yellow]! 封面提取失败，将使用默认封面[/yellow]")
                return False
        except Exception as e:
            logger.error(f"提取封面失败: {e}")
            console.print(f"[yellow]! 封面提取失败: {e}[/yellow]")
            return False

    def get_video_duration(self, video_path: str) -> Optional[float]:
        """获取视频时长（秒）"""
        try:
            result = run_command([
                'ffprobe', '-v', 'error',
                '-show_entries', 'format=duration',
                '-of', 'default=noprint_wrappers=1:nokey=1',
                video_path
            ])
            duration = float(result.stdout.strip())
            return duration
        except Exception as e:
            logger.error(f"获取视频时长失败: {e}")
            return None

    def split_video(self, video_path: str, output_dir: str, file_size_gb: float) -> List[str]:
        """
        切割视频
        Args:
            video_path: 原视频路径
            output_dir: 输出目录
            file_size_gb: 原文件大小（GB）
        Returns:
            切割后的文件路径列表
        """
        try:
            # 计算需要切割的段数
            max_size_gb = self.config.get('upload', 'split_margin_gb', default=14.5)
            num_parts = math.ceil(file_size_gb / max_size_gb)

            logger.info(f"视频大小 {file_size_gb:.2f}GB，将切割为 {num_parts} 段")

            # 获取视频总时长
            duration = self.get_video_duration(video_path)
            if not duration:
                logger.error("无法获取视频时长，切割失败")
                return []

            # 计算每段时长
            part_duration = duration / num_parts

            # 准备输出目录
            Path(output_dir).mkdir(parents=True, exist_ok=True)

            # 生成输出文件名
            base_name = Path(video_path).stem
            output_files = []

            # 切割视频
            console.print(Panel(
                f"[yellow]视频大小: {file_size_gb:.2f} GB[/yellow]\n"
                f"[yellow]将切割为: {num_parts} 段[/yellow]\n"
                f"[yellow]每段约: {part_duration/60:.1f} 分钟[/yellow]",
                title="[bold cyan]视频切割信息[/bold cyan]",
                border_style="cyan"
            ))

            for i in range(num_parts):
                start_time = i * part_duration
                output_file = os.path.join(output_dir, f"{base_name}_part{i+1}.flv")

                console.print(f"\n[bold cyan]正在切割第 {i+1}/{num_parts} 段...[/bold cyan]")
                logger.info(f"正在切割第 {i+1}/{num_parts} 段...")

                cmd = [
                    'ffmpeg', '-y',
                    '-ss', str(start_time),
                    '-i', video_path,
                    '-t', str(part_duration),
                    '-c', 'copy',  # 不重新编码，快速切割
                    '-loglevel', 'warning',  # 减少输出
                    output_file
                ]

                # 实时显示 ffmpeg 输出
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )

                for line in process.stdout:
                    if line.strip():
                        print(f"  {line}", end='')
                        sys.stdout.flush()

                process.wait()

                if Path(output_file).exists():
                    output_files.append(output_file)
                    size_mb = Path(output_file).stat().st_size / (1024 * 1024)
                    console.print(f"[green]✓ 第 {i+1} 段切割完成 ({size_mb:.2f} MB)[/green]")
                    logger.info(f"第 {i+1} 段切割完成: {output_file}")
                else:
                    console.print(f"[red]✗ 第 {i+1} 段切割失败[/red]")
                    logger.error(f"第 {i+1} 段切割失败")

            console.print(f"\n[bold green]✓ 视频切割完成！共 {len(output_files)} 段[/bold green]\n")
            return output_files
        except Exception as e:
            logger.error(f"视频切割失败: {e}")
            return []

# ============================================================================
# 上传历史管理类
# ============================================================================

class UploadHistory:
    """上传历史管理类"""

    def __init__(self, history_file: Path, failed_file: Path):
        self.history_file = history_file
        self.failed_file = failed_file
        self.history = self._load_history()
        self.failed = self._load_failed()

    def _load_history(self) -> List[Dict]:
        """加载上传历史"""
        if not self.history_file.exists():
            return []

        try:
            with open(self.history_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"加载上传历史失败: {e}")
            return []

    def _load_failed(self) -> List[Dict]:
        """加载失败记录"""
        if not self.failed_file.exists():
            return []

        try:
            with open(self.failed_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"加载失败记录失败: {e}")
            return []

    def _save_history(self):
        """保存上传历史"""
        try:
            with open(self.history_file, 'w', encoding='utf-8') as f:
                json.dump(self.history, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"保存上传历史失败: {e}")

    def _save_failed(self):
        """保存失败记录"""
        try:
            with open(self.failed_file, 'w', encoding='utf-8') as f:
                json.dump(self.failed, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"保存失败记录失败: {e}")

    def is_uploaded(self, file_path: str, file_size: int) -> bool:
        """检查文件是否已上传（根据路径和大小）"""
        for record in self.history:
            if record.get('file_path') == file_path and record.get('file_size') == file_size:
                return True
        return False

    def add_success(self, file_path: str, file_size: int, bvid: str, is_split: bool = False, parts: List[str] = None):
        """添加成功记录"""
        record = {
            'file_path': file_path,
            'file_size': file_size,
            'bvid': bvid,
            'upload_time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            'is_split': is_split,
            'parts': parts or []
        }
        self.history.append(record)
        self._save_history()
        logger.info(f"已记录上传成功: {file_path} -> {bvid}")

    def add_failed(self, file_path: str, error_msg: str):
        """添加失败记录"""
        record = {
            'file_path': file_path,
            'error_msg': error_msg,
            'failed_time': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        self.failed.append(record)
        self._save_failed()
        logger.warning(f"已记录上传失败: {file_path}")

    def get_uploaded_count(self, folder_videos: List[str], folder_name: str) -> Tuple[int, int]:
        """获取已上传和未上传的数量"""
        uploaded = 0
        for video in folder_videos:
            file_path = f"{folder_name}/{video}"
            # 简化检查，只看路径
            if any(record.get('file_path') == file_path for record in self.history):
                uploaded += 1

        return uploaded, len(folder_videos) - uploaded

    def prune_invalid_records(self, uploader: 'BilibiliUploader') -> Tuple[int, int]:
        """
        校验上传历史，移除不存在的稿件记录
        Returns: (校验总数, 移除数量)
        """
        checked = 0
        removed = 0
        valid_records = []
        invalid_records = []

        for record in self.history:
            checked += 1
            bvid = record.get('bvid')
            if not bvid:
                invalid_records.append(record)
                continue

            if uploader.validate_bvid(bvid):
                valid_records.append(record)
            else:
                invalid_records.append(record)

        if invalid_records:
            removed = len(invalid_records)
            self.history = valid_records
            self._save_history()
            for record in invalid_records:
                file_path = record.get('file_path', '未知路径')
                bvid = record.get('bvid', '未知BV号')
                logger.warning(f"校验失败: {file_path} 对应的稿件 {bvid} 不存在或已删除，移除历史记录")
                self.add_failed(file_path, f"历史记录校验失败，稿件 {bvid} 不存在或已删除")

        return checked, removed

# ============================================================================
# Bilibili 上传类
# ============================================================================

class BilibiliUploader:
    """Bilibili上传封装类"""

    def __init__(self, config: Config):
        self.config = config
        executable = self.config.get('biliup_cli', 'executable', default=str(BILIUP_DEFAULT_EXECUTABLE))
        self.cli_path = Path(executable).expanduser()

        ensure_biliup_cli(self.cli_path)
        if not self.cli_path.exists():
            logger.error(f"未找到 biliup CLI，可执行文件路径: {self.cli_path}")
            sys.exit(1)

        cookie_file = self.config.get('biliup_cli', 'cookie_file', default=str(BILIUP_DEFAULT_COOKIE))
        self.cookie_file = Path(cookie_file).expanduser()
        self.cookie_file.parent.mkdir(parents=True, exist_ok=True)

        self.proxy = self.config.get('biliup_cli', 'proxy', default=None)

        submit_mode = self.config.get('biliup_cli', 'default_submit', default='client')
        if submit_mode not in ('client', 'app', 'web'):
            logger.warning(f"检测到无效的提交方式 {submit_mode}，将使用 client。")
            submit_mode = 'client'
        self.default_submit = submit_mode

    def _build_cmd(self, subcommand: Optional[List[str]] = None, include_cookie: bool = True) -> List[str]:
        """构建 biliup 命令"""
        cmd = [str(self.cli_path)]
        if include_cookie and self.cookie_file:
            cmd.extend(['-u', str(self.cookie_file)])
        if self.proxy:
            cmd.extend(['-p', str(self.proxy)])
        if subcommand:
            cmd.extend(subcommand)
        return cmd

    def login(self) -> bool:
        """调用 biliup 登录"""
        console.print("[bold cyan]启动 biliup 登录流程，请根据提示完成认证。[/bold cyan]")
        cmd = self._build_cmd(['login'])
        try:
            process = subprocess.Popen(cmd, cwd=str(SCRIPT_DIR))
            process.wait()
            if process.returncode == 0:
                console.print("[green]✓ 登录成功[/green]")
                logger.info("biliup 登录成功")
                return True
            console.print("[red]✗ 登录失败，请重试[/red]")
            logger.error(f"biliup 登录失败，返回码: {process.returncode}")
            return False
        except Exception as e:
            logger.error(f"调用 biliup 登录失败: {e}")
            console.print(f"[red]✗ 登录命令执行失败: {e}[/red]")
            return False

    def check_login(self, silent: bool = False) -> bool:
        """检查登录状态"""
        try:
            cmd = self._build_cmd(['list', '--max-pages', '1'])
            result = run_command(cmd, check=False)
            if result.returncode == 0:
                logger.info("Bilibili 登录状态正常")
                return True

            output = (result.stdout or '') + (result.stderr or '')
            logger.warning(f"biliup 登录状态检查失败: {output.strip()}")
            if not silent:
                console.print("[yellow]未检测到有效的 biliup 登录状态，请先执行“登录B站账号”。[/yellow]")
            return False
        except Exception as e:
            logger.error(f"检查登录状态失败: {e}")
            if not silent:
                console.print(f"[red]检查登录状态失败: {e}[/red]")
        return False

    def ensure_logged_in(self) -> bool:
        """确保已登录"""
        if self.check_login(silent=True):
            return True
        console.print("[red]当前未检测到登录状态，请先在主菜单选择“登录B站账号”。[/red]")
        return False

    def validate_bvid(self, bvid: str) -> bool:
        """校验指定 BV 号是否存在"""
        if not bvid:
            return False
        cmd = self._build_cmd(['show', bvid])
        result = run_command(cmd, check=False)
        if result.returncode != 0:
            logger.warning(f"校验 BV 失败: {bvid}，CLI 返回码 {result.returncode}")
            return False

        output = result.stdout.strip() if result.stdout else ""
        if not output:
            logger.warning(f"校验 BV 失败: {bvid}，CLI 未返回数据")
            return False

        try:
            data = json.loads(output)
            if isinstance(data, dict):
                code = data.get('code')
                if code is not None and code != 0:
                    logger.warning(f"校验 BV 失败: {bvid}，返回 code={code}")
                    return False
        except json.JSONDecodeError:
            # 输出不是 JSON，也可能是成功的文本，忽略解析错误
            pass

        return True

    def set_proxy(self, proxy: Optional[str], persist: bool = True):
        """设置网络代理"""
        self.proxy = proxy
        if persist:
            self.config.set(proxy, 'biliup_cli', 'proxy')
            self.config.save()
        if proxy:
            console.print(f"[green]代理已启用: {proxy}[/green]")
            logger.info(f"已设置代理: {proxy}")
        else:
            console.print("[yellow]代理已关闭[/yellow]")
            logger.info("已清除代理设置")

    def upload_video(self, video_path: str, video_info: VideoInfo,
                    streamer_name: str, cover_path: Optional[str] = None,
                    copyright: str = '1') -> Optional[str]:
        """
        上传视频
        Args:
            copyright: 视频类型，'1'-自制 '2'-转载
        Returns: BV号
        """
        try:
            title = video_info.get_upload_title()
            desc = video_info.get_description(
                self.config.get('bilibili', 'desc_template'),
                streamer_name
            )
            tid = self.config.get('bilibili', 'default_tid')
            tags = ','.join(self.config.get('bilibili', 'default_tags') + [streamer_name])
            source = self.config.get('bilibili', 'source_template').format(room_id=video_info.room_id)

            logger.info(f"准备上传: {title}")
            logger.info(f"转载来源: {source}")

            # 显示上传信息
            console.print(Panel(
                f"[cyan]标题:[/cyan] {title}\n"
                f"[cyan]分区:[/cyan] {tid}\n"
                f"[cyan]标签:[/cyan] {tags}\n"
                f"[cyan]来源:[/cyan] {source}",
                title="[bold yellow]上传信息[/bold yellow]",
                border_style="yellow"
            ))

            # 构建上传命令
            cmd = self._build_cmd(['upload'])
            cmd.extend([
                '--submit', self.default_submit,
                '--title', title,
                '--desc', desc,
                '--tid', str(tid),
                '--tag', tags,
                '--source', source,
                '--copyright', copyright
            ])

            # 添加封面
            if cover_path and Path(cover_path).exists():
                cmd.extend(['--cover', cover_path])

            cmd.append(video_path)

            console.print("[bold cyan]开始上传，请等待...[/bold cyan]\n")

            # 执行上传（实时显示进度）
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True,
                cwd=str(SCRIPT_DIR)
            )

            # 实时读取并显示输出
            output_lines = []
            for line in process.stdout:
                print(line, end='')  # 实时显示
                output_lines.append(line)
                sys.stdout.flush()

            process.wait()

            if process.returncode != 0:
                raise Exception(f"上传命令返回错误代码: {process.returncode}")

            # 解析BV号
            output = ''.join(output_lines)
            bvid_match = re.search(r'bvid:(BV\w+)', output)
            if bvid_match:
                bvid = bvid_match.group(1)
                console.print(f"\n[bold green]✓ 上传成功! BV号: {bvid}[/bold green]\n")
                logger.info(f"上传成功! BV号: {bvid}")
                return bvid
            else:
                logger.error("上传成功但无法解析BV号")
                console.print("[yellow]上传可能成功，但无法解析BV号[/yellow]")
                return None
        except Exception as e:
            logger.error(f"上传失败: {e}")
            console.print(f"[red]✗ 上传失败: {e}[/red]")
            return None

    def append_video(self, video_path: str, bvid: str, part_title: str) -> bool:
        """
        添加分P
        Args:
            video_path: 视频路径
            bvid: 目标视频的BV号
            part_title: 分P标题
        """
        try:
            logger.info(f"添加分P到 {bvid}: {part_title}")

            # 显示添加分P信息
            console.print(Panel(
                f"[cyan]目标视频:[/cyan] {bvid}\n"
                f"[cyan]分P标题:[/cyan] {part_title}",
                title="[bold yellow]添加分P[/bold yellow]",
                border_style="yellow"
            ))

            cmd = self._build_cmd(['append', '--vid', bvid])
            cmd.append(video_path)

            console.print("[bold cyan]开始上传分P，请等待...[/bold cyan]\n")

            # 执行上传（实时显示进度）
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True,
                cwd=str(SCRIPT_DIR)
            )

            # 实时读取并显示输出
            output_lines = []
            for line in process.stdout:
                print(line, end='')  # 实时显示
                output_lines.append(line)
                sys.stdout.flush()

            process.wait()

            output = ''.join(output_lines)

            if process.returncode != 0:
                raise Exception(f"添加分P命令返回错误代码: {process.returncode} 输出: {output}")

            console.print(f"\n[bold green]✓ 分P添加成功: {part_title}[/bold green]\n")
            logger.info(f"分P添加成功: {part_title}")
            return True
        except Exception as e:
            logger.error(f"添加分P失败: {e}")
            console.print(f"[red]✗ 添加分P失败: {e}[/red]")
            return False

    def list_videos(self, size: int = 20) -> List[Dict]:
        """获取最近上传的视频列表"""
        try:
            cmd = self._build_cmd(['list', '--max-pages', '1', '--from-page', '1'])
            result = run_command(cmd, check=False)
            if result.returncode != 0:
                logger.warning(f"获取视频列表失败: {(result.stdout or '').strip()} {(result.stderr or '').strip()}")
                return []

            videos = []
            for raw_line in (result.stdout or '').splitlines():
                clean_line = ANSI_ESCAPE_PATTERN.sub('', raw_line).strip()
                if not clean_line or '\t' not in clean_line:
                    continue
                parts = [p.strip() for p in clean_line.split('\t')]
                if len(parts) < 3:
                    continue
                bvid, title, status = parts[0], parts[1], parts[2]
                videos.append({
                    'status': status,
                    'bvid': bvid,
                    'title': title
                })

            return videos[:size]
        except Exception as e:
            logger.error(f"获取视频列表失败: {e}")
            return []

# ============================================================================
# 交互界面类
# ============================================================================

class InteractiveUI:
    """交互界面类"""

    @staticmethod
    def select_mode() -> str:
        """选择操作模式"""
        return questionary.select(
            "请选择操作模式:",
            choices=[
                "配置 rclone 云盘",
                "配置网络代理",
                "上传新视频",
                "添加分P到现有视频",
                "校验上传记录",
                "登录B站账号",
                "退出"
            ],
            style=custom_style
        ).ask()

    @staticmethod
    def select_folder(folders_info: List[Dict]) -> Optional[str]:
        """选择主播文件夹"""
        if not folders_info:
            console.print("[red]没有找到主播文件夹[/red]")
            return None

        # 创建选择列表
        choices = []
        for info in folders_info:
            name = info['name']
            video_count = info.get('video_count', 0)
            total_size = info.get('total_size', 0)
            uploaded = info.get('uploaded', 0)
            not_uploaded = info.get('not_uploaded', 0)

            # 只在有大小信息时才显示大小
            if total_size > 0:
                label = f"{name} | 视频: {video_count}个 | 大小: {format_size(total_size)} | 已上传: {uploaded} | 未上传: {not_uploaded}"
            else:
                label = f"{name} | 视频: {video_count}个 | 已上传: {uploaded} | 未上传: {not_uploaded}"

            choices.append(questionary.Choice(label, value=name))

        choices.append(questionary.Choice("返回", value=None))

        return questionary.select(
            "请选择主播文件夹:",
            choices=choices,
            style=custom_style
        ).ask()

    @staticmethod
    def select_upload_mode() -> str:
        """选择上传方式"""
        return questionary.select(
            "请选择上传方式:",
            choices=[
                "上传全部视频",
                "选择特定视频",
                "返回"
            ],
            style=custom_style
        ).ask()

    @staticmethod
    def select_videos(videos_info: List[Dict]) -> Optional[List[str]]:
        """选择要上传的视频（多选）"""
        if not videos_info:
            console.print("[red]没有找到视频文件[/red]")
            return None

        choices = []
        for info in videos_info:
            filename = info['filename']
            size = info.get('size', 0)
            date = info.get('date', '未知')
            is_uploaded = info.get('is_uploaded', False)

            status = "[green]✓已上传[/green]" if is_uploaded else "[yellow]未上传[/yellow]"
            label = f"{filename} | {format_size(size)} | {date} | {status}"

            choices.append(questionary.Choice(label, value=filename, disabled=is_uploaded))

        return questionary.checkbox(
            "请选择要上传的视频（空格选择，回车确认）:",
            choices=choices,
            style=custom_style
        ).ask()

    @staticmethod
    def select_bvid_mode() -> str:
        """选择BV号输入方式"""
        return questionary.select(
            "请选择目标视频:",
            choices=[
                "从列表中选择",
                "手动输入BV号",
                "返回"
            ],
            style=custom_style
        ).ask()

    @staticmethod
    def select_from_list(videos: List[Dict]) -> Optional[str]:
        """从视频列表中选择"""
        if not videos:
            console.print("[red]没有找到视频[/red]")
            return None

        choices = []
        for video in videos:
            label = f"{video['bvid']} | {video['title']} | {video['status']}"
            choices.append(questionary.Choice(label, value=video['bvid']))

        choices.append(questionary.Choice("返回", value=None))

        return questionary.select(
            "请选择视频:",
            choices=choices,
            style=custom_style
        ).ask()

    @staticmethod
    def input_bvid() -> Optional[str]:
        """手动输入BV号"""
        bvid = questionary.text(
            "请输入BV号:",
            validate=lambda text: text.startswith('BV') or "BV号必须以'BV'开头",
            style=custom_style
        ).ask()
        return bvid

    @staticmethod
    def confirm_upload(video_count: int, total_size: int) -> bool:
        """确认上传"""
        console.print(Panel(
            f"[yellow]准备上传 {video_count} 个视频，总大小约 {format_size(total_size)}[/yellow]\n"
            f"[cyan]将按时间顺序依次上传[/cyan]",
            title="确认上传",
            border_style="yellow"
        ))

        return questionary.confirm(
            "确认开始上传吗？",
            default=True,
            style=custom_style
        ).ask()

    @staticmethod
    def show_progress_header(current: int, total: int, success: int, failed: int, skipped: int):
        """显示进度头部信息"""
        console.print(Panel(
            f"[bold cyan]总进度: {current}/{total}[/bold cyan] | "
            f"[green]成功: {success}[/green] | "
            f"[red]失败: {failed}[/red] | "
            f"[yellow]跳过: {skipped}[/yellow]",
            border_style="cyan"
        ))

# ============================================================================
# 主控制器类
# ============================================================================

class UploadController:
    """上传控制器，协调所有组件"""

    def __init__(self):
        # 加载配置
        self.config = Config(CONFIG_FILE)

        # 初始化各个组件
        self.rclone = RcloneManager(self.config)
        self.processor = VideoProcessor(self.config)
        self.history = UploadHistory(HISTORY_FILE, FAILED_FILE)
        self.uploader = BilibiliUploader(self.config)
        self.ui = InteractiveUI()

        # 临时文件目录
        self.temp_dir = Path(self.config.get('upload', 'local_cache_path'))
        self.temp_dir.mkdir(parents=True, exist_ok=True)

        # 统计信息
        self.stats = {
            'success': 0,
            'failed': 0,
            'skipped': 0
        }

    def run(self):
        """主运行流程"""
        console.print(Panel.fit(
            "[bold cyan]B站录播自动上传工具[/bold cyan]\n"
            "[yellow]支持批量上传、分P管理、大文件切割、断点续传[/yellow]",
            border_style="cyan"
        ))

        try:
            while True:
                mode = self.ui.select_mode()

                if mode == "退出":
                    break
                elif mode == "配置 rclone 云盘":
                    self.configure_rclone_flow()
                elif mode == "配置网络代理":
                    self.configure_proxy_flow()
                elif mode == "上传新视频":
                    self.upload_new_video_flow()
                elif mode == "添加分P到现有视频":
                    self.append_video_flow()
                elif mode == "校验上传记录":
                    self.validate_history_flow()
                elif mode == "登录B站账号":
                    self.uploader.login()
        except KeyboardInterrupt:
            console.print("\n[yellow]用户中断操作[/yellow]")
        finally:
            self.cleanup()

    def upload_new_video_flow(self):
        """上传新视频流程"""
        if not self.uploader.ensure_logged_in():
            return

        # 1. 选择文件夹
        folder_name = self._select_folder_with_stats()
        if not folder_name:
            return

        # 2. 选择上传方式
        upload_mode = self.ui.select_upload_mode()
        if upload_mode == "返回":
            return

        # 3. 获取视频列表
        videos_to_upload = self._get_videos_to_upload(folder_name, upload_mode)
        if not videos_to_upload:
            console.print("[yellow]没有选择任何视频[/yellow]")
            return

        # 4. 确认上传
        total_size = sum(v['size'] for v in videos_to_upload)
        if not self.ui.confirm_upload(len(videos_to_upload), total_size):
            console.print("[yellow]已取消上传[/yellow]")
            return

        # 5. 选择视频类型
        copyright_choice = questionary.select(
            "请选择视频类型:",
            choices=[
                "自制",
                "转载"
            ],
            style=custom_style
        ).ask()

        if not copyright_choice:
            console.print("[yellow]已取消上传[/yellow]")
            return

        copyright = '1' if copyright_choice == "自制" else '2'

        # 6. 开始上传
        self._batch_upload_videos(folder_name, videos_to_upload, mode='new', copyright=copyright)

    def append_video_flow(self):
        """添加分P流程"""
        if not self.uploader.ensure_logged_in():
            return

        # 1. 选择目标视频
        bvid = self._select_target_bvid()
        if not bvid:
            return

        # 2. 选择文件夹和视频
        folder_name = self._select_folder_with_stats()
        if not folder_name:
            return

        upload_mode = self.ui.select_upload_mode()
        if upload_mode == "返回":
            return

        videos_to_upload = self._get_videos_to_upload(folder_name, upload_mode)
        if not videos_to_upload:
            console.print("[yellow]没有选择任何视频[/yellow]")
            return

        # 3. 确认上传
        total_size = sum(v['size'] for v in videos_to_upload)
        if not self.ui.confirm_upload(len(videos_to_upload), total_size):
            console.print("[yellow]已取消上传[/yellow]")
            return

        # 4. 开始添加分P
        self._batch_upload_videos(folder_name, videos_to_upload, mode='append', target_bvid=bvid)

    def validate_history_flow(self):
        """校验上传历史记录"""
        if not self.uploader.ensure_logged_in():
            return

        total = len(self.history.history)
        if total == 0:
            console.print("[yellow]当前没有上传历史记录。[/yellow]")
            return

        console.print("[bold cyan]正在校验上传历史，请稍候...[/bold cyan]")
        checked, removed = self.history.prune_invalid_records(self.uploader)

        console.print(Panel(
            f"[bold]校验完成[/bold]\n\n"
            f"[cyan]检查记录数: {checked}[/cyan]\n"
            f"[green]保留: {checked - removed}[/green]\n"
            f"[red]移除: {removed}[/red]",
            border_style="cyan"
        ))

        if removed > 0:
            console.print("[yellow]已将失效的历史记录移至失败列表，可重新执行上传。[/yellow]")

    def configure_rclone_flow(self):
        """配置 rclone 云盘"""
        while True:
            # 获取当前配置
            current_remote = self.config.get('rclone', 'remote')
            current_path = self.config.get('rclone', 'backup_path')

            # 显示当前配置
            console.print(Panel(
                f"[cyan]当前 Remote:[/cyan] {current_remote}\n"
                f"[cyan]备份路径:[/cyan] {current_path}",
                title="[bold yellow]当前 rclone 配置[/bold yellow]",
                border_style="yellow"
            ))

            choice = questionary.select(
                "请选择要进行的操作:",
                choices=[
                    "查看所有可用的 remote",
                    "切换到其他 remote",
                    "修改备份路径",
                    "测试当前连接",
                    "添加新的 remote (打开 rclone config)",
                    "返回"
                ],
                style=custom_style
            ).ask()

            if not choice or choice == "返回":
                break

            if choice == "查看所有可用的 remote":
                remotes = self.rclone.list_all_remotes()
                if not remotes:
                    console.print("[yellow]没有找到任何已配置的 remote[/yellow]")
                    console.print("[cyan]提示: 请选择'添加新的 remote'进行配置[/cyan]")
                else:
                    console.print("\n[bold cyan]已配置的 remote 列表:[/bold cyan]")
                    for remote in remotes:
                        if remote == current_remote:
                            console.print(f"  [green]✓ {remote} (当前使用)[/green]")
                        else:
                            console.print(f"  - {remote}")
                    console.print()

            elif choice == "切换到其他 remote":
                remotes = self.rclone.list_all_remotes()
                if not remotes:
                    console.print("[yellow]没有找到任何已配置的 remote[/yellow]")
                    continue

                # 构建选择列表
                choices = []
                for remote in remotes:
                    if remote == current_remote:
                        choices.append(questionary.Choice(f"{remote} (当前)", value=remote, disabled=True))
                    else:
                        choices.append(questionary.Choice(remote, value=remote))
                choices.append(questionary.Choice("返回", value=None))

                selected = questionary.select(
                    "请选择要切换到的 remote:",
                    choices=choices,
                    style=custom_style
                ).ask()

                if selected:
                    # 测试连接
                    if self.rclone.test_connection(selected):
                        self.rclone.switch_remote(selected)
                        console.print(f"[green]✓ 已切换到 remote: {selected}[/green]")
                    else:
                        console.print("[red]连接测试失败，未切换 remote[/red]")

            elif choice == "修改备份路径":
                new_path = questionary.text(
                    f"请输入新的备份路径 (当前: {current_path}):",
                    default=current_path,
                    style=custom_style
                ).ask()

                if new_path and new_path != current_path:
                    self.config.set(new_path, 'rclone', 'backup_path')
                    self.config.save()
                    self.rclone.backup_path = new_path
                    console.print(f"[green]✓ 备份路径已更新为: {new_path}[/green]")
                    console.print("[yellow]提示: 建议测试一下连接[/yellow]")

            elif choice == "测试当前连接":
                self.rclone.test_connection()

            elif choice == "添加新的 remote (打开 rclone config)":
                console.print("\n[bold cyan]即将打开 rclone 配置界面...[/bold cyan]")
                console.print("[yellow]提示: 完成配置后，返回此处选择'切换到其他 remote'即可使用新配置[/yellow]\n")

                try:
                    # 直接调用 rclone config
                    subprocess.run(['rclone', 'config'], check=True)
                    console.print("\n[green]✓ rclone 配置已完成[/green]")
                except subprocess.CalledProcessError:
                    console.print("\n[red]✗ rclone 配置过程中出现错误[/red]")
                except KeyboardInterrupt:
                    console.print("\n[yellow]已取消配置[/yellow]")

    def configure_proxy_flow(self):
        """配置网络代理"""
        choice = questionary.select(
            "请选择要进行的操作:",
            choices=[
                "设置 HTTP 代理",
                "设置 SOCKS5 代理",
                "清除代理",
                "返回"
            ],
            style=custom_style
        ).ask()

        if not choice or choice == "返回":
            return

        if choice == "清除代理":
            self.uploader.set_proxy(None)
            return

        scheme = 'http'
        if choice == "设置 SOCKS5 代理":
            scheme = 'socks5'

        prompt = f"请输入 {scheme.upper()} 代理地址（支持 host:port 或完整 URL）:"
        proxy_input = questionary.text(prompt, style=custom_style).ask()

        if not proxy_input:
            console.print("[yellow]未输入代理地址，已取消。[/yellow]")
            return

        proxy_input = proxy_input.strip()
        if '://' not in proxy_input:
            proxy = f"{scheme}://{proxy_input}"
        else:
            proxy = proxy_input

        if '@' not in proxy:
            need_auth = questionary.confirm(
                "是否需要用户名/密码认证？",
                default=False,
                style=custom_style
            ).ask()

            if need_auth:
                username = questionary.text("请输入代理用户名:", style=custom_style).ask() or ""
                password = questionary.password("请输入代理密码:", style=custom_style).ask() or ""
                if username and password:
                    auth = f"{username}:{password}"
                elif username:
                    auth = username
                elif password:
                    auth = f":{password}"
                else:
                    auth = ""
                if auth:
                    proxy = proxy.replace("://", f"://{auth}@", 1)

        self.uploader.set_proxy(proxy)

    def _select_folder_with_stats(self) -> Optional[str]:
        """选择文件夹（快速显示基本信息）"""
        folders = self.rclone.list_folders()
        if not folders:
            return None

        console.print(f"[cyan]正在加载 {len(folders)} 个文件夹的信息...[/cyan]")

        # 快速显示文件夹列表（不加载详细统计，提升性能）
        folders_info = []
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task(f"[cyan]加载中...", total=len(folders))

            for folder in folders:
                name = folder['name']
                progress.update(task, description=f"[cyan]正在处理: {name}")

                # 快速获取视频文件列表（不获取大小）
                videos = self.rclone.list_videos(name)

                # 获取上传统计（基于历史记录，不需要网络请求）
                uploaded, not_uploaded = self.history.get_uploaded_count(videos, name)

                folders_info.append({
                    'name': name,
                    'video_count': len(videos),
                    'total_size': 0,  # 不显示大小，提升加载速度
                    'uploaded': uploaded,
                    'not_uploaded': not_uploaded
                })

                progress.update(task, advance=1)

        console.print(f"[green]加载完成！共 {len(folders_info)} 个文件夹[/green]")
        return self.ui.select_folder(folders_info)

    def _get_videos_to_upload(self, folder_name: str, upload_mode: str) -> List[Dict]:
        """获取要上传的视频列表"""
        # 解析文件夹名获取直播间ID
        room_id = folder_name.split('-')[0]
        streamer_name = '-'.join(folder_name.split('-')[1:])

        # 获取所有视频
        videos = self.rclone.list_videos(folder_name)

        if upload_mode == "上传全部视频":
            selected_videos = videos
        else:
            # 批量获取所有文件大小（性能优化）
            console.print(f"[cyan]正在加载 {len(videos)} 个视频的信息...[/cyan]")
            file_sizes = self.rclone.get_all_file_sizes(folder_name)

            # 准备视频信息用于选择
            videos_info = []
            for video in videos:
                remote_path = f"{folder_name}/{video}"
                size = file_sizes.get(video, 0)

                # 解析视频信息
                video_info = VideoInfo(video, room_id)
                video_info.size = size

                # 检查是否已上传
                is_uploaded = self.history.is_uploaded(remote_path, size)

                videos_info.append({
                    'filename': video,
                    'size': size,
                    'date': video_info.formatted_date,
                    'is_uploaded': is_uploaded
                })

            selected_videos = self.ui.select_videos(videos_info)
            if not selected_videos:
                return []

        # 批量获取文件大小（如果还没有）
        if upload_mode == "上传全部视频":
            console.print(f"[cyan]正在加载 {len(videos)} 个视频的信息...[/cyan]")
            file_sizes = self.rclone.get_all_file_sizes(folder_name)

        # 构建返回列表
        result = []
        for video in selected_videos:
            remote_path = f"{folder_name}/{video}"
            size = file_sizes.get(video, 0)

            # 跳过已上传的
            if self.history.is_uploaded(remote_path, size):
                continue

            video_info = VideoInfo(video, room_id)
            video_info.size = size

            result.append({
                'filename': video,
                'remote_path': remote_path,
                'size': size,
                'video_info': video_info,
                'streamer_name': streamer_name
            })

        return result

    def _select_target_bvid(self) -> Optional[str]:
        """选择目标BV号"""
        mode = self.ui.select_bvid_mode()

        if mode == "返回":
            return None
        elif mode == "从列表中选择":
            videos = self.uploader.list_videos()
            return self.ui.select_from_list(videos)
        else:
            return self.ui.input_bvid()

    def _batch_upload_videos(self, folder_name: str, videos: List[Dict],
                            mode: str = 'new', target_bvid: Optional[str] = None,
                            copyright: str = '1'):
        """批量上传视频"""
        total = len(videos)
        current = 0

        for video_data in videos:
            current += 1

            # 显示进度
            self.ui.show_progress_header(
                current, total,
                self.stats['success'],
                self.stats['failed'],
                self.stats['skipped']
            )

            # 上传单个视频
            success = self._upload_single_video(
                video_data,
                mode=mode,
                target_bvid=target_bvid,
                copyright=copyright
            )

            if success:
                self.stats['success'] += 1
            else:
                # 失败但继续下一个
                pass

        # 显示最终统计
        console.print(Panel(
            f"[bold]上传完成![/bold]\n\n"
            f"[green]成功: {self.stats['success']}[/green]\n"
            f"[red]失败: {self.stats['failed']}[/red]\n"
            f"[yellow]跳过: {self.stats['skipped']}[/yellow]",
            title="上传统计",
            border_style="green"
        ))

    def _upload_single_video(self, video_data: Dict, mode: str = 'new',
                            target_bvid: Optional[str] = None, copyright: str = '1') -> bool:
        """
        上传单个视频
        Args:
            copyright: 视频类型，'1'-自制 '2'-转载
        Returns: 是否成功
        """
        filename = video_data['filename']
        remote_path = video_data['remote_path']
        size = video_data['size']
        video_info = video_data['video_info']
        streamer_name = video_data['streamer_name']

        console.print(f"\n[bold cyan]正在处理: {filename}[/bold cyan]")

        # 检查是否需要切割
        size_gb = size / (1024 ** 3)
        max_size_gb = self.config.get('upload', 'max_file_size_gb', default=15)
        needs_split = size_gb > max_size_gb

        if needs_split:
            console.print(f"[yellow]文件大小 {size_gb:.2f}GB，需要切割[/yellow]")

        # 重试机制
        retry_times = self.config.get('upload', 'retry_times', default=3)

        for attempt in range(retry_times):
            try:
                if attempt > 0:
                    console.print(f"[yellow]第 {attempt + 1} 次重试...[/yellow]")

                # 获取视频路径（挂载点或下载）
                video_path = self._get_video_path(remote_path, filename, size, needs_split)
                if not video_path:
                    raise Exception("无法获取视频文件")

                # 如果需要切割
                if needs_split:
                    result = self._upload_split_video(
                        video_path, video_info, streamer_name,
                        size_gb, mode, target_bvid, copyright
                    )
                else:
                    result = self._upload_normal_video(
                        video_path, video_info, streamer_name,
                        mode, target_bvid, copyright
                    )

                # 清理临时文件
                self._cleanup_temp_files(video_path, needs_split)

                if result:
                    # 记录成功
                    bvid = result if mode == 'new' else target_bvid
                    self.history.add_success(remote_path, size, bvid, needs_split)
                    return True
                else:
                    raise Exception("上传失败")

            except Exception as e:
                logger.error(f"上传失败 (尝试 {attempt + 1}/{retry_times}): {e}")

                if attempt == retry_times - 1:
                    # 最后一次重试失败
                    self.history.add_failed(remote_path, str(e))
                    self.stats['failed'] += 1
                    console.print(f"[red]上传失败: {filename}[/red]")
                    return False

                time.sleep(2)  # 重试前等待

        return False

    def _get_video_path(self, remote_path: str, filename: str, size: int, needs_split: bool) -> Optional[str]:
        """
        获取视频路径（优先使用挂载点，必要时下载）
        """
        # 如果不需要切割，尝试使用挂载点
        if not needs_split:
            # 尝试挂载
            if not self.rclone.is_mounted:
                self.rclone.mount()

            if self.rclone.is_mounted:
                mounted_path = self.rclone.get_mounted_path(
                    remote_path.split('/')[0],
                    filename
                )
                if mounted_path:
                    logger.info(f"使用挂载点路径: {mounted_path}")
                    return mounted_path

        # 需要下载到本地
        console.print("[yellow]需要下载到本地...[/yellow]")

        # 检查空间
        _, _, free_space = get_disk_usage()
        min_free = self.config.get('upload', 'min_free_space_gb', default=5) * (1024 ** 3)

        if free_space - size < min_free:
            console.print(f"[red]硬盘空间不足！需要 {format_size(size + min_free)}，可用 {format_size(free_space)}[/red]")
            return None

        # 下载
        local_path = self.temp_dir / 'downloads' / filename
        local_path.parent.mkdir(parents=True, exist_ok=True)

        if self.rclone.download_file(remote_path, str(local_path)):
            return str(local_path)
        else:
            return None

    def _upload_normal_video(self, video_path: str, video_info: VideoInfo,
                            streamer_name: str, mode: str, target_bvid: Optional[str],
                            copyright: str = '1') -> Optional[str]:
        """上传普通视频（不需要切割）"""
        # 提取封面
        cover_path = self.temp_dir / 'covers' / f"{Path(video_path).stem}.jpg"
        cover_path.parent.mkdir(parents=True, exist_ok=True)

        self.processor.extract_cover(video_path, str(cover_path))

        # 上传
        if mode == 'new':
            bvid = self.uploader.upload_video(
                video_path, video_info, streamer_name,
                str(cover_path) if cover_path.exists() else None,
                copyright=copyright
            )
            return bvid
        else:
            success = self.uploader.append_video(
                video_path, target_bvid, video_info.get_upload_title()
            )
            return target_bvid if success else None

    def _upload_split_video(self, video_path: str, video_info: VideoInfo,
                           streamer_name: str, size_gb: float, mode: str,
                           target_bvid: Optional[str], copyright: str = '1') -> Optional[str]:
        """上传需要切割的视频"""
        # 切割视频
        split_dir = self.temp_dir / 'splits' / Path(video_path).stem
        split_dir.mkdir(parents=True, exist_ok=True)

        console.print("[yellow]正在切割视频...[/yellow]")
        split_files = self.processor.split_video(video_path, str(split_dir), size_gb)

        if not split_files:
            console.print("[red]视频切割失败[/red]")
            return None

        console.print(f"[green]切割完成，共 {len(split_files)} 段[/green]")

        # 上传各段
        result_bvid = target_bvid

        for i, split_file in enumerate(split_files, 1):
            part_title = f"{video_info.get_upload_title()} - P{i}"
            console.print(f"[cyan]上传第 {i}/{len(split_files)} 段...[/cyan]")

            # 提取封面（只为第一段）
            cover_path = None
            if i == 1:
                cover_path = self.temp_dir / 'covers' / f"{Path(split_file).stem}.jpg"
                cover_path.parent.mkdir(parents=True, exist_ok=True)
                self.processor.extract_cover(split_file, str(cover_path))

            # 第一段：创建新视频或添加到指定视频
            if i == 1 and mode == 'new':
                bvid = self.uploader.upload_video(
                    split_file, video_info, streamer_name,
                    str(cover_path) if cover_path and cover_path.exists() else None,
                    copyright=copyright
                )
                if not bvid:
                    console.print(f"[red]第 {i} 段上传失败[/red]")
                    return None
                result_bvid = bvid
            else:
                # 后续段或append模式：添加分P
                success = self.uploader.append_video(split_file, result_bvid, part_title)
                if not success:
                    console.print(f"[red]第 {i} 段上传失败[/red]")
                    return None

            console.print(f"[green]第 {i} 段上传成功[/green]")

        return result_bvid

    def _cleanup_temp_files(self, video_path: str, needs_split: bool):
        """清理临时文件"""
        try:
            # 如果是下载的文件，删除
            if str(self.temp_dir / 'downloads') in video_path:
                Path(video_path).unlink(missing_ok=True)
                logger.info(f"已删除临时文件: {video_path}")

            # 如果有切割文件，删除切割目录
            if needs_split:
                split_dir = self.temp_dir / 'splits' / Path(video_path).stem
                if split_dir.exists():
                    shutil.rmtree(split_dir)
                    logger.info(f"已删除切割目录: {split_dir}")
        except Exception as e:
            logger.warning(f"清理临时文件失败: {e}")

    def cleanup(self):
        """清理资源"""
        console.print("\n[cyan]正在清理资源...[/cyan]")

        # 卸载挂载点
        self.rclone.unmount()

        # 清理临时目录
        try:
            if (self.temp_dir / 'downloads').exists():
                shutil.rmtree(self.temp_dir / 'downloads')
            if (self.temp_dir / 'splits').exists():
                shutil.rmtree(self.temp_dir / 'splits')
        except Exception as e:
            logger.warning(f"清理临时目录失败: {e}")

        console.print("[green]清理完成[/green]")

# ============================================================================
# 主函数
# ============================================================================

def main():
    """主函数"""
    try:
        controller = UploadController()
        controller.run()
    except Exception as e:
        logger.error(f"程序异常退出: {e}", exc_info=True)
        console.print(f"[red]程序异常退出: {e}[/red]")
        sys.exit(1)

if __name__ == '__main__':
    main()
