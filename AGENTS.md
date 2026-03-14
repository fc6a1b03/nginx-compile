# nginx-compile 项目指南

> 本文档面向 AI 编程助手，用于快速理解本项目架构、构建流程和开发规范。

---

## 项目概述

本项目是一个 **Nginx 自动化编译工具链**，用于在隔离的 Docker 环境中从源码构建高度优化的 Nginx 二进制文件。项目通过 GitHub
Actions 提供完整的 CI/CD 自动化构建流程，支持多种架构级别和模块扩展。

### 核心目标

- 提供可复现的 Nginx 构建环境
- 集成现代 Web 技术（HTTP/3、QUIC、Brotli、Zstd）
- 支持 GeoIP2 地理位置服务
- 可选的 Lua 脚本扩展能力

---

## 项目结构

```
nginx-compile/
├── .github/workflows/          # GitHub Actions 工作流定义
│   ├── build_nginx.yml         # 标准版 Nginx 构建流程（⭐ 主要维护）
│   └── build_nginx_lua.yml     # 集成 Lua 模块的 Nginx 构建流程（⚠️ 备份文件，不维护）
├── geoip/
│   └── geoip2_sync.sh          # GeoIP2 数据库自动下载脚本
├── .idea/                      # IntelliJ IDEA 项目配置（可忽略）
├── .gitignore                  # Git 忽略规则
├── README.md                   # 用户文档（中文）
└── AGENTS.md                   # 本文件
```

---

## 技术栈

### 基础技术

| 组件                   | 用途          |
|----------------------|-------------|
| GitHub Actions       | CI/CD 自动化平台 |
| Docker (AlmaLinux 9) | 隔离的构建环境     |
| Bash                 | 自动化脚本       |

### Nginx 集成的第三方模块与库

| 模块/库                   | 来源                                        | 用途                              |
|------------------------|-------------------------------------------|---------------------------------|
| OpenSSL                | github.com/openssl/openssl                | TLS/SSL 支持（3.5.0/3.6.0+）        |
| PCRE2                  | github.com/PCRE2Project/pcre2             | 正则表达式支持                         |
| ngx_brotli             | github.com/google/ngx_brotli              | Brotli 压缩算法                     |
| ngx_zstd               | github.com/HanadaLee/ngx_http_zstd_module | Zstandard 压缩                    |
| ngx_http_geoip2_module | github.com/leev/ngx_http_geoip2_module    | GeoIP2 地理位置                     |
| libmaxminddb           | github.com/maxmind/libmaxminddb           | MaxMind 数据库解析                   |
| LuaJIT                 | github.com/LuaJIT/LuaJIT                  | Lua 运行时（仅 Lua 版）                |
| lua-nginx-module       | github.com/openresty/lua-nginx-module     | Nginx Lua 扩展（⚠️ Lua 版为备份，不推荐使用） |
| lua-resty-core         | github.com/openresty/lua-resty-core       | Lua 核心库（⚠️ Lua 版为备份，不推荐使用）      |
| jemalloc               | 系统包                                       | 内存分配器优化（标准版）                    |
| tcmalloc               | github.com/gperftools/gperftools          | Google 内存分配器（Lua 版）             |

---

## 构建流程详解

### 标准构建流程 (`build_nginx.yml`)

1. **环境准备**
    - 启动 AlmaLinux 9 Docker 容器
    - 安装开发工具链（gcc、make、cmake 等）
    - 安装系统依赖（brotli-devel、jemalloc-devel 等）

2. **源码获取**
    - 克隆 OpenSSL 指定版本
    - 克隆并构建 libmaxminddb
    - 克隆 ngx_brotli、ngx_zstd、PCRE2、ngx_http_geoip2_module
    - 下载 Nginx 官方源码

3. **可选步骤**
    - 执行 `geoip2_sync.sh` 下载 GeoIP2 数据库（需 `enable_geoip2=yes`）

