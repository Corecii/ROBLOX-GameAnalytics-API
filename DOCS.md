# ROBLOX GameAnalytics API Documentation

The API is split into three parts:
* The `DefaultScheduler` (`Scheduler`)
* The `GameAnalyticsInstance` (`Instance`)
* The `GameAnalyticsRequest` (`Request`)

The `Scheduler` takes in `Request`s and handles submitting them (HTTP POST)

The `Instance` stores information essential to that specific instance of GameAnalytics: The game key, the secret key, the url to post to, and the authentication hasher.

The `Request` represents a request to the GameAnalytics REST API. It stores options, can be cloned, can have children, can collapse all ancestors down into one request, and can be submitted.

---

# The `GameAnalyticsInstance` API

Class `GameAnalyticsInstance`
* Properties
  * `DefaultScheduler DefaultScheduler`  
A reference to the default scheduler. The `GameAnalyticsInstance` class does not use this, it is provided for convenience
  * `GameAnalyticsRequest GameAnalyticsRequest`  
A reference to the GameAnalyticsRequest class. This is used when the instance creates requests.
  * `Scheduler scheduler`  
The scheduler that is this instance will use to schedule its requests.
  * `string url`  
The URL that this instance will use when submitting requests. Defaults to `http://api.gameanalytics.com`
  * `string sandboxUrl`
The URL of the GameAnalytics sandbox. The `GameAnalyticsInstance` class does not use this, it is provided for convenience
  * `boolean hasInit`
Signifies if this instance has been initialized. If `nil`, `:init` has not been called. If `false`, `:init` is sending the init request. If `true`, the init request is complete.
  * `boolean sendEvents`
