-- @File    :   replay.lua
-- @Time    :   2021/11/26 19:33:09
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   查询loki中的日志数据


local jmespath = require "resty.jmespath"
local http = require "resty.http"


function response(data)
    local resp = {status=0, message="ok", data=data}
    return json.encode(resp)
end


-- 搜索日志中的数据
local httpc = http:new()
local trace_id = ngx.req.get_uri_args()['trace_id']

start = (ngx.time() - 3600 * 24) * 10000000000
ngx.log(ngx.ERR, '---------------------------------------------------------------------------')
ngx.log(ngx.ERR, 'ERRRR', start)
loki_query = '{filename="/var/log/access.log"}|="httpbin.org"|="'..trace_id..'"!="admin/replay"'..'!="admin/loki"'
-- loki_query = '{filename="/var/log/access.log"}|="httpbin.org"|="trace_id_test"!="admin/replay"'

local res, err = httpc:request_uri("http://172.22.0.2:3100/loki/api/v1/query_range", {
    -- headers = ngx.req.get_headers(),
    method = 'GET',
    query = {
        query = loki_query, 
        limit = 10, 
        start = start,

        -- start = '1637136240316865800'
    }
})

if res then
    ngx.header['Content-Type'] = 'application/json; charset=utf-8'
    ngx.log(ngx.ERR, 'ERRRR', res.body)
    body = json.decode(res.body)
    expression = "data.result[].values[][1]"
    data = jmespath.search(expression, body)

    ret = {}
    for k, v in pairs(data) do
        da = json.decode(v)
        table.insert(ret, {response=da.response_body, uri=da.uri, trace_id=trace_id})
    end 
    ngx.say(response(ret))
    return
end

