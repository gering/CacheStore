//
//  CacheableUIImage.m
//  CacheStore
//
//  Created by Robert Gering on 14.03.12.
//  Copyright (c) 2012 RGSD. All rights reserved.
//

#import "CacheableUIImage.h"

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation CacheableUIImage

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        NSData *data = [decoder decodeObjectForKey:@"cacheableUIImage"];
        self = [self initWithData:data];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    NSData *data = UIImagePNGRepresentation(self);
    [encoder encodeObject:data forKey:@"cacheableUIImage"];
}

@end
