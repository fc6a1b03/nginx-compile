#!/bin/bash
# =============================================
# GeoIP2 数据库高性能下载脚本
# 最后更新：2026-03-14
# 优化原则：新特性、高性能、低损耗
# =============================================
set -euo pipefail

# 配置区 ============================================================
# 并行连接数（每个文件）
readonly CONCURRENT_CONNECTIONS=4
# 连接超时（秒）
readonly CONNECT_TIMEOUT=10
# 最大重试次数
readonly MAX_RETRIES=2
# 重试间隔（秒）
readonly RETRY_DELAY=1
# 是否启用详细输出（流水线中建议设为 false）
readonly VERBOSE=${VERBOSE:-false}
# 失败时不退出（不影响流水线）
readonly NO_FAIL=${NO_FAIL:-true}
# 跳过已存在的有效文件（基于文件大小检查，>1KB 视为有效）
readonly SKIP_EXISTING=${SKIP_EXISTING:-true}
# 最小有效文件大小（字节）
readonly MIN_VALID_SIZE=1024

# 数据库源配置（按优先级排序）
declare -Ar DATABASE_URLS=(
  # ljxi 维护的中国 IP 数据库
  [GeoCN]="https://github.com/ljxi/GeoCN/releases/download/Latest/GeoCN.mmdb"
  # P3TERX 维护的 MaxMind 镜像（国内加速）
  [GeoLite2-ASN]="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb"
  [GeoLite2-City]="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb"
  [GeoLite2-Country]="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
)

# 颜色输出定义（仅在 VERBOSE 模式下启用）
if [[ "$VERBOSE" == "true" ]] && [[ -t 1 ]]; then
  readonly C_GREEN='\033[0;32m'
  readonly C_RED='\033[0;31m'
  readonly C_YELLOW='\033[1;33m'
  readonly C_BLUE='\033[0;34m'
  readonly C_RESET='\033[0m'
else
  readonly C_GREEN=''
  readonly C_RED=''
  readonly C_YELLOW=''
  readonly C_BLUE=''
  readonly C_RESET=''
fi

