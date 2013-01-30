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
#import "BaseModelObject.h"


static const NSUInteger DEFAULT_CACHE_LIMIT = 0;

@interface ModelManager ()

@property int persistCount;

@property (nonatomic)   NSMutableDictionary *modelCache;
@property               NSMutableDictionary *modelCacheIds;     // since we cannot iterate over the NSCache in modelCache, we have to keep a reference to all possible ids


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
        [self initializeCache];
        self.cacheQueue = dispatch_queue_create("cacheQueue", DISPATCH_QUEUE_CONCURRENT);
        self.persistCount = 0;
    }
    return self;
}

- (void)initializeCache {
    [self clearCache];
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
    NSAssert(class != nil, @"expected class");
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

- (void)clearCache {
    self.modelCache = [NSMutableDictionary dictionary];
    self.modelCacheIds = [NSMutableDictionary dictionary];
}

- (void)removeObjectFromCache:(BaseModelObject *)object {
    __weak ModelManager *weak_self = self;
    NSString *objectId = object.objectId;
    Class objectClass = object.class;
    
    NSAssert(objectId != nil && objectId.length > 0, @"expected an objectId");
    
    dispatch_barrier_async(self.cacheQueue, ^{
        [[NSThread currentThread] isMainThread] ? NSLog(@"SHOULD BE DONE FROM BG THREAD") : nil;
        NSCache *cache = [weak_self cacheForClass:objectClass];
        [cache removeObjectForKey:objectId];
        [weak_self removeObjectFromReferenceWithClass:objectClass andId:objectId];
    });
}

- (void)removeObjectFromReference:(BaseModelObject *)object {
    [self removeObjectFromReferenceWithClass:object.class andId:object.objectId];
}

- (void)removeObjectFromReferenceWithClass:(Class)c andId:(NSString *)objectId {
    if (objectId != nil) {
        NSAssert(objectId != nil, @"expected objectId");
        [[self idSetForClass:c] removeObject:objectId];
    }
}

- (void)addObjectToCache:(BaseModelObject *)object {
    // dispatch_barrier waits for all currently executing blocks on the
    // queue to finish, then locks the queue, executes, and unlocks the queue.
    // during the execution of the barrier block, no other blocks run
    NSAssert(object != nil, @"expected object to not be nil");
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
        [self persistObjectIfAppropriate:obj];
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
        // see persistObjectIfAppropriate: method for further info on @synchronized usage here
        @synchronized(path) {
            bm = [BaseModelObject loadFromPath:path];
        }
    });

    // we purposefully do not add the fetched object to the cache
    // since objectWithId: will create a new object and set it in the cache
    // we do not want to override that one
    
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

static NSString * const modelPathComponent = @"models";

- (NSString *)pathForClassName:(NSString *)cName {
    NSAssert(cName.length > 0, @"cName.length must be > 0");
    return [[[self cacheDirectory] stringByAppendingPathComponent:modelPathComponent] stringByAppendingPathComponent:cName];
}

- (NSArray *)modelCacheDirectoriesOnDisk {
    NSString *string = [[self cacheDirectory] stringByAppendingPathComponent:modelPathComponent];
    NSURL *url = [NSURL fileURLWithPath:string];
    return [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:0 error:nil];
}

static NSString * const modelFileExtension = @".plist";

- (NSString *)pathForClass:(Class)class andObjectId:(NSString *)objectId {
    return [NSString stringWithFormat:@"%@%@", [[self pathForClassName:[self stringNameForClass:class]] stringByAppendingPathComponent:objectId], modelFileExtension];
}

- (NSString *)pathForObject:(BaseModelObject *)object {
    NSAssert(object != nil, @"object cannot be nil");
    return [self pathForClass:object.class andObjectId:object.objectId];
}

- (void)persistObjectIfAppropriate:(BaseModelObject *)bm {
    if (bm != nil && [bm shouldPersistModelObject]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) , ^{
            // we use the synchronized directive in order to lock based on the path
            // this allows us to control read/write access across multiple threads
            @synchronized([self pathForClass:bm.class andObjectId:bm.objectId]) {
                [bm persistToPath:[self pathForObject:bm]];
            }
        });
    }
}

- (void)persist {
    ++self.persistCount;
    
    dispatch_async(self.cacheQueue, ^{
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
                    [self persistObjectIfAppropriate:m];
                }
            }
        }
        [self persistCompleted];
    });
}

- (void)persistCompleted {
    dispatch_barrier_async(self.cacheQueue, ^{
        --self.persistCount;
    });
}

- (BOOL)persistScheduled {
    return self.persistCount > 0;
}

- (void)wipeDiskCache {
    // we can just wipe the entire folder, as it will be recreated when needed
    NSString *modelCachePath = [[self cacheDirectory] stringByAppendingPathComponent:modelPathComponent];
    [[NSFileManager defaultManager] removeItemAtPath:modelCachePath error:nil];
}

@end
