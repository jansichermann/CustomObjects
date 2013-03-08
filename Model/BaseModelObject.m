//
//  BaseModelObject.m
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

#import "BaseModelObject.h"
#import "ModelManager.h"



@interface BaseModelObject ()

MODEL_SINGLE_PROPERTY_M_INTERFACE(NSString, objectId);

@end



@implementation BaseModelObject



#pragma mark - Initialization

+ (id)newObjectWithId:(NSString *)objectId {
    return [self newObjectWithId:objectId cached:NO];
}

+ (id)newObjectWithId:(NSString *)objectId cached:(BOOL)cached {
    if (objectId.length > 0) {
        BaseModelObject *m = [[self alloc] init];
        // the object id needs to be set before the caching behavior
        m.objectId = objectId;
        // as setShouldCacheModel will remove or add the object from or to the cache
        // which requires an objectId
        m.shouldCacheModel = cached ? ModelCachingAlways : ModelCachingNever;
        
        return m;
    }
    return nil;
}

+ (id)objectWithId:(NSString *)objectId cached:(BOOL)cached {
    if (objectId == nil || objectId.length == 0) {
        [modelObjectNoIdException raise];
    }
    BaseModelObject *modelObject = nil;
    
    if (objectId && [objectId isKindOfClass:[NSString class]]) {
        if (cached) {
            modelObject = [[ModelManager shared] fetchObjectFromCacheWithClass:self.class andId:objectId];
        }
        
        if (modelObject == nil && cached && [[ModelManager shared] hasDiskFileForObjectWithId:objectId andClass:self]) {
            modelObject = [[ModelManager shared] fetchObjectFromDiskWithClass:self andId:objectId];
        }
        
        if (modelObject == nil) {
            modelObject = [self newObjectWithId:objectId cached:cached];
        }
        
        if (modelObject && cached) {
            [[ModelManager shared] addObjectToCache:modelObject];
        }
    }
    
    return modelObject;
}

+ (id)withDictionary:(NSDictionary *)dict cached:(BOOL)cached {
    id r = [self objectWithId:dict[kBaseModelIdKey] cached:cached];
    if (r && [r updateWithDictionary:dict]) {
        return r;
    }
    return nil;
}


#pragma mark - Object updating
- (BOOL)updateWithDictionary:(NSDictionary *)dict {
    if (dict[kBaseModelIdKey]) {
        SET_NONPRIMITIVE_IF_VAL_NOT_NIL([NSString class], self.objectId, dict[kBaseModelIdKey]);
        
        if ([self shouldCacheModelObject]) {
            [[ModelManager shared] addObjectToCache:self];
        }
        return YES;
    }
    return NO;
}


#pragma mark - NSCoding
- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.objectId forKey:kBaseModelIdKey];
}

- (BaseModelObject *)initWithCoder:(NSCoder *)decoder {
    // we set the caching behavior to yes,
    // which overrides any object in cache
    
    // we do this, as we assume that any object fetched from disk
    // is fetched from disk due to not being in cache
    self = [self.class newObjectWithId:[decoder decodeObjectForKey:kBaseModelIdKey] cached:YES];
    return self;
}


#pragma mark - Caching behavior
- (void)setShouldCacheModel:(ModelCachingBehavior)shouldCacheModel {
    if (self.objectId == nil || self.objectId.length == 0) {
        [modelObjectNoIdException raise];
    }
    
    _shouldCacheModel = shouldCacheModel;
    if (shouldCacheModel == ModelCachingAlways) {
        [[ModelManager shared] addObjectToCache:self];
    }
    if (shouldCacheModel == ModelCachingNever) {
        [[ModelManager shared] removeObjectFromCache:self];
    }
}

- (BOOL)shouldCacheModelObject {
    if (_shouldCacheModel == ModelCachingAlways)        return YES;
    return NO;
}


#pragma mark - Persisting
- (BOOL)shouldPersistModelObject {
    return [self shouldCacheModelObject];
}

- (void)persistToPath:(NSString *)path {

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    if (![data writeToFile:path atomically:YES]) {
        NSAssert(NO, @"persist failed");
        NSLog(@"### SOMETHING WENT WRONG TRYING TO PERSIST TO DISK ###");
    }
}

+ (id)loadFromPath:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        @try {
            id obj = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
            return obj;
        }
        @catch (NSException *exception) {
            NSLog(@"### FILE AT PATH DID NOT CONTAIN VALID ARCHIVE ###");
#if UNITTESTING
            [exception raise];
#endif
        }
        @finally {
        }
    }
    return nil;
}


#pragma mark - Debugging and Testing

+ (NSMutableDictionary *)modelTestDictionary {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[kBaseModelIdKey] = @"KHJZXV8YQ345HKJLXCVBNMER89Y";
    return dictionary;
}

@end
