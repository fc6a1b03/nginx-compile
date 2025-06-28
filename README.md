# nginx-compile

本项目用于快速构建 [nginx](https://nginx.org/en/download.html)

---

## 目录

- [Geo数据库配置示例](#geo数据库配置示例)
- [屏蔽非中国大陆IP](#屏蔽非中国大陆ip)
- [常见问题与解决](#常见问题与解决)
- [编译参数备忘](#编译参数备忘)

---

## Geo数据库配置示例

> Geo模块可显示访问日志中的 IP 信息，并根据 IP 所在地区进行访问限��。

```nginx
# 加载 GeoLite2 ASN 数据库
geoip2 GeoLite2-ASN.mmdb {
    auto_reload 5m;
    $geoip2_asn_number autonomous_system_number;
    $geoip2_asn_organization autonomous_system_organization;
}
# 加载 GeoLite2 Country 数据库
geoip2 GeoLite2-Country.mmdb {
    auto_reload 5m;
    $geoip2_country_code country iso_code;
    $geoip2_country_name country names en;
}
# 加载 GeoLite2 City 数据库
geoip2 GeoLite2-City.mmdb {
    auto_reload 5m;
    $geoip2_city_name city names en;
    $geoip2_postal_code postal code;
    $geoip2_latitude location latitude;
    $geoip2_longitude location longitude;
    $geoip2_region_name subdivisions 0 names en;
}
# 加载 GeoCN CN 数据库
geoip2 GeoCN.mmdb {
    $geoip2_cn_isp isp;
    $geoip2_cn_city city;
    $geoip2_cn_net_type net;
    $geoip2_cn_province province;
    $geoip2_cn_district district;
}
```

---

## 屏蔽非中国大陆IP

通过 GeoIP2 判断访问者是否为中国大陆用户，非中国大陆 IP 自动拒绝访问：

```nginx
if ($geoip2_country_code != "CN") {
    return 403;
}
```

---

## 常见问题与解决

- **拓展动态库加载**：

> `libs` 可在构建产物中找到

```bash
# 设置扩展库目录
echo "/nginx/libs" | sudo tee /etc/ld.so.conf.d/nginx-libs.conf
# 更新动态链接器缓存
sudo ldconfig
```

---

## 编译参数备忘

```
--with-zlib=../zlib_ng
--add-module=../ngx_devel_kit \
--add-module=../lua-nginx-module \
```

---

## 构建与GeoIP数据库自动化流程说明

### 1. GeoIP2 数据库自动同步脚本（geoip/geoip2_sync.sh）

- 支持自动下载最新的 MaxMind GeoLite2-City、GeoLite2-ASN、GeoLite2-Country 及 GeoCN.mmdb 数据库。
- 需提前设置 `LICENSE_KEY` 环境变量（MaxMind 账户密钥）。
- 并发下载并自动解压，下载失败自动终止。
- 适用于自动化构建流程，确保数据库为最新版本。

### 2. Nginx 自动化编译流程（.GitHub/workflows/build_nginx.yml）

- 支持自定义 Nginx/Openssl 版本、安装前缀、GeoIP2 数据库下载开关等参数。
- 基于 Docker（AlmaLinux 9）隔离环境，自动拉取依赖、源码及第三方模块（如 brotli、zstd、geoip2、pcre2 等）。
- 自动构建并集成 malloc、libmaxminddb、zstd、brotli、pcre2 等依赖。
- 可选自动同步 GeoIP2 数据库（调用 geoip2_sync.sh 脚本）。
- Nginx 编译参数高度优化，支持 HTTP/3、QUIC、TLS1.3、Brotli、Zstd、GeoIP2 等。
- 自动收集依赖动态库，打包产物（nginx 二进制、动态模块、依赖库、构建信息）并上传。

---

## 主要自动化流程模块

- **geoip2_sync.sh**：一键下载并解压 GeoIP2/GeoCN 数据库，适配自动化流水线。
- **build_nginx.yml**：CI/CD 自动化编译 Nginx，集成多模块与依赖，支持灵活参数配置与产物打包。

---