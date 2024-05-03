import time
from portal import login, unbind

# 配置
username = '8123456789' # 学号
password = 'xxxxxxxxxx' # 密码
type = '中国移动' # 中国移动、中国联通、中国电信、校园网

# 先解绑后自动登录
unbind(username=username)
time.sleep(5)
login(username=username, password=password, type=type)