-- @File    :   mock.lua
-- @Time    :   2021/11/23 13:57:12
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   此模块处理管理mock数据的请求
--              path = /admin/mock/path 管理mock接口配置
--              path = /admin/mock/host 管理mock域名分组配置
--              path = /admin/mock/data 管理mock数据


local redis = require "resty.redis"
local json = require "cjson" 
local resty_md5  = require "resty.md5"
local str = require "resty.string"
local utils = require "utils"


local rds = redis:new()
local ok, err = rds:connect("172.22.0.99", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end


function get_path_config(keys, prefix)
    -- 根据输入的redis keys列表查找域名下mock接口列表, index页配置列表使用
    -- Args:
    --     keys (table): 接口配置redis键列表， key格式 config:mock:{group}:{domain}  
    --     prefix (str): path前缀过滤
    local list = {}
    for idx, key in pairs(keys) do
        local domain = string.gmatch(key, 'config:mock:%S+:(%S+)')()
        -- 查询域名下mock接口列表
        local paths, err = rds:smembers(key)
        -- 按前缀过滤paths
        for k=#paths, 1, -1 do
            if not string.gmatch(paths[k], prefix)() then
                table.remove(paths, k)
            end
        end
        table.sort(paths)
        for i, path in pairs(paths) do
            -- 查询接口下 mock数据列表
            local res, err = rds:hgetall('config:path:'..path)
            item = { 
                type = 'path', 
                path = path, 
                domain = domain, 
                children = get_mock_data(path) 
            }
            -- 组织配置格式
            for i=1, #res, 2 do
                item[res[i]] = res[i+1]
            end
            local data = utils.json_decode(item['data'])
            if data then
                item['header'] = data.header
                item['query'] = data.query
                item['body'] = data.body
            end
            table.insert(list, item)
        end
    end
    return list
end

function get_mock_data(path)
    -- 获取接口对应的mock数据
    -- Args
    --    path (str): 接口地址, 例如/test/mock
    local res, err = rds:keys('mock:'..path..':*')
    local ret = {}
    for k, v in pairs(res) do
        local res, err = rds:hgetall(v)
        local item = { domain=string.sub(v, -32), type='data', path=path } -- 截取key，获取数据id, 因为前端列表和domain复用一列，所以key=domain
        -- 组织配置格式
        for i=1, #res, 2 do
            -- data[res[i]] = json.decode(res[i+1])
            item[res[i]] = res[i+1]
        end
        local data = utils.json_decode(item['data'])
        if data then
            item['header'] = data.header
            item['query'] = data.query
            item['body'] = data.body
        end
        table.insert(ret, item)
    end
    return ret
end

function get_path_names(keys)
    -- 返回配置了mock的接口名称列表, mock数据页查询接口名称
    -- Args
    --    keys (table): 接口配置redis键列表， key格式 config:mock:{group}:{domain}
    local list = {}
    for idx, key in pairs(keys) do
        local paths, err = rds:smembers(key)
        for i, path in pairs(paths) do
            table.insert(list, {label=path, value=path})
        end
    end
    return list
end


local method = ngx.req.get_method()
-- 快速编辑接口default数据状态
if ngx.var.uri == '/admin/mock/path/quick' then
    local body = json.decode(ngx.req.get_body_data())
    local key = "config:path:"..body.path
    local ok, err = rds:hset(key, 'switch', body.switch)
    ngx.say(utils.response(ok))
    return

-- 快速编辑mock数据接口状态
elseif ngx.var.uri == '/admin/mock/data/quick' then
    local body = json.decode(ngx.req.get_body_data())
    local key = "mock:"..body.path..':'..body.domain  -- 前端数据id复用domain列
    local ok, err = rds:hset(key, 'switch', body.switch)
    ngx.say(utils.response(ok))
    return

-- 管理mock接口配置信息
elseif ngx.var.uri == '/admin/mock/path' then
    -- 返回mock的path列表
    if method == 'GET' then
        local chained = ngx.req.get_uri_args()['chained'] or ''
        local text = ngx.req.get_uri_args()['text'] or '/'
        local group, domain = string.gmatch(chained, '(%S+),(%S+)')()
        group = group or '*'
        domain = domain or '*'
        local keys, err = rds:keys('config:mock:'..group..':'..domain)

        local type = ngx.req.get_uri_args()['type']
        if type == 'name' then
            ret = get_path_names(keys)
        else
            ret = get_path_config(keys, text)
        end
        ngx.say(utils.response(ret))
        return
    -- 新增或者修改mock path配置
    elseif method == 'POST' then
        local body = json.decode(ngx.req.get_body_data())
        local path = body.path
        local group, domain = string.gmatch(body.chained, '(%S+),(%S+)')()
        body.chained = nil
        -- 添加path到域名下路径集合
        local ok, err = rds:sadd('config:mock:'..group..':'..domain, path)
        -- local ok, err = rds:hset('config:mock', path, json.encode(body))
        -- 添加config:path 配置
        local data = {header=body.header, query=body.query, body=body.body}
        local ok, err = rds:hmset('config:path:'..path, 
            'data', json.encode(data), 
            'resp', body.resp or '{}', 
            'switch', body.switch or 'false', 
            'info', body.info or '', 
            'delay', body.delay or 0)
        if not ok then
            ngx.say("failed to record: ", err)
        end
    -- 删除mock path配置
    elseif method == 'DELETE' then
        local path = ngx.req.get_uri_args()['path']
        local domain = ngx.req.get_uri_args()['id']
        local key = 'mock:path:'..path
        local ok, err = rds:del(key)
        local domkey = rds:keys('config:mock:*:'..domain)[1] -- 获取domain path集合对应的key
        local ok, err = rds:srem(domkey, path)
        ngx.say(utils.response(key))
        return
    end

-- 管理服务的分组与域名
elseif ngx.var.uri == '/admin/mock/domain' then
    -- 返回服务域名列表
    if method == 'GET' then
        local level = ngx.req.get_uri_args()['level']
        -- 第一层级联选项，返回项目分组
        if level == '' then
            local res, err = rds:smembers('config:mock:groups')
            table.sort(res)
            ret = {}
            for k, v in pairs(res) do
                item = {label=v, value=v}
                table.insert(ret, item)
            end
            ngx.say(utils.response(ret))
            return
        -- 第二层级联选线，返回分组下域名列表
        elseif level == '1' then 
            local group = ngx.req.get_uri_args()['parentId']
            local res, err = rds:keys('config:mock:'..group..':*')
            ret = {}
            for k, v in pairs(res) do
                domain = string.gmatch(v, "config:mock:%S+:(%S+)")()
                item = {label=domain, value=domain}
                table.insert(ret, item)
            end
            ngx.say(utils.response(ret))
            return
        else
            ret = {status=0, data=nil}
            ngx.say(json.encode(ret))
            return
        end
    -- 新增一个域名
    elseif method == 'POST' then
        local body = json.decode(ngx.req.get_body_data())
        local ok, err = rds:sadd('config:mock:groups', body.group)
        local ok, err = rds:sadd('config:mock:'..body.group..':'..body.domain, '_')
    end

-- 管理mock数据
elseif ngx.var.uri == '/admin/mock/data' then
    local path = ngx.req.get_uri_args()['path']
    -- 返回对应path的mock数据列表
    if method == 'GET' then
        local res, err = rds:keys('mock:'..path..':*')
        ret = {}
        for k, v in pairs(res) do
            local res, err = rds:hgetall(v)
            data = { id = string.sub(v, -32) }
            -- 组织配置格式,将列表转换成k-v格式的table 
            for i=1, #res, 2 do
                data[res[i]] = res[i+1]
            end
            table.insert(ret, data)
        end
        ngx.say(utils.response(ret))
        return
    -- 添加或修改mock数据配置
    elseif method == 'POST' then
        local type = ngx.req.get_uri_args()['type']
        local body = json.decode(ngx.req.get_body_data())
        -- local hash = ngx.md5(table.concat(json.decode(body.data)))
        -- 计算数据md5
        local tab = {}
        -- 拼接header数据
        for k, v in pairs(body.header or {}) do
            table.insert(tab, v)
        end
        -- 拼接query数据
        for k, v in pairs(body.query or {}) do
            table.insert(tab, v)
        end
        -- 拼接body数据
        for k, v in pairs(body.body or {}) do
            table.insert(tab, v)
        end
        local hash = ngx.md5(table.concat(tab))
        local key = 'mock:'..body.path..':'..hash
        local data = {header=body.header, query=body.query, body=body.body}
        local ok, err = rds:hmset(key, 
            'data', json.encode(data), 
            'resp', body.resp, 
            'switch', body.switch, 
            'info', body.info, 
            'delay', body.delay)

        ngx.say(utils.response(err))
        return
    -- 删除mock数据配置
    elseif method == 'DELETE' then
        local hash = ngx.req.get_uri_args()['id']
        local key = 'mock:'..path..':'..hash
        local ok, err = rds:del(key)
        ngx.say(utils.response(key))
        return
    end
end


ngx.say(utils.response('ok'))
return
