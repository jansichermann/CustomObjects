@protocol ObjectDictionaryProtocol <NSObject>

@optional
+ (NSString *)objectIdFromDict:(NSDictionary *)dict;
+ (NSString *)objectIdFieldName;
+ (Class)classFromDict:(NSDictionary *)dict __attribute__((pure));
+ (BOOL)isValidModelDict:(NSDictionary *)dict;

@end



@protocol ObjectArchivingProtocol <NSObject>

- (BOOL)archiveUniquely;

@end



@protocol ObjectIdProtocol <NSObject>

- (NSString *)objectId;
- (BOOL)isTempObject;

@end




@protocol PersistanceProtocol <NSObject>

- (void)js__persistToPath:(NSString *)path;
+ (instancetype)js__loadFromPath:(NSString *)path;

@end




@protocol ObjectCacheManagerProtocol <NSObject>

- (void)addObjectToCache:(NSObject <ObjectIdProtocol> *)object;
- (void)removeObjectFromCache:(NSObject <ObjectIdProtocol> *)object;
- (NSObject <ObjectIdProtocol> *)fetchObjectFromCacheWithClass:(Class)c
                                                         andId:(NSString *)objectId;

@optional
- (void)clearCache;

@end

@protocol CacheableObjectProtocol <NSObject>

+ (NSString *)cacheKeyForId:(NSString *)objectId;
- (NSString *)cacheKey;

@optional
- (void)setCacheManager:(NSObject<ObjectCacheManagerProtocol> *)cacheManager;

@end
