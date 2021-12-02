local cassandra = require "cassandra"

local session = cassandra.new()
session:set_timeout(1000) -- 1000ms timeout

local connected, err = session:connect("jdbc:cassandra://test.cassandra.shareit.sg2.cassandra:8635/sz_item", 8635)

session:set_keyspace("lua_tests")

ngx.say(err)