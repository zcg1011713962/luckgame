local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
local sportconst = require "sport.sportconst"
local sportutil = require "sport.sportutil"
require("baloot.matchgame")


MatchOnline = class(MatchGame)
