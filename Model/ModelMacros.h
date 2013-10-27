//
//  ModelMacros.h
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


// SINGLETON
#define SHARED_SINGLETON_HEADER(_class) \
+ (_class *)shared;

#define SHARED_SINGLETON_IMPLEMENTATION(_class) \
+ (_class *)shared { \
    static dispatch_once_t once; \
    static _class *sharedInstance = nil; \
    dispatch_once(&once, ^{ \
        sharedInstance = [[self alloc] init]; \
    }); \
    return sharedInstance; \
}


#define WEAK(_obj) \
__weak __typeof__(_obj) weak_ ## _obj = _obj


//
// MODEL
//

// variable setting
#define SET_NONPRIMITIVE_IF_VAL_NOT_NIL(_class, _var, _value) \
if ([_value isKindOfClass:_class]) { \
    _var = _value; \
}

#define ADD_TO_DICT_IF_MISSING(_dict, _key, _value) \
if ([_dict objectForKey:_key] == nil && _value != nil) { \
    [_dict setValue:_value forKey:_key]; \
}

// single property
#define MODEL_SINGLE_PROPERTY_H_RW_INTERFACE(_class, _name) \
@property(nonatomic) _class *_name;

#define MODEL_SINGLE_PROPERTY_H_INTERFACE(_class, _name) \
@property(nonatomic, readonly) _class *_name;

#define MODEL_SINGLE_PROPERTY_M_INTERFACE(_class, _name) \
@property(nonatomic, readwrite) _class *_name;

#define MODEL_SINGLE_PROPERTY_INT_H_RW_INTERFACE(_name) \
@property (nonatomic) int _name;

#define MODEL_SINGLE_PROPERTY_FLOAT_H_RW_INTERFACE(_name) \
@property (nonatomic) float _name;

#define MODEL_SINGLE_PROPERTY_DOUBLE_H_RW_INTERFACE(_name) \
@property (nonatomic) double _name;

// single relation

#define MODEL_SINGLE_RELATION_H_INTERFACE(_class, _name) \
@property (nonatomic, weak) _class *_name; \
@property (nonatomic, readonly) NSString *_name ## Id;

#define MODEL_SINGLE_RELATION_M_INTERFACE(_class, _name) \
@property (nonatomic, readwrite) NSString *_name ## Id;

#define MODEL_SINGLE_RELATION_M_IMPLEMENTATION(_class, _name, _Name) \
@synthesize _name = _ ## _name; \
- (void)set ## _Name:(_class *) object { \
    if ( object.objectId != nil && object.objectId.length) { \
        self._name ## Id = object.objectId; \
        _ ## _name = object; \
    } \
} \
\
- (_class *)_name { \
if (self._name ## Id == nil || self._name ## Id.length < 1) return nil; \
if (_ ## _name == nil) { \
    _ ## _name = (_class *)[[ModelManager shared] fetchObjectFromCacheWithClass:[_class class] andId:self._name ## Id]; \
} \
if (_ ## _name == nil && self._name ## Id != nil) { \
    _ ## _name = (_class *)[[ModelManager shared] fetchObjectFromDiskWithClass:[_class class] andId:self._name ## Id]; \
} \
if (_ ## _name == nil && self._name ## Id != nil) { \
    _ ## _name = (_class *)[self.class objectWithId:self._name ## Id cached:[self shouldCacheModelObject]]; \
} \
return _ ## _name; \
}



// multi relation

#define MODEL_MULTI_RELATION_H_INTERFACE(_class, _name, _Name) \
- (NSArray *)_name; \
- (void)add ## _Name ## Object:(_class *)object; \
- (void)remove ## _Name ## Object:(_class *)object; \
- (void)set ## _Name:(NSArray *)objects;

#define MODEL_MULTI_RELATION_M_INTERFACE(_class, _name) \
@property (nonatomic) NSMutableOrderedSet *_name ## Ids; \
@property (nonatomic) NSMutableOrderedSet *_name ## OrderedMutableSet;

#define MODEL_MULTI_RELATION_M_IMPLEMENTATION(_class, _name, _Name) \
- (NSArray *)_name { \
    if (self._name ## Ids == nil || self._name ## Ids.count < 1) return nil; \
    if (self._name ## OrderedMutableSet.count != self._name ## Ids.count || self._name ## OrderedMutableSet == nil) { \
        self._name ## OrderedMutableSet = [NSMutableOrderedSet orderedSet]; \
        for (NSString *objectId in self._name ## Ids) { \
            [self._name ## OrderedMutableSet addObject: [_class objectWithId:objectId cached:[self shouldCacheModelObject]] ]; \
        } \
    } \
    return self._name ## OrderedMutableSet.array; \
} \
- (void)add ## _Name ## Object:(_class *)object { \
    if (self._name ## Ids == nil) { \
        self._name ## Ids = [NSMutableOrderedSet orderedSet]; \
    } \
    [self._name ## Ids addObject:object.objectId]; \
    [self._name ## OrderedMutableSet addObject: object]; \
} \
- (void)remove ## _Name ## Object:(_class *)object { \
    [self._name ## Ids removeObject:object.objectId]; \
    [self._name ## OrderedMutableSet removeObject: object]; \
} \
- (void)set ## _Name:(NSArray *)objects { \
    if (self._name ## Ids == nil) { \
        self._name ## Ids = [NSMutableOrderedSet orderedSet]; \
    } \
    for (id<ObjectIdProtocol> object in objects) { \
        if (![object conformsToProtocol:@protocol(ObjectIdProtocol)]) { \
[[NSException exceptionWithName:@"Object Conformity" reason:[NSString stringWithFormat:@"Expected object of type %@ to conform to <ObjectIdProtocol>", NSStringFromClass([object class])] userInfo:nil] raise]; \
            continue; \
        } \
        [self._name ## Ids addObject:object.objectId]; \
        [self._name ## OrderedMutableSet addObject:object]; \
    } \
}



// NSCoding

#define DECODE_IF_CLASS_CONSISTENCY(_var, _keyName) \
if ([_var isKindOfClass:[[decoder decodeObjectForKey:_keyName] class]]) { \
_var = [decoder decodeObjectForKey:_keyName]; \
}

#define ENCODE_OBJECT(_var, _keyName) \
[encoder encodeObject:_var forKey:_keyName];

#define ENCODE_INT(_var, _keyName) \
[encoder encodeInteger:_var forKey:_keyName];

#define DECODE_INT(_var, _keyName) \
_var = [decoder decodeIntegerForKey:_keyName];

