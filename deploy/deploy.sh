#!/bin/bash
# ========================================
# 波普特酒店空调系统 - Linux 部署脚本
# ========================================

set -e

echo "=========================================="
echo "  波普特酒店空调系统 - 自动部署脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目路径
PROJECT_DIR=$(dirname $(dirname $(realpath $0)))
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
DEPLOY_DIR="$PROJECT_DIR/deploy"

echo -e "${GREEN}项目路径: $PROJECT_DIR${NC}"

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}警告: 建议使用 root 用户运行此脚本${NC}"
fi

# ========================================
# 1. 安装系统依赖（检查已安装则跳过）
# ========================================
echo ""
echo -e "${GREEN}[1/6] 检查系统依赖...${NC}"

# 检查并安装 Python3
if ! command -v python3 &> /dev/null; then
    echo "安装 Python3..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y python3 python3-pip python3-venv
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip --disableexcludes=all
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip
    fi
else
    echo "Python3 已安装: $(python3 --version)"
fi

# 检查并安装 Node.js
if ! command -v node &> /dev/null; then
    echo "安装 Node.js..."
    if command -v apt-get &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs || dnf install -y nodejs
    fi
else
    echo "Node.js 已安装: $(node --version)"
fi

# 检查并安装 Nginx
if ! command -v nginx &> /dev/null; then
    echo "安装 Nginx..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y nginx
    elif command -v dnf &> /dev/null; then
        dnf install -y nginx --disableexcludes=all
    elif command -v yum &> /dev/null; then
        yum install -y nginx
    fi
else
    echo "Nginx 已安装: $(nginx -v 2>&1)"
fi

# ========================================
# 2. 配置后端
# ========================================
echo ""
echo -e "${GREEN}[2/6] 配置后端...${NC}"

cd "$BACKEND_DIR"

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "创建 Python 虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境并安装依赖
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# 数据库迁移
echo "执行数据库迁移..."
python manage.py makemigrations ac_system --noinput
python manage.py migrate --noinput

# 初始化数据
echo "初始化房间数据..."
python init_data.py

deactivate

# ========================================
# 3. 构建前端
# ========================================
echo ""
echo -e "${GREEN}[3/6] 构建前端...${NC}"

cd "$FRONTEND_DIR"

# 安装依赖
npm install

# 构建生产版本
npm run build

# ========================================
# 4. 配置 Nginx
# ========================================
echo ""
echo -e "${GREEN}[4/6] 配置 Nginx...${NC}"

# 检查 Nginx 配置目录结构（CentOS 和 Ubuntu 不同）
if [ -d "/etc/nginx/sites-available" ]; then
    # Ubuntu/Debian 风格
    cp "$DEPLOY_DIR/nginx.conf" /etc/nginx/sites-available/hotel-ac
    
    if [ -f /etc/nginx/sites-enabled/hotel-ac ]; then
        rm /etc/nginx/sites-enabled/hotel-ac
    fi
    ln -s /etc/nginx/sites-available/hotel-ac /etc/nginx/sites-enabled/
    
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm /etc/nginx/sites-enabled/default
    fi
    
    sed -i "s|/opt/BUPT-air-conditioning|$PROJECT_DIR|g" /etc/nginx/sites-available/hotel-ac
else
    # CentOS/RHEL 风格
    cp "$DEPLOY_DIR/nginx.conf" /etc/nginx/conf.d/hotel-ac.conf
    sed -i "s|/opt/BUPT-air-conditioning|$PROJECT_DIR|g" /etc/nginx/conf.d/hotel-ac.conf
fi

# 测试 Nginx 配置
nginx -t

# ========================================
# 5. 配置 Systemd 服务
# ========================================
echo ""
echo -e "${GREEN}[5/6] 配置系统服务...${NC}"

# 复制服务文件
cp "$DEPLOY_DIR/hotel-ac.service" /etc/systemd/system/

# 替换路径
sed -i "s|/opt/BUPT-air-conditioning|$PROJECT_DIR|g" /etc/systemd/system/hotel-ac.service

# 重新加载 systemd
systemctl daemon-reload

# ========================================
# 6. 启动服务
# ========================================
echo ""
echo -e "${GREEN}[6/6] 启动服务...${NC}"

# 启动并设置开机自启
systemctl enable hotel-ac
systemctl restart hotel-ac
systemctl restart nginx

# ========================================
# 完成
# ========================================
echo ""
echo -e "${GREEN}=========================================="
echo "  部署完成！"
echo "==========================================${NC}"
echo ""
echo "访问地址: http://$(hostname -I | awk '{print $1}')"
echo ""
echo "常用命令:"
echo "  查看状态:   systemctl status hotel-ac"
echo "  重启服务:   systemctl restart hotel-ac"
echo "  查看日志:   journalctl -u hotel-ac -f"
echo "  Nginx日志:  tail -f /var/log/nginx/hotel-ac.error.log"
echo ""