This is set after `:init`. Whether or not this instance is supposed to be sending events to the GameAnalytics servers. See the [GameAnalytics REST API documentation](http://restapidocs.gameanalytics.com/#init) (specifically the `enabled` result of init) for more info.
  * `number timestampOffset`
This is set after `:init`. This is `server_ts - myTS`, and is used to send the proper times to the GameAnalytics servers when requests are submitted.
  * `function hasher`
This is a hashing function that, given the body of a request as its first and only parameter, will return the authorization hash associated with this instance. It is called, by the `Scheduler`, `hasher(string requestBody, dictionary<string, Variant> bucket)`. This should be callable like a function. In my implementation it is a table with a `__call` metamethod.
* Methods
  * `:new(dictionary<string, Variant>)
Create a new GameAnalyticsInstance. The keys and values to the dictionary are:
    * `gameKey = string`
    * `secretKey = string`
    * `[scheduler = Scheduler]`
    * `[url = string]`

  * `:init()`  
Initialize this instance, sending the init request when called (it sends the request without scheduling).
  * `:request(dictionary<string, Variant> data)`  
Returns a `GameAnalyticsRequest` associated with this instance. `data` is passed into the requests `:setTable` method, and the ability to provide it here is for convenience.

---

# The `GameAnalyticsRequest` API

Class `GameAnalyticsRequest`
* Properties
  * `enum routes`
    * `events`
    * `init`
  * `table Nil`  
Used internally to represent to-be blank spaces within the inheritance and push/pop system.
  * `GameAnalyticsInstance instance`  
The instance this request belongs to.
  * `GameAnalyticsRequest parent`  
The parent to this request. This request inherits all of its data.
  * `routes/integer route`
The route this request will take.
  * `dictionary<string, Variant>` data
The data to be sent in this request.
* Methods
  * `:new(GameAnalyticsInstance instance, GameAnalyticsRequest parent)`  
Creates a new request with `instance` as its instance and `paren` as its parent.
  * `:setRoute(routes/integer route)`  
Sets which route this request will take.  
Returns self.
  * `:setInit(dictionary<string, Variant> initData)`  
Sets the `route` to `init` and sets `data` to `initData`.  
Returns self.
  * `:set(string key1, Variant value1, string key2, Variant value2, ...)`  
Allows for setting one or many values are once in an easy-to-read manner.  
Returns self.
  * `:get(string key1, string key2, ...)`  
Returns the values for all the provided keys.
  * `:setTable(dictionary<string, Variant> dataTable)`  
Takes all the key-value pairs from `dataTable` and puts them in `data`.
  * `:push(string key, string value1, string value2, ...)`  
Push `value1` and onward into `key`, such that they will be `value1:value2:...` when POSTed. This works with inheritance.  
Returns self.
  * `:pop(string key, integer amt)`  
Pop `amt` values from `key` and return them.  
If this request does have values to pop then it will return them.  
If this request does not have values to pop then it will mark those slots as `Nil`, and remove them when it gets converted into JSON. It does not return values 'popped' from the parent, even though they were marked as `Nil`.  
  * `:clone()`  
Create and return a clone of this object. The clone will have individual, cloned `data` from self. The clone will not collapse/clone parent `data`, but instead set the clones `parent` property to the same as self.
  * `:child()`  
Create and return a child object. Child objects will inherit all properties, including new/changed ones, of their parent when submitted. Child objects do not modify their parent object and can be collapsed into a single object with its own unique `data` without inheritance using `:collapse`.
  * `:collapse()`  
Inherits all its ancestor's `data` and sets its parent to nil.  
Returns self.
  * `:derive()`  
Returns a new object with all `data` `:collapse`'d.
  * `:submit(boolean now)`  
Submits the request to the `scheduler` in this request's `instance`. If `now` evaluates to true then the request will submit now and return the result. See `Scheduler:schedule` for more details. If `sendEvents` in `instance` evaluates to false then the event is not submitted and onle `self` is returned.  
This returns `self, results` where `results` are the results of `:schedule`.
  * `:getGameKey()`  
Returns the game key associeted with this request. This is used by the `Scheduler` and uses the request's `instance` property to get the key.
  * `:getSecretKey()`  
Returns the secret key associeted with this request. This is used by the `Scheduler` and uses the request's `instance` property to get the key.
  * `:getUrl()`  
Returns the url associeted with this request. This is used by the `Scheduler` and uses the request's `instance` property to get the url.
  * `:getHasher()`  
Returns the hasher associeted with this request. This is used by the `Scheduler` and uses the request's `instance` property to get the hasher.
  * `:getRequestTable()`  
Returns a JSONable request table. This method collapses all ancestor `data` down into a table which it returns.


---


# The `DefaultScheduler` API

Class `DefaultScheduler`
* Properties
  * `integer submitTime`  
The maximum amount of time that a request will wait before being submitted. Any requests made between the first within this time to the end of this time will be submitted with it.
  * `integer maxSizeChars`  
The maximum number of characters in a HTTP POST's data. If a single POST has more than this many characters then it will be split in too. Half of the `GameAnalyticsRequest`s will go in one POST, half in the another.
  * `array scheduledRequests`  
This is only present if `:schedule` has been called and a 'timer' has been started ready to submit everything in `scheduledRequests`.
* Methods
  * `:new()`  
Creates and returns a new `DefaultScheduler`.
  * `:schedule(GameAnalyticsRequest request, [boolean now])`  

    If `now` is unset, `nil`, or `false`:  
    Schedules the given `GameAnalyticsRequest` to be submitted at a maximum of `submitTime` seconds from now.

    If `now` is `true`:  
    Submits the given `GameAnalyticsRequest` to be submitted at the current time. It will return an array (table) containing 1 element: an array (table) with the results of the submit. See `:submitRequests` for details.

  * `:submitRequests(array<GameAnalyticsRequest>)`  
Returns  
    ```
    array<
    	array<Variant>
            boolean succeeded,
            string responseOrError,
            dictionary<string, Variant> bucket
                gameKey = string,
                secretKey = string,
                hasher = function,
                url = string,
                bucketId = string,
                requests = array<table requestTable>
            array<Variant> postDataInfo
                string JSONEncodedRequests,
                integer startIndexInRequests,
                integer stopIndexInRequests
    >
    ```  
	This method is used internally to submit requests. It takes an array (table) of `GameAnalyticsRequest`s, splits them into sections according to what game they belong to, what url they are being sent to, and their self-determined `bucketId`.

    If you are using this yourself or writing/extending your own `Scheduler` then you can use the returns here to check for errors and resubmit requests if needed. At the time of writing this documentation it is not possible to see the responses included with HTTP 400 BAD REQUEST errors. See [this](http://devforum.roblox.com/t/http-get-postasync-reading-returned-content-even-with-an-error/27003) devforum post for a suggestion to change this behavior.

    The only section of the returned content that needs explanation is the last array:  
    `JSONEncodedRequests` are the JSON encoded requests from the `requests` key from `startIndexInRequests` to `stopIndexInRequests` inclusive.

    Note that the 'names' included under `array` types are just descriptions, not keys. For example, `succeeded` is at `[1]`, `responseOrError` is at `[2]`, etc.  

  * `:internalSubmitRequest(dictionary<string, Variant> bucket, string requestJSON)`
Runs a protected call on PostAsync in order to capture either the response data or the error. `bucket` is the same structure as `bucket` in `:submitRequests` return.
