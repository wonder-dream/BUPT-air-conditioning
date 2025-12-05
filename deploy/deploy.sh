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
# 1. 安装系统依赖
# ========================================
echo ""
echo -e "${GREEN}[1/6] 安装系统依赖...${NC}"

if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y python3 python3-pip python3-venv nginx nodejs npm
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    yum install -y python3 python3-pip nginx nodejs npm
elif command -v dnf &> /dev/null; then
    # Fedora
    dnf install -y python3 python3-pip nginx nodejs npm
else
    echo -e "${RED}无法识别的包管理器，请手动安装依赖${NC}"
    exit 1
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

# 复制 Nginx 配置
cp "$DEPLOY_DIR/nginx.conf" /etc/nginx/sites-available/hotel-ac

# 创建软链接
if [ -f /etc/nginx/sites-enabled/hotel-ac ]; then
    rm /etc/nginx/sites-enabled/hotel-ac
fi
ln -s /etc/nginx/sites-available/hotel-ac /etc/nginx/sites-enabled/

# 删除默认配置（可选）
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

# 替换配置中的路径
sed -i "s|/opt/BUPT-air-conditioning|$PROJECT_DIR|g" /etc/nginx/sites-available/hotel-ac

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
