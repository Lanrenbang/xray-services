# 本机环境运行
这是一篇抛砖引玉的内容，并不是所有平台的完整解决方案，因为作者更习惯的是在容器环境使用这些项目。
本文仅涉及 Linux systemd 系统的本机运行设置，包含带有机密（系统服务凭据）和变量替换支持。

------------

如果你期望在本地环境直接使用，可参考以下步骤：

### 入门 - 动态用户服务（安全系数比官方脚本安装的略好一些）
1. 安装 Xray-core 二进制，比如：[官方脚本](https://github.com/XTLS/Xray-install)
2. 克隆本存储库，主要是使用配置好的模板和环境变量，并按下述需求进行设置；
3. 可以利用你现有配置进行初步测试，将配置全部放入 `/etc/xray` （动态用户固定配置目录在 `/etc` 下）；
4. 确定你的 xray 地理数据资源的存储路径，并修改 [xray.service](xray.service) 中定义的环境变量值；
5. 进入当前目录，执行以下命令覆盖原有系统服务：
```shell
sudo install -Dm644 xray.service /etc/systemd/system/xray.service
sudo systemctl daemon-reload
sudo systemctl restart xray.service
```
6. 执行测试，确保新服务可以正常运行；

------------

### 进阶 - 地理数据自动更新
1. 查看 [geo-update.timer](geo-update.timer) ，可调整自动更新时间；
2. 查看 [geo-update.service](geo-update.service) ，可调整地理数据的存储路径（两处），**务必与上一步 4 中一致**；
3. 进入当前目录，执行以下命令安装定时器：
```shell
sudo install -Dm755 ../scripts/geo-update.sh /usr/local/bin/geo-update.sh
sudo install -Dm644 geo-update.service /etc/systemd/system/geo-update.service
sudo install -Dm644 geo-update.timer /etc/systemd/system/geo-update.timer
sudo systemctl daemon-reload
sudo systemctl enable --now geo-update.timer
```
> 注：上述 [geo-update.sh](geo-update.sh) 脚本也适合在非 systemd 系统（如 Alpine）上使用 Cron 任务定时触发，且允许通过参数配置重启容器。
4. 定时器安装完成，执行以下命令手动触发测试：
```shell
sudo systemctl start geo-update.service
```
查看服务日志，确保无错误发生。

------------

### 终极 - 服务凭证与变量替换
1. 选择本项目服务端/客户端模板，自行修改后放入 `/etc/xray/templates` 目录；
2. 更名项目根目录的 [.env.warp.example](.env.warp.example) 为 `.env.warp`，按需配置：
```shell
# 如果按照上述配置，则该变量固定如下值
ENVWARP_TEMPLATE="${CONFIGURATION_DIRECTORY}/templates"
# 该变量是替换后的配置目录，固定不变
ENVWARP_CONFDIR="${RUNTIME_DIRECTORY}"
# 该变量务必为空或者屏蔽掉，本替换针对系统服务而言是前置操作，无需从这里启动服务
ENVWARP_EXECUTION=""
#
# 修改默认为容器设置的机密路径，比如：
# XARY_REALITY_PRIVATEKEY="file./run/secrets/<secret_name>" # <- 这是默认设置
XARY_REALITY_PRIVATEKEY="file.${CREDENTIALS_DIRECTORY}/<secret_name>"
# 简单说就是将 /run/secrets 全部替换为 ${CREDENTIALS_DIRECTORY} 这个固定环境变量即可。
#
# 其他选项请按需配置，务必记录好需要的机密名称用于下一步。
```
3. 使用以下命令语法安装机密到系统服务凭据：
```shell
# 先创建个单独存放凭据的目录，可以存储在任意位置，但系统默认存储的加密凭据是 /etc/credstore.encrypted
sudo mkdir /etc/credstore.encrypted/xray
# 凭据生成：
echo -n "some_creds" | sudo systemd-creds encrypt --name=<prefix>_<cred_name>[.cred] - /etc/credstore.encrypted/<prefix>/<cred_name>[.cred]
# 注意其中的 <prefix> 和 <cred_name> ，为了整体与容器机密统一，如 xray_reality_privateKey
# 我们定义其 <prefix> 固定是 xray，<cred_name> 是 reality_privateKey
# 这样做的目的是凭据加载格式是 <id>[:path]，id 是必须的，如上设置，正确加载凭据的格式就是 `xray_reality_privateKey`:/etc/credstore.encrypted/xray/reality_privateKey
#
# 为了不必多个凭据在服务单元里配置多行，path 允许提供绝对目录，此时生成的凭据名称规则是 <id>_<file_name>
# 因此如上配置后，加载 /etc/credstore.encrypted/xray/ 这个目录的全部凭据，将自动变成 xray_<cred_name>，这就能完美和 .env.warp 定义兼容
#
# 生成凭据时的 --name 选项必须提供，因为最终凭据会内嵌该名称，如果未提供，则默认内嵌生成的文件名，对于我们使用独立目录作为 id 或者说前缀，是无法加载整个目录的；
# 标准的凭据文件名称推荐带 .cred 便于系统自动加载，但我们固定加载目录可省略，否则 --name 中也要指定后缀，相应的 .env.warp 中也必须对应添加该后缀才能找到文件。
#
# 全部凭据配置完毕后，你可以使用以下命令启动调试服务，测试能否正常加载：
sudo systemd-run -P --wait -p LoadCredentialEncrypted=xray:/etc/credstore.encrypted/xray/ systemd-creds list
# 如果全部加载成功，则凭据配置结束。
```

	补充：在配置凭据之前，你应该使用如下命令检测系统是否支持 TPM 设备加密：
```shell
systemd-analyze has-tpm2
```
如果输出包含 yes，则支持硬件 TPM，默认启用，此时生成的凭据必须在相同 TPM 硬件中才能正确解密，否则即使凭据泄露，其他设备也无法解密。
如果你不希望使用 TPM，可以在上述生成命令中添加选项 `-H` 或者 `--with-key=host`
当仅使用主机密钥时，可能会看到如下警告：
```shell
Credential secret file '/var/lib/systemd/credential.secret' is not located on encrypted media, using anyway.
```
这是默认主机密钥存储在非加密卷上的默认提示，对于使用 xray 这种服务而言，直接忽略即可。
4. 下载 [envwarp](https://github.com/Lanrenbang/envwarp/releases) ，在其所在目录安装：
```shell
sudo install -Dm755 envwarp-* /usr/local/bin/envwarp
```
5. 安装服务插入式片段（无需修改原服务的补丁）：
```shell
sudo mkdir /etc/systemd/system/xray.service.d
sudo install -Dm644 xray.service.d/override.conf /etc/systemd/system/xray.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart xray.service
```
检查服务日志，确定一切正常后全部结束。

------------

运行时明文密钥自动存储在 `${CREDENTIALS_DIRECTORY}` 也就是 `/run/credentials/xray.service` 当中；
明文配置文件存储在 `${RUNTIME_DIRECTORY}` 也就是 `/run/xray` 目录，实际是 `/run/private/xray` 的符号链接；
但以上目录当前用户都是无权查看的，**只有 root 才能访问**。

