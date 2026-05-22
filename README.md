# CSU-Net-Portal

自动登录中南大学校园网，保持校园网登录态。

配置项分别是学号、密码、运营商、检测时间间隔（可选）。

有如下四个版本：
- [Shell (macOS / Linux)](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#shell-macos--linux)
- [PowerShell (Windows)](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#powershell)
- [OpenWrt](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#openwrt)
- [Node.js](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#nodejs)

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

- 这条命令依赖系统里已有 `curl`；
- 卸载命令：
```sh
curl -fsSL https://cdn.jsdelivr.net/gh/barkure/CSU-Net-Portal@main/openwrt/uninstall.sh | sh
```

## Node.js
### 说明

适用于安装了 Node.js 18 及以上版本的环境。Node.js 版本可以在各个操作系统的设备上运行，实现校园网无感登录。

首次运行会自动检查 `nodejs/.env`。如果没有配置学号和密码，将会进行引导，并把结果保存到 `.env`。

### 一键安装
使用包管理器安装：
```sh
npm install -g csu-autoauth
```

运行：
```sh
csu-autoauth
```

也可以不全局安装，直接临时运行：
```sh
npx csu-autoauth
```

也可以先手动复制示例文件再编辑：
```sh
cp nodejs/.env.example nodejs/.env
```

### 其他

默认会使用这些路径，也支持通过环境变量覆盖：
```
- ENV_FILE: ./nodejs/.env
- DATA_DIR: ./nodejs/log
- LOG_FILE: ./nodejs/log/csu-autoauth.log
- LOG_TO_STDOUT: 1
- CSU_USERNAME / CSU_PASSWORD / CSU_TYPE / CSU_INTERVAL
```

NPM 仓库地址
```
https://www.npmjs.com/package/csu-autoauth
```