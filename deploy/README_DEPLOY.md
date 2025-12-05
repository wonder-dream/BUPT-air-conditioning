# Linux 服务器部署指南

## 📋 系统要求

- **操作系统**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **配置**: 2核 2GB 内存即可
- **软件**: Python 3.10+, Node.js 18+, Nginx

---

## 🚀 快速部署

### 方式一：一键部署脚本

```bash
# 1. 上传项目到服务器
scp -r BUPT-air-conditioning root@你的服务器IP:/opt/

# 2. SSH 登录服务器
ssh root@你的服务器IP

# 3. 执行部署脚本
cd /opt/BUPT-air-conditioning/deploy
chmod +x deploy.sh
./deploy.sh
```

### 方式二：手动部署

#### 1. 安装系统依赖

```bash
# Ubuntu/Debian
apt update
apt install -y python3 python3-pip python3-venv nginx

# 安装 Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
```

#### 2. 配置后端

```bash
cd /opt/BUPT-air-conditioning/backend

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
pip install gunicorn

# 数据库迁移
python manage.py migrate

# 初始化数据
python init_data.py

deactivate
```

#### 3. 构建前端

```bash
cd /opt/BUPT-air-conditioning/frontend

# 安装依赖并构建
npm install
npm run build
```

#### 4. 配置 Nginx

```bash
# 复制配置文件
cp /opt/BUPT-air-conditioning/deploy/nginx.conf /etc/nginx/sites-available/hotel-ac

# 启用站点
ln -s /etc/nginx/sites-available/hotel-ac /etc/nginx/sites-enabled/

# 删除默认站点（可选）
rm /etc/nginx/sites-enabled/default

# 测试并重启
nginx -t
systemctl restart nginx
```

#### 5. 配置 Systemd 服务

```bash
# 复制服务文件
cp /opt/BUPT-air-conditioning/deploy/hotel-ac.service /etc/systemd/system/

# 启动服务
systemctl daemon-reload
systemctl enable hotel-ac
systemctl start hotel-ac
```

---

## 📋 服务管理

```bash
# 查看服务状态
systemctl status hotel-ac

# 启动/停止/重启
systemctl start hotel-ac
systemctl stop hotel-ac
systemctl restart hotel-ac

# 查看日志
journalctl -u hotel-ac -f

# 查看后端日志
tail -f /var/log/hotel-ac/error.log

# 查看 Nginx 日志
tail -f /var/log/nginx/hotel-ac.error.log
```

---

## 🔧 常见问题

### Q: 502 Bad Gateway
```bash
# 检查后端是否运行
systemctl status hotel-ac

# 检查端口是否监听
ss -tlnp | grep 8000
```

### Q: 前端页面空白
```bash
# 检查前端是否构建
ls /opt/BUPT-air-conditioning/frontend/dist/

# 重新构建
cd /opt/BUPT-air-conditioning/frontend
npm run build
```

### Q: 数据库错误
```bash
# 重新迁移
cd /opt/BUPT-air-conditioning/backend
source venv/bin/activate
python manage.py migrate
python init_data.py
```

---

## 🔒 安全建议（生产环境）

1. **修改 Django SECRET_KEY**
   ```python
   # backend/hotel_ac/settings.py
   SECRET_KEY = '你的随机密钥'
   DEBUG = False
   ALLOWED_HOSTS = ['你的域名']
   ```

2. **配置 HTTPS**
   ```bash
   # 使用 Let's Encrypt
   apt install certbot python3-certbot-nginx
   certbot --nginx -d 你的域名
   ```

3. **配置防火墙**
   ```bash
   ufw allow 80
   ufw allow 443
   ufw enable
   ```

---

## 📊 资源占用

| 组件 | 内存 | CPU |
|------|------|-----|
| Gunicorn (2 workers) | ~150MB | 低 |
| Nginx | ~20MB | 极低 |
| SQLite | ~10MB | 极低 |
| **总计** | **~200MB** | **低** |

2C2G 服务器完全足够运行此项目。
