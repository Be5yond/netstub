-- @File    :   replay.lua
-- @Time    :   2021/11/26 19:33:09
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   查询loki中的日志数据


local jmespath = require "resty.jmespath"
local http = require "resty.http"
local redis = require "resty.redis"
local json = require "cjson" 
local utils = require "utils"


local rds = redis:new()
local ok, err = rds:connect("172.22.0.99", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end


-- 获取trace_id
function get_trace_id(data)
    -- 从loki返回中解析trace_id
    -- Args:
    --     data (table): loki返回的一条日志数据
    local key = 'config:trace_id'
    local res, err = rds:hmget(key, 'header', 'query', 'body')
    -- trace_id在header中
    if res[1] ~= ngx.null then
        local header = utils.json_decode(data.request_header) or {}
        local trace_id = header[res[1]]
        if trace_id then
            return trace_id
        end
    end
    -- trace_id在query中
    if res[2] ~= ngx.null then
        local query = utils.json_decode(data.request_query) or {}
        local trace_id = query[res[2]]
        if trace_id then
            return trace_id
        end
    end
    -- trace_id在body中
    if res[3] ~= ngx.null then
        local body = utils.json_decode(data.request_body) or {}
        local trace_id = jmespath.search(res[3], body)
        if trace_id then
            return trace_id
        end
    end
end


-- 【搜索日志中的数据】
local httpc = http:new()

-- 拼接筛选条件
local host = ngx.req.get_uri_args()['host']
local uri = ngx.req.get_uri_args()['uri']
local trace_id = ngx.req.get_uri_args()['trace_id']
local loki_query = '{job="varlogs"} | json'
if trace_id then
    loki_query = loki_query..' |="'..trace_id..'"'
end
if host then
    loki_query = loki_query..' | host=~".*'..host..'.*"'
end
if uri then
    loki_query = loki_query..' | uri=~".*'..uri..'.*"'
end

-- 查询最近24小时的数据
start = (ngx.time() - 3600 * 24) * 10000000000

local res, err = httpc:request_uri("http://172.22.0.2:3100/loki/api/v1/query_range", {
    -- headers = ngx.req.get_headers(),
    method = 'GET',
    query = {
        query = loki_query, 
        limit = 10, 
        start = start,
    }
})

if res then
    ngx.header['Content-Type'] = 'application/json; charset=utf-8'
    -- ngx.log(ngx.ERR, 'ERRRR', res.body)
    local body = json.decode(res.body)
    local expression = "data.result[].values[][1]"
    local data = jmespath.search(expression, body)

    local ret = {}
    for k, v in pairs(data) do
        local da = json.decode(v)
        local trace_id = get_trace_id(da)
        local item = {
            req_header = da.request_header,
            req_query = da.request_query, 
            req_body = da.request_body, 
            resp_body = da.response_body, 
            resp_header = da.response_header,
            host = da.host, 
            uri = da.uri, 
            trace_id = trace_id
        }
        table.insert(ret, item)
    end 
    ngx.say(utils.response(ret))
    return
end

