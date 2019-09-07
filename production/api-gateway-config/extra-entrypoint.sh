#!/bin/sh

sed -i -e "s/[@]STORAGE_PROXY_HOST[@]/$STORAGE_PROXY_HOST/g" /usr/local/openresty/nginx/conf/nginx.conf

exec /entrypoint.sh $@
