-- Corecii Cyr 2016-07-19

-- See http://restapidocs.gameanalytics.com for element names and values

-- Normally I use my own custom require system here.
-- In order to maintain similarty to my own code and compatibility
--  with others', I have replaced my system with a small one that
--  does the job for just this module. Feel free to replace it with
--  your own code if you want to organize the contained modules
--  differently.
local require = function(name)
	if type(name) == "string" then
		local obj = script:FindFirstChild(name)
		if obj and obj:IsA("ModuleScript") then
			return require(obj)
		else
			error("Could not find the module `"..name.."`")
		end
	end
	return require(name)
end

local HttpService = game:GetService("HttpService")

local Class = require("Class")

local lockbox = require("lockbox")
local enum = require("enum")
-- I personally use an HTTP-based UTC time synchronization module to get my times
-- If you use a similar solution and you need to keep times synchronized
--  between this module and other parts of your game then change this function.
local GET_TIME = function()
	return tick()
end

local tconcat = table.concat
local tinsert = table.insert
local tsort = table.sort
local mrandom = math.random
local mfloor = math.floor
local JSONEncode = HttpService.JSONEncode
local JSONDecode = HttpService.JSONDecode
local PostAsync = HttpService.PostAsync

---

local buildHmacAuthHasher
do
	local array = require(lockbox.util.array)
	local stream = require(lockbox.util.stream)
	local base64 = require(lockbox.util.base64)
	local hmac = require(lockbox.mac.hmac)
	local sha256 = require(lockbox.digest.sha2_256)
	local fromArrayBase64 = base64.fromArray
	local fromStringStream = stream.fromString
	local fromStringArray = array.fromString

	local hasherMeta =
		{
			__call = function(this, body)
				return fromArrayBase64(
					this.init()
						.update(fromStringStream(body))
						.finish()
						.asBytes()
				)
			end
		}

	function buildHmacAuthHasher(key)
		return setmetatable(
			hmac()
				.setBlockSize(64)
				.setDigest(sha256)
				.setKey(fromStringArray(key)),
			hasherMeta
		)
	end
end

