//
//  BaseModelObject.h
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


#import <Foundation/Foundation.h>
#import "ModelMacros.h"
#import "ModelProtocols.h"


#pragma mark - BaseModel Interface

@interface BaseModelObject : NSObject
<
ObjectIdProtocol,
ObjectDictionaryProtocol,
NSCopying
>

@property (nonatomic, weak, readonly) NSObject<ObjectCacheManagerProtocol> *cacheManager;

+ (instancetype)withDict:(NSDictionary *)dict
          inCacheManager:(NSObject <ObjectCacheManagerProtocol> *)cacheManager;

#pragma mark - Initialization
+ (id)newObjectWithId:(NSString *)objectId;
+ (instancetype)newObjectWithDictionary:(NSDictionary *)dict
                         inCacheManager:(NSObject<ObjectCacheManagerProtocol> *)cacheManager;


#pragma mark - Object updating
- (BOOL)updateWithDictionary:(NSDictionary *)dict;
+ (NSString *)objectIdFieldName;


#pragma mark - Temporary Object
+ (instancetype)uncachedObject;
- (instancetype)uncachedCopy;

@end