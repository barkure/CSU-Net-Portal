# Python 版本

Python 版本提供两个入口：

- `auth.py`：执行一次认证
- `autoauth.py`：持续检测网络状态，断网后自动重新认证

## 依赖

```bash
pip install -r python/requirements.txt
```

当前只依赖 `requests`。

## 配置

复制配置模板：

```bash
cp python/.env.example python/.env
```

然后修改 `python/.env`：

```env
USERNAME="YOUR_STUDENT_NUMBER_HERE"
PASSWORD="YOUR_PASSWORD_HERE"
TYPE="1"
INTERVAL="10"
```

配置项说明：

- `USERNAME`：学号
- `PASSWORD`：校园网密码
- `TYPE`：运营商类型，`1=中国移动`、`2=中国联通`、`3=中国电信`、`4=校园网`
- `INTERVAL`：自动检测间隔，单位为秒，仅 `autoauth.py` 使用

## 使用

执行一次认证：

```bash
python python/auth.py
```

持续检测断网并自动认证：

```bash
python python/autoauth.py
```

如果你只想定时执行一次认证，可以配合系统定时任务运行 `python python/auth.py`。
