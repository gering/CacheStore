//
//  CacheStoreEntry.m
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import "CacheStoreEntry.h"
#import "CacheableUIImage.h"
#import <malloc/malloc.h>

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static NSString *const kNSCodingKeyKey = @"key";
static NSString *const kNSCodingKeyValue = @"value";
static NSString *const kNSCodingKeyTimeToLife = @"timeToLife";
static NSString *const kNSCodingKeyAdded = @"added";
static NSString *const kNSCodingKeyLastAccess = @"lastAccess";

@interface CacheStoreEntry()

@property(nonatomic, strong) id key;
@property(nonatomic, strong) id value;

@property(nonatomic) NSTimeInterval timeToLife;
@property(nonatomic, strong) NSDate *added, *lastAccess;
@property(nonatomic) NSUInteger accessCount;

@end


@implementation CacheStoreEntry


- (id)initWithKey:(id)key value:(id)value timeToLife:(NSTimeInterval)ttl {
    if ((self = [super init])) {

        if (![[value class] conformsToProtocol:@protocol(NSCoding)]) {
            // swap object with CacheableUIImage?
            if ([value isKindOfClass:[UIImage class]]) {
                value = [[CacheableUIImage alloc] initWithData:UIImagePNGRepresentation(value)];
            }
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

- (id)value {
    if (self.accessCount < NSUIntegerMax) self.accessCount++;
    self.lastAccess = [NSDate date];
    return _value;
}

- (BOOL)valueConformsToNSCoding {
    return ([[self.value class] conformsToProtocol:@protocol(NSCoding)]);
}

- (NSData *)encodeValue {
    if ([self valueConformsToNSCoding]) {
        return [NSKeyedArchiver archivedDataWithRootObject:self.value];
    } else {
        return nil;
    }
}

- (NSUInteger)valueSize {
    NSData *data = [self encodeValue];
    if (data) {
        return data.length;
    } else {
        return malloc_size(&_value);
    }
}

- (NSTimeInterval)timeSinceAdded {
    return [[NSDate date] timeIntervalSinceDate:self.added];
}

- (NSTimeInterval)remainingTimeToLife {
    return self.timeToLife - self.timeSinceAdded;
}

- (BOOL)isValid {
    return self.remainingTimeToLife > 0;
}

- (NSUInteger)accessCount {
    return _accessCount;
}

- (NSTimeInterval)timeSinceLastAccess {
    return [[NSDate date] timeIntervalSinceDate:self.lastAccess];
}

@end
