//
//  CacheStoreEntry.h
//  ProviderCheck
//
//  Created by Robert Gering on 07.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CacheStoreEntry : NSObject<NSCoding> {  
}

@property(retain, nonatomic) id key;
@property(retain, nonatomic) id value;

@property(assign) NSTimeInterval timeToLife;
@property(retain) NSDate *added, *lastAccess;
@property(assign) long accessCount;

- (id)initWithKey:(id)key value:(id)value timeToLife:(NSTimeInterval)ttl;

- (NSTimeInterval)passed;
- (NSTimeInterval)rest;
- (BOOL)isValid;

@end
