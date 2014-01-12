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

+ (Class)classForDict:(NSDictionary *)dict {
    return self.class;
}

+ (id)newObjectWithId:(NSString *)objectId {
    if (objectId.length > 0) {
        BaseModelObject *m = [[self alloc] init];
        // the object id needs to be set before the caching behavior
        m.objectId = objectId;
        return m;
    }
    return nil;
}

+ (id)objectWithId:(NSString *)objectId {
    if (objectId.length == 0) {
        @throw modelObjectNoIdException;
    }
    
    BaseModelObject *modelObject = nil;
    
    if (objectId && [objectId isKindOfClass:[NSString class]]) {
        modelObject =
        [[ModelManager shared] fetchObjectFromCacheWithClass:self
                                                       andId:objectId];
        
        if (modelObject == nil &&
            [[ModelManager shared] hasDiskFileForObjectWithId:objectId
                                                     andClass:self]) {
                modelObject =
                [[ModelManager shared] fetchObjectFromDiskWithClass:self
                                                              andId:objectId];
            }
        
        if (modelObject == nil) {
            modelObject = [self newObjectWithId:objectId];
        }
        
        [modelObject ensureCaching];
    }
    
    return modelObject;
}

+ (id)withDictionary:(NSDictionary *)dict {
    Class c = [self classForDict:dict];
    id r = [c objectWithId:dict[self.objectIdFieldName]];
    if (r && [r updateWithDictionary:dict]) {
        return r;
    }
    return nil;
}


#pragma mark - Object updating
- (BOOL)updateWithDictionary:(NSDictionary *)dict {
    if (dict[self.class.objectIdFieldName]) {
        SET_NONPRIMITIVE_IF_VAL_NOT_NIL([NSString class], self.objectId, dict[self.class.objectIdFieldName]);
        
        [self ensureCaching];
        return YES;
    }
    return NO;
}

+ (NSString *)objectIdFieldName {
    return @"_id";
}


#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.objectId forKey:self.class.objectIdFieldName];
}

- (BaseModelObject *)initWithCoder:(NSCoder *)decoder {
    // we set the caching behavior to yes,
    // which overrides any object in cache
    
    // we do this, as we assume that any object fetched from disk
    // is fetched from disk due to not being in cache
    self = [self.class newObjectWithId:
            [decoder decodeObjectForKey:self.class.objectIdFieldName]];
    return self;
}


#pragma mark - Caching

- (void)ensureCaching {
    if (self.objectId.length == 0) {
        @throw modelObjectNoIdException;
    }
    [[ModelManager shared] addObjectToCache:self];
}


#pragma mark - Persisting

- (void)persistToPath:(NSString *)path {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    if (![data writeToFile:path atomically:YES]) {
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
    dictionary[self.objectIdFieldName] = @"KHJZXV8YQ345HKJLXCVBNMER89Y";
    return dictionary;
}

@end
