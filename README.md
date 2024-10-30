# nginx-compile
用于构建[nginx](https://nginx.org/en/download.html)

## Geo数据库
> Geo可以显示日志中的访问IP信息，并根据IP所在的地区进行限制访问。
```conf
# 加载 GeoLite2 ASN 数据库
geoip2 GeoLite2-ASN.mmdb {
    auto_reload 5m;
    $geoip2_asn_number autonomous_system_number;
    $geoip2_asn_organization autonomous_system_organization;
}
# 加载 GeoLite2 国家数据库
geoip2 GeoLite2-Country.mmdb {
    auto_reload 5m;
    $geoip2_country_code country iso_code;
    $geoip2_country_name country names en;
}
# 加载 GeoLite2 城市数据库
geoip2 GeoLite2-City.mmdb {
    auto_reload 5m;
    $geoip2_city_name city names en;
    $geoip2_postal_code postal code;
    $geoip2_latitude location latitude;
    $geoip2_longitude location longitude;
    $geoip2_region_name subdivisions 0 names en;
}
# 加载 GeoCN CN数据库
geoip2 GeoCN.mmdb {
    auto_reload 5m;
    $geoip2_cn_isp isp;
    $geoip2_cn_city city;
    $geoip2_cn_net_type net;
    $geoip2_cn_province province;
    $geoip2_cn_district district;
}
```

## 屏蔽所有非CN的IP
```conf
# 检查国家代码，如果不是CN，则拒绝访问
if ($geoip2_country_code != "CN") {
    return 403;
}
```

## 相关问题
```base
# ./nginx: error while loading shared libraries: libjemalloc.so.2: cannot open shared object file: No such file or directory
sudo find / -name libjemalloc.so.2
sudo ln -s /xxx/usr/lib64/libjemalloc.so.2 /usr/lib64/libjemalloc.so.2
sudo ldconfig
# ./nginx: error while loading shared libraries: libcrypt.so.2: cannot open shared object file: No such file or directory
sudo find / -name libcrypt.so.2
sudo ln -s /xxx/usr/lib64/libcrypt.so.2 /usr/lib64/libcrypt.so.2
sudo ldconfig
```

## 备忘录
```
# --add-module=../ngx_devel_kit \
# --add-module=../lua-nginx-module \
```
