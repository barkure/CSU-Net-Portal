import os
import time
from dotenv import dotenv_values
from portal import login, unbind, logout

# 从 config.env 读取配置
config_path = os.path.join(os.path.dirname(__file__), "..", "config.env")
config = dotenv_values(config_path)

username = config["username"]
password = config["password"]

net_type_map = {"1": "中国移动", "2": "中国联通", "3": "中国电信", "4": "校园网"}
net_type = net_type_map[config["type"]]

# 先解绑后自动登录
unbind(username=username)
time.sleep(3)
logout()
time.sleep(3)
# login(username=username, password=password, type=net_type)
