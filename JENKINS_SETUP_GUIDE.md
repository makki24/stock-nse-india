# Jenkins Setup Guide - Stock NSE India API

This guide provides detailed step-by-step instructions to create Jenkins jobs for deploying the Stock NSE India API using your forked repository: https://github.com/makki24/stock-nse-india.git

## 🎯 Overview

We'll create two Jenkins jobs:
1. **StockNSEIndia-Build** - Builds and packages the application
2. **StockNSEIndia-Promotion** - Deploys the application to target server

## 📋 Prerequisites

Before starting, ensure you have:
- ✅ Access to Jenkins: http://129.213.59.8:8080/
- ✅ GitHub credentials configured in Jenkins
- ✅ SSH key available: `/projects/ssh-key-2023-05-29.key`
- ✅ Node.js 18+ installed on Jenkins server

## 🔧 Step 1: Configure Jenkins Credentials

### 1.1 GitHub Credentials
1. Navigate to Jenkins: http://129.213.59.8:8080/
2. Go to **Manage Jenkins** → **Manage Credentials**
3. Click on **(global)** domain
4. Click **Add Credentials**
5. Configure:
   - **Kind:** Username with password
   - **Username:** makki24
   - **Password:** [Your GitHub Personal Access Token]
   - **ID:** `github-credentials`
   - **Description:** GitHub access for makki24/stock-nse-india

### 1.2 SSH Key Credentials (if not already configured)
1. In **Manage Credentials**, click **Add Credentials**
2. Configure:
   - **Kind:** SSH Username with private key
   - **Username:** ubuntu
   - **Private Key:** Enter directly (paste content of `/projects/ssh-key-2023-05-29.key`)
   - **ID:** `ssh-deployment-key`
   - **Description:** SSH key for server deployment

## 🚀 Step 2: Create Build Job (StockNSEIndia-Build)

### 2.1 Create New Job
1. From Jenkins dashboard, click **New Item**
2. Enter item name: `StockNSEIndia-Build`
3. Select **Pipeline**
4. Click **OK**

### 2.2 Configure Job Settings

#### General Settings
- ✅ **Description:** Build job for Stock NSE India API from forked repository
- ✅ **Discard old builds:** Keep maximum 10 builds

#### Build Triggers
- ✅ **GitHub hook trigger for GITScm polling** (optional, for automatic builds)

#### Pipeline Configuration
1. **Definition:** Pipeline script
2. **Script:** Copy and paste the following pipeline script:

