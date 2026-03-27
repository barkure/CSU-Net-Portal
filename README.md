## CSU-Net-Portal
自动登录中南大学校园网，保持校园网登录态。

## 使用方法
主要配置有 `USERNAME`、`PASSWORD`、`TYPE`。
```
# USERNAME 为你的学号
# PASSWORD 为你的密码
# TYPE 为运营商类型：1=中国移动, 2=中国联通, 3=中国电信, 4=校园网
# INTERVAL 为自动检测间隔，单位为秒，默认为 10 秒
```

根据情况选择 Python 版本或者 Shell 版本，**推荐使用 Shell 版本**。如需在路由器上运行，请查看 [OpenWRT](https://github.com/barkure/CSU-Net-Portal#openwrt)。

### Shell
1. 克隆到本地，并复制 `shell/csu-autoauth.sh` 到合适位置，例如 `~/.local/bin/`；
```bash
git clone https://github.com/barkure/CSU-Net-Portal.git && cd CSU-Net-Portal
cp shell/csu-autoauth.sh ~/.local/bin/csu-autoauth.sh
chmod +x ~/.local/bin/csu-autoauth.sh
```

2. 修改 `csu-autoauth.sh` 中的配置项：
```bash
nano ~/.local/bin/csu-autoauth.sh
# edit the following variables: USERNAME, PASSWORD, TYPE, then save (Ctrl+O) and exit (Ctrl+X).
```

3. 脚本会自动创建日志目录并写入日志：
- macOS 默认日志文件：`~/Library/Logs/csu-autoauth/csu-autoauth.log`
- Linux 默认日志文件：`${XDG_STATE_HOME:-$HOME/.local/state}/csu-autoauth/csu-autoauth.log`

4. 添加到系统启动项（以 Linux systemd 为例）：
```bash
mkdir -p ~/.config/systemd/user
cp shell/csu-autoauth.service.example ~/.config/systemd/user/csu-autoauth.service
systemctl --user daemon-reload
systemctl --user enable --now csu-autoauth.service
```

查看运行状态和日志：
```bash
systemctl --user status csu-autoauth.service
journalctl --user -u csu-autoauth.service -f
```

5. 如果你在使用 macOS，可以使用“登录项”添加 `csu-autoauth.sh`，或者使用 `launchd` 创建启动项。

### OpenWRT
如果宿舍使用 OpenWRT 系统的路由器，**非常推荐**在路由器上运行自动认证脚本。

请在仓库的 Release 页面下载与你设备架构匹配的 OpenWrt 安装包，再上传到路由器安装。

安装示例：

```sh
scp -O ./csu-autoauth-*.apk root@<router-ip>:/tmp/csu-autoauth.apk
ssh root@<router-ip> apk add --allow-untrusted /tmp/csu-autoauth.apk
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

### Python
1. 安装依赖（`requests`）：
```python
pip install -r python/requirements.txt
```

2. 运行一次认证：`python python/auth.py`
3. 持续检测断网并自动认证：`python python/autoauth.py`
4. 关于如何保持在后台运行或开机自启，请自行查阅相关资料，例如在 Linux 上可使用 `nohup`、`systemd`、`launchd` 等工具，在 Windows 上可使用“计划任务”等工具。
