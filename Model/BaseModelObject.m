//
//  BaseModelObject.m
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

#import "BaseModelObject.h"

#define DISKMERGE 0

@interface BaseModelObject ()

MODEL_SINGLE_PROPERTY_M_INTERFACE(NSDate, createdAt);
MODEL_SINGLE_PROPERTY_M_INTERFACE(NSString, objectId);

@end


@implementation BaseModelObject

#pragma mark - Initialization

+ (id)newObjectWithId:(NSString *)objectId cached:(BOOL)cached {
    if (objectId == nil || objectId.length < 1) {
        [NSException raise:@"no id" format:@"object needs id to be created"];
    }
    
    BaseModelObject *m = [[self alloc] init];
    m.shouldCacheModel = ModelCachingAlways;
    m.objectId = objectId;
    
    if (cached) {
        [[ModelManager shared] addObjectToCache:m];
    }
    
    return m;
}

+ (id)objectWithId:(NSString *)objectId cached:(BOOL)cached {
    BaseModelObject *modelObject = [[ModelManager shared] fetchObjectFromCacheWithClass:self andId:objectId];
    
    modelObject ? NSLog(@"found object in cache id: %@", modelObject.objectId) : nil ;
    
#if DISKMERGE
    if (modelObject == nil) {
        modelObject = [self newObjectWithId:objectId cached:cached];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            BaseModelObject *bm = [[ModelManager shared] fetchObjectFromDiskWithClass:self andId:objectId];
            if (bm != nil) {
                [modelObject mergeWithDiskModel:bm];
            }
        });
    }
#else
    if (modelObject == nil && cached) {
        modelObject = [[ModelManager shared] fetchObjectFromDiskWithClass:self andId:objectId];
    }
    if (modelObject == nil) {
        modelObject = [self newObjectWithId:objectId cached:cached];
    }
#endif
    
    return modelObject;
}

+ (id)withDictionary:(NSDictionary *)dict cached:(BOOL)cached {
    id r = [self objectWithId:dict[@"id"] cached:cached];
    if (r && [r updateWithDictionary:dict]) {
        return r;
    }
    return nil;
}

#if DISKMERGE
- (void)mergeWithDiskModel:(BaseModelObject *)diskModel {
    if ([self.createdAt isKindOfClass:diskModel.createdAt.class]) {
        if (self.createdAt == nil && diskModel.createdAt != nil) {
            self.createdAt = diskModel.createdAt;
        }
    }
    
    if (self.onDiskMergeBlock != nil) {
        self.onDiskMergeBlock(self);
    }
}
#endif

#pragma mark - Object updating



- (BOOL)updateWithDictionary:(NSDictionary *)dict {
    if (dict[@"id"]) {
        SET_IF_NOT_NIL(self.objectId, dict[@"id"]);
        SET_IF_NOT_NIL(self.createdAt, [NSDate dateWithTimeIntervalSince1970:[dict[@"createdAt"] floatValue]]);

        if ([self shouldCacheModelObject]) {
            [[ModelManager shared] addObjectToCache:self];
        }
        return YES;
    }
    return NO;
}


#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.objectId forKey:@"objectId"];
    [encoder encodeObject:self.createdAt forKey:@"createdAt"];
}

- (BaseModelObject *)initWithCoder:(NSCoder *)decoder {
    self = [self.class newObjectWithId:[decoder decodeObjectForKey:@"objectId"] cached:YES];
    self.createdAt = [decoder decodeObjectForKey:@"createdAt"];
    return self;
}


#pragma mark - Caching behavior
- (void)setShouldCacheModel:(ModelCachingBehavior)shouldCacheModel {
    _shouldCacheModel = shouldCacheModel;
    if (shouldCacheModel == ModelCachingAlways) {
        [[ModelManager shared] addObjectToCache:self];
    }
    if (shouldCacheModel == ModelCachingNever ) {
        [[ModelManager shared] removeObjectFromCache:self];
    }
}

- (BOOL)shouldCacheModelObject {
    if (_shouldCacheModel == ModelCachingNever)         return NO;
    if (_shouldCacheModel == ModelCachingAlways)        return YES;
    return NO;
}

- (BOOL)shouldPersistModelObject {
    return [self shouldCacheModelObject];
}

- (void)persistToPath:(NSString *)path {
    NSLog(@"persisting object to path: %@", path);
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    [data writeToFile:path atomically:NO];
}

+ (id)loadFromPath:(NSString *)path {
    @try {
        id obj = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        return obj;
    }
    @catch (NSException *exception) {
        NSLog(@"### SOMETHING TERRIBLE HAPPENED WHEN LOADING FROM DISK ###");
    }
    @finally {
    }
    return nil;
}

@end
