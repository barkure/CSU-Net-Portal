## CSU-Net-Portal
自动登录中南大学校园网，保持校园网登录态。

## 使用方法
根据情况选择 Python 版本或者 Shell 版本，**推荐使用 Shell 版本**。如需在路由器上运行，请查看 [OpenWRT](https://github.com/barkure/CSU-Net-Portal?tab=readme-ov-file#openwrt)。

### Shell
1. 克隆到本地，并复制 `shell/csu-autoauth.sh` 到合适位置，例如 `~/.local/bin/`；
```bash
git clone https://github.com/barkure/CSU-Net-Portal.git && cd CSU-Net-Portal
cp shell/csu-autoauth.sh ~/.local/bin/csu-autoauth.sh
chmod +x ~/.local/bin/csu-autoauth.sh
```

2. 修改 `csu-autoauth.sh` 中的配置项，需要填写的主要配置有 `USERNAME`、`PASSWORD`、`TYPE`。`TYPE` 的取值为：`1=中国移动`、`2=中国联通`、`3=中国电信`、`4=校园网`。
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

**你需要能访问路由器的终端（SSH）**。

1. 克隆到本地，并修改相关配置项；
```bash
git clone https://github.com/barkure/CSU-Net-Portal.git && cd CSU-Net-Portal

nano openwrt/csu-autoauth.sh
# edit the following variables: username, password, type, then save (Ctrl+O) and exit (Ctrl+X).
```

2. 上传脚本和 init.d 脚本。很多 OpenWRT 设备没有 `sftp-server`，所以建议使用 `scp -O`：
```bash
scp -O openwrt/csu-autoauth.sh root@<router-ip>:/usr/bin/csu-autoauth.sh
scp -O openwrt/init.d.example root@<router-ip>:/etc/init.d/csu-autoauth
```

3. ssh 登录路由器；
```bash
ssh root@<router-ip>
```

4. 确保路由器上安装了 `curl`，如果没有安装，可以使用以下命令安装：
```sh
opkg update && opkg install curl
```

4. 给脚本添加执行权限，并启用服务：
```sh
chmod +x /usr/bin/csu-autoauth.sh /etc/init.d/csu-autoauth
/etc/init.d/csu-autoauth enable
/etc/init.d/csu-autoauth start
```

5. 防止 OpenWRT 更新覆盖脚本；
```sh
cat >> /etc/sysupgrade.conf <<'EOF'
/usr/bin/csu-autoauth.sh
/etc/init.d/csu-autoauth
EOF
```

### Python
1. 安装依赖（仅安装 `requests`）：
```python
pip install -r python/requirements.txt
```

2. 运行一次认证：`python python/auth.py`
3. 持续检测断网并自动认证：`python python/autoauth.py`
4. 关于如何保持在后台运行或开机自启，请自行查阅相关资料，例如在 Linux 上可使用 `nohup`、`systemd`、`launchd` 等工具，在 Windows 上可使用“计划任务”等工具。