4. **编译配置**
    - 使用高度优化的编译参数（-O3、LTO、架构特定优化）
    - 支持 x86-64-v2/v3/v4 或 native 架构级别
    - 启用 HTTP/3、QUIC、TLS 1.3 等现代协议

5. **构建与打包**
    - 并行编译（`make -j$(nproc)`）
    - 收集依赖的动态库
    - 生成构建报告和版本信息
    - 上传产物到 GitHub Artifacts

### Lua 版本构建流程 (`build_nginx_lua.yml`) ⚠️ 备份文件

> **重要提示**：`build_nginx_lua.yml` 为**备份/存档文件**，**无需关注、调整或修改**。
>
> Lua 脚本会显著影响 Nginx 的代理性能，在高效代理场景下不推荐使用。日后大概率不会使用 Lua 版本进行构建。

与标准流程的区别（仅作记录）：

- 额外构建 LuaJIT 并设置环境变量
- 集成 lua-nginx-module 模块
- 使用 tcmalloc 替代 jemalloc
- 添加 Lua 相关编译参数和链接选项
- 包含 lua-resty-core 和 lua-resty-lrucache

---

## 工作流输入参数

### 标准版 (`build_nginx.yml`)

| 参数              | 类型     | 默认值              | 说明              |
|-----------------|--------|------------------|-----------------|
| nginx_version   | string | 1.29.6           | Nginx 版本号       |
| openssl_version | string | openssl-3.6.0    | OpenSSL 分支/标签   |
| prefix          | string | /usr/local/nginx | 安装前缀            |
| enable_geoip2   | choice | no               | 是否下载 GeoIP2 数据库 |
| target_arch     | choice | native           | 目标架构级别          |

### Lua 版 (`build_nginx_lua.yml`)

| 参数              | 类型     | 默认值              | 说明              |
|-----------------|--------|------------------|-----------------|
| nginx_version   | string | 1.29.0           | Nginx 版本号       |
| openssl_version | string | openssl-3.5.0    | OpenSSL 分支/标签   |
| prefix          | string | /usr/local/nginx | 安装前缀            |
| enable_geoip2   | string | no               | 是否下载 GeoIP2 数据库 |

**注意**：Lua 版本需要配置 Secret `MAXMIND_LICENSE_KEY` 才能下载 GeoIP2 数据库。

---

## 构建产物

构建成功后，GitHub Actions 会生成以下产物（保留 2 天）：

```
nginx-linux64-{VERSION}/
├── nginx                    # Nginx 可执行文件
├── libs/                    # 依赖的动态库
│   ├── libbrotli*.so
│   ├── libcrypto.so
│   ├── libmaxminddb.so
│   ├── libssl.so
│   └── ...
├── modules/                 # 动态模块和 GeoIP 数据库
│   ├── ngx_http_geoip2_module.so
│   ├── GeoLite2-City.mmdb
│   ├── GeoLite2-Country.mmdb
│   ├── GeoLite2-ASN.mmdb
│   └── GeoCN.mmdb
├── build_report.txt         # 构建报告
└── nginx_build_info.txt     # nginx -V 输出
```

---

## 开发规范

### 脚本编写规范

- 使用 `set -euo pipefail` 确保脚本严格模式
- 添加清晰的注释说明脚本用途
- 并发下载使用 `wait` 等待完成
- 错误处理需输出清晰的错误信息

### GitHub Actions 规范

- 工作流使用 `workflow_dispatch` 手动触发
- 环境变量集中定义在 `env` 区块
- 使用 Docker 提供一致的构建环境
- 步骤命名应清晰描述操作内容

### 安全配置

- GeoIP2 数据库下载需要 MaxMind License Key
- Secret 名称：`MAXMIND_LICENSE_KEY`
- 编译启用安全加固选项（`-fstack-protector-strong`, `-D_FORTIFY_SOURCE=3` 等）
- 链接器启用 relro 和 now 选项

---

## 使用方法

### 触发构建

1. 进入 GitHub 仓库的 Actions 页面
2. 选择 "Build Nginx Based" 或 "Build Nginx Lua Based"
3. 点击 "Run workflow"
4. 填写参数并确认

