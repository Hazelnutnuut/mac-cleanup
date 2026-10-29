# mac-cleanup

一组 macOS 清理脚本：当 Mac 提示「储存空间已满」或者运行变慢时，按顺序找出占空间的东西，安全地清理掉。

> A small set of macOS shell scripts to find what's eating your disk space and safely clean caches, logs and idle memory.

## 包含的脚本

| 脚本 | 作用 | 会删除东西吗 |
|---|---|---|
| `mac_cleanup.sh` | 清理缓存、旧日志、开发缓存，释放闲置内存，并列出大文件 | ✅ 只删安全项目（可用 `--dry-run` 先预览） |
| `scripts/rank_apps.sh` | 按「多久没用」给 App 排名，显示大小 | ❌ 只读 |
| `scripts/big_folders.sh` | 找出 `~/Library` 里最占空间的文件夹（「系统数据」的大头） | ❌ 只读 |
| `scripts/check_photos_icloud.sh` | 检查照片图库大小，以及照片有没有存到 iCloud | ❌ 只读 |

## 推荐的清理流程

```bash
git clone https://github.com/Hazelnutnuut/mac-cleanup.git
cd mac-cleanup
```

**1. 先预览，不删除任何东西**
```bash
bash mac_cleanup.sh --dry-run
```

**2. 找出不常用的 App**
```bash
bash scripts/rank_apps.sh
```
标「★可考虑删除」的是超过 180 天没打开的 App。把它拖到废纸篓即可删除；自带卸载程序的（Adobe、VPN、杀毒软件等）用它自己的卸载程序。

**3. 找出隐藏的大文件夹**
```bash
bash scripts/big_folders.sh
```

**4. 检查照片是否已存到 iCloud**
```bash
bash scripts/check_photos_icloud.sh
```
需要先给「终端」完全磁盘访问权限：系统设置 → 隐私与安全性 → 完全磁盘访问权限。
如果照片已经在 iCloud 上，打开「照片 → 设置 → iCloud → 优化 Mac 储存空间」就能腾出空间。

**5. 正式清理**
```bash
bash mac_cleanup.sh
```

## `mac_cleanup.sh` 的选项

```bash
bash mac_cleanup.sh             # 运行一次
bash mac_cleanup.sh --dry-run   # 只扫描，不删除
bash mac_cleanup.sh --bg        # 后台运行，报告保存在 ~/CleanupReports
bash mac_cleanup.sh --install   # 每周日 03:00 自动后台清理
bash mac_cleanup.sh --uninstall # 取消自动清理
```

### 自动清理的内容
- `~/Library/Caches` 用户缓存（App 会自动重建）
- `~/Library/Logs` 中 7 天前的日志
- Xcode DerivedData、Homebrew 缓存、npm 缓存（如有安装）
- `sudo purge` 释放闲置内存（需要管理员密码；后台模式会跳过）

### 只列出、不自动删除的内容
- 占内存最多的程序（普通 App 标 ★）
- 废纸篓、下载文件夹的大小
- 个人目录下超过 500 MB 的文件

## 注意事项

- 清空缓存后，部分 App 第一次打开会稍慢，或需要重新登录，这是正常现象。
- **不要**在访达里直接删除 `Photos Library.photoslibrary`，那是你所有照片的图库。
- 开启 iCloud 照片后，在 Mac 上删除照片会同步删除 iCloud 和 iPhone 上的照片。
- 使用风险自负，删除前请确认有备份。

## 自动检查（GitHub Actions）

每次推送代码时，`.github/workflows/check.yml` 会自动：
1. 用 ShellCheck 检查所有脚本有没有错误
2. 在 macOS 机器上做语法检查，并以 `--dry-run` 模式试运行（不删除任何东西）

## 作者

**Hazelnutnuut** · [LinkedIn](https://www.linkedin.com/in/hazel-hanzhang-chen-41ab553a0)

## 许可证

本项目使用 [MIT 许可证](LICENSE)：可以自由使用、修改和分发，请保留版权声明。脚本按「原样」提供，作者不对使用后果负责。
