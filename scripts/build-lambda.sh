#!/bin/bash

# Lambda deployment package build script

set -e

echo "Building Lambda deployment package..."

# Clean up previous builds
rm -f lambda-deployment.zip

# Create deployment package
cd src
zip -r ../lambda-deployment.zip . \
    -x "*.git*" \
    -x "*.DS_Store" \
    -x "node_modules/aws-sdk/*" \
    -x "*.md" \
    -x "*.test.js" \
    -x "*.spec.js"

cd ..

echo "Lambda deployment package created: lambda-deployment.zip"
echo "Size: $(du -h lambda-deployment.zip | cut -f1)"