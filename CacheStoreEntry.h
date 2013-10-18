//
//  CacheStoreEntry.h
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CacheStoreEntry : NSObject<NSCoding>

- (id)initWithKey:(id)key value:(id)value timeToLife:(NSTimeInterval)ttl;

- (id)key;
- (id)value;
- (BOOL)valueConformsToNSCoding;
- (NSUInteger)valueSize;
- (NSTimeInterval)timeSinceAdded;
- (NSTimeInterval)remainingTimeToLife;
- (BOOL)isValid;
- (NSUInteger)accessCount;
- (NSTimeInterval)timeSinceLastAccess;

@end
