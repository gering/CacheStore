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
#import "CacheableUIImage.h"


@interface CacheStore() 

@property(nonatomic, retain) NSCache *cache;

@end

@implementation CacheStore

@synthesize cache;
@synthesize name;
@synthesize cleanupStrategy, persistStrategy;
@synthesize store;
@synthesize firstLevelLimit, secondLevelLimit;
@synthesize defaultTimeToLife;
@dynamic persisting;
@dynamic firstLevelCount, secondLevelCount;

#pragma mark - init

- (id)init {
    if ((self = [super init])) {
        self.firstLevelLimit = 1000;
        self.secondLevelLimit = 0;
        self.defaultTimeToLife = 3600;    // one hour
        self.cache = [[[NSCache alloc] init] autorelease];
    }
    return self;
}

- (id)initWithName:(NSString *)aName firstLevelLimit:(NSUInteger)aFirstLevelLimit secondLevelLimit:(NSUInteger)aSecondLevelLimit defaultTimeToLife:(NSTimeInterval)ttl {
    if ((self = [self init])) {
        self.firstLevelLimit = aFirstLevelLimit;
        self.secondLevelLimit = aSecondLevelLimit;
        self.defaultTimeToLife = ttl;
        self.name = aName;
    }
    return self;
}

# pragma mark -

- (BOOL)isPersisting {
    return secondLevelLimit > 0;
}

- (NSUInteger)firstLevelCount {
    return cache.countLimit;
}

- (NSUInteger)secondLevelCount {
    return [self secondLevelFiles].count;
}

# pragma mark -

+ (NSString *)cacheDirectory {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    return cacheDirectory;
}

- (NSString *)fileForKey:(id)key {
    return [NSString stringWithFormat:@"%@/%@_%i.cache", [CacheStore cacheDirectory], [self name], [key hash]];
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
        if ([item hasSuffix:@".cache"]) {
            [cachedFiles addObject:item];
        }
    }
    return cachedFiles;
}

- (NSArray *)secondLevelFiles {
    NSMutableArray *secondLevelFiles = [NSMutableArray array];
    NSString *searchString = [NSString stringWithFormat:@"/%@_", [self name]];
    for (NSString *item in [CacheStore allCachedFiles]) {
        if ([item rangeOfString:searchString].location != NSNotFound) {
            [secondLevelFiles addObject:item];
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

- (void)clearSecondLevelCache {
    [CacheStore clearFiles:[self secondLevelFiles]];
}

+ (void)clearAllCachedFiles {
    [CacheStore clearFiles:[CacheStore allCachedFiles]];
}

#pragma mark - level based cache access

- (void)removeFromFirstLevel:(id)key {
    [cache removeObjectForKey:key];
}

- (void)removeFromSecondLevel:(id)key {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self fileForKey:key];
    NSError *error;
    BOOL fileExists = [fileManager fileExistsAtPath:path];
    if (fileExists) {
        BOOL success = [fileManager removeItemAtPath:path error:&error];
        if (!success) NSLog(@"Error: %@", [error localizedDescription]);
    }
}

- (CacheStoreEntry *)entryFromFirstLevel:(id)key {
    CacheStoreEntry *entry = [cache objectForKey:key];
    return entry;
}

- (CacheStoreEntry *)entryFromSecondLevel:(id)key {
    CacheStoreEntry *entry = [NSKeyedUnarchiver unarchiveObjectWithFile:[self fileForKey:key]];
    if (entry && ![entry.key isEqual:key]) {
        entry = nil;
        NSLog(@"WARNING: key '%@' mismatch in second level cache", key);
    }
    return entry;
}

- (void)putEntryToFirstLevel:(CacheStoreEntry *)entry {
    if (entry) {
        if ([entry isValid] && firstLevelLimit > 0) {
            [cache setObject:entry forKey:entry.key]; 
        }
    } else {
        NSLog(@"WARNING: not adding null entry to cache");
    }
}

- (void)putEntryToSecondLevel:(CacheStoreEntry *)entry {
    switch (store) {
        case CacheStoreSecondLevelTargetCacheFolder: 
        {
            NSString *file = [self fileForKey:entry.key];
            [NSKeyedArchiver archiveRootObject:entry toFile:file];
            break;
        }
        case CacheStoreSecondLevelTargetUserDefaults: 
        {
            NSLog(@"CacheStoreSecondLevelTargetUserDefaults not supported yet");
            break;
        }
        default:
            NSLog(@"unsupported store");
    }
}

#pragma mark - using the cache

- (id)objectForKey:(id)key {
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

- (void)setObject:(id)object forKey:(id)key {
    [self setObject:object forKey:key withTimeToLife:defaultTimeToLife];
}

- (void)setObject:(id)object forKey:(id)key withTimeToLife:(NSTimeInterval)ttl {
    
    // swap object with CacheableUIImage?
    if ([object isKindOfClass:[UIImage class]]) {
        object = [[[CacheableUIImage alloc] initWithData:UIImagePNGRepresentation(object)] autorelease];
    }
    
    CacheStoreEntry *entry = [[CacheStoreEntry alloc] initWithKey:key value:object timeToLife:ttl];
    
    [self putEntryToFirstLevel:entry];
    
    if ([self isPersisting] && self.persistStrategy == CacheStorePersistStrategyOnFirstLevelInsert) {
        [self putEntryToSecondLevel:entry];
    }
    
    [entry release];
}

- (void)dealloc {
    [cache release];
    [name release];
    [super dealloc];
}

@end
