# CSU-Net-Portal

自动登录中南大学校园网，保持登录态。

配置项：学号、密码、运营商、检测间隔（可选）。

- [Shell (macOS / Linux)](#shell-macos--linux)
- [PowerShell (Windows)](#powershell-windows)
- [OpenWrt](#openwrt)

## Shell (macOS / Linux)
### 安装

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/shell/install.sh | sh
```

### 其他

- 脚本会创建：
  - `~/.local/bin/csu-autoauth`
  - `~/.config/csu-autoauth/config.conf`
  - `~/.local/share/csu-autoauth/csu-autoauth.log`
- Linux 会额外创建：
  - `~/.config/systemd/user/csu-autoauth.service`
- macOS 会额外创建：
  - `~/Library/LaunchAgents/com.barkure.csu-autoauth.plist`

- 卸载：
```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/shell/uninstall.sh | sh
```

## PowerShell (Windows)
### 安装（管理员 PowerShell）

```powershell
irm https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/install.ps1 | iex
```

### 其他

- 安装为 Windows 服务 `csu-autoauth`，开机自启，异常退出自动重启，依赖 Windows 10 1803+ 自带的 `curl.exe`
- 该脚本会自动创建：
  - `$HOME\.local\bin\csu-autoauth.ps1`
  - `$HOME\.config\csu-autoauth\config.ps1`
  - `$HOME\.local\share\csu-autoauth\csu-autoauth.log`
  - `$HOME\.local\bin\csu-autoauth-service.exe`
  - `$HOME\.local\bin\csu-autoauth-service.xml`
- 卸载（管理员 PowerShell）：
```powershell
irm https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/uninstall.ps1 | iex
```

## OpenWrt
### 安装

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/install.sh | sh
```

安装完成后配置账号：

```sh
uci set csu-autoauth.main.username='USERNAME'
uci set csu-autoauth.main.password='PASSWORD'
uci set csu-autoauth.main.type='TYPE'   # 1=移动 2=联通 3=电信 4=校园网
uci set csu-autoauth.main.interval='10'
uci commit csu-autoauth
/etc/init.d/csu-autoauth restart
```

### 其他

- 依赖 `curl`，日志位于 `/var/log/csu-autoauth.log`，`type` 仅接受 `1`/`2`/`3`/`4`
- 卸载：
```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/uninstall.sh | sh
```

## 许可证

[MIT](./LICENSE)
