## Node.js
### 说明

适用于安装了 Node.js 18 及以上版本的环境。Node.js 版本可以在各个操作系统的设备上运行，实现校园网无感登录。

首次运行会自动检查 `nodejs/.env`。如果没有配置学号和密码，将会进行引导，并把结果保存到 `.env`。

### 一键安装
使用包管理器安装：
```sh
npm install -g csu-autoauth
```

运行：
```sh
csu-autoauth
```

也可以不全局安装，直接临时运行：
```sh
npx csu-autoauth
```

也可以先手动复制示例文件再编辑：
```sh
cp nodejs/.env.example nodejs/.env
```

### 其他

默认会使用这些路径，也支持通过环境变量覆盖：
```
- ENV_FILE: ./nodejs/.env
- DATA_DIR: ./nodejs/log
- LOG_FILE: ./nodejs/log/csu-autoauth.log
- LOG_TO_STDOUT: 1
- CSU_USERNAME / CSU_PASSWORD / CSU_TYPE / CSU_INTERVAL
```

NPM 仓库地址
```
https://www.npmjs.com/package/csu-autoauth
```

### GitHub Actions 自动发布到 npm

仓库已经提供 `.github/workflows/npm-publish.yml`，发布方式如下：

```sh
# 先更新 nodejs/package.json 里的 version
git tag v1.0.1
git push origin main --tags
```

或者使用带前缀的 tag：

```sh
git tag nodejs-v1.0.1
git push origin main --tags
```

工作流会自动：

- 在 `nodejs/` 目录安装依赖
- 校验 tag 版本和 `package.json` 的 `version` 一致
- 执行 `npm pack --dry-run`
- 发布到 npm
