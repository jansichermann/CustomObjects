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
#import <objc/runtime.h>



@interface BaseModelObject ()

MODEL_SINGLE_PROPERTY_M_INTERFACE(NSString, objectId);
@property (nonatomic, weak, readwrite) NSObject<ObjectCacheManagerProtocol> *cacheManager;
@end



@implementation BaseModelObject



#pragma mark - Initialization

+ (NSString *)objectIdFromDict:(NSDictionary *)dict {
    return dict[self.objectIdFieldName];
}

+ (NSString *)objectIdFieldName {
    return @"id";
}

+ (Class)classFromDict:(NSDictionary *)dict {
    return self.class;
}

+ (instancetype)withDict:(NSDictionary *)dict
          inCacheManager:(NSObject <ObjectCacheManagerProtocol> *)cacheManager {
    NSParameterAssert([self conformsToProtocol:@protocol(ObjectDictionaryProtocol)]);
    NSParameterAssert([self respondsToSelector:@selector(objectIdFieldName)] ||
                      [self respondsToSelector:@selector(objectIdFromDict:)]);
    NSString *objectId = [self objectIdFromDict:dict];
    NSParameterAssert(objectId.length > 0);
    
    Class c = [self classFromDict:dict];
    BaseModelObject *obj =
    (BaseModelObject *)[cacheManager fetchObjectFromCacheWithClass:c
                                                             andId:objectId];
    NSParameterAssert(obj == nil ||
                      ![obj isKindOfClass:[BaseModelObject class]]);
    
    if (obj) {
        NSParameterAssert(obj.cacheManager != nil);
        [obj updateWithDictionary:dict];
    }
    else {
        obj = [self.class newObjectWithDictionary:dict
                                   inCacheManager:cacheManager];
    }
    return obj;
}

+ (id)newObjectWithId:(NSString *)objectId {
    if (objectId.length > 0) {
        BaseModelObject *m = [[self alloc] init];
        m.objectId = objectId;
        return m;
    }
    return nil;
}

+ (instancetype)newObjectWithDictionary:(NSDictionary *)dict
                         inCacheManager:(NSObject<ObjectCacheManagerProtocol> *)cacheManager {
    Class c = [self classFromDict:dict];
    BaseModelObject *r = [c newObjectWithId:[self objectIdFromDict:dict]];
    [cacheManager addObjectToCache:r];
    r.cacheManager = cacheManager;
    if (r && [r updateWithDictionary:dict]) {
        return r;
    }
    return nil;
}

#pragma mark - Object updating
- (BOOL)updateWithDictionary:(NSDictionary *)dict {
    if (dict[self.class.objectIdFieldName]) {
        SET_NONPRIMITIVE_IF_VAL_NOT_NIL([NSString class],
                                        self.objectId,
                                        dict[self.class.objectIdFieldName]);
        return YES;
    }
    return NO;
}

- (NSString *)description {
    NSString *s = @"\n";
    for (NSString *propName in self.propertyNames) {
        s = [s stringByAppendingFormat:@"%@: %@\n", propName, [[self valueForKey:propName] description]];
    }
    return s;
}

- (NSArray *)_propertyNamesForClass:(Class)c {
    NSMutableArray *props = [NSMutableArray array];
    unsigned int i;
    objc_property_t *properties = class_copyPropertyList(c, &i);
    for (unsigned int ii = 0; ii < i; ii++) {
        objc_property_t property = properties[ii];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        [props addObject:name];
    }
    
    free(properties);
    
    return props;
}

- (NSArray *)propertyNames {
    NSMutableArray *properties = [NSMutableArray array];
    
    Class c = self.class;
    
    while (YES) {
        [properties addObjectsFromArray:[self _propertyNamesForClass:c]];
        if (c == [BaseModelObject class]) {
            break;
        }
        c = c.superclass;
    }
    
    return properties.copy;
}

@end
