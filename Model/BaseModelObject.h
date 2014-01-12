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

#pragma mark - BaseModel Protocols

@protocol ObjectIdProtocol <NSObject>
- (NSString *)objectId;
@end


#pragma mark - BaseModel Interface

@interface BaseModelObject : NSObject <ObjectIdProtocol>


MODEL_SINGLE_PROPERTY_H_INTERFACE(NSString, objectId);



#pragma mark - Initialization
+ (id)newObjectWithId:(NSString *)objectId;
+ (id)objectWithId:(NSString *)objectId;
+ (id)withDictionary:(NSDictionary *)dict;


#pragma mark - Object updating
- (BOOL)updateWithDictionary:(NSDictionary *)dict;
+ (NSString *)objectIdFieldName;

#pragma mark - NSCoding
- (void)encodeWithCoder:(NSCoder *)encoder;
- (BaseModelObject *)initWithCoder:(NSCoder *)decoder;


#pragma mark - Caching behavior

- (void)persistToPath:(NSString *)path;
+ (id)loadFromPath:(NSString *)path;


#pragma mark - Debugging and Testing
+ (NSMutableDictionary *)modelTestDictionary;
@end