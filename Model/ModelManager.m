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
@property (nonatomic)   NSMutableDictionary *diskCacheIds;      // this is informational so we don't hit the disk if an object is obviously not there.


// we have a single concurrent queue
// reading from the cache can be done concurrently w/ sync
// altering the cache (i.e. adding/removing objects) is done with a barrier
// to insure thread-safety.
@property               dispatch_queue_t cacheQueue;

@end


// Exception
NSException *modelObjectNoIdException;

@implementation ModelManager

SHARED_SINGLETON_IMPLEMENTATION(ModelManager);



- (id)init {
    self = [super init];
    if (self) {
        [self initializeCache];
        self.cacheQueue = dispatch_queue_create("cacheQueue", DISPATCH_QUEUE_CONCURRENT);
        self.persistCount = 0;
        modelObjectNoIdException = [NSException exceptionWithName:@"No Id" reason:@"Expected an objectId" userInfo:nil];
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
    NSAssert(class != nil, @"Expected class");
    return class != nil ? NSStringFromClass(class) : nil;
}

- (NSCache *)createCacheForClass:(Class)class {
    NSAssert(class != nil, @"Expected class");
    if (class != nil) {
        // create an appropriate id mapping
        NSMutableSet *idSet = [NSMutableSet set];
        self.modelCacheIds[[self stringNameForClass:class]] = idSet;
        
        // create actual cache
        NSCache *cache = [[NSCache alloc] init];
        self.modelCache[[self stringNameForClass:class]] = cache;
        cache.totalCostLimit = DEFAULT_CACHE_LIMIT;
        return cache;
    }
    return nil;
}

- (NSMutableSet *)idSetForClass:(Class)class {
    NSAssert(class != nil, @"Expected class");
    return class != nil ? self.modelCacheIds[[self stringNameForClass:class]] : nil;
}



#pragma mark - Object Addition, removal

- (void)clearCache {
    self.modelCache = [NSMutableDictionary dictionary];
    self.modelCacheIds = [NSMutableDictionary dictionary];
}

- (void)_removeObjectFromCache:(BaseModelObject *)object {
    // May want to do this from a BG Thread
    NSCache *cache = [self cacheForClass:object.class];
    [cache removeObjectForKey:object.objectId];
    [self removeObjectFromReferenceWithClass:object.class andId:object.objectId];
}

- (void)removeObjectFromCache:(BaseModelObject *)object {
    
    NSAssert(object.objectId.length > 0, @"Expected object to have a valid objectId");
    [self _removeObjectFromCache:object];
}


// Reference is the set of ids kept in order to be able to iterate
// through all objects in cache

- (void)removeObjectFromReference:(BaseModelObject *)object {
    [self removeObjectFromReferenceWithClass:object.class andId:object.objectId];
}

- (void)removeObjectFromReferenceWithClass:(Class)class andId:(NSString *)objectId {
    NSAssert(objectId != nil, @"Expected an objectId");
    NSAssert(class != nil, @"Expected a class");
    
    if (objectId != nil && class != nil) {
        [[self idSetForClass:class] removeObject:objectId];
    }
}

- (void)_addObjectToCache:(BaseModelObject *)object {
    // May want to do this from a BG Thread
    
    NSCache *cache = [self cacheForClass:object.class];
    
    if (cache == nil) {
        cache = [self createCacheForClass:object.class];
    }
    
    [cache setObject:object forKey:object.objectId];
    
    [[self idSetForClass:object.class] addObject:object.objectId];
}

- (void)addObjectToCache:(BaseModelObject *)object {
    NSAssert(object, @"Expected object to be valid");
    NSAssert(object.objectId.length > 0, @"Expected objectId to be valid");
    [self _addObjectToCache:object];
}


#pragma mark = NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(BaseModelObject *)obj {
    [self persistObjectIfAppropriate:obj];
    [self removeObjectFromReference:obj];
}



#pragma mark - Object Retrieval
- (BaseModelObject *)_fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId {
    NSCache *cache = [self cacheForClass:class];
    return [cache objectForKey:objectId];
}

- (BaseModelObject *)fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId {
    BaseModelObject *bm = [self _fetchObjectFromCacheWithClass:class andId:objectId];
    return bm;
}

- (BaseModelObject *)fetchObjectFromDiskWithClass:(Class)class andId:(NSString *)objectId {
    BaseModelObject *bm = nil;
    
    NSString *path = [self pathForClass:class andObjectId:objectId];
    @synchronized(path) {
        bm = [BaseModelObject loadFromPath:path];
    }
    
    // we purposefully do not add the fetched object to the cache
    // since objectWithId: will create a new object and set it in the cache
    // we do not want to override that one
    
    return bm;
}

