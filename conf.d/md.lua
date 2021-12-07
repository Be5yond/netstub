-- @File    :   md.lua
-- @Time    :   2021/11/26 15:57:09
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   此模块处理通用的被代理请求数据，   

--              收到请求
--                 |
--             命中回放数据  --Y-->   return replay数据
--                 | N
--             命中mock数据  --Y-->   return mock数据
--                 | N
--             proxy服务返回                



local json = require "cjson" 
local redis = require "resty.redis"
local jmespath = require "resty.jmespath"


-- 连接redis
local rds = redis:new()
local ok, err = rds:connect("172.22.0.99", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

local path = ngx.var.uri

-- 获取trace_id
function get_trace_id()
    local key = 'config:trace_id'
    local res, err = rds:hmget(key, 'header', 'query', 'body')
    -- trace_id在header中
    if res[1] ~= ngx.null then
        local trace_id = ngx.req.get_headers()[res[1]]
        if trace_id then
            return trace_id
        end
    end
    -- trace_id在query中
    if res[2] ~= ngx.null then
        local trace_id = ngx.req.get_uri_args()[res[2]]
        if trace_id then
            return trace_id
        end
    end
    -- trace_id在body中
    if res[3] ~= ngx.null then
        local body = json.decode(ngx.req.get_body_data() or '{}')
        local trace_id = jmespath.search(res[3], body)
        if trace_id then
            return trace_id
        end
    end
end

-- 【replay】
-- 获取trace_id
local trace_id = get_trace_id()
ngx.log(ngx.ERR, '===========================================')
ngx.log(ngx.ERR, 'TRACE_ID=: ', trace_id)
-- 查找回放数据
if trace_id then
    local key = 'replay:'..path..':'..trace_id
    local res, err = rds:get(key)
    if res ~= ngx.null then
        ngx.header['X-replay'] = trace_id
        ngx.say(res)
        return
    end
end


-- 【mock】
-- 查询对应path的mock配置信息
local res, err = rds:hget('config:mock', path)
-- 接口启用mock
if res ~= ngx.null then
    -- 找到匹配mock数据fields
    local fields = json.decode(res)
    -- 计算数据md5
    local tab = {}
    -- 拼接header数据
    if fields.header then
        local headers, err = ngx.req.get_headers()
        for k, v in pairs(fields.header) do
            table.insert(tab, headers[v])
        end
    end
    -- 拼接query数据
    if fields.query then
        local query = ngx.req.get_uri_args()
        for k, v in pairs(fields.query) do
            table.insert(tab, query[v])
        end
    end
    -- 拼接body数据
    if fields.body then
        local body = json.decode(ngx.req.get_body_data() or '{}')
        for k, expression in pairs(fields.body) do
            val = jmespath.search(expression, body)
            table.insert(tab, val)
        end
    end

    local hex = ngx.md5(table.concat(tab))
    -- 查找对应md5配置了mock数据，且数据状态为有效
    local res, err = rds:hmget('mock:'..path..':'..hex, 'switch', 'resp')
    if res ~= ngx.null and res[1]=='true' then
        ngx.header['X-mock'] = hex
        ngx.say(res[2])
        return
    -- else
    --     ngx.say('mock:'..path..hex)
    end
end

