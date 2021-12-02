
local mysql = require "resty.mysql"
local db, err = mysql:new()
if not db then
    ngx.say("failed to instantiate mysql: ", err)
    return
end

db:set_timeout(1000) -- 1 sec

-- or connect to a unix domain socket file listened
-- by a mysql server:
--     local ok, err, errcode, sqlstate =
--           db:connect{
--              path = "/path/to/mysql.sock",
--              database = "ngx_test",
--              user = "ngx_test",
--              password = "ngx_test" }

local ok, err, errcode, sqlstate = db:connect{
    host = "10.20.2.179",
    port = 3306,
    database = "ushareit_auto_test",
    user = "root",
    password = "@gzNpik2sov#2Qa27gH1",
    charset = "utf8",
    max_packet_size = 1024 * 1024,
}

if not ok then
    ngx.say("failed to connect: ", err, ": ", errcode, " ", sqlstate)
    return
end
-- ngx.say("connected to mysql.")

local res, err, errcode, sqlstate =
        db:query("select * from tb_device order by id asc", 10)
    if not res then
        ngx.say("bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
        return
    end
local cjson = require "cjson"
ngx.say(cjson.encode(res))