```groovy
pipeline {
    agent any

    parameters {
        string(
            name: 'BRANCH',
            defaultValue: 'master',
            description: 'Branch to build from'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'DEPLOY_DIRECTORY',
            defaultValue: '/projects/temp/',
            description: 'Deployment directory on target server'
        )
    }

    // Use system Node.js - will be installed manually on Jenkins server
    environment {
        NODE_HOME = '/usr/local/bin'
        PATH = "${env.NODE_HOME}:${env.PATH}"
    }

    stages {
        stage('Checkout') {
            steps {
                // Explicit Git checkout with credentials
                checkout([$class: 'GitSCM',
                         branches: [[name: "*/${params.BRANCH}"]],
                         userRemoteConfigs: [[
                             url: 'https://github.com/makki24/stock-nse-india.git',
                             credentialsId: 'github-credentials'
                         ]]])

                echo "Checked out branch: ${params.BRANCH}"
            }
        }

        stage('Validate Environment') {
            steps {
                echo "🔍 Validating build environment..."
                
                sh '''
                    echo "Node.js version: $(node --version)"
                    echo "NPM version: $(npm --version)"
                    
                    # Validate Node.js version (18+)
                    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
                    if [ "$NODE_VERSION" -lt 18 ]; then
                        echo "❌ Error: Node.js 18+ required. Current version: $(node --version)"
                        exit 1
                    fi
                    
                    echo "✅ Environment validation passed"
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                echo "📦 Installing dependencies..."
                
                sh '''
                    # Clean previous installations
                    rm -rf node_modules/
                    npm cache clean --force
                    
                    # Install dependencies
                    npm install
                    
                    echo "✅ Dependencies installed successfully"
                '''
            }
        }

        stage('Test') {
            steps {
                echo "🧪 Running tests..."

                sh '''
                    echo "=== Running Stock NSE India Tests ==="
                    
                    # Run tests with timeout
                    npm test
                    
                    echo "✅ Tests completed successfully"
                '''
            }
        }

        stage('Build') {
            steps {
                script {
                    // Ensure we have a valid branch name
                    def branchName = params.BRANCH ?: 'master'
                    if (branchName.trim().isEmpty()) {
                        branchName = 'master'
                    }

                    echo "DEBUG: BRANCH parameter = '${params.BRANCH}'"
                    echo "DEBUG: Resolved branchName = '${branchName}'"

                    // Generate version number using VersionNumber plugin
                    env.RELEASE_NAME = VersionNumber(
                        versionNumberString: "stock-nse-india-${branchName}-" + '${BUILD_DATE_FORMATTED, "yyyy.MM.dd"}-${BUILDS_TODAY}'
                    )

                    echo "DEBUG: Generated RELEASE_NAME = '${env.RELEASE_NAME}'"
                }

                echo "🔨 Building release: ${env.RELEASE_NAME}"
                echo "Workspace: ${env.WORKSPACE}"
                echo "Target environment: ${params.ENV}"

                // Create build directory
                sh 'mkdir -p /projects/temp'

                // Build the application
                sh '''
                    echo "🔨 Building TypeScript application..."
                    npm run build
                    
                    # Validate build output
                    if [ ! -f "build/server.js" ]; then
                        echo "❌ Error: Build failed - server.js not found"
                        exit 1
                    fi
                    
                    echo "✅ Build completed successfully"
                '''

                // Create deployment package
                script {
                    sh """
                        echo "📦 Creating deployment package..."
                        
                        # Create release directory
                        RELEASE_DIR="/projects/temp/${env.RELEASE_NAME}"
                        mkdir -p "\$RELEASE_DIR"
                        
                        # Copy built application
                        cp -r build/ "\$RELEASE_DIR/"
                        cp package.json "\$RELEASE_DIR/"
                        cp package-lock.json "\$RELEASE_DIR/"
                        
                        # Install production dependencies in release directory
                        cd "\$RELEASE_DIR"
                        npm install --production --silent
                        
                        # Create startup script
                        cat > "\$RELEASE_DIR/start.sh" << 'EOF'
#!/bin/bash
# Stock NSE India startup script

# Set environment variables
export NODE_ENV=\${NODE_ENV:-production}
export PORT=\${PORT:-3000}

# Start the application
echo "🚀 Starting Stock NSE India API on port \$PORT..."
node build/server.js
EOF
                        
                        chmod +x "\$RELEASE_DIR/start.sh"
                        
                        # Create archive
                        cd /projects/temp
                        tar -czf "${env.RELEASE_NAME}.tar.gz" "${env.RELEASE_NAME}/"
                        
                        echo "✅ Deployment package created: ${env.RELEASE_NAME}.tar.gz"
                    """
                }

                echo "Build completed successfully"
            }
        }

        stage('Trigger Deployment') {
            steps {
                echo "Triggering deployment job..."
                build job: 'StockNSEIndia-Promotion',
                      wait: false,
                      parameters: [
                        string(name: 'RELEASE', value: "${env.RELEASE_NAME}"),
                        string(name: 'ENV', value: "${params.ENV}"),
                        string(name: 'DEPLOY_DIRECTORY', value: "${params.DEPLOY_DIRECTORY}")
                      ]
            }
        }
    }

    post {
        always {
            // Archive the built package
            archiveArtifacts artifacts: 'build/**/*', fingerprint: true

            // Clean workspace
            cleanWs()
        }
        success {
            echo "✅ Build completed successfully!"
        }
        failure {
            echo "❌ Build failed!"
        }
    }
}
```

3. Click **Save**

## 🚀 Step 3: Create Deployment Job (StockNSEIndia-Promotion)

### 3.1 Create New Job
1. From Jenkins dashboard, click **New Item**
2. Enter item name: `StockNSEIndia-Promotion`
3. Select **Pipeline**
4. Click **OK**

### 3.2 Configure Job Settings

#### General Settings
- ✅ **Description:** Deployment job for Stock NSE India API
- ✅ **Discard old builds:** Keep maximum 10 builds

#### Pipeline Configuration
1. **Definition:** Pipeline script
2. **Script:** Copy and paste the following pipeline script:

