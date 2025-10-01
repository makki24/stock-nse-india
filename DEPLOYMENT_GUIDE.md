# Stock NSE India API - Deployment Guide

This guide provides comprehensive instructions for deploying the Stock NSE India API to your server infrastructure using Jenkins CI/CD pipelines.

## 📋 Overview

The Stock NSE India API provides real-time and historical stock market data from the National Stock Exchange of India. This deployment integrates with your existing MutualFundManager application to provide local stock price data.

## 🏗️ Architecture

### Deployment Infrastructure
- **Jenkins Server:** http://129.213.59.8:8080/
- **Target Server:** 129.213.146.93
- **SSH Key:** `/projects/ssh-key-2023-05-29.key`

### Port Allocation
- **Development:** 3000
- **QA:** 3001
- **Production:** 3002

### Integration Points
- **MutualFundManager:** Uses LocalStockPriceService to fetch data from deployed NSE India API
- **API Endpoint:** `http://129.213.146.93:3000/api/equity/{symbol}`

## 🚀 Deployment Methods

### Method 1: Jenkins Pipeline (Recommended)

#### Step 1: Create Jenkins Jobs

1. **Create Build Job:**
   - Job Name: `StockNSEIndia-Build`
   - Type: Pipeline
   - Pipeline Script: Use content from `scripts/jenkins/build-release`

2. **Create Deployment Job:**
   - Job Name: `StockNSEIndia-Promotion`
   - Type: Pipeline
   - Pipeline Script: Use content from `scripts/jenkins/promotion`

#### Step 2: Configure Jenkins Credentials

Add the following credentials in Jenkins:
- `github-credentials`: GitHub access token for repository access
- `ssh-key-2023-05-29`: SSH private key for server deployment

#### Step 3: Run Deployment

1. Navigate to Jenkins: http://129.213.59.8:8080/
2. Run `StockNSEIndia-Build` job with parameters:
   - **BRANCH:** master (or your target branch)
   - **ENV:** dev/qa/prod
   - **DEPLOY_DIRECTORY:** /projects/temp/

3. The build job will automatically trigger the promotion job for deployment

### Method 2: Manual Deployment

#### Prerequisites
- Node.js 18+ installed on build machine
- SSH access to target server (129.213.146.93)
- SSH key available at `/projects/ssh-key-2023-05-29.key`

#### Step 1: Build Release
```bash
cd /home/maqthyar/d/projects/cp/stock-nse-india
./scripts/build-release.sh
```

#### Step 2: Deploy to Server
```bash
# Deploy to development environment
./scripts/deploy.sh dev

# Deploy to QA environment
./scripts/deploy.sh qa

# Deploy to production environment
./scripts/deploy.sh prod
```

## 🔧 Configuration

### Environment Variables

Create environment-specific configuration files:

**Development (.env.dev):**
```bash
PORT=3000
NODE_ENV=development
CORS_ORIGINS=http://localhost:4200,http://129.213.146.93:8085
LOG_LEVEL=debug
```

**QA (.env.qa):**
```bash
PORT=3001
NODE_ENV=staging
CORS_ORIGINS=http://129.213.146.93:9083
LOG_LEVEL=info
```

**Production (.env.prod):**
```bash
PORT=3002
NODE_ENV=production
CORS_ORIGINS=http://129.213.146.93:8090
LOG_LEVEL=warn
```

### CORS Configuration

The API is configured to allow requests from MutualFundManager applications:
- Development: http://129.213.146.93:8085
- QA: http://129.213.146.93:9083
- Production: http://129.213.146.93:8090

## 🔗 MutualFundManager Integration

### Configuration Update

The MutualFundManager has been updated to use the deployed NSE India API:

**application-template.properties:**
```properties
# Local Stock API Configuration (NSE India API)
local.stock.api.base-url=http://129.213.146.93:3000
local.stock.api.timeout=10000
```

### API Usage

The LocalStockPriceService in MutualFundManager will:
1. Remove `.BO` suffix from stock symbols
2. Call `http://129.213.146.93:3000/api/equity/{symbol}`
3. Extract closing price from `priceInfo.close` field

## 📊 API Endpoints

### Core Endpoints
- **Health Check:** `GET /`
- **Market Status:** `GET /api/marketStatus`
- **Equity Details:** `GET /api/equity/{symbol}`
- **Historical Data:** `GET /api/equity/{symbol}/historical`
- **All Indices:** `GET /api/indices`

