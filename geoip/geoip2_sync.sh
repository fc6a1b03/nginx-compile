#!/bin/bash
# =============================================
# GeoIP数据库下载脚本
# 最后更新：2025-07-13
# =============================================
set -euo pipefail
# 检查依赖
for cmd in curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "错误：未找到 $cmd，请先安装。"
    exit 1
  fi
done
# GitHub源配置
declare -A database_urls=(
  [GeoCN]="https://github.com/ljxi/GeoCN/releases/download/Latest/GeoCN.mmdb"
  # wp-statistics社区维护
  [GeoLite2-City]="https://github.com/wp-statistics/GeoLite2-City/raw/main/GeoLite2-City.mmdb"
  [GeoLite2-ASN]="https://github.com/P3TERX/GeoLite.mmdb/releases/latest/download/GeoLite2-ASN.mmdb"
  [GeoLite2-Country]="https://github.com/wp-statistics/GeoLite2-Country/raw/main/GeoLite2-Country.mmdb"
)
# 下载对应数据库
download_database() {
  local db_name=$1
  local output_file="${db_name}.mmdb"
  local tmp_file="${output_file}.tmp"
  local database_url=${database_urls[$db_name]}
  echo "开始下载 $db_name..."
  if curl -L -o "$tmp_file" \
          --connect-timeout 30 \
          --retry 3 \
          --silent \
          --show-error \
          "$database_url"; then
    mv "$tmp_file" "$output_file"
    # 获取文件大小
    echo "√ $db_name 下载成功 | 大小: $(du -h "$output_file" | cut -f1)"
    return 0
  else
    echo "× $db_name 下载失败 | URL: $database_url"
    rm -f "$tmp_file"
    exit 1
  fi
}
# 创建下载状态数组
declare -A download_status
for db in "${!database_urls[@]}"; do
  download_status[$db]="等待中"
done
# 显示初始状态
echo "数据库下载队列:"
for db in "${!download_status[@]}"; do
  echo "  - $db: ${download_status[$db]}"
done
echo ""
# 并发下载所有数据库
for db in "${!database_urls[@]}"; do
  download_status[$db]="下载中..."
  download_database "$db" &
done
wait
echo -e "所有数据库下载完成！当前版本：$(date +%Y-%m-%d)"
echo "生成文件:"
for db in "${!database_urls[@]}"; do
  echo "  - ${db}.mmdb"
done
