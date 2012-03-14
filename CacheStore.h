//
//  CacheStore.h
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    CacheStoreCleanupStrategyLastAccessed = 0,
    CacheStoreCleanupStrategyLastAdded,
    CacheStoreCleanupStrategyRemainingTTL,
    CacheStoreCleanupStrategyAccessCount,
} CacheStoreCleanupStrategy;

typedef enum {
    CacheStorePersistStrategyExplicit = 0,
    CacheStorePersistStrategyOnFirstLevelInsert,
    CacheStorePersistStrategyOnFirstLevelClean,
    CacheStorePersistStrategyOnDealloc,
} CacheStorePersistStrategy;

typedef enum {
    CacheStoreSecondLevelTargetCacheFolder = 0,
    CacheStoreSecondLevelTargetUserDefaults,
}  CacheStoreSecondLevelTarget;


@interface CacheStore : NSObject

@property(nonatomic, retain) NSString *name;
@property(nonatomic) CacheStoreCleanupStrategy cleanupStrategy;
@property(nonatomic) CacheStorePersistStrategy persistStrategy;
@property(nonatomic) CacheStoreSecondLevelTarget store;
@property(nonatomic) NSUInteger firstLevelLimit, secondLevelLimit;
@property(nonatomic) NSTimeInterval defaultTimeToLife;
@property(nonatomic, readonly, getter = isPersisting) BOOL persisting;
@property(nonatomic, readonly) NSUInteger firstLevelCount, secondLevelCount;

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl;

- (void)clearSecondLevelCache;
+ (void)clearAllCachedFiles;

// return the stored cached files from the second level cache
- (NSArray *)secondLevelFiles; 

- (id)objectForKey:(id)key;
- (void)removeObjectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
- (void)setObject:(id)object forKey:(id)key withTimeToLife:(NSTimeInterval)ttl;

@end