### Documentation
- **API Documentation:** `http://129.213.146.93:3000/api-docs`
- **GraphQL Playground:** `http://129.213.146.93:3000/graphql`

## 🔍 Monitoring & Troubleshooting

### Log Files
```bash
# View application logs
ssh ubuntu@129.213.146.93 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-dev.log'

# View QA logs
ssh ubuntu@129.213.146.93 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-qa.log'

# View production logs
ssh ubuntu@129.213.146.93 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-prod.log'
```

### Process Management
```bash
# Check if application is running
ssh ubuntu@129.213.146.93 'ps aux | grep node'

# Stop application
ssh ubuntu@129.213.146.93 'kill $(cat /home/ubuntu/projects/stock-nse-india/dev/stock-nse-india.pid)'

# Check application status
curl -f http://129.213.146.93:3000/
```

### Health Checks
```bash
# Test API endpoints
curl http://129.213.146.93:3000/api/marketStatus
curl http://129.213.146.93:3000/api/equity/RELIANCE
curl http://129.213.146.93:3000/api/indices
```

## 🚨 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Find process using port
   ssh ubuntu@129.213.146.93 'lsof -i :3000'
   
   # Kill process
   ssh ubuntu@129.213.146.93 'kill -9 <PID>'
   ```

2. **Node.js Version Issues**
   ```bash
   # Check Node.js version
   node --version
   
   # Install Node.js 18+ if needed
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Permission Issues**
   ```bash
   # Fix file permissions
   chmod +x scripts/build-release.sh
   chmod +x scripts/deploy.sh
   ```

4. **SSH Connection Issues**
   ```bash
   # Test SSH connection
   ssh -i /projects/ssh-key-2023-05-29.key ubuntu@129.213.146.93 'echo "Connection successful"'
   ```

### Error Codes
- **EADDRINUSE:** Port already in use - stop existing process
- **ECONNREFUSED:** Cannot connect to NSE India servers - check internet connectivity
- **ENOENT:** File not found - verify build artifacts exist

## 🔄 Rollback Procedure

If deployment fails or issues arise:

1. **Stop Current Application:**
   ```bash
   ssh ubuntu@129.213.146.93 'kill $(cat /home/ubuntu/projects/stock-nse-india/dev/stock-nse-india.pid)'
   ```

2. **Restore Previous Version:**
   ```bash
   # List available releases
   ssh ubuntu@129.213.146.93 'ls -la /home/ubuntu/projects/stock-nse-india/'
   
   # Restore previous release
   ssh ubuntu@129.213.146.93 'cd /home/ubuntu/projects/stock-nse-india/dev && rm -rf current && mv previous-release current'
   ```

3. **Restart Application:**
   ```bash
   ssh ubuntu@129.213.146.93 'cd /home/ubuntu/projects/stock-nse-india/dev/current && nohup node build/server.js > /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-dev.log 2>&1 &'
   ```

## 📈 Performance Optimization

### Production Recommendations
- **Memory:** Allocate at least 512MB RAM per environment
- **CPU:** 1 vCPU minimum for production workloads
- **Disk:** 1GB storage for logs and application files
- **Network:** Ensure stable internet connection for NSE data fetching

### Monitoring
- Set up log rotation to prevent disk space issues
- Monitor API response times and error rates
- Implement health check endpoints for load balancers

## 🔐 Security Considerations

1. **CORS Configuration:** Restrict origins to known MutualFundManager instances
2. **Rate Limiting:** Implement rate limiting to prevent API abuse
3. **SSL/TLS:** Consider adding HTTPS termination via reverse proxy
4. **Firewall:** Restrict access to API ports from authorized sources only

## 📞 Support

For deployment issues or questions:
1. Check application logs first
2. Verify Jenkins build logs
3. Test API endpoints manually
4. Review this deployment guide

## 🎯 Next Steps

After successful deployment:
1. Test API integration with MutualFundManager
2. Monitor application performance and logs
3. Set up automated health checks
4. Configure log rotation and cleanup
5. Plan for scaling if needed

---

**✅ Deployment Complete!** Your Stock NSE India API should now be running and integrated with MutualFundManager for local stock price data.
