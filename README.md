# CSU-Net-Portal

自动登录中南大学校园网，保持校园网登录态。

配置项分别是学号、密码、运营商、检测时间间隔（可选）。

有如下三个版本：
- [Shell (macOS / Linux)](https://github.com/barkure/CSU-Net-Portal#shell-macos--linux)
- [PowerShell (Windows)](https://github.com/barkure/CSU-Net-Portal#powershell)
- [OpenWrt](https://github.com/barkure/CSU-Net-Portal#openwrt)

## Shell (macOS / Linux)
### 一键安装

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/shell/install.sh | sh
```

### 其他

- 脚本会创建这些公共路径：
```
- ~/.local/bin/csu-autoauth
- ~/.config/csu-autoauth/config.conf
- ~/.local/share/csu-autoauth/csu-autoauth.log
```

- Linux 会额外创建：
```
- ~/.config/systemd/user/csu-autoauth.service
```

- macOS 会额外创建：
```
- ~/Library/LaunchAgents/com.barkure.csu-autoauth.plist
```

- 卸载命令：
```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/shell/uninstall.sh | sh
```

## PowerShell (Windows)
### 一键安装

以管理员身份打开 PowerShell 后执行：

```powershell
irm https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/install.ps1 | iex
```

### 其他

- 安装为 Windows 服务 `csu-autoauth`，开机自动运行，异常退出后自动重启
- 脚本依赖 Windows 10 1803+ 自带的 `curl.exe`，缺失时启动会直接报错
- 该脚本会自动创建：
```
- $HOME\.local\bin\csu-autoauth.ps1
- $HOME\.config\csu-autoauth\config.ps1
- $HOME\.local\share\csu-autoauth\csu-autoauth.log
- $HOME\.local\bin\csu-autoauth-service.exe
- $HOME\.local\bin\csu-autoauth-service.xml
```

- 卸载命令（在管理员 PowerShell 中执行）：
```powershell
irm https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/uninstall.ps1 | iex
```

## OpenWrt
### 一键安装

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/install.sh | sh
```

安装完成后，使用 UCI 配置账号密码：

```sh
uci set csu-autoauth.main.username='USERNAME'
uci set csu-autoauth.main.password='PASSWORD'
uci set csu-autoauth.main.type='TYPE'   # 1=移动 2=联通 3=电信 4=校园网
uci set csu-autoauth.main.interval='10'
uci commit csu-autoauth
/etc/init.d/csu-autoauth restart
```

### 其他

- 这条命令依赖系统里已有 `curl`
- 日志文件：`/var/log/csu-autoauth.log`
- `type` 只接受 `1`/`2`/`3`/`4`，其它值会直接报错退出
- 卸载命令：
```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/uninstall.sh | sh
```
