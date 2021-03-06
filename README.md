CacheStore
----

The CacheStore is a cache implementation
that allows you to store object in a cache similar you use an NSMutableDictionary.
Different from NSCache, where the cached objects are stored in memory and are not
persisted on disk, this implementation has a fist level (im memory) cache and also
a second level (on disk) cache.
You can configure this cache store to use your desired cleanup strategy if memory runs
low or limits are reached.
Each object in the CacheStore gets a time to life (ttl) assigned, that will invalidate
cached entries after the ttl has passed. You can define a default ttl.
Big objects can be put into second level cache automatically.


Code Examples
----

initialize cache:
```Objective-C
    CacheStore *cache = [[CacheStore alloc] initWithName:@"MyCache" firstLevelLimit:100 secondLevelLimit:1000 defaultTimeToLife:3600];
    cache.persistStrategy = CacheStorePersistStrategyOnFirstLevelInsertAndClean;
```
