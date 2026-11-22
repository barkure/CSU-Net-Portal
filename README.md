# CSU-Net-Portal

自动认证中南大学校园网并保持登录态。

配置项：学号、密码、运营商。

- [Shell (macOS / Linux / OpenWrt)](#macos--linux--openwrt)
- [PowerShell (Windows)](#windows)

## macOS / Linux / OpenWrt
### 安装

```sh
curl -fsSL https://ssuu.us/csunet/sh/install.sh | sh
```

### 卸载

```sh
curl -fsSL https://ssuu.us/csunet/sh/uninstall.sh | sh
```

### 其他

- macOS / Linux 下会创建：
  - `~/.local/bin/csu-net-auth`
  - `~/.config/csu-net-auth/config.conf`
  - `~/.local/share/csu-net-auth/csu-net-auth.log`
- Linux 下会额外创建：
  - `~/.config/systemd/user/csu-net-auth.service`
- macOS 下会额外创建：
  - `~/Library/LaunchAgents/com.barkure.csu-net-auth.plist`
- OpenWrt 下会创建：
  - `/usr/bin/csu-net-auth.sh`
  - `/etc/init.d/csu-net-auth`
  - `/etc/config/csu-net-auth`
  - `/var/log/csu-net-auth.log`

## Windows
### 安装（管理员 PowerShell）

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://ssuu.us/csunet/pwsh/install.ps1 | iex"
```

### 卸载（管理员 PowerShell）

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://ssuu.us/csunet/pwsh/uninstall.ps1 | iex"
```

### 其他

- 安装为 Windows 服务 `csu-net-auth`，开机自启，异常退出自动重启，依赖 Windows 10 1803+ 自带的 `curl.exe`
- 该脚本会自动创建：
  - `$HOME\.local\bin\csu-net-auth.ps1`
  - `$HOME\.config\csu-net-auth\config.ps1`
  - `$HOME\.local\share\csu-net-auth\csu-net-auth.log`
  - `$HOME\.local\bin\csu-net-auth.exe`
  - `$HOME\.local\bin\csu-net-auth.xml`

## 许可证

[MIT](./LICENSE)
