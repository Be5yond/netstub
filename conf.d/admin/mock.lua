-- @File    :   mock.lua
-- @Time    :   2021/11/23 13:57:12
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   此模块处理管理mock数据的请求，复用一个nginx location，所以用url path来区分接口管理和接口数据管理
--              path = /admin/mock/ 时查看和编辑接口配置
--              path = /admin/mock/{path} 时查看和编辑对应path的mock数据


local redis = require "resty.redis"
local json = require("cjson")
local resty_md5  = require "resty.md5"
local str = require "resty.string"


local rds = redis:new()
local ok, err = rds:connect("172.22.0.99", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end


function response(data)
    local resp = {status=0, message="ok", data=data}
    return json.encode(resp)
end


local method = ngx.req.get_method()
if ngx.var.uri == '/admin/mock/' then
    -- 返回mock的path列表
    if method == 'GET' then
        local res, err = rds:hgetall('config:mock')
        ret = {}
        -- 处理config中的所有数据放到table中
        for i=1, #res, 2 do
            data = json.decode(res[i+1])
            data['path'] = res[i]
            table.insert(ret, data)
        end
        ngx.say(response(ret))
        return

    -- 新增或者修改mock配置
    elseif method == 'POST' then
        local body = json.decode(ngx.req.get_body_data())
        local path = body.path
        body.path = nil
        local ok = rds:hset('config:mock', path, json.encode(body))
        if not ok then
            ngx.say("failed to record: ", err)
        end
    end

else
    local path = string.sub(ngx.var.uri, 12) -- uri为/static/mock/...  从12个字符之后的字符串为实际的path
    -- 返回对应path的mock数据列表
    if method == 'GET' then
        local res, err = rds:keys('mock:'..path..':*')
        ret = {}
        for k, v in pairs(res) do
            local res, err = rds:hgetall(v)
            data = { id = string.sub(v, -32) }
            -- 组织配置格式
            for i=1, #res, 2 do
                -- data[res[i]] = json.decode(res[i+1])
                data[res[i]] = res[i+1]
            end
            table.insert(ret, data)
        end
        ngx.say(response(ret))
        return

    -- 添加或修改
    mock数据配置
    elseif method == 'POST' then
        local body = json.decode(ngx.req.get_body_data())
        local hash = ngx.md5(table.concat(json.decode(body.data)))
        local key = 'mock:'..path..':'..hash
        ngx.say(key)
        -- local ok = rds:hset(key, 'data', body.data)
        -- local ok = rds:hset(key, 'resp', body.resp)
        local ok, err = rds:hmset(key, 'data', body.data, 'resp', body.resp, 'switch', body.switch, 'info', body.info, 'delay', body.delay)
        ngx.say(ok, err)
        ngx.say(response(type(body.switch)))
        return

    -- 删除mock数据配置
    elseif method == 'DELETE' then
        local hash = ngx.req.get_uri_args()['id']
        local key = 'mock:'..path..':'..hash
        local ok = rds:del(key)
        ngx.say(response(key))
        return
    end
end


ngx.say(response('ok'))
return
