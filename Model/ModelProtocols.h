@protocol ObjectDictionaryProtocol <NSObject>

@optional
+ (NSString *)objectIdFromDict:(NSDictionary *)dict;
+ (NSString *)objectIdFieldName;
+ (Class)classFromDict:(NSDictionary *)dict;

@end



@protocol ObjectIdProtocol <NSObject>

- (NSString *)objectId;

@end



@protocol ObjectCacheManagerProtocol <NSObject>

- (void)addObjectToCache:(NSObject <ObjectIdProtocol> *)object;
- (void)removeObjectFromCache:(NSObject <ObjectIdProtocol> *)object;
- (NSObject <ObjectIdProtocol> *)fetchObjectFromCacheWithClass:(Class)c
                                                         andId:(NSString *)objectId;

@optional
- (void)clearCache;

@end
