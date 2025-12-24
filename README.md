# Ansible Playground

快速构建 Ansible 测试环境的 Docker 容器方案。

## 特性

- 🚀 一键启动 Controller 和 6 个 Worker 节点（3 Main + 3 DR）
- 🔑 自动配置 SSH 密钥认证
- 🔀 **DNAT 地址映射** - inventory 中的 IP 可自定义（核心功能）
- 📁 自动挂载 Ansible 脚本目录到 controller
- 🐍 可配置 Python 和 Ansible 版本
- 🏢 支持 Main/DR 双环境部署测试

> **注意：** Controller 容器使用 `privileged` 模式以确保 DNAT 功能正常工作。

## 快速开始

### 方法1：一键设置（推荐）

```bash
bash setup.sh
```

这个脚本会自动完成：
- 清理旧容器
- 创建必要目录
- 生成 SSH 密钥
- 构建镜像
- 启动容器

### 方法2：手动步骤

```bash
# 1. 生成 SSH 密钥（首次使用）
bash scripts/prepare-ssh-keys.sh

# 2. 启动环境
docker-compose up -d

# 3. 进入 controller 测试
docker exec -it controller su - ansible

# 4. 测试连接
ssh worker1  # main环境
ssh worker4  # dr环境
```

## Ansible 脚本目录

`ansible-project/` 目录会自动挂载到 controller 容器的 `/home/ansible/workspace`。

### 使用方法

将你的 Ansible 脚本、playbooks、inventory 等放在 `ansible-project/` 目录下：

```bash
# 在宿主机编辑脚本
vim ansible-project/my-playbook.yml

# 在 controller 中运行
docker exec -it controller su - ansible
cd ~/workspace
ansible-playbook -i inventory my-playbook.yml
```

### 示例演示

项目已包含示例文件，可以直接运行：

```bash
# 进入 controller
docker exec -it controller su - ansible
cd ~/workspace

# 测试连接
ansible -i inventory all -m ping

# 运行示例 playbook
ansible-playbook -i inventory playbook.yml
```

### 目录结构

```
ansible-project/
├── inventory          # Inventory 文件（已包含 DNAT 配置）
├── playbook.yml       # 示例 playbook
├── group_vars/        # 组变量目录
├── host_vars/         # 主机变量目录
├── roles/             # Roles 目录
└── README.md          # 使用说明
```

### 自定义挂载路径

如果需要挂载其他目录，编辑 `docker-compose.yml`：

```yaml
volumes:
  # 修改为你的 ansible 项目路径
  - /path/to/your/ansible/project:/home/ansible/workspace:rw
```

### 测试挂载

运行测试脚本验证挂载和配置：

```bash
bash test-ansible-mount.sh
```

## DNAT 功能

### 什么是 DNAT？

允许在 inventory 中使用自定义 IP 地址，controller 会自动转发到实际的 worker 容器。

**优势：** 无需修改现有 inventory 文件的 IP 地址。

### 配置方法

编辑 `dnat-rules.conf` 文件：

```conf
# Main 环境
10.0.0.1:worker1
10.0.0.2:worker2
10.0.0.3:worker3

# DR 环境
10.1.0.1:worker4
10.1.0.2:worker5
10.1.0.3:worker6
```

重启 controller：

```bash
docker-compose restart controller
```

### 使用示例

配置 DNAT 后，你的 inventory 可以这样写：

```ini
# Main 环境
[main]
10.0.0.1 ansible_user=ansible
10.0.0.2 ansible_user=ansible
10.0.0.3 ansible_user=ansible

# DR 环境
[dr]
10.1.0.1 ansible_user=ansible
10.1.0.2 ansible_user=ansible
10.1.0.3 ansible_user=ansible

# 所有节点
[workers:children]
main
dr

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

然后正常使用 Ansible：

```bash
ansible -i inventory all -m ping
ansible-playbook -i inventory playbook.yml
```

### 测试 DNAT

```bash
# 运行测试脚本
bash test-dnat.sh