### 本地使用构建产物

```bash
# 1. 下载并解压产物
# 2. 设置动态库路径
echo "/path/to/libs" | sudo tee /etc/ld.so.conf.d/nginx-libs.conf
sudo ldconfig

# 3. 运行 Nginx
./nginx -t          # 测试配置
./nginx             # 启动服务
```

### GeoIP2 配置示例

```nginx
# nginx.conf
load_module modules/ngx_http_geoip2_module.so;

geoip2 GeoLite2-Country.mmdb {
    auto_reload 5m;
    $geoip2_country_code country iso_code;
}

# 屏蔽非中国大陆 IP
if ($geoip2_country_code != "CN") {
    return 403;
}
```

---

## 注意事项

1. **架构兼容性**：选择 `target_arch` 时需确保运行环境支持该指令集
    - x86-64-v2：较老的服务器支持
    - x86-64-v3：需要 AVX2 支持（Haswell+）
    - x86-64-v4：需要 AVX-512 支持（较新服务器）
    - native：使用构建机本身的指令集

2. **内存分配器**：
    - 标准版使用 jemalloc
    - Lua 版使用 tcmalloc

3. **OpenSSL 版本**：
    - 使用 OpenSSL 3.x 分支以支持 QUIC/HTTP3
    - 禁用旧版 TLS 1.0/1.1 以提高安全性

---

## 文件关联关系

```
build_nginx.yml (⭐ 主要维护)
    ├── 调用 ──► geoip2_sync.sh（可选）
    └── 产物 ──► nginx + libs/ + modules/

build_nginx_lua.yml (⚠️ 备份文件，不推荐使用)
    ├── 调用 ──► geoip2_sync.sh（可选，需 LICENSE_KEY）
    └── 产物 ──► nginx + libs/ + modules/
```

---

## 硬编码设计原则

> 以下原则适用于所有脚本、配置文件和 GitHub Actions 工作流，**必须严格遵守**。

### 1. 最新版本原则 (Latest Version)

所有依赖和组件**必须**追踪并使用最新版本：

| 类别     | 要求                 | 实现方式                             |
|--------|--------------------|----------------------------------|
| 主版本依赖  | 始终使用最新稳定版          | `git clone --depth 1` 获取默认分支最新代码 |
| 指定版本组件 | 使用最新 Release/Tag   | 定期更新默认参数值                        |
| 系统包    | 构建时执行 `dnf update` | 确保基础环境为最新状态                      |

**示例：**

```yaml
# 始终克隆最新代码（默认分支）
git clone --depth 1 --recurse-submodules https://github.com/google/ngx_brotli.git

  # 使用最新发布的 bazelisk
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
```

### 2. 新特性原则 (New Features)

积极启用新技术和新特性，保持技术领先：

| 特性类别  | 必须启用的功能                           |
|-------|-----------------------------------|
| 协议支持  | HTTP/3、QUIC、TLS 1.3、TCP Fast Open |
| 压缩算法  | Brotli、Zstandard (zstd)           |
| 安全特性  | PQC (后量子密码学)、Kyber、早期数据 (0-RTT)   |
| 内核特性  | io_uring、BPF、KTLS                 |
| 现代指令集 | AVX2、AVX-512、AES-NI (根据架构)        |

**示例：**

```bash
# OpenSSL 配置启用新特性
enable-kyber enable-pqc enable-early-data enable-ktls
```

### 3. 高性能原则 (High Performance)

编译和运行时必须启用最高性能优化：

| 优化类别        | 配置要求                                   |
|-------------|----------------------------------------|
| 编译优化        | `-O3` 最高优化级别                           |
| 链接时优化 (LTO) | `-flto` / `-flto=thin`                 |
| 循环展开        | `-funroll-loops -fpeel-loops`          |
| 函数内联        | `-finline-functions -ftracer`          |
| 指令集优化       | `-march=native` 或特定架构级别 (x86-64-v3/v4) |
| 内存分配器       | jemalloc (标准版) / tcmalloc (Lua版)       |
| 并行编译        | `make -j$(nproc)` 使用全部 CPU 核心          |

