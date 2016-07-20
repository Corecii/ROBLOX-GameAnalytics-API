-- Corecii Cyr 2016-07-19

-- Basic example of using this api to send various requests

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

ga:init()

-- Default annotations that work for every user.
-- Unfortunately, ROBLOX doesn't give us access to and device/platform/manufacturer info
--  Because of this, we will set them all to whatever works. the GA servers only accept actual OS/platforms, so we'll use windows.
local defAnnoAll = ga:request({
	v = 2,
	sdk_version = "rest api v2",
	os_version = "windows 0",
	platform = "windows",
	manufacturer = "unknown",
	device = "unknown",
	build = "1",
})

-- Create default annotations for a specific user.
-- Collapse this request so that the annotations for this user cannot
--  change. You should also be saving the data here so that you can properly
--  signal a session end if the server crashes.
local defAnnoUser = defAnnoAll:child({
	user_id = HttpService:GenerateGUID(false):lower(),
	session_id = HttpService:GenerateGUID(false):lower(),
	session_num = 1
}):collapse()

local session_start = defAnnoUser:child()
	:set("category", "user")
	:submit(TEST_SUBMIT_NOW)

local business_test = defAnnoUser:child()
	:set(
		"category", "business",
		"amount", 100,
		"currency", "USD",
		"transaction_num", 1,
		"cart_type", "test_implementation"
	)
	:push("event_id", "testType", "testId")
	:submit(TEST_SUBMIT_NOW)

local resource_test_sink = defAnnoUser:child()
	:set(
		"category", "resource",
		"amount", 50
	)
	:push("event_id", "Sink", "implementor", "sinker", "implementedSink")
	:submit(TEST_SUBMIT_NOW)

local resource_test_sink = defAnnoUser:child()
	:set(
		"category", "resource",
		"amount", 25
	)
	:push("event_id", "Source", "implementor", "sourcer", "implementedSource")
	:submit(TEST_SUBMIT_NOW)

local progression_test_start = defAnnoUser:child()
	:set(
		"category", "progression"
	)
	:push("event_id", "Start", "ex1", "ex2", "ex3")
	:submit(TEST_SUBMIT_NOW)

local progression_test_fail = defAnnoUser:child()
	:set(
		"category", "progression",
		"attempt_num", 1,
		"score", 4
	)
	:push("event_id", "Fail", "ex1", "ex2", "ex3")
	:submit(TEST_SUBMIT_NOW)

progression_test_start:submit(TEST_SUBMIT_NOW)  -- You can submit a request multiple times.

local progression_test_complete = defAnnoUser:child()
	:set(
		"category", "progression",
		"attempt_num", 2,
		"score", 20
	)
	:push("event_id", "Complete", "ex1", "ex2", "ex3")
	:submit(TEST_SUBMIT_NOW)

print("Did all test requests")
