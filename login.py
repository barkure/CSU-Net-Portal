from portal import login

# 配置
username = '8123456789' # 学号
password = 'xxxxxxxxxx' # 密码
type = '中国移动' # 网络类型: 中国电信, 中国移动, 中国联通, 校园网

# 登录
login(username=username, password=password, type=type)