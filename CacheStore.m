//
//  CacheStore.m
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

// TODO: persist on dealloc if enabled
// TODO: respond and cleanup on limits


#import "CacheStore.h"
#import "CacheStoreEntry.h"

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static NSString * const kCacheFileSuffix = @"cacheobj";


@interface CacheStore() 

@property(nonatomic, strong) NSMutableDictionary *cache;

@end


@implementation CacheStore

@dynamic persisting;
@dynamic firstLevelCount, secondLevelCount;


#pragma mark - init

- (id)init {
    return [self initWithName:nil];
}

- (id)initWithName:(NSString *)name {
    return [self initWithName:name firstLevelLimit:1000 secondLevelLimit:0 defaultTimeToLife:3600];
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl {
    return [self initWithName:name firstLevelLimit:firstLevelLimit secondLevelLimit:secondLevelLimit defaultTimeToLife:ttl cleanupStrategy:CacheStoreCleanupStrategyLastAccessed persistStrategy:CacheStorePersistStrategyExplicit secondLevelTarget:CacheStoreSecondLevelTargetCacheFolder];
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl cleanupStrategy:(CacheStoreCleanupStrategy)cleanupStrategy persistStrategy:(CacheStorePersistStrategy)persistStrategy secondLevelTarget:(CacheStoreSecondLevelTarget)secondLevelTarget {
    if ((self = [super init])) {
        self.name = name;
        self.firstLevelLimit = firstLevelLimit;
        self.secondLevelLimit = secondLevelLimit;
        self.defaultTimeToLife = ttl;
        self.cleanupStrategy = cleanupStrategy;
        self.persistStrategy = persistStrategy;
        self.secondLevelTarget = secondLevelTarget;
        self.cache = [NSMutableDictionary new];
    }
    return self;
}

# pragma mark -

- (BOOL)isPersisting {
    return self.secondLevelLimit > 0;
}

- (NSUInteger)firstLevelCount {
    return self.cache.count;
}

- (NSUInteger)secondLevelCount {
    return self.secondLevelFiles.count;
}

# pragma mark -

+ (NSString *)cacheDirectory {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    return cacheDirectory;
}

- (NSString *)fileForKey:(id)key {
    return [NSString stringWithFormat:@"%@/%@_%02x.%@", [CacheStore cacheDirectory], [self name], [key hash], kCacheFileSuffix];
}

+ (NSArray *)allCachedFiles {
    NSError *error = nil;
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[CacheStore cacheDirectory] error:&error];
    
    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
        return nil;
    }
    
    NSMutableArray *cachedFiles = [NSMutableArray array];
    for (NSString *item in items) {
        if ([item hasSuffix:kCacheFileSuffix]) {
            [cachedFiles addObject:item];
        }
    }
    return cachedFiles;
}

- (NSArray *)secondLevelFiles {
    NSMutableArray *secondLevelFiles = [NSMutableArray array];
    NSString *searchString = [NSString stringWithFormat:@"/%@_", [self name]];
    for (NSString *item in [CacheStore allCachedFiles]) {
        if ([item hasSuffix:kCacheFileSuffix]) {
            if ([item rangeOfString:searchString].location != NSNotFound) {
                [secondLevelFiles addObject:item];
            }
        }
    }
    return secondLevelFiles;
}

+ (void)clearFiles:(NSArray *)files {
    NSLog(@"clearing %i files", files.count);
    for (NSString *item in files) {
        NSLog(@"deleting %@", item);
        NSError *error = nil;
        NSString *file = [NSString stringWithFormat:@"%@/%@", [CacheStore cacheDirectory], item];
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
        if (!success) {
            NSLog(@"Error: %@", [error localizedDescription]);
            return;
        }
    }    
}

- (void)clearCache {
    [self clearFistLevelCache];
    [self clearSecondLevelCache];
}

- (void)clearFistLevelCache {
    [self.cache removeAllObjects];
}

- (void)clearSecondLevelCache {
    [CacheStore clearFiles:[self secondLevelFiles]];
}

+ (void)clearAllCachedFiles {
    [CacheStore clearFiles:[CacheStore allCachedFiles]];
}

#pragma mark - level based cache access

- (void)removeFromFirstLevel:(id)key {
    if (key) {
        if (self.persistStrategy == CacheStorePersistStrategyOnFirstLevelClean) {
            [self putEntryToSecondLevel:[self.cache objectForKey:key]];
        }
        [self.cache removeObjectForKey:key];
    }
}

