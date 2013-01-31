//
//  BaseModelTest.m
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

#import "BaseModelTest.h"
#import "BaseModelObject.h"
#import "ModelManager.h"

@implementation BaseModelTest

static NSString * const objectId = @"cvnxiuhwr98py7fgdkhl";

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    
    [super tearDown];
}

- (void)testModelSetup {
    STAssertNotNil([BaseModelObject withDictionary:[self objectDictionary] cached:YES], @"BaseModel setup failed");
}

- (NSDictionary *)objectDictionary {
    return @{
    @"id" : objectId
    };
}

- (void)testCacheCollision {
    BaseModelObject *objA = [BaseModelObject withDictionary:[self objectDictionary] cached:YES];
    BaseModelObject *objB = [[ModelManager shared] fetchObjectFromCacheWithClass:[BaseModelObject class] andId:objectId];
    STAssertEquals(objA, objB, @"expected objA pointer to equal objB pointer");
    
    BaseModelObject *objC = [BaseModelObject withDictionary:[self objectDictionary] cached:YES];
    STAssertEquals(objA, objC, @"expected objA pointer to equal objC pointer");
    
    BaseModelObject *objD = [BaseModelObject objectWithId:objectId cached:YES];
    STAssertEquals(objA, objD, @"expected objA pointer to equal objD pointer");
    
    BaseModelObject *objE = [BaseModelObject withDictionary:[self objectDictionary] cached:NO];
    STAssertTrue(objA != objE, @"expected objA pointer to not equal objE pointer");
    
    BaseModelObject *objF = [BaseModelObject objectWithId:objectId cached:YES];
    STAssertTrue(objA != objF, @"expected objA pointer to not equal objF pointer");
}

- (void)testCacheSetting {
    BaseModelObject *objA = [BaseModelObject withDictionary:[self objectDictionary] cached:YES];
    STAssertTrue([objA shouldCacheModel], @"expected model to be cached");
    
    BaseModelObject *objB = [BaseModelObject withDictionary:[self objectDictionary] cached:NO];
    STAssertFalse([objB shouldCacheModel], @"expected model to not be cached");
    
    objB.shouldCacheModel = YES;
    STAssertTrue([objB shouldCacheModel], @"expected model to be cached");
}

@end
