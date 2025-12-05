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
# 1. 检查系统依赖（仅检查不安装）
# ========================================
echo ""
echo -e "${GREEN}[1/6] 检查系统依赖...${NC}"

# 检查 Python3 (优先使用 python3.11)
PYTHON_CMD=""
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
    echo "✓ Python3.11 已安装: $(python3.11 --version)"
elif command -v python3.10 &> /dev/null; then
    PYTHON_CMD="python3.10"
    echo "✓ Python3.10 已安装: $(python3.10 --version)"
elif command -v python3 &> /dev/null; then
    PY_VERSION=$(python3 -c 'import sys; print(sys.version_info.minor)')
    if [ "$PY_VERSION" -ge 8 ]; then
        PYTHON_CMD="python3"
        echo "✓ Python3 已安装: $(python3 --version)"
    else
        echo -e "${RED}✗ Python 版本过低，需要 Python 3.8+${NC}"
        echo -e "${YELLOW}请安装: sudo dnf install -y python3.11 python3.11-pip${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ 请先安装 Python3.8+${NC}"
    echo -e "${YELLOW}请安装: sudo dnf install -y python3.11 python3.11-pip${NC}"
    exit 1
fi

# 检查 Node.js
if command -v node &> /dev/null; then
    echo "✓ Node.js 已安装: $(node --version)"
else
    echo -e "${RED}✗ 请先安装 Node.js: curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash - && sudo yum install -y nodejs${NC}"
    exit 1
fi

# 检查 Nginx
if command -v nginx &> /dev/null; then
    echo "✓ Nginx 已安装: $(nginx -v 2>&1)"
else
    echo -e "${RED}✗ 请先安装 Nginx: sudo dnf install -y nginx --disableexcludes=all${NC}"
    exit 1
fi

echo -e "${GREEN}所有依赖已就绪${NC}"

# ========================================
# 2. 配置后端
# ========================================
echo ""
echo -e "${GREEN}[2/6] 配置后端...${NC}"

cd "$BACKEND_DIR"

# 创建虚拟环境（使用检测到的 Python 版本）
if [ ! -d "venv" ]; then
    echo "创建 Python 虚拟环境 (使用 $PYTHON_CMD)..."
    $PYTHON_CMD -m venv venv
fi

# 激活虚拟环境并安装依赖
source venv/bin/activate
pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
pip install gunicorn -i https://pypi.tuna.tsinghua.edu.cn/simple

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
