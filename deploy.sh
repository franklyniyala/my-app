#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Node.js App Deployment Script${NC}"
echo ""

# Configuration
EC2_HOST=${1:-}
EC2_KEY=${2:-}
EC2_USER=${3:-ubuntu}
APP_NAME="nodejs-app"
APP_PORT=${APP_PORT:-5006}

# Check arguments
if [ -z "$EC2_HOST" ] || [ -z "$EC2_KEY" ]; then
  echo -e "${RED}Usage: ./deploy.sh <EC2_IP_OR_HOSTNAME> <SSH_KEY_PATH> [SSH_USER]${NC}"
  echo ""
  echo "Examples:"
  echo "  ./deploy.sh 54.123.45.67 ~/.ssh/my-key.pem"
  echo "  ./deploy.sh ec2-instance.amazonaws.com ~/.ssh/my-key.pem ubuntu"
  exit 1
fi

# Verify SSH key exists
if [ ! -f "$EC2_KEY" ]; then
  echo -e "${RED}❌ SSH key not found: $EC2_KEY${NC}"
  exit 1
fi

echo -e "${YELLOW}📋 Deployment Configuration:${NC}"
echo "  Host: $EC2_HOST"
echo "  User: $EC2_USER"
echo "  Key: $EC2_KEY"
echo "  App Name: $APP_NAME"
echo "  Port: $APP_PORT"
echo ""

# Test SSH connection
echo -e "${YELLOW}🔗 Testing SSH connection...${NC}"
if ! ssh -i "$EC2_KEY" -o ConnectTimeout=5 "$EC2_USER@$EC2_HOST" "echo 'SSH connection successful'" > /dev/null 2>&1; then
  echo -e "${RED}❌ Failed to connect to $EC2_HOST${NC}"
  exit 1
fi
echo -e "${GREEN}✓ SSH connection successful${NC}"
echo ""

# Create deployment directory
DEPLOY_DIR="/home/$EC2_USER/nodejs-app"
echo -e "${YELLOW}📁 Creating deployment directory...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "mkdir -p $DEPLOY_DIR"
echo -e "${GREEN}✓ Directory created${NC}"
echo ""

# Upload files
echo -e "${YELLOW}📤 Uploading application files...${NC}"
rsync -avz -e "ssh -i $EC2_KEY" \
  --exclude node_modules \
  --exclude .git \
  --exclude .env \
  --exclude logs \
  --exclude terraform.tfstate \
  --exclude devops-kubeconfig-file \
  --exclude Jenkinsfile \
  ./ "$EC2_USER@$EC2_HOST:$DEPLOY_DIR/"
echo -e "${GREEN}✓ Files uploaded${NC}"
echo ""

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies on EC2...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "cd $DEPLOY_DIR && npm install --production"
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Setup Node.js and PM2 if not already done
echo -e "${YELLOW}🔧 Checking Node.js and PM2...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" bash << 'SETUP_SCRIPT'
if ! command -v node &> /dev/null; then
  echo "  Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if ! command -v pm2 &> /dev/null; then
  echo "  Installing PM2..."
  sudo npm install -g pm2
fi

echo "Node.js version: $(node --version)"
echo "PM2 version: $(pm2 --version)"
SETUP_SCRIPT
echo -e "${GREEN}✓ Node.js and PM2 verified${NC}"
echo ""

# Stop existing PM2 app
echo -e "${YELLOW}🛑 Stopping existing PM2 app (if running)...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "pm2 stop nodejs-app 2>/dev/null || true"
echo -e "${GREEN}✓ Stopped${NC}"
echo ""

# Start with PM2
echo -e "${YELLOW}▶️  Starting app with PM2...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "cd $DEPLOY_DIR && pm2 start ecosystem.config.js"
echo -e "${GREEN}✓ App started${NC}"
echo ""

# Save PM2 config for auto-restart on reboot
echo -e "${YELLOW}💾 Saving PM2 configuration...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" bash << 'PM2_SETUP'
pm2 save
echo "Setting up PM2 startup script..."
pm2 startup systemd -u ubuntu --hp /home/ubuntu > /dev/null 2>&1 || true
sudo env PATH=$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu > /dev/null 2>&1 || true
PM2_SETUP
echo -e "${GREEN}✓ PM2 configured for auto-restart${NC}"
echo ""

# Display status
echo -e "${YELLOW}📊 App Status:${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "pm2 status"
echo ""

# Get app details
echo -e "${YELLOW}🌐 Application Details:${NC}"
echo "  URL: http://$EC2_HOST:$APP_PORT"
echo "  SSH: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST"
echo ""

# Display logs
echo -e "${YELLOW}📝 Recent logs:${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "pm2 logs nodejs-app --lines 5 --nostream" || true
echo ""

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Useful commands:"
echo "  View logs:     ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'pm2 logs nodejs-app'"
echo "  Restart app:   ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'pm2 restart nodejs-app'"
echo "  Stop app:      ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'pm2 stop nodejs-app'"
echo "  Delete app:    ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'pm2 delete nodejs-app'"
