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

#pragma mark - NSCacheDelegate

- (void)cache:(__unused NSCache *)cache
willEvictObject:(id)obj {
    
//    if ([obj conformsToProtocol:@protocol(PersistanceProtocol)]) {
//        
//        [self.class persistObject:obj];
//    }
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
    NSParameterAssert(!object.isTempObject);
    
    [self.cache setObject:object
                   forKey:[object cacheKey]];
}

- (void)addObjectToCache:(NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)object {
    if (!object) {
        return;
    }
    
    if ([object respondsToSelector:@selector(setCacheManager:)]) {
        object.cacheManager = self;
    }
    [self _addObjectToCache:object];
}


#pragma mark - Object Retrieval

- (NSObject <ObjectIdProtocol, CacheableObjectProtocol, PersistanceProtocol> *)_fetchObjectFromCacheWithClass:(Class)c
                                                                                                        andId:(NSString *)objectId {
    NSObject <ObjectIdProtocol, CacheableObjectProtocol, PersistanceProtocol> *obj =
    [self.cache objectForKey:[c cacheKeyForId:objectId]];
    
    if (!obj) {
        obj = [c js__loadFromPath:[self.class persistancePathForClass:c
                                                               withId:objectId]];
    }
    return obj;
}

- (NSObject<ObjectIdProtocol, CacheableObjectProtocol> *)fetchObjectFromCacheWithClass:(Class)c
                                                                                 andId:(NSString *)objectId {
    NSObject<ObjectIdProtocol, CacheableObjectProtocol> *bm =
    [self _fetchObjectFromCacheWithClass:c
                                   andId:objectId];
    return bm;
}

- (void)reset {
    [self clearCache];
    [self.class wipeDiskCacheDirectory];
}

+ (void)wipeDiskCacheDirectory {
    [[NSFileManager defaultManager] removeItemAtPath:[self cachesFolderPathString]
                                               error:nil];
}

#pragma mark - Persisting

+ (void)persistObject:(NSObject <ObjectIdProtocol, PersistanceProtocol, CacheableObjectProtocol> *)object {
    
    [self ensureFolder];
    
    NSString *path = [self persistancePathForModel:object];
    @synchronized(path) {
        [object js__persistToPath:path];
    }
}

+ (NSString *)persistancePathForModel:(NSObject <ObjectIdProtocol, PersistanceProtocol, CacheableObjectProtocol> *)object {
    return [self persistancePathForClass:object.class
                                  withId:object.objectId];
}

- (NSArray *)diskObjectsForClass:(Class)c {
    NSArray *paths =
    [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self.class cachesFolderPathString]
                                                        error:nil];
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:paths.count];
    NSString *cacheKey = [c cacheKeyForId:@""];
    
    for (NSString *path in paths) {
        if ([path rangeOfString:cacheKey].location == 0) {
            NSObject *obj = [c js__loadFromPath:
             [[self.class cachesFolderPathString] stringByAppendingPathComponent:path]];
            if (obj
                && [obj conformsToProtocol:@protocol(ObjectIdProtocol)]) {
                [self addObjectToCache:(NSObject <ObjectIdProtocol> *)obj];
                [objects addObject:obj];
            }
        }
    }
    
    return objects;
}

+ (NSString *)persistancePathForClass:(Class)cl
                               withId:(NSString *)objectId {
    return [[self cachesFolderPathString] stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@.plist",
             [cl cacheKeyForId:objectId]]];
}


+ (NSString *)cachesFolderPathString {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                         NSUserDomainMask, YES);
    NSString *cachesPath = [paths objectAtIndex:0];
    return [cachesPath stringByAppendingPathExtension:@"modelmanager"];
}

+ (void)ensureFolder {
    [[NSFileManager defaultManager] createDirectoryAtPath:self.cachesFolderPathString
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
}


@end
