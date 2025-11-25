# xray-services
[English](README.md) | [Simplified Chinese](README-cn.md)

Use Xray-core in a secure and simple way. Your configuration files can be shared freely without redaction. With secrets support, even your environment variable configurations can be shared safely.

## Features
- Automatic variable substitution in configuration files.
- Support for secrets in environment variables (e.g., Docker/Podman secrets).
- Automatically tracks upstream updates and rebuilds images.
- Provides out-of-the-box server and client configuration templates.
- Includes Docker/Podman build/compose configurations.
- Provides pre-configured Caddy nesting for Compose.
- Includes Systemd service units and automatic geo-data update timers.

## Project Structure
```shell
.
├── templates                 # Xray configuration templates
│   ├── server                # - Server side
│   └── client                # - Client side
├── log                       # Container volume - Logs
├── v2ray                     # Container volume - Geo data
├── systemd                   # Systemd native execution pack
│   ├── xray.service.d
│   │   └── override.conf     # Drop-in snippet for variable substitution
│   ├── xray.service          # Dynamic user service unit
│   ├── geo-update.timer      # Geo data update timer
│   ├── geo-update.service    # Geo data update service unit
│   └── README.md             # Native execution guide
├── scripts
│   └── geo-update.sh         # Geo data update script
├── .env.warp.example         # Template substitution definitions
├── compose.yaml              # Container orchestration - Sub-service execution
├── compose.override.yaml     # Container override - Standalone execution
├── Dockerfile                # Image generation config
├── README.md
└── README-cn.md
```

## Usage
1. Install Docker or Podman (recommended), or choose to run natively.
2. [caddy-services](https://github.com/Lanrenbang/caddy-services) is recommended as the perfect companion for this project.
   You can also install other versions of Caddy or Nginx yourself, but you will need to implement the corresponding configurations manually.
3. Clone this repository:
```shell
git clone https://github.com/Lanrenbang/xray-services.git
```
> You can also download the [Releases](https://github.com/Lanrenbang/xray-services/releases) archive.
4. Copy or rename [.env.warp.example](.env.warp.example) to `.env.warp` and modify the necessary content as needed.
5. Refer to the internal comments to modify [compose.yaml](compose.yaml)/[compose.override.yaml](compose.override.yaml) as required.
6. Add the information configured as secrets in the previous step to the keystore:
```shell
echo -n "some secret" | docker secret create <secret_name> - 
echo -n "some secret" | podman secret create <secret_name> - 
```
> Or run `docker/podman secret create <secret_name>` directly and enter the secret when prompted.

> **Note:** `<secret_name>` must match the entries in `.env.warp` and `compose.yaml`.
7. Enter the root directory and start the container service:
```shell
docker compose up -d
podman compose up -d
```
> **Tip:**
> - If Caddy is used as a frontend, this service will start as a sub-service. No action is needed here; please refer to [caddy-services](https://github.com/Lanrenbang/caddy-services) for details.

## Others
- The **Server** enables the API service interface and traffic statistics by default; configure as needed.
- The **Client** enables connection observation by default, automatically selecting and using the fastest outbound from 5 available outbounds; configure as needed.
- Both ends strictly support VLESS communication (including raw/xhttp transport). Other requirements can be added manually.
- Both ends enable the new VLESS ML-KEM-768 encryption by default. Generate keys or disable this feature based on your needs.
- The latest REALITY ML-DSA-65 signature mechanism is not used in the configuration. If needed, add the environment variables, secrets, and configuration files yourself.
- If you do not wish to use containers and prefer to run this project natively, please refer to the [Native Execution Guide](systemd/README.md).
- For container health checks, please refer to the [HEALTHCHECK Guide](https://github.com/Lanrenbang/caddy-services/blob/main/HEALTHCHECK.md).

## Related Projects
- [caddy-services](https://github.com/Lanrenbang/caddy-services)
- [xray-api-bridge](https://github.com/Lanrenbang/xray-api-bridge)

## Credits
- [Xray-core](https://github.com/XTLS/Xray-core)
- [5-in-1 Configuration](https://github.com/XTLS/Xray-core/discussions/4118)

## Support Me
[![BuyMeACoffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/bobbynona) [![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/bobbynona) [![USDT(TRC20)/Tether](https://img.shields.io/badge/Tether-168363?style=for-the-badge&logo=tether&logoColor=white)](https://github.com/Lanrenbang/.github/blob/5b06b0b2d0b8e4ce532c1c37c72115dd98d7d849/custom/USDT-TRC20.md) [![Litecoin](https://img.shields.io/badge/Litecoin-A6A9AA?style=for-the-badge&logo=litecoin&logoColor=white)](https://github.com/Lanrenbang/.github/blob/5b06b0b2d0b8e4ce532c1c37c72115dd98d7d849/custom/Litecoin.md)

## License
This project is distributed under the terms of the `LICENSE` file.

