#!/usr/bin/env bash
# Ansible 脚本目录挂载测试脚本

set -e

echo "===================================="
echo "Ansible 脚本目录挂载测试"
echo "===================================="
echo ""

# 检查 controller 容器是否运行
if ! docker ps | grep -q controller; then
    echo "❌ 错误：controller 容器未运行"
    echo "请先执行: docker-compose up -d"
    exit 1
fi

echo "✓ Controller 容器正在运行"
echo ""

# 检查挂载目录
echo "1. 检查目录挂载："
echo "-----------------------------------"
if docker exec controller test -d /home/ansible/workspace; then
    echo "✓ /home/ansible/workspace 目录已挂载"
else
    echo "❌ /home/ansible/workspace 目录不存在"
    exit 1
fi
echo ""

# 检查文件
echo "2. 检查示例文件："
echo "-----------------------------------"
for file in inventory playbook.yml README.md; do
    if docker exec controller test -f /home/ansible/workspace/$file; then
        echo "✓ $file 存在"
    else
        echo "⚠️  $file 不存在"
    fi
done
echo ""

# 检查文件权限
echo "3. 检查文件权限："
echo "-----------------------------------"
docker exec controller ls -la /home/ansible/workspace/ | head -n 10
echo ""

# 测试 Ansible 命令
echo "4. 测试 Ansible 命令："
echo "-----------------------------------"

# 测试 inventory
echo "检查 inventory 文件..."
if docker exec -u ansible controller bash -c "cd ~/workspace && ansible-inventory -i inventory --list" >/dev/null 2>&1; then
    echo "✓ Inventory 文件格式正确"
else
    echo "⚠️  Inventory 文件可能有问题"
fi
echo ""

# 测试 ping
echo "测试 Ansible ping..."
if docker exec -u ansible controller bash -c "cd ~/workspace && ansible -i inventory all -m ping" 2>&1 | grep -q "SUCCESS"; then
    echo "✓ Ansible ping 成功"
else
    echo "❌ Ansible ping 失败"
    echo "提示：确保 SSH 密钥已配置并且 workers 已启动"
fi
echo ""

# 测试 playbook 语法
echo "5. 检查 Playbook 语法："
echo "-----------------------------------"
if docker exec -u ansible controller bash -c "cd ~/workspace && ansible-playbook -i inventory playbook.yml --syntax-check" 2>&1 | grep -q "Syntax OK"; then
    echo "✓ Playbook 语法正确"
else
    echo "⚠️  Playbook 语法可能有问题"
fi
echo ""

echo "===================================="
echo "测试完成"
echo "===================================="
echo ""
echo "运行示例 playbook："
echo "  docker exec -it controller su - ansible"
echo "  cd ~/workspace"
echo "  ansible-playbook -i inventory playbook.yml"
echo ""
echo "或一行命令运行："
echo "  docker exec -u ansible controller bash -c 'cd ~/workspace && ansible-playbook -i inventory playbook.yml'"

