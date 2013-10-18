//
//  CacheStore.h
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CacheStoreCleanupStrategy) {
    CacheStoreCleanupStrategyLastAccessed,  // clean least accessed entries
    CacheStoreCleanupStrategyLastAdded,     // clean oldest entries
    CacheStoreCleanupStrategyRemainingTTL,  // clean entries with short ttl
    CacheStoreCleanupStrategyAccessCount,   // clean entries with smallest access count
};

typedef NS_ENUM(NSUInteger, CacheStorePersistStrategy) {
    CacheStorePersistStrategyOnFirstLevelInsertAndClean,
    CacheStorePersistStrategyOnFirstLevelClean,
};

typedef NS_ENUM(NSUInteger, CacheStoreSecondLevelTarget) {
    CacheStoreSecondLevelTargetCacheFolder,
    CacheStoreSecondLevelTargetUserDefaults,
};

/** The CacheStore is a cache implementation
 that allows you to store object in a cache similar you use an NSMutableDictionary.
 Different from NSCache where the cached objects are stored in memory and are not
 persisted on disk, this implementation has a fist level (im memory) cache and also
 a second level (on disk) cache.
 You can configure this cache store to use your desired cleanup strategy if memory runs
 low or limits are reached.
 Each object in the CacheStore gets an time to life (ttl) assigned, that will invalidate
 cached entries after the ttl has passed. You can define a default ttl.
 Big objects can be put into second level cache automatically.
 */
@interface CacheStore : NSObject

/// the name of the cache, it is used to store the entry files in the cache directory
@property(nonatomic, strong, readonly) NSString *name;
/// the choosen cleanup strategy for the first level cache cleanup
@property(nonatomic) CacheStoreCleanupStrategy cleanupStrategy;
/// the choosen persist strategy, defines when entries are stored in second level cache
@property(nonatomic) CacheStorePersistStrategy persistStrategy;
@property(nonatomic) CacheStoreSecondLevelTarget secondLevelTarget;
/// limits the number of entries that are allowed to be stored in first level cache. An automatic cleanup is performed if the number of entries is exceeded
@property(nonatomic) NSUInteger firstLevelLimit;
/// if this value is set to zero, the second level cachs is disabled
@property(nonatomic) NSUInteger secondLevelLimit;
/// all entries bigger in file size than this value will move directly to second level cache
@property(nonatomic) NSUInteger firstLevelEntrySizeLimit;
@property(nonatomic) NSTimeInterval defaultTimeToLife;


- (id)initWithName:(NSString *)name;
- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl;
- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit firstLevelEntrySizeLimit:(NSUInteger)firstLevelEntrySizeLimit defaultTimeToLife:(NSTimeInterval)ttl ;
- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit firstLevelEntrySizeLimit:(NSUInteger)firstLevelEntrySizeLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl cleanupStrategy:(CacheStoreCleanupStrategy)cleanupStrategy persistStrategy:(CacheStorePersistStrategy)persistStrategy secondLevelTarget:(CacheStoreSecondLevelTarget)secondLevelTarget;

/// returns the folder where all cached entries from second level cache are stored
+ (NSString *)cacheDirectory;

/// returns the number of first level entries
- (NSUInteger)firstLevelCount;

/// returns the number of second level entries
- (NSUInteger)secondLevelCount;

/// clears first and second level cache
- (void)clearCache;

/// clears first level cache, but does not move entries to second level cache
- (void)clearFistLevelCache;

/// clears all cached entry files from this cache
- (void)clearSecondLevelCache;

/// clears all cached entry files in the cache folder
+ (void)clearAllCachedFiles;

/** cleans all first level entries and moves them to second level
 \return number of cleaned entries
 */
- (NSUInteger)cleanupFirstLevel;

/** cleans first level entries and moves them to second level
 \param count this is the number of entries you whish to remove from first level cache
 \return number of cleaned entries
 */
- (NSUInteger)cleanupFirstLevel:(NSUInteger)count;

/// return the stored cached files from the second level cache
- (NSArray *)secondLevelFiles; 

/** retrives an object from the cache 
 \param key the key for the cached object
 \return the cached object if still in cache or nil if the object couldn't be found
 */
- (id)objectForKey:(id)key;

/** removes a object from the cache
 \param key the key for the cached object
 */
- (void)removeObjectForKey:(id)key;

/** adds an object to the cache, the object gets the default time to life
 \param object the object which should be cached
 \param key the key for the cached object
 */
- (void)setObject:(id)object forKey:(id <NSCopying>)key;

/** adds an object to the cache
 \param object the object which should be cached
 \param key the key for the cached object
 \param ttl the time to life in seconds, after the time has passed the object gets invalid and removed from the cache
 */
- (void)setObject:(id)object forKey:(id <NSCopying>)key withTimeToLife:(NSTimeInterval)ttl;

/// returns YES if second level cache is used
- (BOOL)isPersisting;

/// stores all first level entries to second level
- (void)persist;

@end
