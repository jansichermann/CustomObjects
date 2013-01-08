//
//  ModelManager.m
//
//  Created by Jan Sichermann on 01/05/13.
//  Copyright (c) 2013 online in4mation GmbH. All rights reserved.
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
#import "BaseModelObject.h"


static const NSUInteger DEFAULT_CACHE_LIMIT = 0;

@interface ModelManager ()
@property (nonatomic)   NSMutableDictionary *modelCache;
@property               NSMutableDictionary *modelCacheIds;


// we have a single concurrent queue
// reading from the cache can be done concurrently w/ sync
// altering the cache (i.e. adding/removing objects) is done with a barrier
// to insure thread-safety. 
@property               dispatch_queue_t cacheQueue;

@end


@implementation ModelManager

SHARED_SINGLETON_IMPLEMENTATION(ModelManager);

- (id)init {
    self = [super init];
    if (self) {
        self.modelCache = [NSMutableDictionary dictionary];
        self.modelCacheIds = [NSMutableDictionary dictionary];
        self.cacheQueue = dispatch_queue_create("com.in4mation.cacheQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}



#pragma mark - Cache creation

- (NSCache *)cacheForClass:(Class)class {
    return self.modelCache[[self stringNameForClass:class]];
}

- (NSString *)stringNameForClass:(Class)class {
    NSAssert(class != nil, @"expected class");
    return NSStringFromClass(class);
}

- (NSCache *)createCacheForClass:(Class)class {
    // create an appropriate id mapping
    NSMutableSet *idSet = [NSMutableSet set];
    self.modelCacheIds[[self stringNameForClass:class]] = idSet;
    
    // create actual cache
    NSCache *cache = [[NSCache alloc] init];
    self.modelCache[[self stringNameForClass:class]] = cache;
    cache.totalCostLimit = DEFAULT_CACHE_LIMIT;
    return cache;
}

- (NSMutableSet *)idSetForClass:(Class)class {
    return self.modelCacheIds[[self stringNameForClass:class]];
}



#pragma mark - Object Addition, removal

- (void)removeObjectFromCache:(BaseModelObject *)object {
    dispatch_barrier_async(self.cacheQueue, ^{
        NSCache *cache = [self cacheForClass:object.class];
        [cache removeObjectForKey:object.objectId];
        [self removeObjectFromCache:object];
    });
}

- (void)removeObjectFromReference:(BaseModelObject *)object {
    [[self idSetForClass:object.class] removeObject:object.objectId];
}

- (void)addObjectToCache:(BaseModelObject *)object {
    // dispatch_barrier waits for all currently executing blocks on the
    // queue to finish, then locks the queue, executes, and unlocks the queue.
    // during the execution of the barrier block, no other blocks run
    dispatch_barrier_async(self.cacheQueue, ^{
        [[NSThread currentThread] isMainThread] ? NSLog(@"SHOULD BE DONE FROM BG THREAD") : nil;
        
        NSCache *cache = [self cacheForClass:object.class];
        
        if (cache == nil) {
            cache = [self createCacheForClass:object.class];
        }
        
        [cache setObject:object forKey:object.objectId];
        
        [[self idSetForClass:object.class] addObject:object.objectId];
    });

}


#pragma mark = NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(BaseModelObject *)obj {
    dispatch_barrier_async(self.cacheQueue, ^{
        [self removeObjectFromReference:obj];
    });
}



#pragma mark - Object Retrieval
- (BaseModelObject *)_fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId {
    NSCache *cache = [self cacheForClass:class];
    return [cache objectForKey:objectId];
}

- (BaseModelObject *)fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId {
    __block BaseModelObject *bm = nil;
    dispatch_sync(self.cacheQueue, ^{
        bm = [self _fetchObjectFromCacheWithClass:class andId:objectId];
    });
    return bm;
}

- (BaseModelObject *)fetchObjectFromDiskWithClass:(Class)class andId:(NSString *)objectId {
    __block BaseModelObject *bm = nil;
    
    // we grab it from disk synchronously on a high priority queue
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString *path = [self pathForClass:class andObjectId:objectId];
        bm = [BaseModelObject loadFromPath:path];
    });

    // we purposefully do not add the fetched object to the cache
    // since objectWithId: will create a new object and set it in the cache
    // we do not want to override that one
    // further, the mergeWithDiskModel: will handle merging these two objects
    
    return bm;
}

- (NSArray *)cacheNames {
    return self.modelCache.allKeys;
}


#pragma mark - Persisting

- (NSString *)cacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths[0];
}

- (NSString *)pathForClassName:(NSString *)cName {
    NSAssert(cName.length > 0, @"cName.length must be > 0");
    return [[self cacheDirectory] stringByAppendingPathComponent:cName];
}

- (NSString *)pathForClass:(Class)class andObjectId:(NSString *)objectId {
    return [NSString stringWithFormat:@"%@.plist", [[self pathForClassName:[self stringNameForClass:class]] stringByAppendingPathComponent:objectId]];
}

- (NSString *)pathForObject:(BaseModelObject *)object {
    NSAssert(object != nil, @"object cannot be nil");
    return [self pathForClass:object.class andObjectId:object.objectId];
}

- (void)persist {
    dispatch_async(self.cacheQueue, ^{
        NSLog(@"cache names: %@", self.cacheNames);
        
        for (NSString *className in self.modelCacheIds.allKeys) {
            // create folder
            NSString *classPath = [self pathForClassName:className];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSError *error = nil;
            [fileManager createDirectoryAtPath:classPath withIntermediateDirectories:YES attributes:nil error:&error];
            
            if (!error) {
                Class objectClass = NSClassFromString(className);
                NSMutableSet *classIdSet = [self idSetForClass:objectClass];
                
                for (NSString *objectId in classIdSet) {
                    BaseModelObject *m = [self _fetchObjectFromCacheWithClass:objectClass andId:objectId];
                    if ([m shouldPersistModelObject]) {
                        NSString *objectPath = [self pathForObject:m];
                    
                        // persist model
                        [m persistToPath:objectPath];
                    }
                }
            }
        }
    });
}

@end
