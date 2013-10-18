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

static NSString *const kCacheFileSuffix = @"cacheobj";

static NSUInteger const kDefaultFirstLevelLimit = 100;                  // 100 entries
static NSUInteger const kDefaultSecondLevelLimit = 1000;                // 1000 entries
static NSUInteger const kDefaultTimeToLife = 24 * 60 * 60;              // 1 day ttl
static NSUInteger const kDefaultFistLevelEntrySizeLimit = 10 * 1024;    // 10 KB
static CacheStoreCleanupStrategy const kDefaultCleanupStrategy = CacheStoreCleanupStrategyLastAccessed;
static CacheStorePersistStrategy const kDefaultPersistStrategy = CacheStorePersistStrategyOnFirstLevelClean;
static CacheStoreSecondLevelTarget const kDefaultSecondLevelTarget = CacheStoreSecondLevelTargetCacheFolder;


@interface CacheStore() 

@property(nonatomic, strong) NSMutableDictionary *cache;

@end


@implementation CacheStore


#pragma mark - init

- (id)init {
    return [self initWithName:nil];
}

- (id)initWithName:(NSString *)name {
    return [self initWithName:name firstLevelLimit:kDefaultFirstLevelLimit secondLevelLimit:kDefaultSecondLevelLimit defaultTimeToLife:kDefaultTimeToLife];
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit firstLevelEntrySizeLimit:(NSUInteger)firstLevelEntrySizeLimit defaultTimeToLife:(NSTimeInterval)ttl {
    return [self initWithName:name firstLevelLimit:firstLevelLimit firstLevelEntrySizeLimit:firstLevelEntrySizeLimit secondLevelLimit:kDefaultSecondLevelLimit defaultTimeToLife:ttl cleanupStrategy:kDefaultCleanupStrategy persistStrategy:kDefaultPersistStrategy secondLevelTarget:kDefaultSecondLevelTarget];
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl {
    return [self initWithName:name firstLevelLimit:firstLevelLimit firstLevelEntrySizeLimit:kDefaultFistLevelEntrySizeLimit secondLevelLimit:secondLevelLimit defaultTimeToLife:ttl cleanupStrategy:kDefaultCleanupStrategy persistStrategy:kDefaultPersistStrategy secondLevelTarget:kDefaultSecondLevelTarget];
}

- (id)initWithName:(NSString *)name firstLevelLimit:(NSUInteger)firstLevelLimit firstLevelEntrySizeLimit:(NSUInteger)firstLevelEntrySizeLimit secondLevelLimit:(NSUInteger)secondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl cleanupStrategy:(CacheStoreCleanupStrategy)cleanupStrategy persistStrategy:(CacheStorePersistStrategy)persistStrategy secondLevelTarget:(CacheStoreSecondLevelTarget)secondLevelTarget {
    if ((self = [super init])) {
        _name = name;
        self.firstLevelLimit = firstLevelLimit;
        self.firstLevelEntrySizeLimit = firstLevelEntrySizeLimit;
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
        if ([entry valueConformsToNSCoding]) {
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
        } else {
            NSLog(@"CacheStore WARNING: %@ does not conform to NSCoding protocol and can't be stored into second level cache", [entry.value class]);
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

- (BOOL)isPersisting {
    return self.secondLevelLimit > 0;
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

        NSUInteger size = entry.valueSize;
        BOOL tooBig = size > self.firstLevelEntrySizeLimit;
        
        // first level
        if (!tooBig) {
            [self putEntryToFirstLevel:entry];
        } else {
            NSLog(@"CacheStore INFO: skipping first level, entry too big: %i bytes", size);
        }
        
        if (self.firstLevelCount > self.firstLevelLimit) {
            [self cleanupFirstLevel:self.firstLevelCount - self.firstLevelLimit];
        }
        
        // second level
        if (tooBig || self.persistStrategy == CacheStorePersistStrategyOnFirstLevelInsertAndClean) {
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
    NSUInteger count = self.firstLevelCount;
    [self persist];
    [self clearFistLevelCache];
    return count;
}

- (NSUInteger)cleanupFirstLevel:(NSUInteger)count {
    // cleanup all?
    if (count >= self.firstLevelCount)  {
        return [self cleanupFirstLevel];
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
