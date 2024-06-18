import requests

# 加载页面设置信息
def load_config():
    url = 'https://portal.csu.edu.cn:802/eportal/portal/page/loadConfig'
    response = requests.get(url)
    print(response.text)

# 检查状态
def check_status():
    dr = ''
    url = f'https://portal.csu.edu.cn/drcom/chkstatus?callback={dr}'
    response = requests.get(url)
    print(response.text)

# 在线数据
def online_data(username, password):
    url = f'https://portal.csu.edu.cn:802/eportal/portal/Custom/online_data?username={username}&password={password}'
    response = requests.get(url)
    print(response.text)

# 登录认证
def login(username, password, type):
    net_types = {
        '中国电信': 'telecomn',
        '中国移动': 'cmccn',
        '中国联通': 'unicomn',
        '校园网': ''
    }
    user_account = username + '@' + net_types[type]
    print(user_account)
    url = f'https://portal.csu.edu.cn:802/eportal/portal/login?user_account={user_account}&user_password={password}'
    response = requests.get(url)
    print(response.text)

# 解绑
def unbind(username):
    url = f'https://portal.csu.edu.cn:802/eportal/portal/mac/unbind?user_account={username}'
    response = requests.get(url)
    print(response.text)

# 退出
def logout():
    url = 'https://portal.csu.edu.cn:802/eportal/portal/logout'
    response = requests.get(url)
    print(response.text)
