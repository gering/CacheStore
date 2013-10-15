//
//  CacheStoreEntry.m
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import "CacheStoreEntry.h"
#import "CacheableUIImage.h"

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static NSString * const kNSCodingKeyKey = @"key";
static NSString * const kNSCodingKeyValue = @"value";
static NSString * const kNSCodingKeyTimeToLife = @"timeToLife";
static NSString * const kNSCodingKeyAdded = @"added";
static NSString * const kNSCodingKeyLastAccess = @"lastAccess";


@implementation CacheStoreEntry

- (id)initWithKey:(id)key value:(id)value timeToLife:(NSTimeInterval)ttl {
    if ((self = [super init])) {

        // swap object with CacheableUIImage?
        if ([value isKindOfClass:[UIImage class]]) {
            value = [[CacheableUIImage alloc] initWithData:UIImagePNGRepresentation(value)];
        }
        
        self.key = key;
        self.value = value;
        self.timeToLife = ttl;
        self.added = [NSDate date];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        self.key = [decoder decodeObjectForKey:kNSCodingKeyKey];
        self.value = [decoder decodeObjectForKey:kNSCodingKeyValue];
        self.timeToLife = [decoder decodeDoubleForKey:kNSCodingKeyTimeToLife];
        self.added = [decoder decodeObjectForKey:kNSCodingKeyAdded];
        self.lastAccess = [decoder decodeObjectForKey:kNSCodingKeyLastAccess];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.key forKey:kNSCodingKeyKey];
    [encoder encodeObject:self.value forKey:kNSCodingKeyValue];
    [encoder encodeDouble:self.timeToLife forKey:kNSCodingKeyTimeToLife];
    [encoder encodeObject:self.added forKey:kNSCodingKeyAdded];
    [encoder encodeObject:self.lastAccess forKey:kNSCodingKeyLastAccess];
}

- (NSTimeInterval)passed {
    return [[NSDate date] timeIntervalSinceDate:self.added];
}

- (NSTimeInterval)rest {
    return self.timeToLife - self.passed;
}

- (BOOL)isValid {
    return self.rest > 0;
}

@end