- (void)removeFromSecondLevel:(id)key {
    if (key) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = [self fileForKey:key];
        NSError *error;
        BOOL fileExists = [fileManager fileExistsAtPath:path];
        if (fileExists) {
            BOOL success = [fileManager removeItemAtPath:path error:&error];
            if (!success) NSLog(@"Error: %@", [error localizedDescription]);
        }
    }
}

- (CacheStoreEntry *)entryFromFirstLevel:(id)key {
    CacheStoreEntry *entry = [self.cache objectForKey:key];
    return entry;
}

- (CacheStoreEntry *)entryFromSecondLevel:(id)key {
    CacheStoreEntry *entry = [NSKeyedUnarchiver unarchiveObjectWithFile:[self fileForKey:key]];
    if (entry && ![entry.key isEqual:key]) {
        entry = nil;
        NSLog(@"WARNING: key '%@' collision in second level cache", key);
    }
    return entry;
}

- (void)putEntryToFirstLevel:(CacheStoreEntry *)entry {
    if (entry) {
        if ([entry isValid] && self.firstLevelLimit > 0) {
            [self.cache setObject:entry forKey:entry.key];
        }
    } else {
        NSLog(@"WARNING: not adding null entry to cache");
    }
}

- (void)putEntryToSecondLevel:(CacheStoreEntry *)entry {
    if ([self isPersisting] && [entry isValid]) {
        switch (self.secondLevelTarget) {
            case CacheStoreSecondLevelTargetCacheFolder:
            {
                NSString *file = [self fileForKey:entry.key];
                NSLog(@"persisting cache entry %@", file);
                [NSKeyedArchiver archiveRootObject:entry toFile:file];
                break;
            }
            case CacheStoreSecondLevelTargetUserDefaults:
            {
                NSLog(@"CacheStoreSecondLevelTargetUserDefaults not supported yet");
                break;
            }
            default:
                NSLog(@"unsupported second level target");
        }
    }
}

#pragma mark - using the cache

- (id)objectForKey:(id)key {
    if (!key) return nil;
    
    CacheStoreEntry *entry = [self entryFromFirstLevel:key];    // try first level
    if (!entry) {   // try second level?
        entry = [self entryFromSecondLevel:key];
        if (entry && [entry isValid]) {
            [self putEntryToFirstLevel:entry];
        }
    }
    if (entry && ![entry isValid]) {
        [self removeObjectForKey:key];
        entry = nil;
    }
    return entry.value;
}

- (void)removeObjectForKey:(id)key {
    [self removeFromFirstLevel:key];
    [self removeFromSecondLevel:key];
}

- (void)setObject:(id)object forKey:(id <NSCopying>)key {
    [self setObject:object forKey:key withTimeToLife:self.defaultTimeToLife];
}

- (void)setObject:(id)object forKey:(id <NSCopying>)key withTimeToLife:(NSTimeInterval)ttl {
    CacheStoreEntry *entry = [[CacheStoreEntry alloc] initWithKey:key value:object timeToLife:ttl];

    // first level
    [self putEntryToFirstLevel:entry];
    
    if (self.firstLevelCount > self.firstLevelLimit) {
        [self cleanupFistLevel:self.firstLevelCount - self.firstLevelLimit];
    }
    
    // second level
    if (self.persistStrategy == CacheStorePersistStrategyOnFirstLevelInsert) {
        [self putEntryToSecondLevel:entry];
    }
}


#pragma mark - cleanup


- (NSUInteger)cleanupFistLevel:(NSUInteger)count {
    if (count > self.firstLevelCount) count = self.firstLevelCount;

    NSArray *keys = self.cache.allKeys;

    int removedCount = 0;
    for (id key in keys) {
        CacheStoreEntry *entry = [self entryFromFirstLevel:key];
        if (!entry.isValid) {
            [self removeFromFirstLevel:key];
            removedCount++;
        }
    }
    
    keys = self.cache.allKeys;
    
    if (removedCount < count) {
        switch (self.cleanupStrategy) {
            case CacheStoreCleanupStrategyAccessCount:
            {
                NSLog(@"cleanup strategy CacheStoreCleanupStrategyAccessCount not implemented");
                break;
            }
            case CacheStoreCleanupStrategyLastAdded:
            {
                NSLog(@"cleanup strategy CacheStoreCleanupStrategyLastAdded not implemented");
                break;
            }
            case CacheStoreCleanupStrategyRemainingTTL:
            {
                NSLog(@"cleanup strategy CacheStoreCleanupStrategyRemainingTTL not implemented");
                break;
            }
            default:
                NSLog(@"unsupported cleanup strategy %i", self.cleanupStrategy);
                break;
        }
    }
    return removedCount;
}


#pragma mark -

- (void)dealloc {
    // TODO: persist?
}

@end