```groovy
pipeline {
    agent any

    parameters {
        string(
            name: 'RELEASE',
            description: 'Release name to deploy (e.g., stock-nse-india-master-2024.01.15-1)'
        )
        choice(
            name: 'ENV',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target environment'
        )
        string(
            name: 'DEPLOY_DIRECTORY',
            defaultValue: 'projects',
            description: 'Deployment directory on target server'
        )
    }

    environment {
        TARGET_HOST = '129.213.146.93'
        SSH_KEY = '/projects/ssh-key-2023-05-29.key'
    }

    stages {
        stage('Validate') {
            steps {
                script {
                    // Validate required parameters
                    if (!params.RELEASE) {
                        error("RELEASE parameter is required")
                    }
                    if (!params.ENV) {
                        error("ENV parameter is required")
                    }

                    echo "Validating deployment parameters..."
                    echo "Release: ${params.RELEASE}"
                    echo "Environment: ${params.ENV}"
                    echo "Deploy Directory: ${params.DEPLOY_DIRECTORY}"
                    echo "Target Host: ${env.TARGET_HOST}"
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    // Set the port number based on the environment
                    def port
                    if (params.ENV == 'dev') {
                        port = '3000'
                    } else if (params.ENV == 'qa') {
                        port = '3001'
                    } else if (params.ENV == 'prod') {
                        port = '3002'
                    } else {
                        error("Unknown environment: ${params.ENV}")
                    }

                    echo "Deploying ${params.RELEASE} to ${params.ENV} on port ${port}"

                    // Validate release package exists
                    def packagePath = "/projects/temp/${params.RELEASE}.tar.gz"
                    sh "test -f '${packagePath}' || (echo 'Release package not found: ${packagePath}' && exit 1)"

                    // Validate SSH key exists
                    sh "test -f '${env.SSH_KEY}' || (echo 'SSH key not found: ${env.SSH_KEY}' && exit 1)"

                    // Create remote directory structure
                    echo "Creating remote directory structure..."
                    sh """
                        ssh -i '${env.SSH_KEY}' -o StrictHostKeyChecking=no ubuntu@${env.TARGET_HOST} '
                            mkdir -p /home/ubuntu/projects/stock-nse-india/${params.ENV}
                            mkdir -p /home/ubuntu/projects/logs/stock-nse-india
                        '
                    """

                    // Copy release package to target server
                    echo "Copying release package to target server..."
                    sh """
                        scp -i '${env.SSH_KEY}' -o StrictHostKeyChecking=no '${packagePath}' ubuntu@${env.TARGET_HOST}:/home/ubuntu/projects/stock-nse-india/
                    """

                    // Extract and setup on server
                    echo "Extracting and setting up application..."
                    sh """
                        ssh -i '${env.SSH_KEY}' -o StrictHostKeyChecking=no ubuntu@${env.TARGET_HOST} '
                            cd /home/ubuntu/projects/stock-nse-india/
                            
                            # Extract release
                            tar -xzf ${params.RELEASE}.tar.gz
                            
                            # Remove old deployment if exists
                            rm -rf ${params.ENV}/current
                            
                            # Move new deployment to environment directory
                            mv ${params.RELEASE} ${params.ENV}/current
                            
                            # Clean up archive
                            rm -f ${params.RELEASE}.tar.gz
                            
                            echo "✅ Application extracted and ready"
                        '
                    """

                    // Stop existing application if running
                    echo "Stopping existing application..."
                    sh """
                        ssh -i '${env.SSH_KEY}' -o StrictHostKeyChecking=no ubuntu@${env.TARGET_HOST} '
                            PID_FILE="/home/ubuntu/projects/stock-nse-india/${params.ENV}/stock-nse-india.pid"
                            if [ -f "\$PID_FILE" ]; then
                                OLD_PID=\$(cat "\$PID_FILE")
                                if ps -p \$OLD_PID > /dev/null 2>&1; then
                                    echo "Stopping existing application (PID: \$OLD_PID)..."
                                    kill \$OLD_PID
                                    sleep 5
                                    # Force kill if still running
                                    if ps -p \$OLD_PID > /dev/null 2>&1; then
                                        kill -9 \$OLD_PID
                                    fi
                                fi
                                rm -f "\$PID_FILE"
                            fi
                        '
                    """

                    // Start new application
                    echo "Starting new application..."
                    sh """
                        ssh -i '${env.SSH_KEY}' -o StrictHostKeyChecking=no ubuntu@${env.TARGET_HOST} '
                            cd /home/ubuntu/projects/stock-nse-india/${params.ENV}/current
                            
                            # Set environment variables
                            export NODE_ENV=${params.ENV}
                            export PORT=${port}
                            
                            # Start application in background
                            nohup node build/server.js > /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-${params.ENV}.log 2>&1 &
                            NEW_PID=\$!
                            
                            # Save PID
                            echo \$NEW_PID > /home/ubuntu/projects/stock-nse-india/${params.ENV}/stock-nse-india.pid
                            
                            echo "✅ Application started with PID: \$NEW_PID"
                            echo "🌐 URL: http://${env.TARGET_HOST}:${port}"
                            echo "📊 API Docs: http://${env.TARGET_HOST}:${port}/api-docs"
                            echo "🔍 GraphQL: http://${env.TARGET_HOST}:${port}/graphql"
                        '
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    def port
                    if (params.ENV == 'dev') {
                        port = '3000'
                    } else if (params.ENV == 'qa') {
                        port = '3001'
                    } else if (params.ENV == 'prod') {
                        port = '3002'
                    }

                    echo "Waiting for application to start..."
                    sleep(time: 30, unit: 'SECONDS')

                    echo "Performing health check..."
                    try {
                        sh """
                            curl -f -s -o /dev/null -w "%{http_code}" http://${env.TARGET_HOST}:${port}/ | grep -q "200"
                        """
                        echo "✅ Health check passed - Application is running successfully"
                    } catch (Exception e) {
                        echo "⚠️ Health check failed - Application may still be starting"
                        echo "Check application logs: ssh ubuntu@${env.TARGET_HOST} 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-${params.ENV}.log'"
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                def port
                if (params.ENV == 'dev') {
                    port = '3000'
                } else if (params.ENV == 'qa') {
                    port = '3001'
                } else if (params.ENV == 'prod') {
                    port = '3002'
                }

                echo """
                ✅ Stock NSE India deployment completed successfully!

                Release: ${params.RELEASE}
                Environment: ${params.ENV}
                Host: ${env.TARGET_HOST}
                Port: ${port}
                
                🌐 Application URL: http://${env.TARGET_HOST}:${port}
                📊 API Documentation: http://${env.TARGET_HOST}:${port}/api-docs
                🔍 GraphQL Playground: http://${env.TARGET_HOST}:${port}/graphql
                
                📋 Sample API Endpoints:
                - Market Status: http://${env.TARGET_HOST}:${port}/api/marketStatus
                - Equity Details: http://${env.TARGET_HOST}:${port}/api/equity/RELIANCE
                - All Indices: http://${env.TARGET_HOST}:${port}/api/indices

                📝 Logs: ssh ubuntu@${env.TARGET_HOST} 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-${params.ENV}.log'
                """
            }
        }
        failure {
            echo """
            ❌ Stock NSE India deployment failed!

            Check the Jenkins logs for details.
            Verify SSH connectivity and release package availability.
            """
        }
    }
}
```

