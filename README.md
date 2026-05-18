# CSU-Net-Portal
自动登录中南大学校园网，保持校园网登录态。

# How to use
主要配置有 `USERNAME`、`PASSWORD`、`TYPE`。
```
# USERNAME 为你的学号
# PASSWORD 为你的密码
# TYPE 为运营商类型：1=中国移动, 2=中国联通, 3=中国电信, 4=校园网
# INTERVAL 为自动检测间隔，单位为秒，默认为 10 秒
```

有如下四个版本：
- [Shell (Linux)](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#shell-linux)
- [Shell (macOS)](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#shell-macos)
- [PowerShell (Windows)](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#powershell)
- [OpenWrt](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#openwrt)

## Shell (Linux)
### 安装
1. 克隆到本地并安装脚本和配置文件：
```bash
git clone https://github.com/barkure/CSU-Net-Portal.git && cd CSU-Net-Portal
sudo install -D -m 755 shell/linux/csu-autoauth.sh /usr/local/bin/csu-autoauth
sudo install -D -m 644 shell/linux/config.conf.example /usr/local/etc/csu-autoauth/config.conf
```

2. 修改配置：
```bash
sudo nano /usr/local/etc/csu-autoauth/config.conf
```

3. 添加到系统启动项：
```bash
sudo cp shell/linux/csu-autoauth.service /etc/systemd/system/csu-autoauth.service
sudo systemctl daemon-reload
sudo systemctl enable --now csu-autoauth.service
```

### 其他
- 脚本遵循 [文件系统层次结构标准 (FHS)](https://zh.wikipedia.org/wiki/%E6%96%87%E4%BB%B6%E7%B3%BB%E7%BB%9F%E5%B1%82%E6%AC%A1%E7%BB%93%E6%9E%84%E6%A0%87%E5%87%86)：
```
- /usr/local/bin/csu-autoauth
- /usr/local/etc/csu-autoauth/config.conf
- /var/log/csu-autoauth/csu-autoauth.log
- /etc/systemd/system/csu-autoauth.service
```

- 运行状态：
```bash
sudo systemctl status csu-autoauth.service
```

- 查看日志：
```bash
sudo journalctl -u csu-autoauth.service -f
```

## Shell (macOS)
### 安装
1. 克隆到本地：
```bash
git clone https://github.com/barkure/CSU-Net-Portal.git && cd CSU-Net-Portal
```

2. 修改配置模板：
```bash
nano shell/macos/config.conf.example
```

3. 安装 `launchd` 服务：
```bash
sh shell/macos/install-launchd.sh
```

### 其他
- 该脚本会自动创建：
```
- ~/.local/bin/csu-autoauth
- ~/.config/csu-autoauth/config.conf
- ~/Library/Logs/csu-autoauth/
- ~/Library/LaunchAgents/com.barkure.csu-autoauth.plist
```

- 卸载服务：
```bash
sh shell/macos/uninstall-launchd.sh
```

- 脚本默认日志文件：
```
- ~/Library/Logs/csu-autoauth/csu-autoauth.log
- ~/Library/Logs/csu-autoauth/launchd.out.log
- ~/Library/Logs/csu-autoauth/launchd.err.log
```

## PowerShell
### 安装
1. 克隆到本地：
```powershell
git clone https://github.com/barkure/CSU-Net-Portal.git; cd .\CSU-Net-Portal
```

2. 修改配置模板：
```powershell
notepad .\powershell\config.ps1.example
```

3. 安装并启用自启动：
```powershell
powershell -ExecutionPolicy Bypass -File .\powershell\install-startup.ps1
```

### 其他
- 该脚本会自动创建：
```
- $HOME\csu-autoauth.ps1
- $HOME\.config\csu-autoauth\config.ps1
```

- 取消自启并即刻停止：
```powershell
powershell -ExecutionPolicy Bypass -File .\powershell\uninstall-startup.ps1
```

- 默认日志文件：`$env:LOCALAPPDATA\csu-autoauth\csu-autoauth.log`

## OpenWrt

使用此脚本可以检测并下载安装系统对应的软件包：

```sh
sh <(curl -fsSL https://raw.githubusercontent.com/barkure/CSU-Net-Portal/main/openwrt/install.sh)
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

注意：
- 这条命令依赖系统里已有 `curl`、`ubus`、`jsonfilter`；
- 如果包依赖无法自动补齐，需要确保路由器当前官方软件源可用。
