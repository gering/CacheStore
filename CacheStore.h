//
//  CacheStore.h
//  ProviderCheck
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CacheStoreImageSupport.h"

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


@interface CacheStore : NSObject {  
@private
    NSCache *cache;
}

@property(nonatomic) CacheStoreCleanupStrategy cleanupStrategy;
@property(nonatomic) CacheStorePersistStrategy persistStrategy;
@property(nonatomic) CacheStoreSecondLevelTarget store;
@property(nonatomic) NSUInteger firstLevelLimit, secondLevelLimit;
@property(nonatomic) NSTimeInterval defaultTimeToLife;
@property(readonly, getter = isPersisting, nonatomic) BOOL persisting;
@property(readonly, nonatomic) NSUInteger firstLevelCount, secondLevelCount;

- (id)initWithFirstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl;

+ (CacheStore *)cacheStoreWithFirstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl;

// return the stored cached files from the second level cache
- (NSSet *)files;

- (id)objectForKey:(id)key;
- (void)removeObjectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
- (void)setObject:(id)object forKey:(id)key withTimeToLife:(NSTimeInterval)ttl;

@end
