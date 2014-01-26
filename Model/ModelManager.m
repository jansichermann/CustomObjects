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


static const NSUInteger DEFAULT_CACHE_LIMIT = 0;



@interface ModelManager () <NSCacheDelegate>

@property               NSDictionary            *modelCache;

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

#pragma mark - Cache Creation

- (NSCache *)cacheForClass:(Class)class {
    return self.modelCache[[self stringNameForClass:class]];
}

- (NSString *)stringNameForClass:(Class)class {
    NSParameterAssert(class != nil);
    return NSStringFromClass(class);
}

- (NSCache *)createCacheForClass:(Class)class {
    NSParameterAssert(class != nil);
    
    NSString *cacheKey = [self stringNameForClass:class];
    NSParameterAssert(cacheKey.length > 0);
    
    NSCache *cache = [[NSCache alloc] init];
    NSParameterAssert(cache);
    cache.totalCostLimit = DEFAULT_CACHE_LIMIT;
    
    // We do this as with an immutable copy as it provides
    // better thread safety for future compatability
    if (self.modelCache) {
        NSArray *objects = self.modelCache.allValues;
        NSArray *keys = self.modelCache.allKeys;
        NSAssert(objects, @"Expected objects");
        NSAssert(keys, @"Expected keys");
        self.modelCache =
        [[NSDictionary alloc] initWithObjects:[objects arrayByAddingObject:cache]
                                      forKeys:[keys arrayByAddingObject:cacheKey]];
    }
    else {
        self.modelCache = @{cacheKey : cache};
    }
    
    NSParameterAssert(self.modelCache != nil);
    
    return cache;
}


#pragma mark - Object Addition, Removal

- (void)clearCache {
    self.modelCache = nil;
}

- (void)_removeObjectFromCache:(NSObject<ObjectIdProtocol> *)object {
    NSCache *cache = [self cacheForClass:object.class];
    [cache removeObjectForKey:object.objectId];
}

- (void)removeObjectFromCache:(NSObject<ObjectIdProtocol> *)object {
    NSParameterAssert(object.objectId.length > 0);
    [self _removeObjectFromCache:object];
}

- (void)_addObjectToCache:(NSObject<ObjectIdProtocol> *)object {
    NSParameterAssert(object.objectId.length > 0);
    NSParameterAssert([[NSThread currentThread] isMainThread]);
    
    NSCache *cache = [self cacheForClass:object.class];
    
    if (cache == nil) {
        cache = [self createCacheForClass:object.class];
    }
    
    NSParameterAssert(cache);
    [cache setObject:object
              forKey:object.objectId];
}

- (void)addObjectToCache:(NSObject<ObjectIdProtocol> *)object {
    NSParameterAssert(object.objectId.length > 0);
    NSParameterAssert([[NSThread currentThread] isMainThread]);
    [self _addObjectToCache:object];
}


#pragma mark - Object Retrieval

- (NSObject<ObjectIdProtocol> *)_fetchObjectFromCacheWithClass:(Class)c
                                              andId:(NSString *)objectId {
    NSCache *cache = [self cacheForClass:c];
    return [cache objectForKey:objectId];
}

- (NSObject<ObjectIdProtocol> *)fetchObjectFromCacheWithClass:(Class)c
                                             andId:(NSString *)objectId {
    NSObject<ObjectIdProtocol> *bm = [self _fetchObjectFromCacheWithClass:c
                                                         andId:objectId];
    return bm;
}

@end
