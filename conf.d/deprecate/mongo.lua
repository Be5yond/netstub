local moongoo = require("resty.moongoo")

local mg, err = moongoo.new("mongodb://test1:I%3FaeW1xaaAdJ%3FyUh@10.20.5.105:8635,10.20.2.151:8635/shareit_contacts?authSource=admin")
if not mg then
    error(err)
end

local col = mg:db("shareit_contacts"):collection("contacts")

local doc, err = col:find_one({ c = "7ESu2"})

local cjson = require "cjson"
ngx.say(cjson.encode(doc))