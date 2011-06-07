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
    CacheStoreStrategyLastAccessed = 0,
    CacheStoreStrategyLastAdded,
    CacheStoreStrategyRemainingTTL,
    CacheStoreStrategyAccessCount,
} CacheStoreStrategy;

typedef enum {
    SecondLevelCacheStoreTempFolder = 0,
    SecondLevelCacheStoreUserDefaults,
} SecondLevelCacheStore;


@interface CacheStore : NSObject {  

@private
    NSMutableDictionary *cache;

}

@property(nonatomic) CacheStoreStrategy strategy;
@property(nonatomic) SecondLevelCacheStore store;
@property(nonatomic) NSUInteger firstLevelLimit, secondLevelLimit;
@property(nonatomic) NSTimeInterval defaultTimeToLife;
@property(readonly, getter = isPersisting, nonatomic) BOOL persisting;
@property(readonly, nonatomic) NSUInteger firstLevelCount, secondLevelCount;

- (id)initWithFirstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit;

+ (CacheStore *)cacheStoreWithFirstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit;

// return the stored cached files from the second level cache
- (NSSet *)files;

- (id)objectForKey:(id)key;
- (void)removeObjectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
- (void)setObject:(id)object forKey:(id)key withTimeToLife:(NSTimeInterval)ttl;

@end
