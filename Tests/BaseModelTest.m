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

- (void)testModelSetup {
    STAssertNotNil([BaseModelObject withDictionary:[BaseModelObject modelTestDictionary] cached:YES], @"BaseModel setup failed");
}

- (void)testCacheCollision {
    NSDictionary *d = [BaseModelObject modelTestDictionary];
    BaseModelObject *objA = [BaseModelObject withDictionary:d cached:YES];
    BaseModelObject *objB = [[ModelManager shared] fetchObjectFromCacheWithClass:[BaseModelObject class] andId:d[kBaseModelIdKey]];
    STAssertEquals(objA, objB, @"expected objA pointer to equal objB pointer");
    
    BaseModelObject *objC = [BaseModelObject withDictionary:d cached:YES];
    STAssertEquals(objA, objC, @"expected objA pointer to equal objC pointer");
    
    BaseModelObject *objD = [BaseModelObject objectWithId:d[kBaseModelIdKey] cached:YES];
    STAssertEquals(objA, objD, @"expected objA pointer to equal objD pointer");
    
    BaseModelObject *objE = [BaseModelObject withDictionary:d cached:NO];
    STAssertTrue(objA != objE, @"expected objA pointer to not equal objE pointer");
    
    BaseModelObject *objF = [BaseModelObject objectWithId:d[kBaseModelIdKey] cached:YES];
    STAssertTrue(objA != objF, @"expected objA pointer to not equal objF pointer");
}

- (void)testCacheSetting {
    NSDictionary *d = [BaseModelObject modelTestDictionary];
    BaseModelObject *objA = [BaseModelObject withDictionary:d cached:YES];
    STAssertTrue([objA shouldCacheModel], @"expected model to be cached");
    
    BaseModelObject *objB = [BaseModelObject withDictionary:d cached:NO];
    STAssertFalse([objB shouldCacheModel], @"expected model to not be cached");
    
    STAssertNoThrow([objB setShouldCacheModel: ModelCachingAlways], @"expected to be able to set caching behavior");
    STAssertTrue([objB shouldCacheModel], @"expected model to be cached");
}

- (void)testExceptions {
    STAssertThrows([BaseModelObject objectWithId:nil cached:YES], @"expected an exception on nil id object");
}

- (void)testNewObject {
    STAssertNoThrow([BaseModelObject newObjectWithId:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected no exception on newObjectWithId:");
}

- (void)testNilObjectId {
    STAssertNil([BaseModelObject newObjectWithId:nil], @"Expected Nil Object to be returned");
}

- (void)testNilObjectIdException {
    STAssertThrows([BaseModelObject objectWithId:nil cached:YES], @"Expected modelObjectNoIdException");
}

- (void)testUpdateWithDictionaryNil {
    BaseModelObject *bm = [[BaseModelObject alloc] init];
    STAssertFalse([bm updateWithDictionary:@{}], @"Expected to return NO");
}

- (void)testSetShouldCacheWithoutId {
    BaseModelObject *bm = [[BaseModelObject alloc] init];
    STAssertThrows([bm setShouldCacheModel:ModelCachingAlways], @"Expected to throw on no id");
}

- (void)testShouldPersistModel {
    NSDictionary *d = [BaseModelObject modelTestDictionary];
    BaseModelObject *bm = [BaseModelObject withDictionary:d cached:YES];
    STAssertTrue([bm shouldPersistModelObject], @"Expected model to be persistable");
    bm.shouldCacheModel = ModelCachingNever;
    STAssertFalse([bm shouldPersistModelObject], @"Expected model to not be persistable");
}

@end
