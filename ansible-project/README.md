# Ansible 项目目录

这个目录会被挂载到 controller 容器的 `/home/ansible/workspace`。

## 使用方法

### 1. 进入 controller

```bash
docker exec -it controller su - ansible
cd ~/workspace
```

### 2. 运行 Ansible 命令

```bash
# 测试连接
ansible -i inventory all -m ping

# 运行 playbook
ansible-playbook -i inventory playbook.yml

# 运行 ad-hoc 命令
ansible -i inventory all -m shell -a "uptime"
```

## 目录结构

```
ansible-project/
├── inventory          # Inventory 文件
├── playbook.yml       # 示例 playbook
├── group_vars/        # 组变量目录（可选）
├── host_vars/         # 主机变量目录（可选）
├── roles/             # Roles 目录（可选）
└── README.md          # 本文件
```

## 添加你的脚本

将你的 Ansible 脚本、playbooks、roles 等放在这个目录下，它们会自动同步到 controller 容器中。

## 示例

### 运行示例 playbook

```bash
docker exec -it controller su - ansible
cd ~/workspace

# 运行基础 playbook
ansible-playbook -i inventory playbook.yml

# 运行使用 role 的 playbook
ansible-playbook -i inventory playbook-with-role.yml
```

### 创建自己的 playbook

在本目录创建 `my-playbook.yml`，然后在 controller 中运行：

```bash
ansible-playbook -i inventory my-playbook.yml
```

### 使用 Roles

项目已包含一个示例 role (`roles/example-role/`)，你可以：

1. 查看示例 role 结构
2. 创建自己的 roles
3. 在 playbook 中引用 roles

```yaml
# 在 playbook 中使用 role
- name: My Playbook
  hosts: workers
  roles:
    - example-role
    - your-custom-role
```

