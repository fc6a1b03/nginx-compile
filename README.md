# nginx-compile
用于构建[nginx](https://nginx.org/en/download.html)

## 屏蔽所有非中国大陆 IP
```conf
# 检查国家代码，如果不是 CN，则拒绝访问
if ($geoip2_data_country_code != "CN") {
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
