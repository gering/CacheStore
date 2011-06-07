//
//  CacheStoreImageSupport.h
//  ProviderCheck
//
//  Created by Robert Gering on 08.06.11.
//  Copyright 2011 RGSD. All rights reserved.
//

#import <Foundation/Foundation.h>

    
@interface UIImageNSCoding <NSCoding>

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@end
