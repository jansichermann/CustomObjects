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



#pragma mark - Interface Extensions
@interface ModelManager ()
- (BaseModelObject *)_fetchObjectFromCacheWithClass:(Class)class andId:(NSString *)objectId;
- (void)_addObjectToCache:(BaseModelObject *)object;
- (void)_removeObjectFromCache:(BaseModelObject *)object;
- (NSCache *)cacheForClass:(Class)class;
- (NSString *)stringNameForClass:(Class)class;
- (NSCache *)createCacheForClass:(Class)class;
- (NSMutableSet *)idSetForClass:(Class)class;
- (void)removeObjectFromReferenceWithClass:(Class)class andId:(NSString *)objectId;
- (void)addObjectToDiskCacheIdSetWithObjectId:(NSString *)objectId andClassName:(NSString *)className;
- (NSMutableDictionary *)diskCacheIds;
- (NSString *)pathForObject:(BaseModelObject *)object;
- (NSString *)pathForClass:(Class)class andObjectId:(NSString *)objectId;
@end




@implementation ModelManagerTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}


+ (BaseModelObject *)testModelObject {
    return [BaseModelObject withDictionary:[BaseModelObject modelTestDictionary] cached:YES];
}


- (BOOL)cacheHasObjectWithClass:(Class)class andId:(NSString *)objectId {
    id object = [[ModelManager shared] fetchObjectFromCacheWithClass:[BaseModelObject class] andId:objectId];
    return object != nil;
}

- (void)testModelManagerSingleton {
    STAssertNoThrow([ModelManager shared], @"expected to be able to get a pointer to modelManager");
    STAssertEquals([ModelManager shared], [ModelManager shared], @"expected singleton pointers to equal");
}

- (void)testAddObjectToCache {
    STAssertNoThrow([[ModelManager shared] _addObjectToCache:[BaseModelObject withDictionary:[BaseModelObject modelTestDictionary] cached:NO]], @"expected to be able to add object to cache");
    STAssertTrue([[[ModelManager shared] idSetForClass:[BaseModelObject class]] containsObject:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected id to be in ref set");
    STAssertNotNil([[ModelManager shared] _fetchObjectFromCacheWithClass:[BaseModelObject class] andId:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected object to be in cache");
}

- (void)testCacheClearance {
    STAssertNoThrow([[ModelManager shared] _addObjectToCache:[BaseModelObject withDictionary:[BaseModelObject modelTestDictionary] cached:YES]], @"expected model to be inserted into cache");
    STAssertNotNil([[ModelManager shared] _fetchObjectFromCacheWithClass:[BaseModelObject class] andId:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected object in cache");
    STAssertNoThrow([[ModelManager shared] clearCache], @"expected to be able to clear cache");
    STAssertNil([[ModelManager shared] _fetchObjectFromCacheWithClass:[BaseModelObject class] andId:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected object to no longer be in cache");
}

- (void)testCacheCreation {
    STAssertNil([[ModelManager shared] createCacheForClass:nil], @"expected nil class to return nil");
    NSCache *cache = [[ModelManager shared] createCacheForClass:[BaseModelObject class]];
    STAssertNotNil(cache, @"expected a cache back");
    STAssertEqualObjects(cache.class, [NSCache class], @"expected the returned object to be of type NSCache");
}

- (void)testStringNameForClass {
    STAssertEqualObjects([[ModelManager shared] stringNameForClass:[BaseModelObject class]], NSStringFromClass([BaseModelObject class]), @"expected stringNameForClass to return BaseModelObject");
}

- (void)testCacheForClass {
    STAssertNoThrow([[ModelManager shared] createCacheForClass:[BaseModelObject class]], @"expected to be able to create cache");
    STAssertNotNil([[ModelManager shared] cacheForClass:[BaseModelObject class]], @"expected to return not nil");
    STAssertEqualObjects([[[ModelManager shared] cacheForClass:[BaseModelObject class]] class], [NSCache class] , @"expected object returned to be of type class");
}

- (void)testRemoveObjectFromCache {
    [self.class testModelObject];
    STAssertNoThrow([[ModelManager shared] _removeObjectFromCache:[BaseModelObject withDictionary:[BaseModelObject modelTestDictionary] cached:YES]], @"expected to be able to remove object from cache");
}

- (void)testIdSetForClass {
    STAssertNil([[ModelManager shared] idSetForClass:nil], @"expected nil object");
    [[ModelManager shared] createCacheForClass:[BaseModelObject class]];
    STAssertNotNil([[ModelManager shared] idSetForClass:[BaseModelObject class]], @"expected valid reference set for class");
}

- (void)testRemoveObjectFromReference {
    [[ModelManager shared] createCacheForClass:[BaseModelObject class]];
    NSMutableSet *set = [[ModelManager shared] idSetForClass:[BaseModelObject class]];
    [set addObject:[BaseModelObject modelTestDictionary][kBaseModelIdKey]];
    STAssertEquals([[ModelManager shared] idSetForClass:[BaseModelObject class]], set, @"expected to have a pointer to the same idset");
    STAssertTrue([set containsObject:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected id of object to be in reference set");
    STAssertNoThrow( [[ModelManager shared] removeObjectFromReferenceWithClass:[BaseModelObject class] andId:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected to be able to remove object from set");
    STAssertFalse([set containsObject:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected id of object to be in reference set");
}

- (void)testAddObjectToCacheNoId {
    STAssertThrows([[ModelManager shared] addObjectToCache:nil], @"expected exception because of no id");
}

- (void)testAddObjectToDiskCacheIdSetWithObjectId {
    STAssertNoThrow([[ModelManager shared] addObjectToDiskCacheIdSetWithObjectId:[BaseModelObject modelTestDictionary][kBaseModelIdKey] andClassName:[[ModelManager shared] stringNameForClass:[BaseModelObject class]]], @"expected to be able to add objectId to diskIdSet");
    STAssertTrue( [[[[ModelManager shared] diskCacheIds] objectForKey:[[ModelManager shared] stringNameForClass:[BaseModelObject class]]] containsObject:[BaseModelObject modelTestDictionary][kBaseModelIdKey]], @"expected diskIds to contain objectId");
}

- (void)testPathForObject {
    STAssertNil([[ModelManager shared] pathForClass:nil andObjectId:nil], @"expected nil return for nil objectId");
    STAssertNil([[ModelManager shared] pathForObject:nil], @"expected nil return for nil object");
    STAssertEqualObjects([[ModelManager shared] pathForObject:[BaseModelObject withDictionary:[BaseModelObject modelTestDictionary] cached:YES]],
                   [[ModelManager shared] pathForClass:[BaseModelObject class] andObjectId:[BaseModelObject modelTestDictionary][kBaseModelIdKey]],
                   @"expected paths to equal");
}

@end
