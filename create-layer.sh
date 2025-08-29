#!/bin/bash

# Lambda Layer作成スクリプト
# Node.js 22.x用の依存パッケージをインストールしてLayer用のzipファイルを作成

echo "Creating Lambda Layer for Node.js 22.x..."

# 作業ディレクトリの作成
WORK_DIR="layer_build"
rm -rf $WORK_DIR
mkdir -p $WORK_DIR/nodejs

# package.jsonをコピー
cp src/package.json $WORK_DIR/nodejs/

# 作業ディレクトリに移動
cd $WORK_DIR/nodejs

# 依存パッケージのインストール（開発依存は除外）
echo "Installing dependencies..."
npm install --production --no-package-lock

# 不要なファイルを削除
echo "Cleaning up..."
find . -name "*.md" -delete
find . -name "*.txt" -delete
find . -name "*.yml" -delete
find . -name "*.yaml" -delete
find . -name ".DS_Store" -delete
find . -name "test" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# zipファイルの作成
cd ..
echo "Creating zip file..."
zip -r ../terraform/layer.zip nodejs -q

# 作業ディレクトリの削除
cd ..
rm -rf $WORK_DIR

echo "Layer created successfully: terraform/layer.zip"
echo "Size: $(ls -lh terraform/layer.zip | awk '{print $5}')"