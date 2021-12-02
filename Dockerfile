FROM openresty/openresty:centos AS resty
LABEL org.opencontainers.image.authors="beyond147896@126.com"

# 安装jmespath
RUN yum -y install gcc
RUN /usr/local/openresty/luajit/bin/luarocks install luajson
RUN curl -o  /usr/local/openresty/lualib/resty/jmespath.lua https://raw.githubusercontent.com/jmespath/jmespath.lua/master/jmespath.lua

# 安装resty.http
RUN curl -o /usr/local/openresty/lualib/resty/http.lua https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http.lua \
        -o /usr/local/openresty/lualib/resty/http_headers.lua https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http_headers.lua \
        -o /usr/local/openresty/lualib/resty/http_connect.lua https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http_connect.lua

# 拷贝amis sdk 和html文件
COPY conf.d/static /etc/nginx/static

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]