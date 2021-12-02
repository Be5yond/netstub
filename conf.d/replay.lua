
local json = require("cjson")
local redis = require("resty.redis")
local resty_md5  = require "resty.md5"
local str = require "resty.string"
local rds = redis:new()

local ok, err = rds:connect("192.168.8.171", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end


-- 查找对应服务的ip地址   
local env = ngx.var.http_x_env
local host = ngx.var.host

ngx.var.host_ip = ngx.var.host
-- local res, err = rds:hget(env, host)
-- if res ~= ngx.null then
--     ngx.log(ngx.ERR, 'logging:', res, ',', err, res ~= 'null')
--     ngx.var.host_ip = res
-- else
--     return ngx.exit(500)
-- end


-- mock 
-- 查询对应path的配置信息
local path = '/get/jia'
local res, err = rds:hget('config', path)
-- 接口启用mock
if res ~= ngx.null then
    -- 找到mock数据
    local config = json.decode(res)
    md5 = resty_md5:new()
    -- 计算数据md5
    local query = ngx.req.get_uri_args()
    for k, v in pairs(config.query) do
        ngx.log(ngx.ERR, '====================================================================================')
        ngx.log(ngx.ERR, 'CONFIG: QUERY_DATA', query[v])
        val = query[v]
        if not val then
            goto nomock
        end
        local ok = md5:update(query[v])
        if not ok then
            ngx.say("failed to add data")
            return
        end
    end
    -- local body = ngx.req.get_body_data()
    -- for k, v in pairs(config.body) do
    --     ngx.log(ngx.ERR, '====================================================================================')
    --     val = body[v]
    --     if not val then
    --         goto nomock
    --     end
    --     local ok = md5:update(body[v])
    --     if not ok then
    --         ngx.say("failed to add data")
    --         return
    --     end
    -- end
    local digest = md5:final()
    local hex = str.to_hex(digest)
    -- 查找对应md5的返回
    local res, err = rds:hget('mock:'..path..':'..hex, 'resp')
    if res ~= ngx.null then
        ngx.say(res)
        return
    else
        ngx.say('mock:'..path..hex)
    end
else
    ngx.say('123')
    return
end

::nomock::





local res, err = rds:get("isreplay")
-- 回放
if res == '1' then
    local trace = ngx.var.http_x_trace
    local res, err = rds:get(trace)
    if res ~= ngx.null then
        ngx.log(ngx.ERR, 'logging:', res, ',', err, res ~= 'null')
        ngx.say(res)
    end
end

-- 录制
if res == '200' then
    local trace = ngx.var.http_x_trace
    ngx.log(ngx.ERR, 'TTTTT', ':', trace)

    local body = ngx.req.get_body_data()
    ngx.ctx.request_body = body

    local ok, err = rds:set(trace, body)
    if not ok then
        ngx.say("failed to record: ", err)
        return
    end
end

-- mock 
if res == '3' then
    local trace = ngx.var.http_x_trace
    local ok, err = rds:hget(trace, 'body')
    if not ok then
        ngx.say("failed to record: ", err)
        return
    end
end

-- 坑③
local ok, err = rds:set_keepalive(10000, 100) --将连接放入连接池,100个连接，最长10秒的闲置时间
if not ok then --判断放池结果
    ngx.say("failed to set keepalive: ", err)
    return
end