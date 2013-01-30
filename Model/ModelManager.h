//
//  ModelManager.h
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

@class BaseModelObject;

@interface ModelManager : NSObject <NSCacheDelegate>

SHARED_SINGLETON_HEADER(ModelManager);

// can be queried to gain insight into whether a persist operation
// is about to be, or currently being executed
@property (readonly) BOOL persistScheduled;

- (void)removeObjectFromCache:(BaseModelObject *)object;
- (void)addObjectToCache:(BaseModelObject *)object;

- (BaseModelObject *)fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId;
- (BaseModelObject *)fetchObjectFromDiskWithClass:(Class)class andId:(NSString *)objectId;


- (NSArray *)cacheNames;
- (void)persist;
- (void)wipeDiskCache;


// this should only be used for unit-testing and debug
// clearing the cache does not have any
// influence on pointers held to objects
- (void)clearCache;
@end
