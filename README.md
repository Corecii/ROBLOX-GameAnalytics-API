# ROBLOX-GameAnalytics-API
A basic API to use GameAnalytics in ROBLOX.

This provides a simple interface to initialize a GameAnalytics instance, build
requests, and schedule them to be submitted to the GameAnalytics servers.

The easiest way to use this is to grab the .rbxm file which contains the
GameAnalytics API and everything it requires. In the case that you only wanted to
look at the source and not actually use the API, I have provided it for convenience.

This API does *not* automatically handle player leaving/joining, saving of data
or analytics-specific ids. It only provides a simple system to build and submit
requests with any desired properties.

A list of the 'properties' that can be submitted, and how they should be submitted,
is available at the [GameAnalytics REST API](http://restapidocs.gameanalytics.com/#event-types).
