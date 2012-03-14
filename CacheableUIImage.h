//
//  CacheableUIImage.h
//  CacheStore
//
//  Created by Robert Gering on 14.03.12.
//  Copyright (c) 2012 RGSD. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CacheableUIImage : UIImage

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@end
