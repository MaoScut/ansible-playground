#!/usr/bin/env bash
# DNAT功能测试脚本

set -e

echo "===================================="
echo "DNAT功能测试脚本"
echo "===================================="
echo ""

# 检查controller容器是否运行
if ! docker ps | grep -q controller; then
    echo "❌ 错误：controller容器未运行"
    echo "请先执行: docker-compose up -d"
    exit 1
fi

echo "✓ Controller容器正在运行"
echo ""

# 检查iptables规则
echo "1. 检查DNAT规则配置："
echo "-----------------------------------"
docker exec controller iptables -t nat -L -n -v | grep -A 20 "Chain OUTPUT\|Chain PREROUTING" || echo "未找到DNAT规则"
echo ""

# 检查IP转发
echo "2. 检查IP转发状态："
echo "-----------------------------------"
IP_FORWARD=$(docker exec controller cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    echo "✓ IP转发已启用"
else
    echo "❌ IP转发未启用"
fi
echo ""

# 检查DNS解析
echo "3. 检查目标主机DNS解析："
echo "-----------------------------------"
for host in worker1 worker2; do
    IP=$(docker exec controller getent hosts "$host" | awk '{ print $1 }' | head -n1)
    if [ -n "$IP" ]; then
        echo "✓ $host -> $IP"
    else
        echo "❌ 无法解析 $host"
    fi
done
echo ""

# 测试SSH连接（使用DNAT IP）
echo "4. 测试通过DNAT IP的SSH连接："
echo "-----------------------------------"

# 尝试从配置文件或环境变量获取DNAT规则
DNAT_RULES_ARRAY=()

# 优先从配置文件读取
if docker exec controller test -f /etc/dnat-rules.conf 2>/dev/null; then
    echo "从配置文件读取DNAT规则..."
    while IFS= read -r line; do
        # 跳过注释和空行
        line=$(echo "$line" | sed 's/#.*//' | xargs)
        if [ -n "$line" ]; then
            DNAT_RULES_ARRAY+=("$line")
        fi
    done < <(docker exec controller cat /etc/dnat-rules.conf 2>/dev/null)
else
    # 从环境变量获取
    DNAT_RULES=$(docker exec controller printenv DNAT_RULES 2>/dev/null || echo "")
    if [ -n "$DNAT_RULES" ]; then
        echo "从环境变量读取DNAT规则..."
        IFS=',' read -ra DNAT_RULES_ARRAY <<< "$DNAT_RULES"
    fi
fi

if [ ${#DNAT_RULES_ARRAY[@]} -eq 0 ]; then
    echo "⚠️  未配置DNAT规则"
    echo "请配置 dnat-rules.conf 文件或 DNAT_RULES 环境变量"
else
    echo "找到 ${#DNAT_RULES_ARRAY[@]} 条DNAT规则"
    echo ""
    
    # 测试每个规则
    for rule in "${DNAT_RULES_ARRAY[@]}"; do
        IFS=':' read -r source_ip target_host <<< "$rule"
        echo "测试: $source_ip -> $target_host"
        
        # 测试SSH连接（使用-o BatchMode=yes避免交互）
        if docker exec -u ansible controller timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$source_ip" "hostname" 2>/dev/null; then
            echo "✓ SSH连接成功: $source_ip -> $target_host"
        else
            echo "❌ SSH连接失败: $source_ip"
            echo "   提示：确保SSH密钥已正确配置"
        fi
        echo ""
    done
fi

echo "===================================="
echo "测试完成"
echo "===================================="
echo ""
echo "如需查看详细日志，执行："
echo "  docker logs controller | grep -i dnat"
echo ""
echo "如需查看DNAT配置文件，执行："
echo "  cat dnat-rules.conf"
echo "  docker exec controller cat /etc/dnat-rules.conf"
echo ""
echo "如需手动测试SSH，执行："
echo "  docker exec -it controller su - ansible"
echo "  ssh 10.0.0.1  # 使用DNAT配置的IP"

