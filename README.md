## CSU-Net-Portal
自动登录中南大学校园网，保持校园网登录态。

## 使用方法
### 配置
复制 `config.env.example` 为 `config.env`，填写你的学号、密码和运营商类型：
```bash
cp config.env.example config.env
```

### 1. Python 版本
1. 安装依赖：`pip install -r requirements.txt`
2. 运行 `python python/auto.py`；
2. 可以使用“Windows 任务计划”、软路由或者其他设备设置定时任务（如每天 05:00 运行一次）；
3. **推荐 Shell 版本。**

### 2. Shell 版本
自行研究 `shell/csu-autoauth.sh` ，推荐使用这个。