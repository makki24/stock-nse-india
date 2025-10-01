#!/bin/bash

# Stock NSE India - Deployment Script
# This script deploys the Node.js application to target server

set -e

# Configuration
PROJECT_NAME="stock-nse-india"
BUILD_DIR="/projects/temp"
SSH_KEY="/projects/ssh-key-2023-05-29.key"
TARGET_HOST="129.213.146.93"
TARGET_USER="ubuntu"

# Default values
ENVIRONMENT=${1:-dev}
RELEASE_NAME=${2:-""}

# Environment-specific configuration
case "$ENVIRONMENT" in
    dev)
        PORT=3000
        ;;
    qa)
        PORT=3001
        ;;
    prod)
        PORT=3002
        ;;
    *)
        echo "❌ Error: Invalid environment. Use: dev, qa, or prod"
        exit 1
        ;;
esac

echo "🚀 Deploying Stock NSE India to $ENVIRONMENT environment..."
echo "📡 Target: $TARGET_HOST:$PORT"

# Validate inputs
if [ -z "$RELEASE_NAME" ]; then
    # Find latest release if not specified
    RELEASE_NAME=$(ls -t "$BUILD_DIR"/${PROJECT_NAME}-*.tar.gz 2>/dev/null | head -1 | xargs basename -s .tar.gz)
    if [ -z "$RELEASE_NAME" ]; then
        echo "❌ Error: No release package found. Run build-release.sh first."
        exit 1
    fi
fi

RELEASE_PACKAGE="$BUILD_DIR/${RELEASE_NAME}.tar.gz"

# Validate release package exists
if [ ! -f "$RELEASE_PACKAGE" ]; then
    echo "❌ Error: Release package not found: $RELEASE_PACKAGE"
    exit 1
fi

# Validate SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Error: SSH key not found: $SSH_KEY"
    exit 1
fi

echo "📦 Deploying release: $RELEASE_NAME"

# Create remote directories
echo "📁 Creating remote directories..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "
    mkdir -p /home/ubuntu/projects/stock-nse-india/$ENVIRONMENT
    mkdir -p /home/ubuntu/projects/logs/stock-nse-india
"

# Copy release package to server
echo "📤 Copying release package to server..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$RELEASE_PACKAGE" "$TARGET_USER@$TARGET_HOST:/home/ubuntu/projects/stock-nse-india/"

# Extract and setup on server
echo "📦 Extracting and setting up application..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "
    cd /home/ubuntu/projects/stock-nse-india/
    
    # Extract release
    tar -xzf ${RELEASE_NAME}.tar.gz
    
    # Remove old deployment if exists
    rm -rf $ENVIRONMENT/current
    
    # Move new deployment to environment directory
    mv $RELEASE_NAME $ENVIRONMENT/current
    
    # Clean up archive
    rm -f ${RELEASE_NAME}.tar.gz
    
    echo '✅ Application extracted and ready'
"

# Stop existing application
echo "🛑 Stopping existing application..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "
    PID_FILE=\"/home/ubuntu/projects/stock-nse-india/$ENVIRONMENT/stock-nse-india.pid\"
    if [ -f \"\$PID_FILE\" ]; then
        OLD_PID=\$(cat \"\$PID_FILE\")
        if ps -p \$OLD_PID > /dev/null 2>&1; then
            echo \"Stopping existing application (PID: \$OLD_PID)...\"
            kill \$OLD_PID
            sleep 5
            # Force kill if still running
            if ps -p \$OLD_PID > /dev/null 2>&1; then
                kill -9 \$OLD_PID
            fi
        fi
        rm -f \"\$PID_FILE\"
    fi
"

# Start new application
echo "🚀 Starting new application..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_HOST" "
    cd /home/ubuntu/projects/stock-nse-india/$ENVIRONMENT/current
    
    # Set environment variables
    export NODE_ENV=$ENVIRONMENT
    export PORT=$PORT
    
    # Start application in background
    nohup node build/server.js > /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-$ENVIRONMENT.log 2>&1 &
    NEW_PID=\$!
    
    # Save PID
    echo \$NEW_PID > /home/ubuntu/projects/stock-nse-india/$ENVIRONMENT/stock-nse-india.pid
    
    echo \"✅ Application started with PID: \$NEW_PID\"
    echo \"🌐 URL: http://$TARGET_HOST:$PORT\"
    echo \"📊 API Docs: http://$TARGET_HOST:$PORT/api-docs\"
    echo \"🔍 GraphQL: http://$TARGET_HOST:$PORT/graphql\"
"

# Health check
echo "🏥 Performing health check..."
sleep 10

# Test if application is responding
if curl -f -s "http://$TARGET_HOST:$PORT/" > /dev/null; then
    echo "✅ Health check passed - Application is running successfully"
    echo "
🎉 Deployment completed successfully!

📊 Application Details:
- Environment: $ENVIRONMENT
- URL: http://$TARGET_HOST:$PORT
- API Documentation: http://$TARGET_HOST:$PORT/api-docs
- GraphQL Playground: http://$TARGET_HOST:$PORT/graphql
- Logs: ssh $TARGET_USER@$TARGET_HOST 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-$ENVIRONMENT.log'

🔧 Management Commands:
- View logs: ssh $TARGET_USER@$TARGET_HOST 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-$ENVIRONMENT.log'
- Stop app: ssh $TARGET_USER@$TARGET_HOST 'kill \$(cat /home/ubuntu/projects/stock-nse-india/$ENVIRONMENT/stock-nse-india.pid)'
"
else
    echo "⚠️ Health check failed - Application may still be starting"
    echo "Check logs: ssh $TARGET_USER@$TARGET_HOST 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-$ENVIRONMENT.log'"
fi