- (NSArray *)cacheNames {
    return self.modelCache.allKeys;
}


- (void)addObjectToDiskCacheIdSetWithObjectId:(NSString *)objectId andClassName:(NSString *)className {
    if (self.diskCacheIds == nil) {
        self.diskCacheIds = [NSMutableDictionary dictionary];
    }
    if ([self.diskCacheIds objectForKey:className] == nil) {
        self.diskCacheIds[className] = [NSMutableSet set];
    }
    [self.diskCacheIds[className] addObject:objectId];
}

- (void)primeDiskModelIds {
    NSArray *modelCacheDirs = [self modelCacheDirectoriesOnDisk];
    
    for (NSURL *classPathDir in modelCacheDirs) {
        NSArray *cachedObjectFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:classPathDir includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:0 error:nil];
        
        for (NSURL *cachedObjectFilePath in cachedObjectFiles) {
            NSArray *pathComponents = cachedObjectFilePath.pathComponents;
            
            if (pathComponents.count > 1) {
                NSString *fileName = [pathComponents objectAtIndex:pathComponents.count -1];
                NSString *modelClassName = [pathComponents objectAtIndex:pathComponents.count -2];
                
                NSRange plistRange = [fileName rangeOfString:modelFileExtension];
                if (plistRange.location != NSNotFound) {
                    NSString *objectId = [fileName substringToIndex:plistRange.location];
                    [self addObjectToDiskCacheIdSetWithObjectId:objectId andClassName:modelClassName];
                }
            }
        }
    }
}

- (BOOL)hasDiskFileForObjectWithId:(NSString *)objectId andClass:(Class)objectClass {
    BOOL contains = [self.diskCacheIds[[self stringNameForClass:objectClass]] containsObject:objectId];
    return contains;
}

#pragma mark - Persisting

+ (NSString *)cacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths[0];
}

static NSString * const modelPathComponent = @"models";

- (NSString *)pathForClassName:(NSString *)cName {
    NSAssert(cName.length > 0, @"cName.length must be > 0");
    return [[[self.class cacheDirectory] stringByAppendingPathComponent:modelPathComponent] stringByAppendingPathComponent:cName];
}

- (NSArray *)modelCacheDirectoriesOnDisk {
    NSString *string = [[self.class cacheDirectory] stringByAppendingPathComponent:modelPathComponent];
    NSURL *url = [NSURL fileURLWithPath:string];
    
    NSError *err = nil;
    NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:0 error:&err];
    if (err) {
        NSLog(@"Couldn't read modelCacheDirectories on Disk: %@", err);
        return nil;
    }
    
    return dirs;
}

static NSString * const modelFileExtension = @".plist";

- (NSString *)pathForClass:(Class)class andObjectId:(NSString *)objectId {
    NSAssert(objectId.length > 0, @"Expected objectId");
    if (objectId.length > 0) {
        return [NSString stringWithFormat:@"%@%@", [[self pathForClassName:[self stringNameForClass:class]] stringByAppendingPathComponent:objectId], modelFileExtension];
    }
    return nil;
}

- (NSString *)pathForObject:(BaseModelObject *)object {
    NSAssert(object != nil, @"Expected Object");
    if (object != nil) {
        return [self pathForClass:object.class andObjectId:object.objectId];
    }
    return nil;
}

- (void)persistObjectIfAppropriate:(BaseModelObject *)bm {
    if (bm != nil && [bm shouldPersistModelObject]) {
        // we use the synchronized directive in order to lock based on the path
        // this allows us to control read/write access across multiple threads
        @synchronized([self pathForClass:bm.class andObjectId:bm.objectId]) {
            [self addObjectToDiskCacheIdSetWithObjectId:bm.objectId andClassName:[self stringNameForClass:bm.class]];
            [bm persistToPath:[self pathForObject:bm]];
        }
    }
}

- (void)persist {
    ++self.persistCount;
    
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
}

- (void)persistCompleted {
    --self.persistCount;
}

- (BOOL)persistScheduled {
    return self.persistCount > 0;
}

- (void)wipeDiskCache {
    // we can just wipe the entire folder, as it will be recreated when needed
    NSString *modelCachePath = [[self.class cacheDirectory] stringByAppendingPathComponent:modelPathComponent];
    [[NSFileManager defaultManager] removeItemAtPath:modelCachePath error:nil];
}

@end
