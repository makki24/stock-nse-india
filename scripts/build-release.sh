#!/bin/bash

# Stock NSE India - Build Release Script
# This script builds the Node.js application for deployment

set -e

echo "🚀 Starting Stock NSE India build process..."

# Configuration
PROJECT_NAME="stock-nse-india"
BUILD_DIR="/projects/temp"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Validate Node.js version
echo "📋 Validating Node.js version..."
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Error: Node.js 18+ required. Current version: $(node --version)"
    exit 1
fi
echo "✅ Node.js version: $(node --version)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -rf node_modules/
npm cache clean --force

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production=false

# Run tests
echo "🧪 Running tests..."
npm test

# Build the application
echo "🔨 Building application..."
npm run build

# Validate build output
if [ ! -f "build/server.js" ]; then
    echo "❌ Error: Build failed - server.js not found"
    exit 1
fi

# Create deployment package
echo "📦 Creating deployment package..."
mkdir -p "$BUILD_DIR"

# Create release directory
RELEASE_NAME="${PROJECT_NAME}-${TIMESTAMP}"
RELEASE_DIR="$BUILD_DIR/$RELEASE_NAME"
mkdir -p "$RELEASE_DIR"

# Copy built application
cp -r build/ "$RELEASE_DIR/"
cp package.json "$RELEASE_DIR/"
cp package-lock.json "$RELEASE_DIR/"

# Install production dependencies in release directory
echo "📦 Installing production dependencies..."
cd "$RELEASE_DIR"
npm install --production --silent

# Create startup script
cat > "$RELEASE_DIR/start.sh" << 'EOF'
#!/bin/bash
# Stock NSE India startup script

# Set environment variables
export NODE_ENV=${NODE_ENV:-production}
export PORT=${PORT:-3000}

# Start the application
echo "🚀 Starting Stock NSE India API on port $PORT..."
node build/server.js
EOF

chmod +x "$RELEASE_DIR/start.sh"

# Create archive
cd "$BUILD_DIR"
tar -czf "${RELEASE_NAME}.tar.gz" "$RELEASE_NAME/"

echo "✅ Build completed successfully!"
echo "📦 Release package: $BUILD_DIR/${RELEASE_NAME}.tar.gz"
echo "📁 Release directory: $RELEASE_DIR"

# Output release information
echo "
🎉 Build Summary:
- Release Name: $RELEASE_NAME
- Package Size: $(du -h ${RELEASE_NAME}.tar.gz | cut -f1)
- Build Directory: $RELEASE_DIR
- Archive: ${RELEASE_NAME}.tar.gz
"
