//
//  CacheStoreEntry.m
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import "CacheStoreEntry.h"


@implementation CacheStoreEntry

@synthesize key, value;
@synthesize timeToLife;
@synthesize added, lastAccess;
@synthesize accessCount;

- (id)initWithKey:(id)aKey value:(id)aValue timeToLife:(NSTimeInterval)ttl {
    if ((self = [super init])) {
        self.key = aKey;
        self.value = aValue;
        self.timeToLife = ttl;
        self.added = [NSDate date];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        self.key = [decoder decodeObjectForKey:@"key"];
        self.value = [decoder decodeObjectForKey:@"value"];
        self.timeToLife = [decoder decodeDoubleForKey:@"timeToLife"];
        self.added = [decoder decodeObjectForKey:@"added"];
        self.lastAccess = [decoder decodeObjectForKey:@"lastAccess"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.key forKey:@"key"];
    [encoder encodeObject:self.value forKey:@"value"];
    [encoder encodeDouble:self.timeToLife forKey:@"timeToLife"];
    [encoder encodeObject:self.added forKey:@"added"];
    [encoder encodeObject:self.lastAccess forKey:@"lastAccess"];
}

- (NSTimeInterval)passed {
    return [[NSDate date] timeIntervalSinceDate:added];
}

- (NSTimeInterval)rest {
    return timeToLife - [self passed];
}

- (BOOL)isValid {
    return [self rest] > 0;
}

- (void)dealloc {
    [key release];
    [value release];
    [added release];
    [lastAccess release];
    [super dealloc];
}

@end
