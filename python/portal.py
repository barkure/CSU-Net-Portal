import os
import time
from datetime import datetime

import requests

TIMEOUT = 5
CAPTIVE_CHECK_URL = "http://captive.apple.com"
LOGIN_URL = "https://portal.csu.edu.cn:802/eportal/portal/login"
UNBIND_URL = "https://portal.csu.edu.cn:802/eportal/portal/mac/unbind"
LOGOUT_URL = "https://portal.csu.edu.cn:802/eportal/portal/logout"

NET_SUFFIX_MAP = {
    "1": "cmccn",
    "2": "unicomn",
    "3": "telecomn",
    "4": "",
}


def now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def log(message: str) -> None:
    print(f"[{now()}] {message}")


def parse_env_file(env_path: str) -> dict[str, str]:
    config: dict[str, str] = {}

    with open(env_path, "r", encoding="utf-8") as env_file:
        for raw_line in env_file:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            if "#" in line:
                line = line.split("#", 1)[0].rstrip()

            if "=" not in line:
                continue

            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()

            if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
                value = value[1:-1]

            config[key] = value

    return config


def load_env_config() -> dict[str, str]:
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    config = parse_env_file(env_path)

    required_keys = ("USERNAME", "PASSWORD", "TYPE")
    missing_keys = [key for key in required_keys if not config.get(key)]
    if missing_keys:
        missing = ", ".join(missing_keys)
        raise ValueError(f"Missing required keys in {env_path}: {missing}")

    net_type = str(config["TYPE"])
    if net_type not in NET_SUFFIX_MAP:
        raise ValueError("type must be one of: 1, 2, 3, 4")

    interval = str(config.get("INTERVAL", "10"))
    return {
        "username": str(config["USERNAME"]),
        "password": str(config["PASSWORD"]),
        "type": net_type,
        "interval": interval,
    }


def build_user_account(username: str, net_type: str) -> str:
    suffix = NET_SUFFIX_MAP[net_type]
    return f"{username}@{suffix}" if suffix else username


def is_online() -> bool:
    try:
        response = requests.get(CAPTIVE_CHECK_URL, timeout=TIMEOUT)
    except requests.RequestException:
        return False
    return "Success" in response.text


def login(username: str, password: str, net_type: str) -> str:
    user_account = build_user_account(username, net_type)
    params = {"user_account": user_account, "user_password": password}
    response = requests.get(LOGIN_URL, params=params, timeout=TIMEOUT, verify=False)
    response.raise_for_status()
    return response.text


def unbind(username: str) -> str:
    response = requests.get(
        UNBIND_URL,
        params={"user_account": username},
        timeout=TIMEOUT,
        verify=False,
    )
    response.raise_for_status()
    return response.text


def logout() -> str:
    response = requests.get(LOGOUT_URL, timeout=TIMEOUT, verify=False)
    response.raise_for_status()
    return response.text


def run_autoauth(interval: int) -> None:
    config = load_env_config()
    username = config["username"]
    password = config["password"]
    net_type = config["type"]

    log(f"Start monitoring network status (every {interval}s)...")
    while True:
        if is_online():
            log("Network up")
        else:
            log("Network down, triggering authentication...")
            try:
                result = login(username=username, password=password, net_type=net_type)
                log(f"Login response: {result}")
            except requests.RequestException as exc:
                log(f"Authentication failed: {exc}")
        time.sleep(interval)
