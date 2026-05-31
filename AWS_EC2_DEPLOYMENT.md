# AWS EC2 Deployment Guide

This guide covers deploying the Node.js app to an AWS EC2 instance.

## Prerequisites

1. **EC2 Instance**: Ubuntu 22.04 LTS or similar (t2.micro or larger)
2. **Security Group**: Allow inbound traffic on port 5006 (or your chosen port)
3. **SSH Key Pair**: For accessing your instance

## Step 1: Launch EC2 Instance

1. Go to AWS Console → EC2 → Instances → Launch Instance
2. Choose **Ubuntu 22.04 LTS** AMI
3. Select instance type (t2.micro or t3.micro recommended)
4. Configure security group:
   - SSH (22) from your IP
   - HTTP (80) - optional, if using reverse proxy
   - Custom TCP (5006) from your IP or 0.0.0.0/0
5. Create/select key pair and launch

## Step 2: Connect to Instance

```bash
ssh -i /path/to/key.pem ubuntu@<your-ec2-public-ip>
```

## Step 3: Install Node.js and PM2

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version
npm --version

# Install PM2 globally
sudo npm install -g pm2
```

## Step 4: Deploy Application

### Option A: Git Clone
```bash
cd /home/ubuntu
git clone https://github.com/your-username/your-repo.git
cd your-repo
npm install --production
```

### Option B: Upload ZIP
```bash
# On your local machine, create zip:
zip -r app.zip . -x "node_modules/*" ".git/*"

# On EC2, extract:
cd /home/ubuntu
unzip app.zip
npm install --production
```

## Step 5: Start App with PM2

```bash
# Start the app
pm2 start ecosystem.config.js

# Save PM2 config to restart on reboot
pm2 startup
sudo env PATH=$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu
pm2 save

# Monitor your app
pm2 status
pm2 logs
```

## Step 6: Configure Reverse Proxy (Optional but Recommended)

Using Nginx to handle traffic on port 80:

```bash
sudo apt install -y nginx

# Create Nginx config
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://localhost:5006;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx
```

Now access your app at `http://<your-ec2-public-ip>`

## Useful PM2 Commands

```bash
# View logs
pm2 logs nodejs-app

# Restart app
pm2 restart nodejs-app

# Stop app
pm2 stop nodejs-app

# Delete app
pm2 delete nodejs-app

# View real-time monitoring
pm2 monit
```

## Monitoring & Maintenance

```bash
# Check app status
pm2 status

# View detailed logs
pm2 logs --lines 100

# SSH into instance for debugging
ssh -i /path/to/key.pem ubuntu@<your-ec2-public-ip>
```

## Troubleshooting

**Port already in use:**
```bash
sudo lsof -i :5006
# Kill process if needed: sudo kill -9 <PID>
```

**App not starting:**
```bash
pm2 logs nodejs-app --err
```

**Permission issues:**
```bash
# Ensure files are readable by ubuntu user
sudo chown -R ubuntu:ubuntu /home/ubuntu/your-repo
```

## Cost Optimization

- Use t2.micro or t3.micro for low-traffic apps (eligible for free tier)
- Enable auto-stop in off-hours if not needed 24/7
- Use CloudWatch for monitoring

## Security Best Practices

- Keep security group rules minimal
- Use SSH key pairs (never use password auth)
- Keep Node.js and packages updated: `npm update`
- Use environment variables for sensitive data (.env file, not committed)
- Consider using Systems Manager Session Manager instead of opening SSH port publicly
