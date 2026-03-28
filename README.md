## CSU-Net-Portal
自动登录中南大学校园网，保持校园网登录态。

## How to use
主要配置有 `USERNAME`、`PASSWORD`、`TYPE`。
```
# USERNAME 为你的学号
# PASSWORD 为你的密码
# TYPE 为运营商类型：1=中国移动, 2=中国联通, 3=中国电信, 4=校园网
# INTERVAL 为自动检测间隔，单位为秒，默认为 10 秒
```

Linux 请查看 [Shell (Linux)](https://github.com/barkure/CSU-Net-Portal#shell-linux)，macOS 请查看 [Shell (macOS)](https://github.com/barkure/CSU-Net-Portal#shell-macos)，Windows 请查看 [PowerShell](https://github.com/barkure/CSU-Net-Portal#powershell)，OpenWrt 路由器请查看 [OpenWrt](https://github.com/barkure/CSU-Net-Portal#openwrt)。

### Shell (Linux)
#### 安装
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

#### 其他

[文件系统层次结构标准 (FHS)](https://zh.wikipedia.org/wiki/%E6%96%87%E4%BB%B6%E7%B3%BB%E7%BB%9F%E5%B1%82%E6%AC%A1%E7%BB%93%E6%9E%84%E6%A0%87%E5%87%86)：
```
- /usr/local/bin/csu-autoauth
- /usr/local/etc/csu-autoauth/config.conf
- /var/log/csu-autoauth/csu-autoauth.log
- /etc/systemd/system/csu-autoauth.service
```

查看运行状态和日志：
```bash
systemctl status csu-autoauth.service
journalctl -u csu-autoauth.service -f
```

### Shell (macOS)
#### 安装
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

#### 其他
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

### PowerShell
1. 克隆到本地，并复制 `powershell/csu-autoauth.ps1` 到合适位置：
```powershell
git clone https://github.com/barkure/CSU-Net-Portal.git
cd .\CSU-Net-Portal
Copy-Item .\powershell\csu-autoauth.ps1 $HOME\csu-autoauth.ps1
```

2. 修改 `csu-autoauth.ps1` 中的配置项：
```powershell
notepad $HOME\csu-autoauth.ps1
```

3. 运行脚本：
```powershell
powershell -ExecutionPolicy Bypass -File $HOME\csu-autoauth.ps1
```

4. 如需开机自启，可执行：
```powershell
powershell -ExecutionPolicy Bypass -File .\powershell\install-startup.ps1
```

该命令会在 Windows Startup 文件夹中创建启动器，并立即在后台启动脚本。

5. 取消开机自启可执行：
```powershell
powershell -ExecutionPolicy Bypass -File .\powershell\uninstall-startup.ps1
```

该命令会删除 Startup 启动器，并停止当前正在运行的脚本进程。

6. 脚本默认日志文件：
- Windows 默认日志文件：`$env:LOCALAPPDATA\csu-autoauth\csu-autoauth.log`

### OpenWrt
请在仓库的 Release 页面下载与你设备架构和 OpenWrt 版本匹配的安装包，再上传到路由器安装。
如果 Release 中没有你设备对应的架构包，请提交 Issue。
认证接口默认直连 `10.1.1.1`，以避免 OpenWrt 本地 DNS 解析链路带来的干扰。

OpenWrt 目前使用新的包管理器 `apk` 替换了 `opkg`，请使用对应的包管理器进行安装：

- OpenWrt `25.12+` 使用 `apk`：

```sh
scp -O ./csu-autoauth-*.apk root@<router-ip>:/tmp/csu-autoauth.apk
ssh root@<router-ip> apk add --allow-untrusted /tmp/csu-autoauth.apk
```

- OpenWrt `24.10` 及更早版本使用 `opkg`：

```sh
scp -O ./csu-autoauth_*.ipk root@<router-ip>:/tmp/csu-autoauth.ipk
ssh root@<router-ip> opkg install /tmp/csu-autoauth.ipk
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

如果仓库软件源可用，包管理器会自动拉取 `curl`；如果软件源不可用，需要先确保路由器能访问对应软件源，或提前准备好离线的依赖包一并安装。

OpenWrt 包版本维护约定：

- 程序逻辑变化 -> bump `PKG_VERSION`, reset `PKG_RELEASE` to `1`
- 仅打包变化 -> bump `PKG_RELEASE` only
- 仅文档变化 -> no version bump
