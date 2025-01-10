import requests
from urllib.parse import quote


# 加载页面设置信息
def load_config():
    url = "https://portal.csu.edu.cn:802/eportal/portal/page/loadConfig"
    response = requests.get(url)
    print(response.text)


# 检查状态
def check_status():
    dr = ""
    url = "https://portal.csu.edu.cn/drcom/chkstatus"
    params = {"callback": dr}
    response = requests.get(url, params=params)
    print(response.text)


# 在线数据
def online_data(username: str, password: str):
    url = "https://portal.csu.edu.cn:802/eportal/portal/Custom/online_data"
    encoded_password = quote(password)
    params = {"username": username, "password": encoded_password}
    response = requests.get(url, params=params)
    print(response.text)


# 登录认证
def login(username: str, password: str, type: str):
    net_types = {
        "中国电信": "telecomn",
        "中国移动": "cmccn",
        "中国联通": "unicomn",
        "校园网": "",
    }
    user_account = username + "@" + net_types[type]
    print("登陆账户：", user_account)
    url = "https://portal.csu.edu.cn:802/eportal/portal/login"
    encoded_password = quote(password)
    params = {"user_account": user_account, "user_password": encoded_password}
    response = requests.get(url, params=params)
    print(response.text)


# 解绑
def unbind(username: int):
    url = "https://portal.csu.edu.cn:802/eportal/portal/mac/unbind"
    params = {"user_account": username}
    response = requests.get(url, params=params)
    print(response.text)


# 退出
def logout():
    url = "https://portal.csu.edu.cn:802/eportal/portal/logout"
    response = requests.get(url)
    print(response.text)
