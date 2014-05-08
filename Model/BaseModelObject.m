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
#import "ModelReference.h"
@import ObjectiveC.runtime;



@interface BaseModelObject ()

@property (nonatomic)                   NSString                            *objectId;
@property (nonatomic, weak, readwrite)  NSObject<ObjectCacheManagerProtocol>*cacheManager;
@property (nonatomic)                   BOOL                                isTempObject;

@end



@implementation BaseModelObject
@synthesize cacheManager = _cacheManager;
@synthesize isTempObject = _isTempObject;
@synthesize objectId = _objectId;


#pragma mark - Initialization

// determines whether the object
// is archived as part of its parent
// or by itself and its parent holds a reference
+ (BOOL)archiveUniquely {
    return YES;
}

- (BOOL)archiveUniquely {
    return self.class.archiveUniquely;
}

+ (NSString *)cacheKeyForId:(NSString *)objectId {
    return [NSStringFromClass(self) stringByAppendingFormat:@"__%@", objectId];
}

- (NSString *)cacheKey {
    return [self.class cacheKeyForId:self.objectId];
}

+ (NSString *)objectIdFromDict:(NSDictionary *)dict {
    NSObject *obj = dict[self.objectIdFieldName];
    if ([obj isKindOfClass:[NSString class]]) {
        return (NSString *)obj;
    }
    return nil;
}

+ (NSString *)objectIdFieldName __attribute__((const)) {
    return @"id";
}

+ (Class)classFromDict:(__unused NSDictionary *)dict __attribute__((pure)) {
    return self.class;
}

+ (BOOL)isValidModelDict:(NSDictionary *)dict {
    return [self objectIdFromDict:dict].length > 0 &&
    [self classFromDict:dict] != nil;
}


+ (instancetype)withDict:(NSDictionary *)dict
          inCacheManager:(NSObject <ObjectCacheManagerProtocol> *)cacheManager {
    NSParameterAssert([self conformsToProtocol:@protocol(ObjectDictionaryProtocol)]);
    NSParameterAssert([self respondsToSelector:@selector(objectIdFieldName)] ||
                      [self respondsToSelector:@selector(objectIdFromDict:)]);
    if (![self isValidModelDict:dict]) {
        return nil;
    }
    
    NSString *objectId = [self objectIdFromDict:dict];
    if (!objectId.length > 0) {
        return nil;
    }
    
    Class c = [self classFromDict:dict];
    if (![c isSubclassOfClass:[BaseModelObject class]]) {
        return nil;
    }
    
    BaseModelObject *obj = [c objectWithId:objectId
                            inCacheManager:cacheManager];
    
    obj.cacheManager = cacheManager;
    [obj updateWithDictionary:dict];
    
    return obj;
}

+ (id)objectWithId:(NSString *)objectId
    inCacheManager:(NSObject <ObjectCacheManagerProtocol> *)cacheManager {
    
    BaseModelObject *obj =
    (BaseModelObject *)[cacheManager fetchObjectFromCacheWithClass:self.class
                                                             andId:objectId];
    
    if (!obj) {
        obj = [self.class newObjectWithId:objectId];
        
        [cacheManager addObjectToCache:obj];
        
        obj.cacheManager = cacheManager;
    }
    
    NSParameterAssert([obj isKindOfClass:[BaseModelObject class]]);
    
    return obj;
}

+ (id)newObjectWithId:(NSString *)objectId {
    if (objectId.length > 0) {
        BaseModelObject *m = [[self alloc] init];
        m.objectId = objectId;
        NSParameterAssert(m.objectId.length > 0);
        return m;
    }
    return nil;
}

#pragma mark - Temporary Object

+ (instancetype)uncachedObject {
    BaseModelObject *m = [[self.class alloc] init];
    m.isTempObject = YES;
    return m;
}

- (instancetype)uncachedCopy {
    BaseModelObject *m = self.copy;
    m.isTempObject = YES;
    m.cacheManager = nil;
    return m;
}

+ (instancetype)uncachedObjectWithId:(NSString *)objectId {
    BaseModelObject *m = [[self.class alloc] init];
    m.objectId = objectId;
    return m;
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

- (NSArray *)_writeableNamesForClass:(Class)c {
    NSMutableArray *props = [NSMutableArray array];
    unsigned int i;
    objc_property_t *properties = class_copyPropertyList(c, &i);
    for (unsigned int ii = 0; ii < i; ii++) {
        objc_property_t property = properties[ii];
        
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        
        const char *pa = property_getAttributes(property);
        NSString *propType = [NSString stringWithUTF8String:pa];
        if ([propType rangeOfString:@"R"].location == NSNotFound) {
            [props addObject:name];
        }
    }
    
    free(properties);
    
    return props;
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


- (NSArray *)writeablePropertyNames {
    NSMutableArray *properties = [NSMutableArray array];
    Class c = self.class;
    while (YES) {
        [properties addObjectsFromArray:[self _writeableNamesForClass:c]];
        if (c == [BaseModelObject class]) {
            break;
        }
        c = c.superclass;
    }
    return properties.copy;
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

#pragma mark - NSCopying

- (void)encodeWithCoder:(NSCoder *)aCoder {
    for (NSString *propName in self.writeablePropertyNames) {
        NSObject *obj = [self valueForKey:propName];
        
        if ([obj conformsToProtocol:@protocol(NSCopying)]) {
            
            if ([obj conformsToProtocol:@protocol(ObjectArchivingProtocol)] &&
                ((NSObject<ObjectArchivingProtocol> *)obj).archiveUniquely) {
                
                ModelReference *r =
                [ModelReference newObjectWithId:((NSObject <ObjectIdProtocol> *)obj).objectId];
                r.className = NSStringFromClass(obj.class);
                
                [aCoder encodeObject:r
                              forKey:propName];
            }
            else {
                [aCoder encodeObject:obj
                              forKey:propName];
            }
        }
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    for (NSString *propName in self.writeablePropertyNames) {
        
        NSObject *obj = [aDecoder decodeObjectForKey:propName];
        if (obj) {
            if ([obj isKindOfClass:[ModelReference class]]) {
                ModelReference *mObj = (ModelReference *)obj;
                Class c = NSClassFromString(mObj.className);
                BaseModelObject *bm = [c objectWithId:mObj.objectId
                                       inCacheManager:self.cacheManager];
                [self setValue:bm
                    forKeyPath:propName];
            }
            else {
                [self setValue:obj
                        forKey:propName];
            }
        }
    }
    return self;
}


- (instancetype)copyWithZone:(NSZone *)zone {
    BaseModelObject *bm = [[self.class alloc] init];
    
    for (NSString *propName in self.writeablePropertyNames) {
        id prop = [self valueForKey:propName];
        if ([prop conformsToProtocol:@protocol(NSCopying)]) {
            [bm setValue:[prop copyWithZone:zone]
                  forKey:propName];
        };
    }
    return bm;
}

@end
