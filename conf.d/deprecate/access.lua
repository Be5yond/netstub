
local redis = require "resty.redis"
local rds = redis:new()

local ok, err = rds:connect("192.168.27.239", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

local env = ngx.var.http_x_env
local host = ngx.var.host

-- 查找对应服务的ip地址
local res, err = rds:hget(env, host)
if res ~= ngx.null then
    ngx.log(ngx.ERR, 'logging:', res, ',', err, res ~= 'null')
end
ngx.var.host_ip = res

-- 坑③
rds:set_keepalive(10000, 100)