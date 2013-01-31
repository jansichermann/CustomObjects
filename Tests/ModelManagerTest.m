//
//  ModelManagerTest.m
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

#import "ModelManagerTest.h"
#import "ModelManager.h"
#import "BaseModelObject.h"

@interface ModelManagerTest ()
@property (nonatomic) BaseModelObject *uncachedBaseModel;
@end

@implementation ModelManagerTest

static NSString * const objectId = @"randomHashIDString";

- (void)setUp {
    self.uncachedBaseModel = [self modelObject];
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (BaseModelObject *)modelObject {
    NSDictionary *baseModelDict = @{
    @"id" : objectId};
    return [BaseModelObject withDictionary:baseModelDict cached:NO];
}

- (BOOL)cacheHasObjectWithClass:(Class)class andId:(NSString *)objectId {
    id object = [[ModelManager shared] fetchObjectFromCacheWithClass:[BaseModelObject class] andId:objectId];
    return object != nil;
}

- (void)testCacheAddition {
    STAssertNotNil(self.uncachedBaseModel, @"expected object to not be nil");
    
    STAssertEquals([self cacheHasObjectWithClass:[BaseModelObject class] andId:objectId], NO, @"expected cache to not contain object");
    
    [[ModelManager shared] addObjectToCache:self.uncachedBaseModel];
    
    STAssertEquals([self cacheHasObjectWithClass:[BaseModelObject class] andId:objectId], YES, @"expected cache to contain object");
}

- (void)testCacheDeletion {
    [self testCacheAddition];
    
    [[ModelManager shared] removeObjectFromCache:self.uncachedBaseModel];
    
    STAssertEquals([self cacheHasObjectWithClass:[BaseModelObject class] andId:objectId], NO, @"expected cache to not contain object");
}

- (void)testCachePersistance {
    // TODO!
}

@end