# 或手动测试
docker exec -it controller su - ansible
ssh 10.0.0.1  # 自动转发到 worker1
```

### 配置文件说明

- **dnat-rules.conf** - DNAT 规则配置文件（每行一条规则，支持注释）
- **dnat-rules.conf.example** - 配置示例文件

**注意：** 也可以通过环境变量 `DNAT_RULES` 配置，但配置文件优先级更高。

## 自定义配置

### systemctl 命令说明

**问题：** Docker 容器默认不运行 systemd，因此没有 `systemctl` 命令。

**当前方案：** 项目提供了一个模拟的 `systemctl` 命令用于测试：
- 位置：`/usr/bin/systemctl`
- 支持常见操作：`start`, `stop`, `restart`, `status`, `enable`, `disable` 等
- **注意：** 这是模拟命令，不会真正启动/停止服务，仅用于 Ansible playbook 测试

**如果需要真正的 systemd：**
- 使用 `Dockerfile.systemd` 构建镜像
- 需要修改 docker-compose.yml 添加更多权限
- 容器会更重，启动更慢，但行为更接近真实系统

### 修改 Python/Ansible 版本

编辑 `Dockerfile`：

```dockerfile
ARG PYTHON_VERSION=3.12.3
ARG ANSIBLE_VERSION=9.2.0
```

### 添加更多 Worker 节点

当前配置包含 **6 个 worker 节点**：
- **Main 环境**: worker1, worker2, worker3 (10.0.0.1-3)
- **DR 环境**: worker4, worker5, worker6 (10.1.0.1-3)

如需添加更多节点，编辑 `docker-compose.yml`：

```yaml
worker7:
  build:
    context: .
  container_name: worker7
  hostname: worker7
  environment:
    - ROLE=worker
  volumes:
    - ./ssh-keys:/shared-ssh:ro
  depends_on:
    - controller
```

同时更新 `dnat-rules.conf`：

```conf
10.0.0.7:worker7
```

## 常用命令

```bash
# 查看容器状态
docker-compose ps

# 查看日志
docker logs controller

# 停止环境
docker-compose down

# 重建容器
docker-compose up -d --build

# 进入 controller 运行 ansible
docker exec -it controller su - ansible

# 在 controller 中运行 playbook（一行命令）
docker exec -u ansible controller bash -c "cd ~/workspace && ansible-playbook -i inventory playbook.yml"

# 查看 DNAT 规则
docker exec controller iptables -t nat -L -n -v
```

## 故障排查

### SSH 连接失败

```bash
# 检查 SSH 密钥
ls -la ssh-keys/

# 查看容器日志
docker logs controller
docker logs worker1
```

### DNAT 不工作

```bash
# 检查配置文件
cat dnat-rules.conf

# 查看 iptables 规则
docker exec controller iptables -t nat -L -n -v

# 检查 IP 转发
docker exec controller cat /proc/sys/net/ipv4/ip_forward  # 应该输出 1

# 运行 DNAT 测试脚本
bash test-dnat.sh

# 测试 Ansible 脚本目录挂载
bash test-ansible-mount.sh
```

### 容器启动失败

如果容器启动失败，检查：

```bash
# 查看详细日志
docker logs controller

# 常见问题：
# 1. ssh-keys 目录不存在 -> 运行 bash setup.sh
# 2. DNAT 配置错误 -> 检查 dnat-rules.conf 格式
# 3. 端口被占用 -> 修改 docker-compose.yml 中的端口映射
```

**DNAT 功能说明：**
- Controller 容器已配置为 `privileged` 模式，确保 DNAT 功能正常工作
- 如果你的环境不允许使用 privileged 模式，可以注释掉 docker-compose.yml 中的 `privileged: true`
- 注意：移除 privileged 模式后，DNAT 功能可能无法使用

## 目录结构

```
.
├── docker-compose.yml        # Docker Compose 配置
├── Dockerfile                # 容器镜像定义
├── setup.sh                  # 一键设置脚本（推荐）
├── dnat-rules.conf           # DNAT 规则配置
├── dnat-rules.conf.example   # DNAT 配置示例
├── inventory.example         # Inventory 示例
├── test-dnat.sh              # DNAT 测试脚本
├── test-ansible-mount.sh     # Ansible 挂载测试脚本
├── ansible-project/          # Ansible 脚本目录（挂载到 controller）
│   ├── inventory             # Inventory 文件
│   ├── playbook.yml          # 示例 playbook
│   ├── group_vars/           # 组变量
│   ├── host_vars/            # 主机变量
│   ├── roles/                # Ansible roles
│   └── README.md             # 使用说明
├── scripts/
│   ├── entrypoint.sh         # 容器启动脚本
│   └── prepare-ssh-keys.sh   # SSH 密钥生成脚本
└── README.md                 # 本文件
```

## 许可证

MIT License
