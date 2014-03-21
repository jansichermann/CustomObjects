//
//  ModelManager.m
//
//  Created by Jan Sichermann on 01/05/13.
//  Copyright (c) 2013 Jan Sichermann. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "ModelManager.h"



@interface ModelManager () <NSCacheDelegate>

@property (atomic)               NSCache *cache;

@end



@implementation ModelManager

- (id)init {
    self = [super init];
    if (self) {
        [self initializeCache];
    }
    return self;
}

- (void)initializeCache {
    [self clearCache];
}

#pragma mark - Object Addition, Removal

- (void)clearCache {
    self.cache = [[NSCache alloc] init];
    self.cache.delegate = self;
}

- (void)_removeObjectFromCache:(NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)object {
    [self.cache removeObjectForKey:[object cacheKey]];
}

- (void)removeObjectFromCache:(NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)object {
    NSParameterAssert([object conformsToProtocol:@protocol(ObjectIdProtocol)]);
    NSParameterAssert([object conformsToProtocol:@protocol(CacheableObjectProtocol)]);
    NSParameterAssert(object.objectId.length > 0);
    [self _removeObjectFromCache:object];
}

- (void)_addObjectToCache:(NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)object {
    NSParameterAssert([object conformsToProtocol:@protocol(ObjectIdProtocol)]);
    NSParameterAssert([object conformsToProtocol:@protocol(CacheableObjectProtocol)]);
    NSParameterAssert(object.objectId.length > 0);
    NSParameterAssert([[NSThread currentThread] isMainThread]);
    NSParameterAssert(!object.isTempObject);
    
    [self.cache setObject:object
                   forKey:[object cacheKey]];
}

- (void)addObjectToCache:(NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)object {
    
    if (!object) {
        return;
    }
    
    NSParameterAssert([[NSThread currentThread] isMainThread]);
    if ([object respondsToSelector:@selector(setCacheManager:)]) {
        object.cacheManager = self;
    }
    [self _addObjectToCache:object];
}


#pragma mark - Object Retrieval

- (NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)_fetchObjectFromCacheWithClass:(Class)c
                                                                                  andId:(NSString *)objectId {
    return [self.cache objectForKey:[c cacheKeyForId:objectId]];
}

- (NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)fetchObjectFromCacheWithClass:(Class)c
                                                                                 andId:(NSString *)objectId {
    NSObject<ObjectIdProtocol, CacheableObjectProtocol> *bm =
    [self _fetchObjectFromCacheWithClass:c
                                   andId:objectId];
    return bm;
}

@end