# 日志函数 ==========================================================
log() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${C_BLUE}[$(date +%H:%M:%S)]${C_RESET} $*"
  fi
}
log_ok() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${C_GREEN}✓${C_RESET} $*"
  fi
}
log_warn() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${C_YELLOW}!${C_RESET} $*" >&2
  fi
}
log_err() {
  echo -e "${C_RED}✗${C_RESET} $*" >&2
}
# 下载引擎选择（性能优先）
select_downloader() {
  # 优先级：aria2c > curl-http3 > curl-http2 > curl
  if command -v aria2c &>/dev/null; then
    echo "aria2c"
  elif command -v curl &>/dev/null; then
    # 检测 curl 是否支持 HTTP/3
    if curl --version | grep -q "http3\|nghttp3\|quiche"; then
      echo "curl-http3"
    elif curl --version | grep -q "http2"; then
      echo "curl-http2"
    else
      echo "curl"
    fi
  else
    log_err "未找到 aria2c 或 curl，请先安装"
    return 1
  fi
}
# 文件大小获取（低损耗：使用 stat 避免子进程）
get_file_size() {
  local file="$1"
  if [[ -f "$file" ]]; then
    # 优先使用 stat（无子进程开销）
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      stat -c%s "$file" 2>/dev/null || echo 0
    else
      stat -f%z "$file" 2>/dev/null || echo 0
    fi
  else
    echo 0
  fi
}
# 高性能下载函数
download_with_aria2c() {
  local url="$1" output="$2"
  local tmp_output="${output}.tmp.$$"
  aria2c "$url" \
    --dir="$(dirname "$output")" \
    --out="$(basename "$tmp_output")" \
    --split="$CONCURRENT_CONNECTIONS" \
    --max-connection-per-server="$CONCURRENT_CONNECTIONS" \
    --min-split-size=1M \
    --connect-timeout="$CONNECT_TIMEOUT" \
    --timeout="$CONNECT_TIMEOUT" \
    --max-tries="$MAX_RETRIES" \
    --retry-wait="$RETRY_DELAY" \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --quiet=true \
    --disable-ipv6=false \
    --enable-http-keep-alive=true \
    --enable-http-pipelining=true \
    --async-dns=true
  local status=$?
  if [[ $status -eq 0 ]] && [[ -f "$tmp_output" ]]; then
    mv -f "$tmp_output" "$output"
    return 0
  else
    rm -f "$tmp_output"
    return 1
  fi
}
download_with_curl() {
  local url="$1" output="$2"
  local curl_variant="$3"
  local tmp_output="${output}.tmp.$$"
  local curl_opts=(
    -L -f
    -o "$tmp_output"
    --connect-timeout "$CONNECT_TIMEOUT"
    --max-time 120
    --retry "$MAX_RETRIES"
    --retry-delay "$RETRY_DELAY"
    --retry-max-time 60
    --silent
    --show-error
  )
  # 根据 curl 能力启用新特性
  case "$curl_variant" in
    curl-http3)
      curl_opts+=(--http3)
      log "使用 HTTP/3 协议"
      ;;
    curl-http2)
      curl_opts+=(--http2)
      ;;
  esac
  # 高性能 DNS 和连接优化
  curl_opts+=(
    --dns-servers "1.1.1.1,8.8.8.8,223.5.5.5"
    --tcp-fastopen
    --compressed
    -H "Accept-Encoding: zstd,br,gzip"
  )
  if curl "${curl_opts[@]}" "$url"; then
    mv -f "$tmp_output" "$output"
    return 0
  else
    rm -f "$tmp_output"
    return 1
  fi
}
# 智能下载函数（带重试和降级）
download_database() {
  local db_name="$1"
  local url="$2"
  local output="${db_name}.mmdb"
  local downloader
  local size_after
  # 检查是否需要跳过
  if [[ "$SKIP_EXISTING" == "true" ]]; then
    local existing_size
    existing_size=$(get_file_size "$output")
    if [[ "$existing_size" -gt "$MIN_VALID_SIZE" ]]; then
      log_ok "$db_name 已存在且有效，跳过下载"
      echo "skip"
      return 0
    fi
  fi
  log "开始下载 $db_name..."
  # 选择最优下载器
  downloader=$(select_downloader) || return 1
  local retry_count=0
  local success=false
  while [[ $retry_count -lt $MAX_RETRIES ]] && [[ "$success" == "false" ]]; do
    case "$downloader" in
      aria2c)
        if download_with_aria2c "$url" "$output"; then
          success=true
          break
        fi
        ;;
      curl-http3|curl-http2|curl)
        if download_with_curl "$url" "$output" "$downloader"; then
          success=true
          break
        fi
        ;;
    esac
    ((retry_count++))
    if [[ $retry_count -lt $MAX_RETRIES ]]; then
      log_warn "$db_name 下载失败，${RETRY_DELAY}秒后重试 (${retry_count}/${MAX_RETRIES})"
      sleep "$RETRY_DELAY"
      # 降级策略：HTTP/3 -> HTTP/2 -> HTTP/1.1
      case "$downloader" in
        curl-http3) downloader="curl-http2"; log "降级到 HTTP/2" ;;
        curl-http2) downloader="curl"; log "降级到 HTTP/1.1" ;;
      esac
    fi
  done
  # 验证下载结果
  if [[ "$success" == "true" ]]; then
    size_after=$(get_file_size "$output")
    if [[ "$size_after" -lt "$MIN_VALID_SIZE" ]]; then
      log_err "$db_name 文件过小，可能下载失败"
      rm -f "$output"
      return 1
    fi
    log_ok "$db_name 下载成功 ($(numfmt --to=iec "$size_after" 2>/dev/null || echo "${size_after}B"))"
    echo "ok"
    return 0
  else
    log_err "$db_name 下载失败"
    rm -f "$output"
    return 1
  fi
}
# 主程序
main() {
  local start_time end_time duration
  local total_count=0 success_count=0 skip_count=0 fail_count=0
  local -A results
  start_time=$(date +%s)
  log "GeoIP2 数据库同步开始"
  log "下载器: $(select_downloader), 并行连接: $CONCURRENT_CONNECTIONS"
  # 并发下载（使用进程替换减少 subshell 开销）
  exec 3>&1
  for db in "${!DATABASE_URLS[@]}"; do
    ((total_count++))
    (
      result=$(download_database "$db" "${DATABASE_URLS[$db]}")
      echo "$db:$result" >&3
    ) &
  done
  wait
  exec 3>&-
  # 汇总结果
  for db in "${!DATABASE_URLS[@]}"; do
    # 从文件或变量读取结果
    if [[ -f "${db}.mmdb" ]]; then
      if [[ "${results[$db]:-fail}" == "skip" ]]; then
        ((skip_count++))
      else
        ((success_count++))
      fi
    else
      ((fail_count++))
    fi
  done
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  # 最终输出（简洁模式，不影响流水线解析）
  if [[ "$VERBOSE" == "true" ]]; then
    echo ""
    echo "==================================="
    echo "同步完成: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "耗时: ${duration}s"
    echo "总计: $total_count | 成功: $success_count | 跳过: $skip_count | 失败: $fail_count"
    echo "文件列表:"
    ls -lh -- ./*.mmdb 2>/dev/null || true
    echo "==================================="
  else
    # 极简输出，便于流水线解析
    echo "geoip2_sync: total=$total_count ok=$success_count skip=$skip_count fail=$fail_count time=${duration}s"
  fi
  # 返回码控制
  if [[ $fail_count -gt 0 ]]; then
    if [[ "$NO_FAIL" == "true" ]]; then
      log_warn "${fail_count} 个数据库下载失败，但 NO_FAIL=true，继续执行"
      return 0
    else
      return 1
    fi
  fi
  return 0
}
# 入口
main "$@"
