-- Corecii Cyr 2016-07-19

-- This is a very basic test of the functionality, it is not near complete!
-- This also acts as an example as to how it can be used.

local GAInstance = require(game.ServerStorage.GameAnalytics)

local HttpService = game:GetService("HttpService")

---

-- Submit requests ASAP, or wait until they're scheduled?
local TEST_SUBMIT_NOW = true

---

local ga = GAInstance:new({
	gameKey = "5c6bcb5402204249437fb5a7a80a4959",
	secretKey = "16813a12f718bc5c620f56944e1abc3ea13ccbac",
	url = GAInstance.sandboxUrl
})

print("test init...")
ga:init()
print("inited")

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


local session_start = defAnno:child()
	:set("category", "user")
	:submit(TEST_SUBMIT_NOW)

local business_test = defAnno:child()
	:set(
		"category", "business",
		"amount", 100,
		"currency", "USD",
		"transaction_num", 1,
		"cart_type", "test_implementation"
	)
	:push("event_id", "testType", "testId")
	:clone():child():collapse():submit()  -- test clone, child, and collapse

local resource_test_sink = defAnno:child()
	:set(
		"category", "resource",
		"amount", 50
	)
	:push("event_id", "Sink", "implementor", "sinker", "implementedSink")
	:submit(TEST_SUBMIT_NOW)

local resource_test_sink = defAnno:child()
	:set(
		"category", "resource",
		"amount", 25
	)
	:push("event_id", "Source", "implementor", "sourcer", "implementedSource")
	:submit(TEST_SUBMIT_NOW)

local progression_test_start = defAnno:child()
	:set(
		"category", "progression"
	)
	:push("event_id", "Start", "ex1", "ex2", "ex3")
	:submit(TEST_SUBMIT_NOW)

local progression_test_fail = defAnno:child()
	:set(
		"category", "progression",
		"attempt_num", 1,
		"score", 4
	)
	:push("event_id", "Fail", "ex1", "ex2", "ex3")
	:submit(TEST_SUBMIT_NOW)

progression_test_start:submit()

local progression_test_complete = defAnno:child()
	:set(
		"category", "progression",
		"attempt_num", 2,
		"score", 20
	)
	:push("event_id", "Complete", "ex1", "ex2", "ex3")
	:submit(TEST_SUBMIT_NOW)

print("Did all test requests, any errors are posted.")
