//
//  CacheStore.h
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, CacheStoreCleanupStrategy) {
    CacheStoreCleanupStrategyLastAccessed,
    CacheStoreCleanupStrategyLastAdded,
    CacheStoreCleanupStrategyRemainingTTL,
    CacheStoreCleanupStrategyAccessCount,
};

typedef NS_ENUM(NSUInteger, CacheStorePersistStrategy) {
    CacheStorePersistStrategyExplicit,
    CacheStorePersistStrategyOnFirstLevelInsert,
    CacheStorePersistStrategyOnFirstLevelClean,
    CacheStorePersistStrategyOnDealloc,
};

typedef NS_ENUM(NSUInteger, CacheStoreSecondLevelTarget) {
    CacheStoreSecondLevelTargetCacheFolder,
    CacheStoreSecondLevelTargetUserDefaults,
};


@interface CacheStore : NSObject

@property(nonatomic, copy) NSString *name;
@property(nonatomic) CacheStoreCleanupStrategy cleanupStrategy;
@property(nonatomic) CacheStorePersistStrategy persistStrategy;
@property(nonatomic) CacheStoreSecondLevelTarget secondLevelTarget;
@property(nonatomic) NSUInteger firstLevelLimit, secondLevelLimit;
@property(nonatomic) NSTimeInterval defaultTimeToLife;
@property(nonatomic, readonly, getter = isPersisting) BOOL persisting;
@property(nonatomic, readonly) NSUInteger firstLevelCount, secondLevelCount;

- (id)initWithName:(NSString *)name;

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl;

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl cleanupStrategy:(CacheStoreCleanupStrategy)cleanupStrategy persistStrategy:(CacheStorePersistStrategy)persistStrategy secondLevelTarget:(CacheStoreSecondLevelTarget)secondLevelTarget;


+ (NSString *)cacheDirectory;

- (void)clearCache;
- (void)clearFistLevelCache;
- (void)clearSecondLevelCache;

+ (void)clearAllCachedFiles;

/// @Description return the stored cached files from the second level cache
- (NSArray *)secondLevelFiles; 

- (id)objectForKey:(id)key;
- (void)removeObjectForKey:(id)key;
- (void)setObject:(id)object forKey:(id <NSCopying>)key;
- (void)setObject:(id)object forKey:(id <NSCopying>)key withTimeToLife:(NSTimeInterval)ttl;

@end
