#!/usr/bin/env bash
# 完整的环境设置脚本

set -e

echo "===================================="
echo "Ansible Playground 环境设置"
echo "===================================="
echo ""

# 获取脚本所在目录
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT_DIR"

echo "工作目录: $ROOT_DIR"
echo ""

# 1. 停止并清理已存在的容器
echo "1. 清理旧容器..."
if docker-compose ps -q 2>/dev/null | grep -q .; then
    echo "   停止已存在的容器..."
    docker-compose down 2>/dev/null || true
fi
echo "   ✓ 清理完成"
echo ""

# 2. 创建必要的目录
echo "2. 创建必要的目录..."

# ssh-keys 目录
if [ ! -d "ssh-keys" ]; then
    mkdir -p ssh-keys
    chmod 700 ssh-keys
    echo "   ✓ 创建 ssh-keys 目录"
else
    echo "   ✓ ssh-keys 目录已存在"
fi

# ansible-project 目录
if [ ! -d "ansible-project" ]; then
    mkdir -p ansible-project
    echo "   ✓ 创建 ansible-project 目录"
else
    echo "   ✓ ansible-project 目录已存在"
fi

echo ""

# 3. 生成 SSH 密钥
echo "3. 生成 SSH 密钥..."
bash scripts/prepare-ssh-keys.sh
echo ""

# 4. 验证文件
echo "4. 验证必要文件..."

REQUIRED_FILES=(
    "ssh-keys/controller_ed25519"
    "ssh-keys/controller_ed25519.pub"
    "dnat-rules.conf"
    "ansible-project/inventory"
)

ALL_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ❌ $file 不存在"
        ALL_OK=false
    fi
done

echo ""

if [ "$ALL_OK" = false ]; then
    echo "❌ 某些必要文件缺失，请检查"
    exit 1
fi

# 5. 构建镜像
echo "5. 构建 Docker 镜像..."
docker-compose build
echo ""

# 6. 启动容器
echo "6. 启动容器..."
docker-compose up -d
echo ""

# 7. 等待容器启动
echo "7. 等待容器启动..."
sleep 3
echo ""

# 8. 检查容器状态
echo "8. 检查容器状态..."
docker-compose ps
echo ""

# 9. 检查日志
echo "9. 检查 controller 日志（最后 10 行）..."
docker logs controller 2>&1 | tail -n 10
echo ""

echo "===================================="
echo "✓ 环境设置完成！"
echo "===================================="
echo ""
echo "下一步："
echo "  1. 测试 DNAT 功能："
echo "     bash test-dnat.sh"
echo ""
echo "  2. 测试 Ansible 挂载："
echo "     bash test-ansible-mount.sh"
echo ""
echo "  3. 进入 controller："
echo "     docker exec -it controller su - ansible"
echo ""

