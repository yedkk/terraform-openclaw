# OpenClaw Terraform Deploy

[中文](#中文) | [English](#english)

---

## 中文

在 AWS、Azure 或 GCP 上一键部署 [OpenClaw](https://github.com/openclaw/openclaw)。

- **多云支持** — 同一套流程覆盖 AWS、Azure、GCP
- **多 Agent** — 支持 1-16 个 OpenClaw Agent 并行运行
- **自动选型** — 根据 Agent 数量自动匹配 VM 实例大小（2 GB ~ 32 GB）
- **零配置网络** — 自动创建 VPC、安全组、公网 IP、HTTPS 反向代理
- **独立 Token** — 每个 Agent 拥有独立的 auth token，部署完直接输出
- **SSH 免管理** — 密钥自动生成，`terraform output` 一条命令导出

### 前置条件

- 安装 [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- 配置好云平台凭据：
  - **AWS**: [配置指南](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) — `aws configure` 或设置环境变量 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
  - **Azure**: [配置指南](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli) — `az login`
  - **GCP**: [配置指南](https://cloud.google.com/docs/authentication/provide-credentials-adc) — `gcloud auth application-default login`

### 使用方法

```bash
git clone https://github.com/yedkk/terraform-openclaw.git
cd terraform-openclaw/aws   # 或 azure/ 或 gcp/

terraform init
terraform apply
# Terraform 会提示输入 agent 数量（1-16），region 默认 us-east-1
# GCP 还会提示输入 project_id
```

部署完成后输出示例：

```
agents = {
  "agent-1" = {
    token = "a8f3..."
    url   = "https://54.123.45.67"
  }
}
ssh_command = "ssh -i key.pem ubuntu@54.123.45.67"
```

浏览器打开 URL，接受自签证书警告，输入对应 agent 的 token 即可进入 Dashboard。

### 设备配对

首次访问 Dashboard 需要在服务器上批准设备：

```bash
terraform output -raw ssh_private_key > key.pem && chmod 600 key.pem
ssh -i key.pem ubuntu@$(terraform output -raw public_ip) \
  "sudo docker exec openclaw-openclaw-1-1 openclaw devices approve --latest"
```

多 agent 场景替换容器名中的数字（如 `openclaw-openclaw-2-1`）。每个浏览器只需批准一次。Azure 用户将 `ubuntu` 替换为 `azureuser`。

### 销毁

```bash
terraform destroy
```

---

## English

One-command deployment of [OpenClaw](https://github.com/openclaw/openclaw) on AWS, Azure, or GCP.

- **Multi-cloud** — Same workflow across AWS, Azure, and GCP
- **Multi-agent** — Run 1–16 OpenClaw Agents on a single VM
- **Auto-sizing** — VM instance type scales with agent count (2 GB – 32 GB)
- **Zero network config** — VPC, security groups, public IP, and HTTPS reverse proxy created automatically
- **Per-agent tokens** — Each agent gets its own auth token, printed in deploy output
- **SSH hands-free** — Key pair auto-generated, export with one command

### Prerequisites

- Install [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- Configure cloud credentials:
  - **AWS**: [Setup guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) — `aws configure` or set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
  - **Azure**: [Setup guide](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli) — `az login`
  - **GCP**: [Setup guide](https://cloud.google.com/docs/authentication/provide-credentials-adc) — `gcloud auth application-default login`

### Usage

```bash
git clone https://github.com/yedkk/terraform-openclaw.git
cd terraform-openclaw/aws   # or azure/ or gcp/

terraform init
terraform apply
# Terraform will prompt for agent count (1-16). Region defaults to us-east-1.
# GCP also prompts for project_id.
```

Example output after deploy:

```
agents = {
  "agent-1" = {
    token = "a8f3..."
    url   = "https://54.123.45.67"
  }
}
ssh_command = "ssh -i key.pem ubuntu@54.123.45.67"
```

Open the URL in your browser, accept the self-signed certificate warning, and enter the agent's token to access the Dashboard.

### Device Pairing

On first visit, approve your device from the server:

```bash
terraform output -raw ssh_private_key > key.pem && chmod 600 key.pem
ssh -i key.pem ubuntu@$(terraform output -raw public_ip) \
  "sudo docker exec openclaw-openclaw-1-1 openclaw devices approve --latest"
```

For multi-agent setups, replace the number in the container name (e.g. `openclaw-openclaw-2-1`). Only needed once per browser. Azure users: replace `ubuntu` with `azureuser`.

### Teardown

```bash
terraform destroy
```

---

## License

MIT
