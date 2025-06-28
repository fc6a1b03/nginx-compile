#!/bin/bash

# 检查依赖
for cmd in curl tar; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "错误：未找到 $cmd，请先安装。"
    exit 1
  fi
done

# 检查是否提供了 LICENSE_KEY
if [ -z "$LICENSE_KEY" ]; then
  echo "错误：未设置LICENSE_KEY。请将其导出为环境变量。"
  exit 1
fi

BASE_URL="https://download.maxmind.com/app/geoip_download"

# 下载和解压函数
download_and_extract() {
  local edition_id=$1
  local filename="${edition_id}.mmdb.tar.gz"
  echo "下载 ${edition_id}.mmdb..."
  if curl -L -o "$filename" "${BASE_URL}?edition_id=${edition_id}&license_key=${LICENSE_KEY}&suffix=tar.gz"; then
    if tar -xvzf "$filename" --strip-components=1; then
      rm "$filename"
      echo "${edition_id}.mmdb 已成功下载并提取。"
    else
      echo "${edition_id}.mmdb 解压失败。"
      exit 1
    fi
  else
    echo "${edition_id}.mmdb 下载失败。"
    exit 1
  fi
}

# 并发下载 MaxMind 数据库
for edition in GeoLite2-City GeoLite2-ASN GeoLite2-Country; do
  download_and_extract $edition &
done
wait

# 下载 GeoCN.mmdb
echo "下载 GeoCN.mmdb..."
if curl -L -o "GeoCN.mmdb" \
  "https://github.com/ljxi/GeoCN/releases/download/Latest/GeoCN.mmdb"; then
  echo "GeoCN.mmdb 已成功下载。"
else
  echo "GeoCN.mmdb 下载失败。"
  exit 1
fi

echo "所有下载已完成。"