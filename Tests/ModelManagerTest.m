//
//  ModelManagerTest.m
//  agents
//
//  Created by Jan on 1/30/13.
//  Copyright (c) 2013 Urban Compass. All rights reserved.
//

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
