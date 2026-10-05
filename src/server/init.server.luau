--!strict
local MatchServer = require("@self/Match/MatchServer")
local TestStage = require("@self/TestStage/TestStage")

TestStage.buildIfMissing()
MatchServer.start()
