-- Corecii Cyr 2016-07-19

-- Test most of the functionality of this API

local GAInstance = require(game.ServerStorage.GameAnalytics)

local HttpService = game:GetService("HttpService")

---

local sandboxGameKey = "5c6bcb5402204249437fb5a7a80a4959"
local sandboxSecretKey = "16813a12f718bc5c620f56944e1abc3ea13ccbac"

local hasherTestBody = '{"test": "test"}'
local hasherTestHash = 'slnR8CKJtKtFDaESSrqnqQeUvp5FaVV7d5XHxt50N5A='

local testUnnecessaryScheduler = GAInstance.DefaultScheduler:new()

local ga = GAInstance:new({
	gameKey = sandboxGameKey,
	secretKey = sandboxSecretKey,
	url = GAInstance.sandboxUrl,
	scheduler = testUnnecessaryScheduler
})

assert(ga, "Failed! GameAnalyticsInstance:new did not return an instance")
assert(ga.gameKey == sandboxGameKey, "Failed! GameAnalyticsInstance:new failed to set the proper game key")
assert(ga.secretKey == sandboxSecretKey, "Failed! GameAnalyticsInstance:new failed to set the proper secret key")
assert(ga.url == GAInstance.sandboxUrl, "Failed! GameAnalyticsInstance:new failed to set the proper url")
assert(ga.hasher, "Failed! GameAnalyticsInstance:new did not create a hashing function")
assert(ga.hasher(hasherTestBody) == hasherTestHash, "Failed! GameAnalyticsInstance:new's hashing function does not return the correct values")

ga:init()
assert(ga.hasInit, "Failed! GameAnalyticsInstance:init did not set hasInit properly")
assert(ga.sendEvents ~= nil, "Failed! GameAnalyticsInstance:init did not set sendEvents properly")
assert(ga.timestampOffset, "Failed! GameAnalyticsInstance:init did not set the timestamp offset properly or could not init")

local defAnno = ga:request({
	device = "unknown",
	v = 2,
	user_id = HttpService:GenerateGUID(false):lower(),
	sdk_version = "rest api v2",
	os_version = "windows 0",
	manufacturer = "unknown",
	platform = "windows",
	session_id = HttpService:GenerateGUID(false):lower(),
	session_num = 1,
	build = "1",
})


local req, res = defAnno:child()
	:set("category", "user")
	:submit(true)
assert(res[1][1], "Failed! Did not submit properly: "..tostring(res[1][2]))
-- If this works then requests in general work.
-- The next step is to check if :child, :clone, :collapse, and :derive work properly.


local ancestorTest = ga:request():set("ancestorValue", 4)
local parentTest = ancestorTest:child():set("parentValue", 5)
local childTest = parentTest:child():set("childValue", 6)

local cloneInheritanceTest = childTest:clone():collapse()
assert(cloneInheritanceTest:get("childValue") == 6, "Failed! GARequest does not clone values properly")
assert(cloneInheritanceTest:get("parentValue") == 5, "Failed! GARequest does not inherit parent values properly on clones")
assert(cloneInheritanceTest:get("ancestorValue") == 4, "Failed! GARequest does not inherit ancestor values properly on clones")

local deriveInheritanceTest = childTest:derive()
assert(deriveInheritanceTest:get("childValue") == 6, "Failed! GARequest does not derive values properly")
assert(deriveInheritanceTest:get("parentValue") == 5, "Failed! GARequest does not inherit parent values properly on derived request")
assert(deriveInheritanceTest:get("ancestorValue") == 4, "Failed! GARequest does not inherit ancestor values properly on derived requests")

childTest:collapse()
assert(childTest:get("childValue") == 6, "Failed! GARequest does not collapse values properly")
assert(childTest:get("parentValue") == 5, "Failed! GARequest does not inherit parent values properly on collapsed children")
assert(childTest:get("ancestorValue") == 4, "Failed! GARequest does not inherit ancestor values properly on collapsed children")

childTest = parentTest:child()
ancestorTest:push("testFragments", "a", "b")
parentTest:push("testFragments", "c")
childTest:push("testFragments", "d", "e")

assert(
	ancestorTest.data._sub_testFragments
	and ancestorTest.data._sub_testFragments[1] == "a"
	and ancestorTest.data._sub_testFragments[2] == "b",
	"Failed! GARequest does not push values properly"
)

local ancestorClone = ancestorTest:clone()
assert(
	ancestorClone.data._sub_testFragments
	and ancestorClone.data._sub_testFragments[1] == "a"
	and ancestorClone.data._sub_testFragments[2] == "b",
	"Failed! GARequest does not clone values properly"
)

ancestorClone:collapse(true)
assert(ancestorClone:get("testFragments") == "a:b", "Failed! GARequest does not collapse fragments properly")

local child2Test = childTest:child():pop("testFragments", 4):push("testFragments", "f", "g"):collapse(true)
assert(child2Test:get("testFragments") == "a:f:g", "Failed! GARequest:pop/:push does not pop/push values across multiple ancestors properly")

print("All GameAnalytics tests succeeded")
