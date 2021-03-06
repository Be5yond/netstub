-- @File    :   replay.lua
-- @Time    :   2021/11/26 15:57:09
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   此模块处理管理replay数据的请求

local redis = require "resty.redis"
local json = require "cjson"
local utils = require "utils"


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
    ngx.say(utils.response(ret))
    return
-- 添加数据到replay数据
elseif method == 'POST' then
    local body = json.decode(utils.get_body_data())
    local key = 'replay:'..body.uri..':'..body.trace_id --body中使用uri字段标识接口路径
    local ok, err = rds:set(key, body.resp_body)
    ngx.say(key)
    return
-- 删除replay数据
elseif method == 'DELETE' then
    local path = ngx.req.get_uri_args()['path']
    local trace_id = ngx.req.get_uri_args()['trace_id']
    local key = 'replay:'..path..':'..trace_id
    local ok = rds:del(key)
    ngx.say(utils.response(key))
    return
end

