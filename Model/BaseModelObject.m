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
#import "ModelManager.h"

@interface BaseModelObject ()

MODEL_SINGLE_PROPERTY_M_INTERFACE(NSDate, createdAt);
MODEL_SINGLE_PROPERTY_M_INTERFACE(NSString, objectId);

@end


@implementation BaseModelObject


#pragma mark - Initialization
+ (id)newObjectWithId:(NSString *)objectId {
    return [self newObjectWithId:objectId cached:NO];
}

+ (id)newObjectWithId:(NSString *)objectId cached:(BOOL)cached {
    if (objectId == nil || objectId.length < 1) {
        [NSException raise:@"no id" format:@"object needs id to be created"];
    }
    
    BaseModelObject *m = [[self alloc] init];
    // the object id needs to be set before the caching behavior
    m.objectId = objectId;
    // as setShouldCacheModel will remove or add the object from or to the cache
    // which requires an objectId
    m.shouldCacheModel = cached ? ModelCachingAlways : ModelCachingNever;
    
    
    if (cached) {
        [[ModelManager shared] addObjectToCache:m];
    }
    else {
        [[ModelManager shared] removeObjectFromCache:m];
    }
    
    return m;
}

+ (id)objectWithId:(NSString *)objectId cached:(BOOL)cached {
    BaseModelObject *modelObject = nil;
    
    if (cached) {
        modelObject = [[ModelManager shared] fetchObjectFromCacheWithClass:self.class andId:objectId];
    }
    
    if (modelObject == nil && cached) {
        // we run into the issue of trying to fetch from disk every time
        modelObject = [[ModelManager shared] fetchObjectFromDiskWithClass:self andId:objectId];
        [[ModelManager shared] addObjectToCache:modelObject];
    }
    
    if (modelObject == nil) {
        modelObject = [self newObjectWithId:objectId cached:cached];
    }
    return modelObject;
}

+ (id)withDictionary:(NSDictionary *)dict cached:(BOOL)cached {
    id r = [self objectWithId:dict[@"id"] cached:cached];
    if (r && [r updateWithDictionary:dict]) {
        return r;
    }
    return nil;
}


#pragma mark - Object updating
- (BOOL)updateWithDictionary:(NSDictionary *)dict {
    if (dict[@"id"]) {
        SET_IF_NOT_NIL([NSString class], self.objectId, dict[@"id"]);
        SET_IF_NOT_NIL([NSDate class], self.createdAt, [NSDate dateWithTimeIntervalSince1970:[dict[@"createdAt"] floatValue]]);

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
    [encoder encodeObject:@([self.createdAt timeIntervalSince1970]) forKey:@"createdAt"];
}

- (BaseModelObject *)initWithCoder:(NSCoder *)decoder {
    // models from disk aren't cached as they would otherwise overwrite in-memory objects
    // this should rather be handled with a merge
    self = [self.class newObjectWithId:[decoder decodeObjectForKey:@"objectId"] cached:NO];
    self.createdAt = [NSDate dateWithTimeIntervalSince1970:[[decoder decodeObjectForKey:@"createdAt"] intValue]];
    return self;
}


#pragma mark - Caching behavior
- (void)setShouldCacheModel:(ModelCachingBehavior)shouldCacheModel {

    NSAssert(self.objectId != nil && self.objectId.length > 0, @"expected an objectId on the model");
    
    _shouldCacheModel = shouldCacheModel;
    if (shouldCacheModel == ModelCachingAlways) {
        [[ModelManager shared] addObjectToCache:self];
    }
    if (shouldCacheModel == ModelCachingNever) {
        [[ModelManager shared] removeObjectFromCache:self];
    }
}

- (BOOL)shouldCacheModelObject {
    if (_shouldCacheModel == ModelCachingNever)         return NO;
    if (_shouldCacheModel == ModelCachingAlways)        return YES;
    return NO;
}


#pragma mark - Persisting
- (BOOL)shouldPersistModelObject {
    return [self shouldCacheModelObject];
}

- (void)persistToPath:(NSString *)path {
    @try {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
        [data writeToFile:path atomically:NO];
    }
    @catch (NSException *exception) {
        NSLog(@"### SOMETHING WENT WRONG TRYING TO PERSIST TO DISK ###");
    }
    @finally {
    }
}

+ (id)loadFromPath:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        @try {
            id obj = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
            return obj;
        }
        @catch (NSException *exception) {
            NSLog(@"### SOMETHING TERRIBLE HAPPENED WHEN LOADING FROM DISK ###");
        }
        @finally {
        }
    }
    return nil;
}

@end
