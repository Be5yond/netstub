# netstub
基于openresty实现的网络桩工具

# Feature
- 请求的mock和回放
  - 基于规则的mock,同一api可配置多条mock数据
  - 基于trace_id的回放,将特定请求录制再次请求时返回确定的值
- 环境逻辑复用
- 日志的定制化与预处理
- 日志数据汇总与持久化以便数据分析

# Requirments
- Docker
- docker-compose

# Quick Start
1. git clone https://github.com/Be5yond/netstub.git   
2. 修改coredns/hosts文件将要mock的服务域名改为netstub设备的ip, 如：192.168.2.20
```
192.168.2.20 httpbin.org
192.168.2.20 www.zhihu.com
192.168.2.20 www.baidu.com
```
3. 配置mock数据   
修改本地电脑hosts文件,以便进入管理页面。   
192.168.2.20 www.netstub.com   
进入管理界面http://www.netstub.com/static/index.html    
①  配置mock规则：对于/get的api, query中的page字段，参与数据计算   
![mock_rule.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/config_rule.png)
② 配置mock数据, page=1时，返回{"page": 1}   
   page=2时，返回{"page": 2}
![mock_data.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/config_data.png)
4. 测试请求   
请求query中page=1，命中mock规则c4ca4238a0b923820dcc509a6f75849b，返回mock数据
```
❯ http http://192.168.2.20/get?page=1 Host:httpbin.org
HTTP/1.1 200 OK
Connection: keep-alive
Content-Type: application/json; charset=utf-8
Date: Fri, 03 Dec 2021 02:54:05 GMT
Server: openresty/1.19.9.1
Transfer-Encoding: chunked
X-mock: c4ca4238a0b923820dcc509a6f75849b

{
    "page": 1
}
```
请求query中page=2，命中mock规则c81e728d9d4c2f636f067f89cc14862c，返回mock数据
```
❯ http http://192.168.2.20/get?page=2 Host:httpbin.org
HTTP/1.1 200 OK
Connection: keep-alive
Content-Type: application/json; charset=utf-8
Date: Fri, 03 Dec 2021 02:54:40 GMT
Server: openresty/1.19.9.1
Transfer-Encoding: chunked
X-mock: c81e728d9d4c2f636f067f89cc14862c

{
    "page": 2
}
```
请求query中page=3，未命中mock规则, 返回服务端数据
```
❯ http http://192.168.2.20/get?page=3 Host:httpbin.org
HTTP/1.1 200 OK
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *
Connection: keep-alive
Content-Length: 324
Content-Type: application/json; charset=utf-8
Date: Fri, 03 Dec 2021 02:54:57 GMT
Server: openresty/1.19.9.1

{
    "args": {
        "page": "3"
    },
    "headers": {
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate",
        "Host": "httpbin.org",
        "User-Agent": "HTTPie/2.2.0",
        "X-Amzn-Trace-Id": "Root=1-61a98702-18966bec192a4d7d0089172a"
    },
    "origin": "124.156.108.193",
    "url": "http://httpbin.org/get?page=3"
}
```
5. 客户端使用   
① 配置手机DNS服务地址为192.168.2.20   
② 访问 http://httpbin.org/get?page=1 即可返回mock数据


# Info
## 1.使用服务端反向代理的好处
![proxy.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/proxy.png)
- mock数据共享
- 数据统计分析   
   
客户端接入netstub流程
![process.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/process.png)

## 2.服务端mock
一个典型的系统，服务A依赖服务B和服务C的返回。   
![topo_net.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/topo_net.png)

如果要对服务A进行测试，那么对于服务A来说，服务B和服务C的返回可以认为是另一种输入，在一些特定的场景如回归测试，需要保证输入的一致以便输出固定的预期结果。需要有手段对依赖服务的返回进行控制即mock。   
![topo_star.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/topo_star.png)
接入netstub后，网络变成星状的拓扑，所有服务之间的请求都经过nginx, 可以对服务的返回进行控制。
![topo_mock.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/topo_mock.png)

## 3.虚拟环境复用
所有流量都经过网络桩，除了请求日志的记录，还可以对流量进行路由转发控制。
通过在请求中添加环境标识，将请求转发到特定的服务，从而使得多个版本的服务可以在同一环境进行运行。
一般场景下的多环境，每个环境需要部署全套服务。
![env_multi.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/env_multi.png)
利用netstub进行转发
![topo_env.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/topo_env.png)
对服务进行复用,从而达到节约资源的目的
![env_virtual.png](https://raw.githubusercontent.com/Be5yond/netstub/main/imgs/env_virtual.png)


