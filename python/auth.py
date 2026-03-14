from portal import load_env_config, login, log


def main() -> None:
    config = load_env_config()
    username = config["username"]
    password = config["password"]
    net_type = config["type"]

    log(f"Authenticating as: {username}")
    result = login(username=username, password=password, net_type=net_type)
    log(f"Login response: {result}")


if __name__ == "__main__":
    main()
