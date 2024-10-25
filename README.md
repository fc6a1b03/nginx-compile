# nginx-compile
用于构建nginx

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

```
# --add-module=../ngx_devel_kit \
# --add-module=../lua-nginx-module \
```
