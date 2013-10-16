//
//  CacheStore.m
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

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
    return [self initWithName:name firstLevelLimit:100 secondLevelLimit:1000 defaultTimeToLife:24 * 60 * 60];   // 1 day ttl
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl {
    return [self initWithName:name firstLevelLimit:firstLevelLimit secondLevelLimit:secondLevelLimit defaultTimeToLife:ttl cleanupStrategy:CacheStoreCleanupStrategyLastAccessed persistStrategy:CacheStorePersistStrategyOnFirstLevelClean secondLevelTarget:CacheStoreSecondLevelTargetCacheFolder];
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl cleanupStrategy:(CacheStoreCleanupStrategy)cleanupStrategy persistStrategy:(CacheStorePersistStrategy)persistStrategy secondLevelTarget:(CacheStoreSecondLevelTarget)secondLevelTarget {
    if ((self = [super init])) {
        _name = name;
        self.firstLevelLimit = firstLevelLimit;
        self.secondLevelLimit = secondLevelLimit;
        self.defaultTimeToLife = ttl;
        self.cleanupStrategy = cleanupStrategy;
        self.persistStrategy = persistStrategy;
        self.secondLevelTarget = secondLevelTarget;
        self.cache = [NSMutableDictionary new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cleanupFirstLevel) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

# pragma mark -

+ (NSString *)cacheDirectory {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    return cacheDirectory;
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

- (NSString *)fileForKey:(id)key {
    return [NSString stringWithFormat:@"%@/%@_%02x.%@", [CacheStore cacheDirectory], [self name], [key hash], kCacheFileSuffix];
}

+ (NSArray *)allCachedFiles {
    NSError *error = nil;
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[CacheStore cacheDirectory] error:&error];
    
    if (error) {
        NSLog(@"CacheStore ERROR: %@", [error localizedDescription]);
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
    NSString *searchString = [NSString stringWithFormat:@"%@_", [self name]];
    for (NSString *item in [CacheStore allCachedFiles]) {
        if ([item rangeOfString:searchString].location != NSNotFound) {
            [secondLevelFiles addObject:item];
        }
    }
    return secondLevelFiles;
}

+ (void)clearFiles:(NSArray *)files {
    NSLog(@"CacheStore INFO: clearing %i second level files", files.count);
    for (NSString *item in files) {
        //NSLog(@"CacheStore INFO: deleting %@", item);
        NSError *error = nil;
        NSString *file = [NSString stringWithFormat:@"%@/%@", [CacheStore cacheDirectory], item];
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
        if (!success || error) {
            NSLog(@"CacheStore ERROR: %@", [error localizedDescription]);
            return;
        }
    }    
}

#pragma mark - clear cache

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

// low level access to cache dict
- (void)removeEntryFromFirstLevelWithKey:(id)key {
    if (key) {
        [self.cache removeObjectForKey:key];
    }
}

- (void)removeEntriesFromFirstLevel:(NSArray *)entries {
    for (CacheStoreEntry *entry in entries) {
        [self removeEntryFromFirstLevelWithKey:entry.key];
    }
}

- (void)removeEntryFromSecondLevelWithKey:(id)key {
    if (key) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = [self fileForKey:key];
        NSError *error;
        BOOL fileExists = [fileManager fileExistsAtPath:path];
        if (fileExists) {
            BOOL success = [fileManager removeItemAtPath:path error:&error];
            if (!success) NSLog(@"CacheStore ERROR: %@", [error localizedDescription]);
        }
    }
}

// low level access to cache dict
- (CacheStoreEntry *)entryFromFirstLevelWithKey:(id)key {
    CacheStoreEntry *entry = [self.cache objectForKey:key];
    if (entry && !entry.isValid) {
        [self removeEntryFromFirstLevelWithKey:key];
        entry = nil;
    }
    return entry;
}

- (CacheStoreEntry *)entryFromSecondLevelWithKey:(id)key {
    CacheStoreEntry *entry = [NSKeyedUnarchiver unarchiveObjectWithFile:[self fileForKey:key]];
    if (entry && ![entry.key isEqual:key]) {
        entry = nil;
        NSLog(@"CacheStore WARNING: key '%@' collision in second level cache", key);
    }
    if (entry && !entry.isValid) {
        [self removeEntryFromSecondLevelWithKey:key];
        entry = nil;
    }
    return entry;
}

// low level access to cache dict
- (void)putEntryToFirstLevel:(CacheStoreEntry *)entry {
    if (entry) {
        if (entry.isValid && self.firstLevelLimit > 0) {
            [self.cache setObject:entry forKey:entry.key];
        }
    } else {
        NSLog(@"CacheStore WARNING: not adding null entry to cache");
    }
}

- (void)putEntryToSecondLevel:(CacheStoreEntry *)entry {
    if (self.isPersisting && entry.isValid) {
        switch (self.secondLevelTarget) {
            case CacheStoreSecondLevelTargetCacheFolder:
            {
                NSString *file = [self fileForKey:entry.key];
                //NSLog(@"CacheStore INFO: persisting cache entry to file %@", file);
                [NSKeyedArchiver archiveRootObject:entry toFile:file];
                break;
            }
            case CacheStoreSecondLevelTargetUserDefaults:
                NSLog(@"CacheStore WARNING: CacheStoreSecondLevelTargetUserDefaults not supported yet");
                break;
            default:
                NSLog(@"CacheStore WARNING: unsupported second level target");
                break;
        }
    }
}

- (void)putEntriesToSecondLevel:(NSArray *)entries {
    if (self.isPersisting) {
        for (CacheStoreEntry *entry in entries) {
            [self putEntryToSecondLevel:entry];
        }
    }
}

- (void)persist {
    [self putEntriesToSecondLevel:self.cache.allValues];
}


#pragma mark - using the cache

- (id)objectForKey:(id)key {
    if (!key) return nil;
    
    CacheStoreEntry *entry = [self entryFromFirstLevelWithKey:key];    // try first level
    if (!entry) {   // try second level?
        entry = [self entryFromSecondLevelWithKey:key];
        if (entry && entry.isValid) {
            [self putEntryToFirstLevel:entry];
        }
    }
    if (entry && !entry.isValid) {
        [self removeObjectForKey:key];
        entry = nil;
    }
    return entry.value;
}

- (void)removeObjectForKey:(id)key {
    [self removeEntryFromFirstLevelWithKey:key];
    [self removeEntryFromSecondLevelWithKey:key];
}

- (void)setObject:(id)object forKey:(id <NSCopying>)key {
    [self setObject:object forKey:key withTimeToLife:self.defaultTimeToLife];
}

- (void)setObject:(id)object forKey:(id <NSCopying>)key withTimeToLife:(NSTimeInterval)ttl {
    if (object && key) {
        CacheStoreEntry *entry = [[CacheStoreEntry alloc] initWithKey:key value:object timeToLife:ttl];
        
        // first level
        [self putEntryToFirstLevel:entry];
        
        if (self.firstLevelCount > self.firstLevelLimit) {
            [self cleanupFirstLevel:self.firstLevelCount - self.firstLevelLimit];
        }
        
        // second level
        if (self.persistStrategy == CacheStorePersistStrategyOnFirstLevelInsertAndClean) {
            [self putEntryToSecondLevel:entry];
        }
    }
}


#pragma mark - cleanup

// choose sort descriptor based on strategy, descriptor sorts entries that can be removed to front
- (NSSortDescriptor *)sortDescriptorForCleanupStrategy:(CacheStoreCleanupStrategy)strategy {
    switch (strategy) {
        case CacheStoreCleanupStrategyAccessCount:
            return [[NSSortDescriptor alloc] initWithKey:NSStringFromSelector(@selector(accessCount)) ascending:YES];
        case CacheStoreCleanupStrategyLastAccessed:
            return [[NSSortDescriptor alloc] initWithKey:NSStringFromSelector(@selector(timeSinceLastAccess)) ascending:NO];
        case CacheStoreCleanupStrategyRemainingTTL:
            return [[NSSortDescriptor alloc] initWithKey:NSStringFromSelector(@selector(remainingTimeToLife)) ascending:YES];
        case CacheStoreCleanupStrategyLastAdded:
            return [[NSSortDescriptor alloc] initWithKey:NSStringFromSelector(@selector(timeSinceAdded)) ascending:NO];
        default:
            NSLog(@"CacheStore WARNING: unsupported cleanup strategy %i", self.cleanupStrategy);
            return nil;
    }
}

- (NSUInteger)cleanupFirstLevel {
    return [self cleanupFirstLevel:self.firstLevelLimit];
}

- (NSUInteger)cleanupFirstLevel:(NSUInteger)count {
    if (count > self.firstLevelCount) count = self.firstLevelCount;

    // cleanup all?
    if (count == self.firstLevelCount) {
        [self persist];
        [self clearFistLevelCache];
        return count;
    }
    
    NSArray *keys = self.cache.allKeys;

    int removedCount = 0;
    for (id key in keys) {
        CacheStoreEntry *entry = [self entryFromFirstLevelWithKey:key];
        if (!entry.isValid) {
            [self removeEntryFromFirstLevelWithKey:key];
            removedCount++;
        }
    }
    
    keys = self.cache.allKeys;

    int remaining = count - removedCount;
    if (remaining > 0) {
        NSSortDescriptor *sortDescriptor = [self sortDescriptorForCleanupStrategy:self.cleanupStrategy];
        NSArray *sorted = [self.cache.allValues sortedArrayUsingDescriptors:@[sortDescriptor]];
        NSArray *waste = [sorted subarrayWithRange:NSMakeRange(0, remaining)];
        
        // save to second level
        [self putEntriesToSecondLevel:waste];
        
        // remove waste
        [self removeEntryFromFirstLevelWithKey:waste];
        removedCount += waste.count;
    }
    
    NSLog(@"CacheStore INFO: cleaned %i frist level entries", removedCount);
    return removedCount;
}

#pragma mark -

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self persist];
}

@end
