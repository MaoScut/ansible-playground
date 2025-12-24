#!/usr/bin/env bash
# Fake systemctl for Docker containers without systemd
# This script simulates common systemctl commands for testing purposes
# 专门为 Ansible check mode 优化，确保所有检查都能通过

ACTION="$1"
SERVICE="$2"

# 处理可能的参数变化
if [[ "$ACTION" == "show" ]] && [[ "$SERVICE" == "-p" ]]; then
    # systemctl show -p UnitFileState service_name
    PROPERTY="$2"
    SERVICE="$4"
fi

case "$ACTION" in
    start)
        echo "Starting $SERVICE (simulated)..."
        exit 0
        ;;
    stop)
        echo "Stopping $SERVICE (simulated)..."
        exit 0
        ;;
    restart)
        echo "Restarting $SERVICE (simulated)..."
        exit 0
        ;;
    reload)
        echo "Reloading $SERVICE (simulated)..."
        exit 0
        ;;
    status)
        # 模拟服务运行状态
        echo "● $SERVICE.service - $SERVICE service (simulated)"
        echo "   Loaded: loaded (/etc/systemd/system/$SERVICE.service; enabled; vendor preset: enabled)"
        echo "   Active: active (running) since $(date)"
        echo "     Docs: man:$SERVICE(8)"
        echo " Main PID: $$ ($SERVICE)"
        echo "    Tasks: 1"
        echo "   Memory: 1.0M"
        echo "   CGroup: /system.slice/$SERVICE.service"
        echo "           └─$$ /usr/sbin/$SERVICE"
        exit 0
        ;;
    show)
        # Ansible 使用 show 命令检查服务状态
        # 返回服务已加载和启用的信息
        if [[ -n "$SERVICE" ]]; then
            echo "Id=$SERVICE.service"
            echo "LoadState=loaded"
            echo "ActiveState=active"
            echo "SubState=running"
            echo "UnitFileState=enabled"
            echo "UnitFilePreset=enabled"
            echo "Description=$SERVICE service (simulated)"
        fi
        exit 0
        ;;
    list-unit-files|list-units)
        # 列出所有服务单元（模拟）
        if [[ -n "$SERVICE" ]]; then
            echo "$SERVICE.service    enabled    enabled"
        else
            echo "UNIT FILE                              STATE          VENDOR PRESET"
            echo "sshd.service                           enabled        enabled"
            echo "nginx.service                          enabled        enabled"
        fi
        exit 0
        ;;
    cat)
        # 显示服务文件内容（模拟）
        echo "[Unit]"
        echo "Description=$SERVICE service (simulated)"
        echo "After=network.target"
        echo ""
        echo "[Service]"
        echo "Type=simple"
        echo "ExecStart=/usr/bin/$SERVICE"
        echo ""
        echo "[Install]"
        echo "WantedBy=multi-user.target"
        exit 0
        ;;
    enable)
        echo "Created symlink /etc/systemd/system/multi-user.target.wants/$SERVICE.service → /etc/systemd/system/$SERVICE.service (simulated)"
        exit 0
        ;;
    disable)
        echo "Removed /etc/systemd/system/multi-user.target.wants/$SERVICE.service (simulated)"
        exit 0
        ;;
    is-active)
        echo "active"
        exit 0
        ;;
    is-enabled)
        echo "enabled"
        exit 0
        ;;
    is-failed)
        echo "inactive"
        exit 1
        ;;
    daemon-reload)
        echo "" # systemd daemon-reload 通常没有输出
        exit 0
        ;;
    reset-failed)
        echo "" # reset-failed 通常没有输出
        exit 0
        ;;
    *)
        # 未知命令，也返回成功，避免阻止 Ansible
        exit 0
        ;;
esac

