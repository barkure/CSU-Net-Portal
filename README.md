# CSU-Net-Portal

自动登录中南大学校园网，保持校园网登录态。

配置项分别是学号、密码、运营商、检测时间间隔（可选）。

有如下四个版本：
- [Shell (macOS / Linux)](https://github.com/barkure/CSU-Net-Portal#shell-macos--linux)
- [PowerShell (Windows)](https://github.com/barkure/CSU-Net-Portal#powershell)
- [OpenWrt](https://github.com/barkure/CSU-Net-Portal#openwrt)
- [Node.js CLI](https://github.com/barkure/CSU-Net-Portal#nodejs-cli)

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

```powershell
irm https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/powershell/install.ps1 | iex
```

### 其他

- 该脚本会自动创建：
```
- $HOME\.local\bin\csu-autoauth.ps1
- $HOME\.config\csu-autoauth\config.ps1
- $HOME\.local\share\csu-autoauth\csu-autoauth.log
- %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\csu-autoauth.vbs
```

- 卸载命令：
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
uci set csu-autoauth.main.type='TYPE'
uci set csu-autoauth.main.interval='10'
uci commit csu-autoauth
/etc/init.d/csu-autoauth restart
```

### 其他

- 这条命令依赖系统里已有 `curl`
- 卸载命令：
```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/uninstall.sh | sh
```

## Node.js CLI
### 安装与运行

运行：

```sh
npx csu-autoauth
```

或全局安装后运行：

```sh
npm install -g csu-autoauth
csu-autoauth
```

也支持直接带参数运行：

```sh
csu-autoauth -u YOUR_STUDENT_NUMBER -p YOUR_PASSWORD -t 1 -i 10
```

### 参数

```text
-u, --username <value>   学号
-p, --password <value>   密码
-t, --type <value>       运营商，支持 1/2/3/4 或 cmcc/unicom/telecom/campus
-i, --interval <value>   检查间隔，单位秒，默认 10
-h, --help               查看帮助
--config <path>          自定义配置文件路径
--log-file <path>        自定义日志文件路径
--no-save                本次运行不保存配置
--reset                  清除已保存配置并重新引导
```

### 配置与日志路径

macOS / Linux：
- `~/.config/csu-autoauth/config.env`
- `~/.local/share/csu-autoauth/csu-autoauth.log`

Windows：
- `%APPDATA%\csu-autoauth\config.env`
- `%LOCALAPPDATA%\csu-autoauth\csu-autoauth.log`