local DefaultScheduler
DefaultScheduler = Class:new({
	submitTime = 60,
	maxSizeChars = (1024*1024)*0.9,  -- limit amount of chars.
	construct = function(this)
	end,
	schedule = function(this, request, now)
		if now then
			return this:submitRequests({request})
		else
			if not this.scheduledRequests then
				this.scheduledRequests = {}
				spawn(function()
					wait(this.submitTime)
					local reqs = this.scheduledRequests
					this.scheduledRequests = nil
					this:submitRequests(reqs)
				end)
			end
			this.scheduledRequests[#this.scheduledRequests + 1] = request
		end
	end,
	submitRequests = function(this, requests)
		local submitRequest = this.internalSubmitRequest
		local buckets, results = {}, {}
		for i, v in next, requests do
			local gameKey = v:getGameKey()
			local secretKey = v:getSecretKey()
			local url = v:getUrl()
			local bucketId = v.getBucketId and v:getBucketId() or ""
			local uniqueId = gameKey..secretKey..url..bucketId
			local bucket = buckets[uniqueId]
			if not bucket then
				bucket = {
					gameKey = gameKey,
					secretKey = secretKey,
					hasher = v:getHasher(),
					url = url,
					bucketId = bucketId,
					requests = {}
				}
				buckets[uniqueId] = bucket
			end
			bucket.requests[#bucket.requests + 1] = v:getRequestTable()
		end
		for index, bucket in next, buckets do
			local reqsRaw = bucket.requests
			local reqs = {{JSONEncode(HttpService, bucket.requests), 1, #reqsRaw}}
			local builder, succ, val = {}
			local i, v = 1
			while i <= #reqs do
				v = reqs[i]
				if #v[1] > this.maxSizeChars then
					local start, stop
					do
						start = v[2] - 1
						stop = start + mfloor((v[3] - start)/2)
						for i2 = 1, stop - start do
							builder[i2] = reqsRaw[start + i2]
						end
						v[1], v[2], v[3] = JSONEncode(HttpService, builder), start + 1, stop
						for i2 = #builder, 1, -1 do
							builder[i2] = nil
						end
					end
					do
						start = stop
						stop = v[3]
						for i2 = 1, stop - start do
							builder[i2] = reqsRaw[start + i2]
						end
						tinsert(reqs, i + 1, {JSONEncode(HttpService, builder), start + 1, stop})
						for i2 = #builder, 1, -1 do
							builder[i2] = nil
						end
					end
				else  -- if we split the requests then we need to check it again before continuing
					i = i + 1
					succ, val = submitRequest(this, bucket, v[1])
					results[#results + 1] = {succ, val, bucket, v}
				end
			end
		end
		return results
	end,
	internalSubmitRequest = function(this, info, request)
		--[[  -- DEBUG
		print("POSTING:")
		print(" -  url:", info.url)
		print(" - data:\n", request)
		--]]  -- DEBUG
		local success, val = pcall(PostAsync, HttpService,
			info.url,
			request,
			Enum.HttpContentType.ApplicationJson,
			false,
			{
				Authorization = info.hasher(request, info)
			}
		)
		--pcall(this.internalPost, info, request)
		if success then
			--[[
			warn("Post Success:")
			warn(val)
			print()
			--]]
			return success, val
		else
			warn("Post Failure:")
			warn(val)
			print()
			return success, val
		end
	end
}):new()

local waitForInit = function(obj)
	while not obj.hasInit do
		wait()
	end
end

local GameAnalyticsInstance, GameAnalyticsRequest
GameAnalyticsInstance = Class:new({
	DefaultScheduler = DefaultScheduler,
	waitForInit = waitForInit,
	scheduler = DefaultScheduler,
	url = "http://api.gameanalytics.com",  -- had problems with https://
	sandboxUrl = "http://sandbox-api.gameanalytics.com",
	construct = function(this, options)
		assert(options ~= nil, "You must provide an options table (parameter 1)")
		assert(type(options) == 'table', "Options (parameter 1) must be a table")
		assert(options.gameKey ~= nil, "You must provide a gameKey string in the options table")
		assert(type(options.gameKey) == "string", "gameKey should be a string")
		assert(options.secretKey ~= nil, "You must provide a secretKey string in the options table")
		assert(type(options.secretKey) == "string", "secretKey should be a string")
		assert(
			options.scheduler == nil or (type(options.secretKey) == "table" and type(options.schedule)),
			"If you provide a scheduler, it must be a table with a 'schedule' method"
		)
		assert(
			options.url == nil or (type(options.url) == "string" and options.url:match("^https?://")),
			"If you provide a url, it must be a string starting with `http://` or `https://`"
		)

		this.gameKey = options.gameKey
		this.secretKey = options.secretKey
		this.scheduler = options.scheduler
		this.url = options.url

		this.hasher = buildHmacAuthHasher(this.secretKey)

		this.hasInit = nil
		this.sendEvents = nil
		this.timestampOffset = nil
	end,
	init = function(this)
		this.hasInit = false
		local request = this.GameAnalyticsRequest:new(this)
			:setInit({
				platform = "roblox",
				os_version = "unknown",
				sdk_version = "rest api v2"
			})
		local myTS = GET_TIME()
		local result = this.scheduler:schedule(request, true)[1]
		if not result[1] then
			this.sendEvents = false
			warn("init failure:")
			warn(result[2])
		else
			local succ, data = pcall(function()
				return JSONDecode(HttpService, result[2])
			end)
			if succ then
				if type(data.enabled) ~= "boolean" or type(data.server_ts) ~= "number" then
					this.sendEvents = false
					warn("init data failure, enabled was not a boolean or timestamp was not a number:")
					warn(result[2])
				else
					this.sendEvents = true
					this.timestampOffset = data.server_ts - myTS
				end
			else
				warn("init JSONDecode failure:")
				warn(data)
				warn(result[2])
			end
		end
		this.hasInit = true
	end,
	request = function(this, data)
		local req = this.GameAnalyticsRequest:new(this)
		if data then
			req:setTable(data)
		end
		return req
	end
})

local gtblnum, gtbli
local function getTableSize(tbl)
	gtblnum = #tbl
	if gtblnum > 0 then
		return gtblnum
	end
	gtbli = 0
	while tbl[gtbli] do
		gtbli = gtbli - 1
	end
	return gtbli ~= 0 and gtbli
end

local function submitterWait(this, now)
	-- ALSO EDIT :submit BELOW
	this.instance:waitForInit()
	if this.instance.sendEvents then
		this:set("client_ts", mfloor(GET_TIME() + this.instance.timestampOffset))
		return this.instance.scheduler:schedule(this, now) or this
	elseif now then
		return
	else
		return this
	end
end

GameAnalyticsRequest = Class:new({
	routes = enum("events", "init"),
	Nil = {},
	construct = function(this, instance, parent)
		assert(instance, "You must provide a GameAnalyticsInstance (parameter 1)")
		this.instance = instance
		this.parent = parent
		this.route = parent and parent.route or this.routes()
		this.data = {}
	end,

	setRoute = function(this, route)
		this.route = this.routes(route)
		return this
	end,
	setInit = function(this, initInfo)
		this
			:setRoute(this.routes("init"))
			.data = initInfo
		return this
	end,
	set = function(this, ...)
		local t = {...}
		for i = 1, #t, 2 do
			this.data[t[i]] = t[i + 1]
		end
		return this
	end,
	get = function(this, ...)
		local t = {...}
		for i = 1, #t do
			t[i] = this.data[t[i]]
		end
		return unpack(t)
	end,
	setTable = function(this, data)
		for k, v in next, data do
			this.data[k] = v
		end
		return this
	end,
	push = function(this, key, ...)
		local data = this.data
		local push = {...}
		if data[key] then
			tinsert(push, 1, data[key])
			data[key] = nil
		end
		local name = "_sub_"..key
		local tb = data[name]
		if not tb then
			tb = {}
			data[name] = tb
		end
		local num = getTableSize(tb) or 0
		for i = 1, #push do
			tb[num + i] = push[i]
		end
		return this
	end,
	pop = function(this, key, amt)
		local vals = {}
		local data = this.data
		local val = data[key]
		local o = 0
		if val ~= nil then
			vals[1] = data[key]
			data[key] = nil
			o = 1
		end
		if val == nil or (amt or 1) > 1 then
			local name = "_sub_"..key
			local tb = data[name]
			if not tb then
				tb = {}
				data[name] = tb
			end
			local num = getTableSize(tb) or 0
			for i = 0, (amt or 1) - 1 do
				vals[i + o + 1] = tb[num - i]
				tb[num - i] = num > 0 and nil or this.Nil
			end
		end
		return this, unpack(vals)
	end,

	clone = function(this)
		local cloneObj = this:new(this.instance, this.parent)
		cloneObj.route = this.route
		for k, v in next, this.data do
			if k:match("^_sub_(.*)") then
				local t = {}
				for i = 1, #v do
					t[i] = v[i]
				end
				cloneObj:set(k, t)
			else
				cloneObj:set(k, v)
			end
		end
		return cloneObj
	end,
	child = function(this)
		return this:new(this.instance, this)
	end,
	collapse = function(this)
		-- collapse all parent data down into this one and remove the parent property
		local data = {}
		local top, req = {this}
		while top[1].parent do
			top = {top[1].parent, top}
		end
		repeat
			req = top[1]
			for k, v in next, req.data do
				if k:match("^_sub_(.*)") then
					local t = data[k] or {}
					local loc = #t
					for i, vi in next, v do
						t[loc + i] = vi
					end
					data[k] = t
				else
					data[k] = v
				end
			end
			top = top[2]
		until
			not top
		this.data = data
		this.parent = nil
		return this
	end,
	derive = function(this)
		return this:child():collapse()
	end,

	getGameKey = function(this)
		return this.instance.gameKey
	end,
	getSecretKey = function(this)
		return this.instance.secretKey
	end,
	getUrl = function(this)
		if this.route == this.routes("events") then
			return this.instance.url.."/v2/"..this:getGameKey().."/events"
		elseif this.route == this.routes("init") then
			return this.instance.url.."/v2/"..this:getGameKey().."/init"
		end
	end,
	--[[getBucketId = function(this)
		-- This may be useful if ROBLOX ever allows access to player IPs
		-- With Player IPs, each IP should be a separate bucket so that requests can be sent
		--  as if from that IP in order to have proper geo data.
		-- The DefaultScheduler class will need to be modified to recognize these new IPs.
	end,  --]]
	getHasher = function(this)
		return this.instance.hasher
	end,
	getRequestTable = function(this)
		local data, revisit = {}, {}
		local top, req = {this}
		while top[1].parent do
			top = {top[1].parent, top}
		end
		repeat
			req = top[1]
			local n
			for k, v in next, req.data do
				n = k:match("^_sub_(.*)$")
				if n then
					revisit[n] = true
					local t = data[k] or {}
					local loc = #t
					for i, vi in next, v do
						t[loc + i] = vi
					end
					data[k] = t
				else
					data[k] = v
				end
			end
			top = top[2]
		until
			not top
		local i, n, val
		for k in next, revisit do
			n = "_sub_"..k
			data[k] = tconcat(data[n], ":")
			data[n] = nil
		end
		return data
	end,
	submit = function(this, now)
		-- ALSO EDIT submitterWait ABOVE
		if this.instance.hasInit == nil then
			if not now then
				coroutine.wrap(submitterWait)(this)
				return this
			else
				this.instance:waitForInit()
			end
		end
		if this.instance.sendEvents then
			this:set("client_ts", mfloor(GET_TIME() + this.instance.timestampOffset))
			return this, this.instance.scheduler:schedule(this, now)
		elseif now then
			return this
		else
			return this
		end
	end
})

GameAnalyticsInstance.class.GameAnalyticsRequest = GameAnalyticsRequest

return GameAnalyticsInstance
