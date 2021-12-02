-- @File    :   replay.lua
-- @Time    :   2021/11/26 15:57:09
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   此模块处理管理replay数据的请求

local redis = require "resty.redis"
local json = require "cjson"


function response(data)
    local resp = {status=0, message="ok", data=data}
    return json.encode(resp)
end


local rds = redis:new()
local ok, err = rds:connect("172.22.0.99", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

local method = ngx.req.get_method()
local path = ngx.req.get_uri_args()['path']
-- 搜索对应path的replay数据列表
if method == 'GET' then
    local res, err = rds:keys('replay:'..path..':*')
    ret = {}
    for k, v in pairs(res) do
        local trace_id = string.gmatch(v, "replay:%S+:(%S+)")()
        local res, err = rds:get(v)
        -- 组织配置格式
        data = { 
            trace_id = trace_id,
            path = path,
            resp = res
        }
        table.insert(ret, data)
    end
    ngx.say(response(ret))
    return
-- 添加数据到replay数据
elseif method == 'POST' then
    local body = json.decode(ngx.req.get_body_data())
    local key = 'replay:'..body.path..':'..body.trace_id
    local ok, err = rds:set(key, body.resp)
    ngx.say(key)
    return
end

