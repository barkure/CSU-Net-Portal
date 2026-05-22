## Node.js CLI

建议使用 Node.js 18 及以上版本。

### 安装与运行

```sh
npx csu-autoauth
```

或全局安装：

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

- macOS / Linux 默认配置文件：`~/.config/csu-autoauth/config.env`
- macOS / Linux 默认日志文件：`~/.local/share/csu-autoauth/csu-autoauth.log`
- Windows 默认配置文件：`%APPDATA%\csu-autoauth\config.env`
- Windows 默认日志文件：`%LOCALAPPDATA%\csu-autoauth\csu-autoauth.log`

首次运行如果缺少必要参数，会进入交互式配置，并把结果保存到配置文件。

如需重新配置：

```sh
csu-autoauth --reset
```
