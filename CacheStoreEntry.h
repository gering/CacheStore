//
//  CacheStoreEntry.h
//  CacheStore
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CacheStoreEntry : NSObject<NSCoding>

@property(nonatomic, strong) id key;
@property(nonatomic, strong) id value;

@property(nonatomic) NSTimeInterval timeToLife;
@property(nonatomic, strong) NSDate *added, *lastAccess;
@property(nonatomic) long accessCount;

- (id)initWithKey:(id)key value:(id)value timeToLife:(NSTimeInterval)ttl;

- (NSTimeInterval)passed;
- (NSTimeInterval)rest;
- (BOOL)isValid;

@end
