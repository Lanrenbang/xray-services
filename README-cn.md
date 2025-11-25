# xray-services
[英文](README.md) | [简体中文](README-cn.md)

以安全/简单的方式使用 Xray-core；你的配置文件无需任何隐藏处理即可随意分享，甚至使用机密支持后，你的环境变量配置也可随意分享。

## 功能
- 配置文件实现自动变量替换；
- 环境变量支持机密，如 Docker/Podman secrets 等；
- 自动跟踪上游更新并构建镜像；
- 提供开箱即用的服务端/客户端配置模板；
- 提供 Docker/Podman build/compose 配置；
- 提供 compose 前置 caddy 嵌套配置；
- 提供 Systemd 服务单元、地理数据自动更新定时器；

## 项目结构
```shell
.
├── templates                 # xray 配置模板
│   ├── server                # - 服务端
│   └── client                # - 客户端
├── log                       # 容器挂载卷 - 日志
├── v2ray                     # 容器挂载卷 - 地理数据
├── systemd                   # systemd 本机运行包
│   ├── xray.service.d
│   │   └── override.conf     # 变量替换插入式片段
│   ├── xray.service          # 动态用户服务单元
│   ├── geo-update.timer      # 地理数据更新定时器
│   ├── geo-update.service    # 地理数据更新服务单元
│   └── README.md             # 本机运行指南
├── scripts
│   └── geo-update.sh         # 地理数据更新脚本
├── .env.warp.example         # 模板替换定义
├── compose.yaml              # 容器编排配置 - 子服务运行
├── compose.override.yaml     # 容器覆盖配置 - 独立运行
├── Dockerfile                # 镜像生成配置
├── README.md
└── README-cn.md
```

## 用法
1. 自行安装 Docker 或者 Podman（推荐），也可以选择本机运行；
2. 推荐 [caddy-services](https://github.com/Lanrenbang/caddy-services)，与本项目完美搭配；
自行安装其他版本的 Caddy 或者 Ningx 也可，但相应配置需自己实现。
3. 克隆本仓库：
```shell
git clone https://github.com/Lanrenbang/xray-services.git
```
> 也可下载 [Releases](https://github.com/Lanrenbang/xray-services/releases) 档案
4. 复制或更名 [.env.warp.example](.env.warp.example) 为 `.env.warp`，按需修改必要内容；
5. 参考内部注释按需修改 [compose.yaml](compose.yaml)/[compose.override.yaml](compose.override.yaml)；
6. 将上一步配置为机密的信息加入密钥：
```shell
echo -n "some secret" | docker secret create <secret_name> - 
echo -n "some secret" | podman secret create <secret_name> - 
```
> 或者直接运行 `docker/podman secret create <secret_name>`，然后根据提示输入密钥；

> **注意：**`<secret_name>` 必须在 `.env.warp`、`compose.yaml` 相关文件中保持一致！
7. 进入根目录后，启动容器服务：
```shell
docker compose up -d
podman compose up -d
```
> 提示：
>  - 如果前置 caddy，本服务将作为子服务启动，这里无需操作，具体查看 [caddy-services](https://github.com/Lanrenbang/caddy-services)

## 其他
- 服务端默认开启 API 服务接口和流量统计，按需配置；
- 客户端默认开启连接观测，从 5 条出站中自动选择最快的出站使用，按需配置；
- 双端仅提供 vless 通信，包含 raw/xhttp 传输，其他需求可自行添加；
- 双端默认启用新版的 vless ML-KEM-768 加密，根据需求生成密钥或者禁用该功能；
- 最新 REALITY ML-DSA-65 签名机制在配置中未使用，如有需求自行添加环境变量、机密和配置文件；
- 如果不希望使用容器，在本机环境运行本项目，请参考 [本机运行指南](systemd/README.md)；
- 关于容器健康检查，请参考 [HEALTHCHECK 说明](https://github.com/Lanrenbang/caddy-services/blob/main/HEALTHCHECK.md)

## 相关项目
- [caddy-services](https://github.com/Lanrenbang/caddy-services)
- [xray-api-bridge](https://github.com/Lanrenbang/xray-api-bridge)

## 鸣谢
- [Xray-core](https://github.com/XTLS/Xray-core)
- [五合一配置](https://github.com/XTLS/Xray-core/discussions/4118)

## 通过捐赠支持我
[![BuyMeACoffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/bobbynona) [![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/bobbynona) [![USDT(TRC20)/Tether](https://img.shields.io/badge/Tether-168363?style=for-the-badge&logo=tether&logoColor=white)](https://github.com/Lanrenbang/.github/blob/5b06b0b2d0b8e4ce532c1c37c72115dd98d7d849/custom/USDT-TRC20.md) [![Litecoin](https://img.shields.io/badge/Litecoin-A6A9AA?style=for-the-badge&logo=litecoin&logoColor=white)](https://github.com/Lanrenbang/.github/blob/5b06b0b2d0b8e4ce532c1c37c72115dd98d7d849/custom/Litecoin.md)

## 许可
本项目按照 `LICENSE` 文件中的条款进行分发。