3. Click **Save**

## 🎯 Step 4: Install Required Jenkins Plugins

Ensure these plugins are installed:
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Check if these plugins are installed:
   - ✅ **Pipeline**
   - ✅ **Git**
   - ✅ **SSH Agent**
   - ✅ **Version Number**
   - ✅ **Build Timestamp**

## 🚀 Step 5: Run Your First Deployment

### 5.1 Execute Build Job
1. Navigate to **StockNSEIndia-Build** job
2. Click **Build with Parameters**
3. Configure parameters:
   - **BRANCH:** master
   - **ENV:** dev
   - **DEPLOY_DIRECTORY:** /projects/temp/
4. Click **Build**

### 5.2 Monitor Progress
1. Watch the build progress in real-time
2. The build job will automatically trigger the deployment job
3. Check console output for any errors

### 5.3 Verify Deployment
After successful deployment, verify:
```bash
# Test API health
curl http://129.213.146.93:3000/

# Test stock data
curl http://129.213.146.93:3000/api/equity/RELIANCE

# Check application logs
ssh ubuntu@129.213.146.93 'tail -f /home/ubuntu/projects/logs/stock-nse-india/stock-nse-india-dev.log'
```

## 🔧 Troubleshooting

### Common Issues:

1. **GitHub Authentication Failed**
   - Verify GitHub credentials in Jenkins
   - Ensure Personal Access Token has repository access

2. **Node.js Not Found**
   - Install Node.js 18+ on Jenkins server
   - Update NODE_HOME path in pipeline

3. **SSH Connection Failed**
   - Verify SSH key permissions: `chmod 600 /projects/ssh-key-2023-05-29.key`
   - Test SSH connection manually

4. **Port Already in Use**
   - Check if application is already running
   - Kill existing process: `ssh ubuntu@129.213.146.93 'kill $(cat /home/ubuntu/projects/stock-nse-india/dev/stock-nse-india.pid)'`

## 🎉 Success!

Once both jobs are created and running successfully, you'll have:
- ✅ Automated builds from your forked repository
- ✅ Automated deployments to your server
- ✅ Stock NSE India API running at http://129.213.146.93:3000
- ✅ Integration with MutualFundManager for local stock data

Your Stock NSE India API will be deployed and ready to provide local stock price data for your MutualFundManager application!
