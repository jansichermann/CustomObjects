//
//  ModelManager.h
//  CustomObjectModels
//
//  Created by jan on 01/05/13.
//  Copyright (c) 2013 online in4mation GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Macros.h"

@class BaseModelObject;

@interface ModelManager : NSObject <NSCacheDelegate>

SHARED_SINGLETON_HEADER(ModelManager);

- (void)removeObjectFromCache:(BaseModelObject *)object;
- (void)addObjectToCache:(BaseModelObject *)object;

- (BaseModelObject *)fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId;
- (BaseModelObject *)fetchObjectFromDiskWithClass:(Class)class andId:(NSString *)objectId;


- (NSArray *)cacheNames;
- (void)persist;
@end
