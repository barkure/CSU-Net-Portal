from portal import load_env_config, run_autoauth


def main() -> None:
    config = load_env_config()
    interval = int(config["interval"])
    run_autoauth(interval=interval)


if __name__ == "__main__":
    main()
