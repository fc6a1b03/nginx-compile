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

> Geo模块可显示访问日志中的 IP 信息，并根据 IP 所在地区进行访问限制。

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