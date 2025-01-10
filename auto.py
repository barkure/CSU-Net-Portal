import time
from portal import login, unbind, logout

# 配置
username = "8211211214"  # 学号
password = "qin070809"  # 密码
type = "中国联通"  # 中国移动、中国联通、中国电信、校园网

# 先解绑后自动登录
unbind(username=username)
time.sleep(3)
logout()
time.sleep(3)
login(username=username, password=password, type=type)