**示例：**

```bash
# 高性能编译参数（--with-cc-opt）
-O3 -march=native -funroll-loops -fpeel-loops -ftracer \
-fomit-frame-pointer -finline-functions -flto -fuse-ld=lld

# OpenSSL 专用优化
-O3 -funroll-loops -fpeel-loops -ftracer -fomit-frame-pointer
```

### 4. 低损耗原则 (Low Overhead)

减少不必要的资源消耗和性能损耗：

| 优化方向  | 配置要求                                       |
|-------|--------------------------------------------|
| 去除冗余  | `--as-needed --gc-sections` 去除未使用代码        |
| 禁用旧协议 | `no-tls1 no-tls1_1 no-legacy` 禁用旧版 TLS     |
| 精简模块  | `--without-http_autoindex_module` 移除不需要的模块 |
| 最小化依赖 | Lua版 tcmalloc 使用 `--enable-minimal`        |
| 裁剪符号  | 链接优化 `-Wl,-O2`                             |

**示例：**

```bash
# 链接参数优化（--with-ld-opt）
-Wl,--as-needed -Wl,--gc-sections -Wl,-O2

# 禁用旧版 TLS 降低开销
no-tls1 no-tls1_1 no-legacy no-weak-ssl-ciphers
```

---

## 各文件具体要求

### GitHub Actions 工作流 (*.yml)

1. **版本参数**：默认版本号必须定期更新至最新稳定版
2. **克隆策略**：第三方模块使用 `--depth 1` 获取最新代码
3. **系统更新**：构建前执行完整的 `dnf update`
4. **并行编译**：始终使用 `make -j$(nproc)`
5. **优化标志**：完整的 `-O3` + LTO + 架构优化参数

### Shell 脚本 (*.sh)

1. **依赖检查**：脚本开头检查必要工具是否存在
2. **错误处理**：使用 `set -euo pipefail` 严格模式
3. **并发下载**：支持并发的地方使用 `&` + `wait`
4. **超时重试**：curl 下载必须配置 `--connect-timeout` 和 `--retry`
5. **版本追踪**：下载 URL 优先使用 `latest` 或自动获取最新版本

### 编译配置参数

#### 标准版 (`build_nginx.yml`)

```yaml
# 核心优化参数（禁止降低或删除）
--with-cc-opt='-O3 -march=${TARGET_ARCH} ... -flto ...'
--with-ld-opt='-ljemalloc ... -flto ...'
--with-openssl-opt='-O3 -march=${TARGET_ARCH} ... enable-kyber enable-pqc ...'
```

#### Lua 版 (`build_nginx_lua.yml`)

```yaml
# Lua 版专用优化
--with-ld-opt="-ltcmalloc_minimal ... -flto=thin ..."
--with-cc-opt='-O3 -march=native ... -flto ...'
```

---

## 维护建议

- **定期更新**：每月检查并更新第三方模块和依赖版本
- **关注上游**：订阅 OpenSSL、Nginx 的安全更新（LuaJIT 仅需关注，不主动更新）
- **GeoIP2 同步**：数据库需定期同步更新（建议每周）
- **性能回归**：新版本发布后需验证性能基准
- **安全审计**：关注 CVE 公告，及时应用安全补丁
- **指令集验证**：构建后验证 AVX2/AVX-512 指令是否正确生成

### 关于 Lua 版本的特别说明

`build_nginx_lua.yml` 为**备份/存档文件**，存在以下限制：

1. **不维护**：无需对该文件进行任何调整或修改
2. **不推荐使用**：Lua 脚本会显著降低 Nginx 的代理性能
3. **未来发展**：日后大概率不会使用 Lua 版本进行构建
4. **仅作参考**：如需 Lua 功能，建议考虑 OpenResty 等专门方案

**结论**：所有开发和维护工作聚焦于 `build_nginx.yml`（标准版）即可。
