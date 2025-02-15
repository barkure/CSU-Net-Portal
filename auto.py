import time
from portal import login, unbind, logout

# 配置
username = "812345678"  # 学号
password = "abcdefg"  # 密码
type = "中国联通"  # 中国移动、中国联通、中国电信、校园网

# 先解绑后自动登录
unbind(username=username)
time.sleep(3)
logout()
time.sleep(3)
login(username=username, password=password, type=type)
