//
//  CacheStore.m
//  ProviderCheck
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

// TODO: persist on setObject:forKey: if enabled
// TODO: persist on dealloc if enabled


#import "CacheStore.h"
#import "CacheStoreEntry.h"

@implementation CacheStore

@synthesize strategy;
@synthesize store;
@synthesize firstLevelLimit, secondLevelLimit;
@synthesize defaultTimeToLife;
@dynamic persisting;
@dynamic firstLevelCount, secondLevelCount;

#pragma mark - init

- (id)init {
    if ((self = [super init])) {
        self.firstLevelLimit = 1000;
        self.defaultTimeToLife = 3600;    // one hour
        cache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithFirstLevelLimit:(NSUInteger)aFirstLevelLimit secondLevelLimit:(NSUInteger)aSecondLevelLimit {
    if ((self = [self init])) {
        self.firstLevelLimit = aFirstLevelLimit;
        self.secondLevelLimit = aSecondLevelLimit;
    }
    return self;
}

- (id)initWithFirstLevelLimit:(NSUInteger)aFirstLevelLimit secondLevelLimit:(NSUInteger)aSecondLevelLimit andStrategy:(CacheStoreStrategy)aStrategy {
    if ((self = [self initWithFirstLevelLimit:aFirstLevelLimit secondLevelLimit:aSecondLevelLimit])) {
        self.strategy = aStrategy;
    }
    return self;
}

+ (CacheStore *)cacheStoreWithFirstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit {
    return [[[CacheStore alloc] initWithFirstLevelLimit:firstLevelLimit secondLevelLimit:secondLevelLimit] autorelease];
}

+ (CacheStore *)cacheStoreWithFirstLevelLimit:(NSUInteger)firstLevelLimit secondLevelLimit:(NSUInteger)secondLevelLimit andStrategy:(CacheStoreStrategy)strategy {
    return [[[CacheStore alloc] initWithFirstLevelLimit:firstLevelLimit secondLevelLimit:secondLevelLimit andStrategy:strategy] autorelease];
}

# pragma mark -

- (BOOL)isPersisting {
    return secondLevelLimit > 0;
}

- (NSUInteger)firstLevelCount {
    return cache.count;
}

- (NSUInteger)secondLevelCount {
    // TODO: return number of files
    return 0;
}

# pragma mark -

- (NSSet *)files {
    // TODO: return all files
    return nil;
}

#pragma mark - level based cache access

- (NSString *)cacheDirectory {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    return cacheDirectory;
}

- (NSString *)fileForKey:(id)key {
    return [NSString stringWithFormat:@"%@/%i.cache", [self cacheDirectory], [key hash]];
}

- (CacheStoreEntry *)entryFromFirstLevel:(id)key {
    CacheStoreEntry *entry = [cache objectForKey:key];
    return entry;
}

- (CacheStoreEntry *)entryFromSecondLevel:(id)key {
    CacheStoreEntry *entry = [NSKeyedUnarchiver unarchiveObjectWithFile:[self fileForKey:key]];
    if (![entry.key isEqual:key]) {
        entry = nil;
        NSLog(@"key mismatch in second level cache");
    }
    return entry;
}

- (void)putEntryToCache:(CacheStoreEntry *)entry {
    if ([entry isValid]) {
        [cache setObject:entry forKey:entry.key]; 
    }
}

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


#pragma mark - using the cache

- (id)objectForKey:(id)key {
    
    // try first level
    CacheStoreEntry *entry = [self entryFromFirstLevel:key];
    
    if (!entry) {
        // try second level
        entry = [self entryFromSecondLevel:key];
        [self putEntryToCache:entry];
    }
    
    // validate
    if (entry && ![entry isValid]) {
        [self removeFromFirstLevel:key];
        [self removeFromSecondLevel:key];
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
    CacheStoreEntry *entry = [[CacheStoreEntry alloc] initWithKey:key value:object timeToLife:ttl];
    [self putEntryToCache:entry];
    [entry release];
}

- (void)dealloc {
    [cache release];
    [super dealloc];
}

@end
