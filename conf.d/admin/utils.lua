-- @File    :   utils.lua
-- @Time    :   2021/12/20 19:43:19
-- @Author  :   wuyangyang
-- @Version :   1.0
-- @Contact :   beyond147896@126.com.com
-- @License :   (C)Copyright 2020-2021, WYY
-- @Desc    :   通用工具函数模块


utils = {}
local json = require "cjson" 

function utils.response(data)
    -- 转换成amis response 标准格式
    -- Args:
    --     data (table): 接口返回的data字段
    local resp = {status=0, message="ok", data=data}
    json.encode_empty_table_as_object(false)
    return json.encode(resp)
end


local function _json_decode(str)
    return json.decode(str)
end


function utils.json_decode( str )
    local ok, t = pcall(_json_decode, str)
    if not ok then
        return nil
    end
    return t
end


return utils