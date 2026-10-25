#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@class SorawalletExtrinsicParam, SorawalletExtrinsics, SorawalletSignerInfo, SorawalletSoraHistoryDatabaseCompanion, SorawalletRuntimeQuery<__covariant RowType>, SorawalletResponsePageInfoCompanion, SorawalletResponsePageInfo, SorawalletUtils, SorawalletKotlinx_serialization_jsonJson, SorawalletWebSocketClientConfig, SorawalletNetworkClientConfig, SorawalletKtor_client_coreHttpClient, SorawalletKtor_httpHttpMethod, SorawalletKotlinPair<__covariant A, __covariant B>, SorawalletKtor_httpContentType, SorawalletKtor_client_coreHttpResponse, SorawalletKotlinThrowable, SorawalletKotlinArray<T>, SorawalletDatabaseDriverFactory, SorawalletHistoryMapper, SorawalletTxHistoryItemNested, SorawalletTxHistoryItem, SorawalletTxHistoryInfo, SorawalletTxHistoryItemParam, SorawalletSoramitsuNetworkClient, SorawalletHistoryDatabaseProvider, SorawalletTxHistoryResult<R>, SorawalletSubQueryClient<T, R>, SorawalletSubQueryRequestCompanion, SorawalletSubQueryRequest, SorawalletErrorCompanion, SorawalletError, SorawalletExecutionResultCompanion, SorawalletExecutionResult, SorawalletHistoryResponseItem, SorawalletHistoryResponseDataElementsCompanion, SorawalletHistoryResponseDataElements, SorawalletKotlinx_serialization_jsonJsonElement, SorawalletHistoryResponseItemCompanion, SorawalletSoraSubQueryResponseData, SorawalletSoraSubQueryResponseCompanion, SorawalletSoraSubQueryResponse, SorawalletSoraSubQueryResponseDataCompanion, SorawalletSoraWalletSubQueryHistoryMapper, SorawalletSoraRemoteConfigBuilder, SorawalletSubQueryClientForSoraWallet, SorawalletSoraTokenWhitelistDto, SorawalletSoraTokensWhitelistManagerCompanion, SorawalletConfigExplorerType, SorawalletSoraConfigNode, SorawalletSoraCurrency, SorawalletSoraConfig, SorawalletAssetsInfo, SorawalletFiatData, SorawalletReferrerRewardsInfo, SorawalletSbApyInfo, SorawalletSoraWalletFiatCase2ResponseData, SorawalletSoraWalletFiatCase2ResponseCompanion, SorawalletSoraWalletFiatCase2Response, SorawalletSoraWalletFiatCase2ResponseDataEntities, SorawalletSoraWalletFiatCase2ResponseDataCompanion, SorawalletSoraWalletFiatCase2ResponseDataEntitiesNode, SorawalletSoraWalletFiatCase2ResponseDataEntitiesCompanion, SorawalletSoraWalletFiatCase2ResponseDataEntitiesNodeCompanion, SorawalletSoraWalletAssetsCase0ResponseData, SorawalletSoraWalletAssetsCase0ResponseCompanion, SorawalletSoraWalletAssetsCase0Response, SorawalletSoraWalletAssetsCase0ResponseDataEntities, SorawalletSoraWalletAssetsCase0ResponseDataCompanion, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNode, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesCompanion, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHour, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeCompanion, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourCompanion, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodeCompanion, SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePriceCompanion, SorawalletSoraWalletAssetsCase1ResponseData, SorawalletSoraWalletAssetsCase1ResponseCompanion, SorawalletSoraWalletAssetsCase1Response, SorawalletSoraWalletAssetsCase1ResponseDataEntities, SorawalletSoraWalletAssetsCase1ResponseDataCompanion, SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNode, SorawalletSoraWalletAssetsCase1ResponseDataEntitiesCompanion, SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHour, SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeCompanion, SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHourCompanion, SorawalletReferrerReward, SorawalletSoraWalletReferrerCase1ResponseData, SorawalletSoraWalletReferrerCase1ResponseCompanion, SorawalletSoraWalletReferrerCase1Response, SorawalletSoraWalletReferrerCase1ResponseDataRewards, SorawalletSoraWalletReferrerCase1ResponseDataCompanion, SorawalletSoraWalletReferrerCase1ResponseDataRewardsNode, SorawalletSoraWalletReferrerCase1ResponseDataRewardsCompanion, SorawalletSoraWalletReferrerCase1ResponseDataRewardsNodeCompanion, SorawalletSoraWalletSbApyCase2ResponseData, SorawalletSoraWalletSbApyCase2ResponseCompanion, SorawalletSoraWalletSbApyCase2Response, SorawalletSoraWalletSbApyCase2ResponseDataEntities, SorawalletSoraWalletSbApyCase2ResponseDataCompanion, SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNode, SorawalletSoraWalletSbApyCase2ResponseDataEntitiesCompanion, SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNodeCompanion, SorawalletKotlinByteArray, SorawalletRuntimeTransacterTransaction, SorawalletKtor_client_coreHttpClientEngineConfig, SorawalletKotlinx_serialization_coreSerializersModule, SorawalletKotlinx_serialization_jsonJsonDefault, SorawalletKotlinx_serialization_jsonJsonConfiguration, SorawalletKtor_client_coreHttpClientConfig<T>, SorawalletKtor_eventsEvents, SorawalletKtor_client_coreHttpReceivePipeline, SorawalletKtor_client_coreHttpRequestPipeline, SorawalletKtor_client_coreHttpResponsePipeline, SorawalletKtor_client_coreHttpSendPipeline, SorawalletKotlinException, SorawalletKotlinRuntimeException, SorawalletKotlinIllegalStateException, SorawalletKtor_httpHttpMethodCompanion, SorawalletKtor_httpHeaderValueParam, SorawalletKtor_httpHeaderValueWithParametersCompanion, SorawalletKtor_httpHeaderValueWithParameters, SorawalletKtor_httpContentTypeCompanion, SorawalletKtor_client_coreHttpClientCall, SorawalletKtor_utilsGMTDate, SorawalletKtor_httpHttpStatusCode, SorawalletKtor_httpHttpProtocolVersion, SorawalletKotlinx_serialization_jsonJsonElementCompanion, SorawalletKotlinByteIterator, SorawalletKotlinx_serialization_coreSerialKind, SorawalletKotlinNothing, SorawalletKtor_client_coreHttpRequestData, SorawalletKtor_client_coreHttpResponseData, SorawalletKotlinx_coroutines_coreCoroutineDispatcher, SorawalletKtor_client_coreProxyConfig, SorawalletKtor_utilsAttributeKey<T>, SorawalletKtor_eventsEventDefinition<T>, SorawalletKtor_utilsPipelinePhase, SorawalletKtor_utilsPipeline<TSubject, TContext>, SorawalletKtor_client_coreHttpReceivePipelinePhases, SorawalletKotlinUnit, SorawalletKtor_client_coreHttpRequestPipelinePhases, SorawalletKtor_client_coreHttpRequestBuilder, SorawalletKtor_client_coreHttpResponsePipelinePhases, SorawalletKtor_client_coreHttpResponseContainer, SorawalletKtor_client_coreHttpSendPipelinePhases, SorawalletKtor_client_coreHttpClientCallCompanion, SorawalletKtor_utilsTypeInfo, SorawalletKtor_ioMemory, SorawalletKtor_ioChunkBuffer, SorawalletKtor_ioBuffer, SorawalletKtor_ioByteReadPacket, SorawalletKtor_utilsGMTDateCompanion, SorawalletKtor_utilsWeekDay, SorawalletKtor_utilsMonth, SorawalletKtor_httpHttpStatusCodeCompanion, SorawalletKtor_httpHttpProtocolVersionCompanion, SorawalletKtor_httpUrl, SorawalletKtor_httpOutgoingContent, SorawalletKotlinAbstractCoroutineContextElement, SorawalletKotlinx_coroutines_coreCoroutineDispatcherKey, SorawalletKtor_httpHeadersBuilder, SorawalletKtor_client_coreHttpRequestBuilderCompanion, SorawalletKtor_httpURLBuilder, SorawalletKtor_ioMemoryCompanion, SorawalletKtor_ioBufferCompanion, SorawalletKtor_ioChunkBufferCompanion, SorawalletKtor_ioInputCompanion, SorawalletKtor_ioInput, SorawalletKtor_ioByteReadPacketCompanion, SorawalletKotlinEnumCompanion, SorawalletKotlinEnum<E>, SorawalletKtor_utilsWeekDayCompanion, SorawalletKtor_utilsMonthCompanion, SorawalletKtor_httpUrlCompanion, SorawalletKtor_httpURLProtocol, SorawalletKotlinCancellationException, SorawalletKotlinAbstractCoroutineContextKey<B, E>, SorawalletKtor_utilsStringValuesBuilderImpl, SorawalletKtor_httpURLBuilderCompanion, SorawalletKotlinKTypeProjection, SorawalletKtor_httpURLProtocolCompanion, SorawalletKotlinKVariance, SorawalletKotlinKTypeProjectionCompanion;

@protocol SorawalletSoraHistoryDatabaseQueries, SorawalletRuntimeTransactionWithoutReturn, SorawalletRuntimeTransactionWithReturn, SorawalletRuntimeTransacter, SorawalletSoraHistoryDatabase, SorawalletRuntimeSqlDriver, SorawalletRuntimeSqlDriverSchema, SorawalletKotlinx_serialization_coreKSerializer, SorawalletKotlinx_coroutines_coreFlow, SorawalletKtor_client_coreHttpClientEngineFactory, SorawalletSoramitsuHttpClientProvider, SorawalletKotlinx_serialization_coreDeserializationStrategy, SorawalletMultiplatform_settingsSettings, SorawalletKtor_httpHeaders, SorawalletRuntimeTransactionCallbacks, SorawalletRuntimeSqlPreparedStatement, SorawalletRuntimeSqlCursor, SorawalletRuntimeCloseable, SorawalletRuntimeQueryListener, SorawalletKotlinx_serialization_coreEncoder, SorawalletKotlinx_serialization_coreSerialDescriptor, SorawalletKotlinx_serialization_coreSerializationStrategy, SorawalletKotlinx_serialization_coreDecoder, SorawalletKotlinx_coroutines_coreFlowCollector, SorawalletKtor_client_coreHttpClientEngine, SorawalletKotlinx_serialization_coreSerialFormat, SorawalletKotlinx_serialization_coreStringFormat, SorawalletKotlinCoroutineContext, SorawalletKotlinx_coroutines_coreCoroutineScope, SorawalletKtor_ioCloseable, SorawalletKtor_client_coreHttpClientEngineCapability, SorawalletKtor_utilsAttributes, SorawalletKtor_httpHttpMessage, SorawalletKtor_ioByteReadChannel, SorawalletKotlinIterator, SorawalletKotlinMapEntry, SorawalletKtor_utilsStringValues, SorawalletKotlinx_serialization_coreCompositeEncoder, SorawalletKotlinAnnotation, SorawalletKotlinx_serialization_coreCompositeDecoder, SorawalletKotlinx_serialization_coreSerializersModuleCollector, SorawalletKotlinKClass, SorawalletKotlinx_serialization_jsonJsonNamingStrategy, SorawalletKotlinCoroutineContextElement, SorawalletKotlinCoroutineContextKey, SorawalletKtor_client_coreHttpClientPlugin, SorawalletKotlinx_coroutines_coreDisposableHandle, SorawalletKotlinSuspendFunction2, SorawalletKtor_client_coreHttpRequest, SorawalletKtor_ioReadSession, SorawalletKotlinSuspendFunction1, SorawalletKotlinAppendable, SorawalletKotlinComparable, SorawalletKotlinx_coroutines_coreJob, SorawalletKotlinContinuation, SorawalletKotlinContinuationInterceptor, SorawalletKotlinx_coroutines_coreRunnable, SorawalletKotlinKDeclarationContainer, SorawalletKotlinKAnnotatedElement, SorawalletKotlinKClassifier, SorawalletKotlinFunction, SorawalletKtor_httpHttpMessageBuilder, SorawalletKotlinKType, SorawalletKtor_ioObjectPool, SorawalletKtor_httpParameters, SorawalletKotlinx_coroutines_coreChildHandle, SorawalletKotlinx_coroutines_coreChildJob, SorawalletKotlinSequence, SorawalletKotlinx_coroutines_coreSelectClause0, SorawalletKtor_utilsStringValuesBuilder, SorawalletKtor_httpParametersBuilder, SorawalletKotlinx_coroutines_coreParentJob, SorawalletKotlinx_coroutines_coreSelectInstance, SorawalletKotlinx_coroutines_coreSelectClause;

NS_ASSUME_NONNULL_BEGIN
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-warning-option"
#pragma clang diagnostic ignored "-Wincompatible-property-type"
#pragma clang diagnostic ignored "-Wnullability"

#pragma push_macro("_Nullable_result")
#if !__has_feature(nullability_nullable_result)
#undef _Nullable_result
#define _Nullable_result _Nullable
#endif

__attribute__((swift_name("KotlinBase")))
@interface SorawalletBase : NSObject
- (instancetype)init __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (void)initialize __attribute__((objc_requires_super));
@end

@interface SorawalletBase (SorawalletBaseCopying) <NSCopying>
@end

__attribute__((swift_name("KotlinMutableSet")))
@interface SorawalletMutableSet<ObjectType> : NSMutableSet<ObjectType>
@end

__attribute__((swift_name("KotlinMutableDictionary")))
@interface SorawalletMutableDictionary<KeyType, ObjectType> : NSMutableDictionary<KeyType, ObjectType>
@end

@interface NSError (NSErrorSorawalletKotlinException)
@property (readonly) id _Nullable kotlinException;
@end

__attribute__((swift_name("KotlinNumber")))
@interface SorawalletNumber : NSNumber
- (instancetype)initWithChar:(char)value __attribute__((unavailable));
- (instancetype)initWithUnsignedChar:(unsigned char)value __attribute__((unavailable));
- (instancetype)initWithShort:(short)value __attribute__((unavailable));
- (instancetype)initWithUnsignedShort:(unsigned short)value __attribute__((unavailable));
- (instancetype)initWithInt:(int)value __attribute__((unavailable));
- (instancetype)initWithUnsignedInt:(unsigned int)value __attribute__((unavailable));
- (instancetype)initWithLong:(long)value __attribute__((unavailable));
- (instancetype)initWithUnsignedLong:(unsigned long)value __attribute__((unavailable));
- (instancetype)initWithLongLong:(long long)value __attribute__((unavailable));
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value __attribute__((unavailable));
- (instancetype)initWithFloat:(float)value __attribute__((unavailable));
- (instancetype)initWithDouble:(double)value __attribute__((unavailable));
- (instancetype)initWithBool:(BOOL)value __attribute__((unavailable));
- (instancetype)initWithInteger:(NSInteger)value __attribute__((unavailable));
- (instancetype)initWithUnsignedInteger:(NSUInteger)value __attribute__((unavailable));
+ (instancetype)numberWithChar:(char)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedChar:(unsigned char)value __attribute__((unavailable));
+ (instancetype)numberWithShort:(short)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedShort:(unsigned short)value __attribute__((unavailable));
+ (instancetype)numberWithInt:(int)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedInt:(unsigned int)value __attribute__((unavailable));
+ (instancetype)numberWithLong:(long)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedLong:(unsigned long)value __attribute__((unavailable));
+ (instancetype)numberWithLongLong:(long long)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value __attribute__((unavailable));
+ (instancetype)numberWithFloat:(float)value __attribute__((unavailable));
+ (instancetype)numberWithDouble:(double)value __attribute__((unavailable));
+ (instancetype)numberWithBool:(BOOL)value __attribute__((unavailable));
+ (instancetype)numberWithInteger:(NSInteger)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedInteger:(NSUInteger)value __attribute__((unavailable));
@end

__attribute__((swift_name("KotlinByte")))
@interface SorawalletByte : SorawalletNumber
- (instancetype)initWithChar:(char)value;
+ (instancetype)numberWithChar:(char)value;
@end

__attribute__((swift_name("KotlinUByte")))
@interface SorawalletUByte : SorawalletNumber
- (instancetype)initWithUnsignedChar:(unsigned char)value;
+ (instancetype)numberWithUnsignedChar:(unsigned char)value;
@end

__attribute__((swift_name("KotlinShort")))
@interface SorawalletShort : SorawalletNumber
- (instancetype)initWithShort:(short)value;
+ (instancetype)numberWithShort:(short)value;
@end

__attribute__((swift_name("KotlinUShort")))
@interface SorawalletUShort : SorawalletNumber
- (instancetype)initWithUnsignedShort:(unsigned short)value;
+ (instancetype)numberWithUnsignedShort:(unsigned short)value;
@end

__attribute__((swift_name("KotlinInt")))
@interface SorawalletInt : SorawalletNumber
- (instancetype)initWithInt:(int)value;
+ (instancetype)numberWithInt:(int)value;
@end

__attribute__((swift_name("KotlinUInt")))
@interface SorawalletUInt : SorawalletNumber
- (instancetype)initWithUnsignedInt:(unsigned int)value;
+ (instancetype)numberWithUnsignedInt:(unsigned int)value;
@end

__attribute__((swift_name("KotlinLong")))
@interface SorawalletLong : SorawalletNumber
- (instancetype)initWithLongLong:(long long)value;
+ (instancetype)numberWithLongLong:(long long)value;
@end

__attribute__((swift_name("KotlinULong")))
@interface SorawalletULong : SorawalletNumber
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value;
@end

__attribute__((swift_name("KotlinFloat")))
@interface SorawalletFloat : SorawalletNumber
- (instancetype)initWithFloat:(float)value;
+ (instancetype)numberWithFloat:(float)value;
@end

__attribute__((swift_name("KotlinDouble")))
@interface SorawalletDouble : SorawalletNumber
- (instancetype)initWithDouble:(double)value;
+ (instancetype)numberWithDouble:(double)value;
@end

__attribute__((swift_name("KotlinBoolean")))
@interface SorawalletBoolean : SorawalletNumber
- (instancetype)initWithBool:(BOOL)value;
+ (instancetype)numberWithBool:(BOOL)value;
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExtrinsicParam")))
@interface SorawalletExtrinsicParam : SorawalletBase
- (instancetype)initWithExtrinsicHash:(NSString *)extrinsicHash paramName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("init(extrinsicHash:paramName:paramValue:)"))) __attribute__((objc_designated_initializer));
- (SorawalletExtrinsicParam *)doCopyExtrinsicHash:(NSString *)extrinsicHash paramName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("doCopy(extrinsicHash:paramName:paramValue:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *extrinsicHash __attribute__((swift_name("extrinsicHash")));
@property (readonly) NSString *paramName __attribute__((swift_name("paramName")));
@property (readonly) NSString *paramValue __attribute__((swift_name("paramValue")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Extrinsics")))
@interface SorawalletExtrinsics : SorawalletBase
- (instancetype)initWithTxHash:(NSString *)txHash signAddress:(NSString *)signAddress blockHash:(NSString * _Nullable)blockHash module:(NSString *)module method:(NSString *)method networkFee:(NSString *)networkFee timestamp:(int64_t)timestamp success:(BOOL)success batch:(BOOL)batch parentHash:(NSString * _Nullable)parentHash networkName:(NSString *)networkName __attribute__((swift_name("init(txHash:signAddress:blockHash:module:method:networkFee:timestamp:success:batch:parentHash:networkName:)"))) __attribute__((objc_designated_initializer));
- (SorawalletExtrinsics *)doCopyTxHash:(NSString *)txHash signAddress:(NSString *)signAddress blockHash:(NSString * _Nullable)blockHash module:(NSString *)module method:(NSString *)method networkFee:(NSString *)networkFee timestamp:(int64_t)timestamp success:(BOOL)success batch:(BOOL)batch parentHash:(NSString * _Nullable)parentHash networkName:(NSString *)networkName __attribute__((swift_name("doCopy(txHash:signAddress:blockHash:module:method:networkFee:timestamp:success:batch:parentHash:networkName:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL batch __attribute__((swift_name("batch")));
@property (readonly) NSString * _Nullable blockHash __attribute__((swift_name("blockHash")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@property (readonly) NSString *networkFee __attribute__((swift_name("networkFee")));
@property (readonly) NSString *networkName __attribute__((swift_name("networkName")));
@property (readonly) NSString * _Nullable parentHash __attribute__((swift_name("parentHash")));
@property (readonly) NSString *signAddress __attribute__((swift_name("signAddress")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));
@property (readonly) NSString *txHash __attribute__((swift_name("txHash")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SignerInfo")))
@interface SorawalletSignerInfo : SorawalletBase
- (instancetype)initWithSignAddress:(NSString *)signAddress topTime:(int64_t)topTime oldTime:(int64_t)oldTime oldCursor:(NSString * _Nullable)oldCursor endReached:(BOOL)endReached networkName:(NSString *)networkName __attribute__((swift_name("init(signAddress:topTime:oldTime:oldCursor:endReached:networkName:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSignerInfo *)doCopySignAddress:(NSString *)signAddress topTime:(int64_t)topTime oldTime:(int64_t)oldTime oldCursor:(NSString * _Nullable)oldCursor endReached:(BOOL)endReached networkName:(NSString *)networkName __attribute__((swift_name("doCopy(signAddress:topTime:oldTime:oldCursor:endReached:networkName:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL endReached __attribute__((swift_name("endReached")));
@property (readonly) NSString *networkName __attribute__((swift_name("networkName")));
@property (readonly) NSString * _Nullable oldCursor __attribute__((swift_name("oldCursor")));
@property (readonly) int64_t oldTime __attribute__((swift_name("oldTime")));
@property (readonly) NSString *signAddress __attribute__((swift_name("signAddress")));
@property (readonly) int64_t topTime __attribute__((swift_name("topTime")));
@end

__attribute__((swift_name("RuntimeTransacter")))
@protocol SorawalletRuntimeTransacter
@required
- (void)transactionNoEnclosing:(BOOL)noEnclosing body:(void (^)(id<SorawalletRuntimeTransactionWithoutReturn>))body __attribute__((swift_name("transaction(noEnclosing:body:)")));
- (id _Nullable)transactionWithResultNoEnclosing:(BOOL)noEnclosing bodyWithReturn:(id _Nullable (^)(id<SorawalletRuntimeTransactionWithReturn>))bodyWithReturn __attribute__((swift_name("transactionWithResult(noEnclosing:bodyWithReturn:)")));
@end

__attribute__((swift_name("SoraHistoryDatabase")))
@protocol SorawalletSoraHistoryDatabase <SorawalletRuntimeTransacter>
@required
@property (readonly) id<SorawalletSoraHistoryDatabaseQueries> soraHistoryDatabaseQueries __attribute__((swift_name("soraHistoryDatabaseQueries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraHistoryDatabaseCompanion")))
@interface SorawalletSoraHistoryDatabaseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraHistoryDatabaseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletSoraHistoryDatabase>)invokeDriver:(id<SorawalletRuntimeSqlDriver>)driver __attribute__((swift_name("invoke(driver:)")));
@property (readonly) id<SorawalletRuntimeSqlDriverSchema> Schema __attribute__((swift_name("Schema")));
@end

__attribute__((swift_name("SoraHistoryDatabaseQueries")))
@protocol SorawalletSoraHistoryDatabaseQueries <SorawalletRuntimeTransacter>
@required
- (void)insertExtrinsicTxHash:(NSString *)txHash signAddress:(NSString *)signAddress networkName:(NSString *)networkName blockHash:(NSString * _Nullable)blockHash module:(NSString *)module method:(NSString *)method networkFee:(NSString *)networkFee timestamp:(int64_t)timestamp success:(BOOL)success batch:(BOOL)batch parentHash:(NSString * _Nullable)parentHash __attribute__((swift_name("insertExtrinsic(txHash:signAddress:networkName:blockHash:module:method:networkFee:timestamp:success:batch:parentHash:)")));
- (void)insertExtrinsicParamExtrinsicHash:(NSString *)extrinsicHash paramName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("insertExtrinsicParam(extrinsicHash:paramName:paramValue:)")));
- (void)insertSignerInfoSignAddress:(NSString *)signAddress networkName:(NSString *)networkName topTime:(int64_t)topTime oldTime:(int64_t)oldTime oldCursor:(NSString * _Nullable)oldCursor endReached:(BOOL)endReached __attribute__((swift_name("insertSignerInfo(signAddress:networkName:topTime:oldTime:oldCursor:endReached:)")));
- (void)insertSignerInfoFullSignerInfo:(SorawalletSignerInfo *)SignerInfo __attribute__((swift_name("insertSignerInfoFull(SignerInfo:)")));
- (void)removeAllExtrinsics __attribute__((swift_name("removeAllExtrinsics()")));
- (void)removeAllSignerInfo __attribute__((swift_name("removeAllSignerInfo()")));
- (void)removeExtrinsicsAddress:(NSString *)address network:(NSString *)network __attribute__((swift_name("removeExtrinsics(address:network:)")));
- (void)removeSignerInfoAddress:(NSString *)address network:(NSString *)network __attribute__((swift_name("removeSignerInfo(address:network:)")));
- (SorawalletRuntimeQuery<SorawalletExtrinsics *> *)selectExtrinsicHash:(NSString *)hash address:(NSString *)address network:(NSString *)network __attribute__((swift_name("selectExtrinsic(hash:address:network:)")));
- (SorawalletRuntimeQuery<id> *)selectExtrinsicHash:(NSString *)hash address:(NSString *)address network:(NSString *)network mapper:(id (^)(NSString *, NSString *, NSString * _Nullable, NSString *, NSString *, NSString *, SorawalletLong *, SorawalletBoolean *, SorawalletBoolean *, NSString * _Nullable, NSString *))mapper __attribute__((swift_name("selectExtrinsic(hash:address:network:mapper:)")));
- (SorawalletRuntimeQuery<SorawalletExtrinsicParam *> *)selectExtrinsicParamsExtrinsicHash:(NSString *)extrinsicHash __attribute__((swift_name("selectExtrinsicParams(extrinsicHash:)")));
- (SorawalletRuntimeQuery<id> *)selectExtrinsicParamsExtrinsicHash:(NSString *)extrinsicHash mapper:(id (^)(NSString *, NSString *, NSString *))mapper __attribute__((swift_name("selectExtrinsicParams(extrinsicHash:mapper:)")));
- (SorawalletRuntimeQuery<SorawalletExtrinsics *> *)selectExtrinsicsNestedParentHash:(NSString * _Nullable)parentHash __attribute__((swift_name("selectExtrinsicsNested(parentHash:)")));
- (SorawalletRuntimeQuery<id> *)selectExtrinsicsNestedParentHash:(NSString * _Nullable)parentHash mapper:(id (^)(NSString *, NSString *, NSString * _Nullable, NSString *, NSString *, NSString *, SorawalletLong *, SorawalletBoolean *, SorawalletBoolean *, NSString * _Nullable, NSString *))mapper __attribute__((swift_name("selectExtrinsicsNested(parentHash:mapper:)")));
- (SorawalletRuntimeQuery<SorawalletExtrinsics *> *)selectExtrinsicsPagedAddress:(NSString *)address network:(NSString *)network limit:(int64_t)limit offset:(int64_t)offset __attribute__((swift_name("selectExtrinsicsPaged(address:network:limit:offset:)")));
- (SorawalletRuntimeQuery<id> *)selectExtrinsicsPagedAddress:(NSString *)address network:(NSString *)network limit:(int64_t)limit offset:(int64_t)offset mapper:(id (^)(NSString *, NSString *, NSString * _Nullable, NSString *, NSString *, NSString *, SorawalletLong *, SorawalletBoolean *, SorawalletBoolean *, NSString * _Nullable, NSString *))mapper __attribute__((swift_name("selectExtrinsicsPaged(address:network:limit:offset:mapper:)")));
- (SorawalletRuntimeQuery<SorawalletSignerInfo *> *)selectSignerInfoAddress:(NSString *)address network:(NSString *)network __attribute__((swift_name("selectSignerInfo(address:network:)")));
- (SorawalletRuntimeQuery<id> *)selectSignerInfoAddress:(NSString *)address network:(NSString *)network mapper:(id (^)(NSString *, SorawalletLong *, SorawalletLong *, NSString * _Nullable, SorawalletBoolean *, NSString *))mapper __attribute__((swift_name("selectSignerInfo(address:network:mapper:)")));
- (SorawalletRuntimeQuery<NSString *> *)selectTransfersPeersNetwork:(NSString *)network query:(NSString *)query __attribute__((swift_name("selectTransfersPeers(network:query:)")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ResponsePageInfo")))
@interface SorawalletResponsePageInfo : SorawalletBase
- (instancetype)initWithHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("init(hasNextPage:endCursor:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletResponsePageInfoCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletResponsePageInfo *)doCopyHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("doCopy(hasNextPage:endCursor:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ResponsePageInfo.Companion")))
@interface SorawalletResponsePageInfoCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletResponsePageInfoCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Utils")))
@interface SorawalletUtils : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)utils __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletUtils *shared __attribute__((swift_name("shared")));
- (SorawalletDouble * _Nullable)toDoubleNan:(NSString *)receiver __attribute__((swift_name("toDoubleNan(_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Cryp")))
@interface SorawalletCryp : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (id<SorawalletKotlinx_coroutines_coreFlow>)doFlow __attribute__((swift_name("doFlow()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpEngineFactory")))
@interface SorawalletHttpEngineFactory : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (id<SorawalletKtor_client_coreHttpClientEngineFactory>)createEngine __attribute__((swift_name("createEngine()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkClientConfig")))
@interface SorawalletNetworkClientConfig : SorawalletBase
- (instancetype)initWithLogging:(BOOL)logging requestTimeoutMillis:(int64_t)requestTimeoutMillis connectTimeoutMillis:(int64_t)connectTimeoutMillis socketTimeoutMillis:(int64_t)socketTimeoutMillis json:(SorawalletKotlinx_serialization_jsonJson *)json webSocketClientConfig:(SorawalletWebSocketClientConfig * _Nullable)webSocketClientConfig __attribute__((swift_name("init(logging:requestTimeoutMillis:connectTimeoutMillis:socketTimeoutMillis:json:webSocketClientConfig:)"))) __attribute__((objc_designated_initializer));
- (SorawalletNetworkClientConfig *)doCopyLogging:(BOOL)logging requestTimeoutMillis:(int64_t)requestTimeoutMillis connectTimeoutMillis:(int64_t)connectTimeoutMillis socketTimeoutMillis:(int64_t)socketTimeoutMillis json:(SorawalletKotlinx_serialization_jsonJson *)json webSocketClientConfig:(SorawalletWebSocketClientConfig * _Nullable)webSocketClientConfig __attribute__((swift_name("doCopy(logging:requestTimeoutMillis:connectTimeoutMillis:socketTimeoutMillis:json:webSocketClientConfig:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t connectTimeoutMillis __attribute__((swift_name("connectTimeoutMillis")));
@property (readonly) SorawalletKotlinx_serialization_jsonJson *json __attribute__((swift_name("json")));
@property (readonly) BOOL logging __attribute__((swift_name("logging")));
@property (readonly) int64_t requestTimeoutMillis __attribute__((swift_name("requestTimeoutMillis")));
@property (readonly) int64_t socketTimeoutMillis __attribute__((swift_name("socketTimeoutMillis")));
@property (readonly) SorawalletWebSocketClientConfig * _Nullable webSocketClientConfig __attribute__((swift_name("webSocketClientConfig")));
@end

__attribute__((swift_name("SoramitsuHttpClientProvider")))
@protocol SorawalletSoramitsuHttpClientProvider
@required
- (SorawalletKtor_client_coreHttpClient *)provideConfig:(SorawalletNetworkClientConfig *)config __attribute__((swift_name("provide(config:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoramitsuHttpClientProviderImpl")))
@interface SorawalletSoramitsuHttpClientProviderImpl : SorawalletBase <SorawalletSoramitsuHttpClientProvider>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SorawalletKtor_client_coreHttpClient *)provideConfig:(SorawalletNetworkClientConfig *)config __attribute__((swift_name("provide(config:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoramitsuNetworkClient")))
@interface SorawalletSoramitsuNetworkClient : SorawalletBase
- (instancetype)initWithTimeout:(int64_t)timeout logging:(BOOL)logging provider:(id<SorawalletSoramitsuHttpClientProvider>)provider __attribute__((swift_name("init(timeout:logging:provider:)"))) __attribute__((objc_designated_initializer));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)createJsonRequestPath:(NSString *)path methodType:(SorawalletKtor_httpHttpMethod *)methodType body:(id)body headers:(NSArray<SorawalletKotlinPair<NSString *, NSString *> *> * _Nullable)headers completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("createJsonRequest(path:methodType:body:headers:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)createRequestPath:(NSString *)path methodType:(SorawalletKtor_httpHttpMethod *)methodType body:(id)body contentType:(SorawalletKtor_httpContentType * _Nullable)contentType headersList:(NSArray<SorawalletKotlinPair<NSString *, NSString *> *> * _Nullable)headersList completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("createRequest(path:methodType:body:contentType:headersList:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getUrl:(NSString *)url completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("get(url:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getJsonRequestBearerToken:(NSString * _Nullable)bearerToken header:(NSString * _Nullable)header url:(NSString *)url completionHandler:(void (^)(SorawalletKtor_client_coreHttpResponse * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getJsonRequest(bearerToken:header:url:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)postJsonRequestBearerToken:(NSString * _Nullable)bearerToken header:(NSString * _Nullable)header url:(NSString *)url body:(id)body completionHandler:(void (^)(SorawalletKtor_client_coreHttpResponse * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("postJsonRequest(bearerToken:header:url:body:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id _Nullable)wrapInExceptionHandlerAndReturnError:(NSError * _Nullable * _Nullable)error block:(id (^)(void))block __attribute__((swift_name("wrapInExceptionHandler(block:)")));
@property (readonly) SorawalletKtor_client_coreHttpClient *httpClient __attribute__((swift_name("httpClient")));
@property (readonly) SorawalletKotlinx_serialization_jsonJson *json __attribute__((swift_name("json")));
@end

__attribute__((swift_name("KotlinThrowable")))
@interface SorawalletKotlinThrowable : SorawalletBase
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));

/**
 * @note annotations
 *   kotlin.experimental.ExperimentalNativeApi
*/
- (SorawalletKotlinArray<NSString *> *)getStackTrace __attribute__((swift_name("getStackTrace()")));
- (void)printStackTrace __attribute__((swift_name("printStackTrace()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletKotlinThrowable * _Nullable cause __attribute__((swift_name("cause")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
- (NSError *)asError __attribute__((swift_name("asError()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoramitsuNetworkException")))
@interface SorawalletSoramitsuNetworkException : SorawalletKotlinThrowable
- (instancetype)initWithM:(NSString *)m c:(SorawalletKotlinThrowable * _Nullable)c reason:(NSString *)reason __attribute__((swift_name("init(m:c:reason:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (readonly) NSString *m __attribute__((swift_name("m")));
@property (readonly) NSString *reason __attribute__((swift_name("reason")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WebSocketClientConfig")))
@interface SorawalletWebSocketClientConfig : SorawalletBase
- (instancetype)initWithPingInterval:(int64_t)pingInterval maxFrameSize:(int64_t)maxFrameSize __attribute__((swift_name("init(pingInterval:maxFrameSize:)"))) __attribute__((objc_designated_initializer));
- (SorawalletWebSocketClientConfig *)doCopyPingInterval:(int64_t)pingInterval maxFrameSize:(int64_t)maxFrameSize __attribute__((swift_name("doCopy(pingInterval:maxFrameSize:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t maxFrameSize __attribute__((swift_name("maxFrameSize")));
@property (readonly) int64_t pingInterval __attribute__((swift_name("pingInterval")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryDatabaseProvider")))
@interface SorawalletHistoryDatabaseProvider : SorawalletBase
- (instancetype)initWithDatabaseDriverFactory:(SorawalletDatabaseDriverFactory *)databaseDriverFactory __attribute__((swift_name("init(databaseDriverFactory:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryMapper")))
@interface SorawalletHistoryMapper : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)historyMapper __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletHistoryMapper *shared __attribute__((swift_name("shared")));
- (SorawalletTxHistoryItemNested *)mapItemNestedExtrinsic:(SorawalletExtrinsics *)extrinsic params:(NSArray<SorawalletExtrinsicParam *> *)params __attribute__((swift_name("mapItemNested(extrinsic:params:)")));
- (SorawalletTxHistoryItem *)mapItemsExtrinsic:(SorawalletExtrinsics *)extrinsic params:(NSArray<SorawalletTxHistoryItemNested *> *)params __attribute__((swift_name("mapItems(extrinsic:params:)")));
- (SorawalletTxHistoryItem *)mapParamsExtrinsic:(SorawalletExtrinsics *)extrinsic params:(NSArray<SorawalletExtrinsicParam *> *)params __attribute__((swift_name("mapParams(extrinsic:params:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryInfo")))
@interface SorawalletTxHistoryInfo : SorawalletBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached items:(NSArray<SorawalletTxHistoryItem *> *)items __attribute__((swift_name("init(endCursor:endReached:items:)"))) __attribute__((objc_designated_initializer));
- (SorawalletTxHistoryInfo *)doCopyEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached items:(NSArray<SorawalletTxHistoryItem *> *)items __attribute__((swift_name("doCopy(endCursor:endReached:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL endReached __attribute__((swift_name("endReached")));
@property (readonly) NSArray<SorawalletTxHistoryItem *> *items __attribute__((swift_name("items")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryItem")))
@interface SorawalletTxHistoryItem : SorawalletBase
- (instancetype)initWithId:(NSString *)id blockHash:(NSString *)blockHash module:(NSString *)module method:(NSString *)method timestamp:(NSString *)timestamp networkFee:(NSString *)networkFee success:(BOOL)success data:(NSArray<SorawalletTxHistoryItemParam *> * _Nullable)data nestedData:(NSArray<SorawalletTxHistoryItemNested *> * _Nullable)nestedData __attribute__((swift_name("init(id:blockHash:module:method:timestamp:networkFee:success:data:nestedData:)"))) __attribute__((objc_designated_initializer));
- (SorawalletTxHistoryItem *)doCopyId:(NSString *)id blockHash:(NSString *)blockHash module:(NSString *)module method:(NSString *)method timestamp:(NSString *)timestamp networkFee:(NSString *)networkFee success:(BOOL)success data:(NSArray<SorawalletTxHistoryItemParam *> * _Nullable)data nestedData:(NSArray<SorawalletTxHistoryItemNested *> * _Nullable)nestedData __attribute__((swift_name("doCopy(id:blockHash:module:method:timestamp:networkFee:success:data:nestedData:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *blockHash __attribute__((swift_name("blockHash")));
@property (readonly) NSArray<SorawalletTxHistoryItemParam *> * _Nullable data __attribute__((swift_name("data")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@property (readonly) NSArray<SorawalletTxHistoryItemNested *> * _Nullable nestedData __attribute__((swift_name("nestedData")));
@property (readonly) NSString *networkFee __attribute__((swift_name("networkFee")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@property (readonly) NSString *timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryItemNested")))
@interface SorawalletTxHistoryItemNested : SorawalletBase
- (instancetype)initWithModule:(NSString *)module method:(NSString *)method hash:(NSString *)hash data:(NSArray<SorawalletTxHistoryItemParam *> *)data __attribute__((swift_name("init(module:method:hash:data:)"))) __attribute__((objc_designated_initializer));
- (SorawalletTxHistoryItemNested *)doCopyModule:(NSString *)module method:(NSString *)method hash:(NSString *)hash data:(NSArray<SorawalletTxHistoryItemParam *> *)data __attribute__((swift_name("doCopy(module:method:hash:data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletTxHistoryItemParam *> *data __attribute__((swift_name("data")));
@property (readonly, getter=hash_) NSString *hash __attribute__((swift_name("hash")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryItemParam")))
@interface SorawalletTxHistoryItemParam : SorawalletBase
- (instancetype)initWithParamName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("init(paramName:paramValue:)"))) __attribute__((objc_designated_initializer));
- (SorawalletTxHistoryItemParam *)doCopyParamName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("doCopy(paramName:paramValue:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *paramName __attribute__((swift_name("paramName")));
@property (readonly) NSString *paramValue __attribute__((swift_name("paramValue")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryResult")))
@interface SorawalletTxHistoryResult<R> : SorawalletBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached page:(int64_t)page items:(NSArray<id> *)items errorMessage:(NSString * _Nullable)errorMessage __attribute__((swift_name("init(endCursor:endReached:page:items:errorMessage:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL endReached __attribute__((swift_name("endReached")));
@property (readonly) NSString * _Nullable errorMessage __attribute__((swift_name("errorMessage")));
@property (readonly) NSArray<id> *items __attribute__((swift_name("items")));
@property (readonly) int64_t page __attribute__((swift_name("page")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryClient")))
@interface SorawalletSubQueryClient<T, R> : SorawalletBase
- (instancetype)initWithNetworkClient:(SorawalletSoramitsuNetworkClient *)networkClient pageSize:(int32_t)pageSize deserializationStrategy:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializationStrategy jsonToHistoryInfo:(SorawalletTxHistoryInfo *(^)(T _Nullable, NSString *))jsonToHistoryInfo historyInfoToResult:(R _Nullable (^)(SorawalletTxHistoryItem *))historyInfoToResult historyRequest:(NSString *)historyRequest historyDatabaseProvider:(SorawalletHistoryDatabaseProvider *)historyDatabaseProvider __attribute__((swift_name("init(networkClient:pageSize:deserializationStrategy:jsonToHistoryInfo:historyInfoToResult:historyRequest:historyDatabaseProvider:)"))) __attribute__((objc_designated_initializer));
- (void)clearAllData __attribute__((swift_name("clearAllData()")));
- (void)clearDataAddress:(NSString *)address networkName:(NSString *)networkName __attribute__((swift_name("clearData(address:networkName:)")));
- (SorawalletTxHistoryInfo *)getTransactionCachedAddress:(NSString *)address networkName:(NSString *)networkName txHash:(NSString *)txHash __attribute__((swift_name("getTransactionCached(address:networkName:txHash:)")));
- (NSArray<id> *)getTransactionHistoryCachedAddress:(NSString *)address networkName:(NSString *)networkName count:(int32_t)count filter:(SorawalletBoolean *(^ _Nullable)(R _Nullable))filter __attribute__((swift_name("getTransactionHistoryCached(address:networkName:count:filter:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getTransactionHistoryPagedAddress:(NSString *)address networkName:(NSString *)networkName page:(int64_t)page url:(NSString *)url filter:(SorawalletBoolean *(^ _Nullable)(R _Nullable))filter completionHandler:(void (^)(SorawalletTxHistoryResult<R> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getTransactionHistoryPaged(address:networkName:page:url:filter:completionHandler:)")));
- (NSArray<NSString *> *)getTransactionPeersQuery:(NSString *)query networkName:(NSString *)networkName __attribute__((swift_name("getTransactionPeers(query:networkName:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryClientFactory")))
@interface SorawalletSubQueryClientFactory<T, R> : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SorawalletSubQueryClient<T, R> *)createSoramitsuNetworkClient:(SorawalletSoramitsuNetworkClient *)soramitsuNetworkClient baseUrl:(NSString *)baseUrl pageSize:(int32_t)pageSize deserializationStrategy:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializationStrategy jsonToHistoryInfo:(SorawalletTxHistoryInfo *(^)(T _Nullable, NSString *))jsonToHistoryInfo historyIntoToResult:(R _Nullable (^)(SorawalletTxHistoryItem *))historyIntoToResult historyRequest:(NSString *)historyRequest __attribute__((swift_name("create(soramitsuNetworkClient:baseUrl:pageSize:deserializationStrategy:jsonToHistoryInfo:historyIntoToResult:historyRequest:)")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryRequest")))
@interface SorawalletSubQueryRequest : SorawalletBase
- (instancetype)initWithQuery:(NSString *)query variables:(NSString * _Nullable)variables __attribute__((swift_name("init(query:variables:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSubQueryRequestCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSubQueryRequest *)doCopyQuery:(NSString *)query variables:(NSString * _Nullable)variables __attribute__((swift_name("doCopy(query:variables:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *query __attribute__((swift_name("query")));
@property (readonly) NSString * _Nullable variables __attribute__((swift_name("variables")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryRequest.Companion")))
@interface SorawalletSubQueryRequestCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSubQueryRequestCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("DatabaseDriverFactory")))
@interface SorawalletDatabaseDriverFactory : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (id<SorawalletRuntimeSqlDriver>)createDriver __attribute__((swift_name("createDriver()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Error")))
@interface SorawalletError : SorawalletBase
- (instancetype)initWithModuleErrorId:(NSString * _Nullable)moduleErrorId moduleErrorIndex:(SorawalletInt * _Nullable)moduleErrorIndex nonModuleErrorMessage:(NSString * _Nullable)nonModuleErrorMessage __attribute__((swift_name("init(moduleErrorId:moduleErrorIndex:nonModuleErrorMessage:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletErrorCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletError *)doCopyModuleErrorId:(NSString * _Nullable)moduleErrorId moduleErrorIndex:(SorawalletInt * _Nullable)moduleErrorIndex nonModuleErrorMessage:(NSString * _Nullable)nonModuleErrorMessage __attribute__((swift_name("doCopy(moduleErrorId:moduleErrorIndex:nonModuleErrorMessage:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable moduleErrorId __attribute__((swift_name("moduleErrorId")));
@property (readonly) SorawalletInt * _Nullable moduleErrorIndex __attribute__((swift_name("moduleErrorIndex")));
@property (readonly) NSString * _Nullable nonModuleErrorMessage __attribute__((swift_name("nonModuleErrorMessage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Error.Companion")))
@interface SorawalletErrorCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletErrorCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExecutionResult")))
@interface SorawalletExecutionResult : SorawalletBase
- (instancetype)initWithSuccess:(BOOL)success error:(SorawalletError * _Nullable)error __attribute__((swift_name("init(success:error:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletExecutionResultCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletExecutionResult *)doCopySuccess:(BOOL)success error:(SorawalletError * _Nullable)error __attribute__((swift_name("doCopy(success:error:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletError * _Nullable error __attribute__((swift_name("error")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExecutionResult.Companion")))
@interface SorawalletExecutionResultCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletExecutionResultCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryResponseDataElements")))
@interface SorawalletHistoryResponseDataElements : SorawalletBase
- (instancetype)initWithNodes:(NSArray<SorawalletHistoryResponseItem *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletHistoryResponseDataElementsCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletHistoryResponseDataElements *)doCopyNodes:(NSArray<SorawalletHistoryResponseItem *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletHistoryResponseItem *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) SorawalletResponsePageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryResponseDataElements.Companion")))
@interface SorawalletHistoryResponseDataElementsCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletHistoryResponseDataElementsCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryResponseItem")))
@interface SorawalletHistoryResponseItem : SorawalletBase
- (instancetype)initWithId:(NSString *)id blockHash:(NSString *)blockHash module:(NSString *)module method:(NSString *)method timestamp:(NSString *)timestamp networkFee:(NSString *)networkFee execution:(SorawalletExecutionResult *)execution data:(SorawalletKotlinx_serialization_jsonJsonElement *)data __attribute__((swift_name("init(id:blockHash:module:method:timestamp:networkFee:execution:data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletHistoryResponseItemCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletHistoryResponseItem *)doCopyId:(NSString *)id blockHash:(NSString *)blockHash module:(NSString *)module method:(NSString *)method timestamp:(NSString *)timestamp networkFee:(NSString *)networkFee execution:(SorawalletExecutionResult *)execution data:(SorawalletKotlinx_serialization_jsonJsonElement *)data __attribute__((swift_name("doCopy(id:blockHash:module:method:timestamp:networkFee:execution:data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *blockHash __attribute__((swift_name("blockHash")));
@property (readonly) SorawalletKotlinx_serialization_jsonJsonElement *data __attribute__((swift_name("data")));
@property (readonly) SorawalletExecutionResult *execution __attribute__((swift_name("execution")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@property (readonly) NSString *networkFee __attribute__((swift_name("networkFee")));
@property (readonly) NSString *timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryResponseItem.Companion")))
@interface SorawalletHistoryResponseItemCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletHistoryResponseItemCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubQueryResponse")))
@interface SorawalletSoraSubQueryResponse : SorawalletBase
- (instancetype)initWithData:(SorawalletSoraSubQueryResponseData *)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraSubQueryResponseCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraSubQueryResponse *)doCopyData:(SorawalletSoraSubQueryResponseData *)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraSubQueryResponseData *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubQueryResponse.Companion")))
@interface SorawalletSoraSubQueryResponseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraSubQueryResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubQueryResponseData")))
@interface SorawalletSoraSubQueryResponseData : SorawalletBase
- (instancetype)initWithHistoryElements:(SorawalletHistoryResponseDataElements *)historyElements __attribute__((swift_name("init(historyElements:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraSubQueryResponseDataCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraSubQueryResponseData *)doCopyHistoryElements:(SorawalletHistoryResponseDataElements *)historyElements __attribute__((swift_name("doCopy(historyElements:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletHistoryResponseDataElements *historyElements __attribute__((swift_name("historyElements")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubQueryResponseData.Companion")))
@interface SorawalletSoraSubQueryResponseDataCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraSubQueryResponseDataCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSubQueryHistoryMapper")))
@interface SorawalletSoraWalletSubQueryHistoryMapper : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)soraWalletSubQueryHistoryMapper __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletSubQueryHistoryMapper *shared __attribute__((swift_name("shared")));
- (SorawalletTxHistoryInfo *)mapResponse:(SorawalletSoraSubQueryResponse *)response myAddress:(NSString *)myAddress __attribute__((swift_name("map(response:myAddress:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryClientForSoraWallet")))
@interface SorawalletSubQueryClientForSoraWallet : SorawalletBase
- (instancetype)initWithNetworkClient:(SorawalletSoramitsuNetworkClient *)networkClient pageSize:(int32_t)pageSize historyDatabaseProvider:(SorawalletHistoryDatabaseProvider *)historyDatabaseProvider soraRemoteConfigBuilder:(SorawalletSoraRemoteConfigBuilder *)soraRemoteConfigBuilder __attribute__((swift_name("init(networkClient:pageSize:historyDatabaseProvider:soraRemoteConfigBuilder:)"))) __attribute__((objc_designated_initializer));
- (void)clearAllData __attribute__((swift_name("clearAllData()")));
- (void)clearDataAddress:(NSString *)address __attribute__((swift_name("clearData(address:)")));
- (SorawalletTxHistoryInfo *)getTransactionCachedAddress:(NSString *)address txHash:(NSString *)txHash __attribute__((swift_name("getTransactionCached(address:txHash:)")));
- (NSArray<SorawalletTxHistoryItem *> *)getTransactionHistoryCachedAddress:(NSString *)address count:(int32_t)count filter:(SorawalletBoolean *(^ _Nullable)(SorawalletTxHistoryItem *))filter __attribute__((swift_name("getTransactionHistoryCached(address:count:filter:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getTransactionHistoryPagedAddress:(NSString *)address page:(int64_t)page filter:(SorawalletBoolean *(^ _Nullable)(SorawalletTxHistoryItem *))filter completionHandler:(void (^)(SorawalletTxHistoryResult<SorawalletTxHistoryItem *> * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("getTransactionHistoryPaged(address:page:filter:completionHandler:)")));
- (NSArray<NSString *> *)getTransactionPeersQuery:(NSString *)query __attribute__((swift_name("getTransactionPeers(query:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryClientForSoraWalletFactory")))
@interface SorawalletSubQueryClientForSoraWalletFactory : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SorawalletSubQueryClientForSoraWallet *)createSoramitsuNetworkClient:(SorawalletSoramitsuNetworkClient *)soramitsuNetworkClient pageSize:(int32_t)pageSize soraRemoteConfigBuilder:(SorawalletSoraRemoteConfigBuilder *)soraRemoteConfigBuilder __attribute__((swift_name("create(soramitsuNetworkClient:pageSize:soraRemoteConfigBuilder:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraTokenWhitelistDto")))
@interface SorawalletSoraTokenWhitelistDto : SorawalletBase
- (instancetype)initWithAddress:(NSString *)address rawIcon:(id)rawIcon type:(NSString *)type __attribute__((swift_name("init(address:rawIcon:type:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSoraTokenWhitelistDto *)doCopyAddress:(NSString *)address rawIcon:(id)rawIcon type:(NSString *)type __attribute__((swift_name("doCopy(address:rawIcon:type:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *address __attribute__((swift_name("address")));
@property (readonly) id rawIcon __attribute__((swift_name("rawIcon")));
@property (readonly) NSString *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraTokensWhitelistManager")))
@interface SorawalletSoraTokensWhitelistManager : SorawalletBase
- (instancetype)initWithNetworkClient:(SorawalletSoramitsuNetworkClient *)networkClient __attribute__((swift_name("init(networkClient:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraTokensWhitelistManagerCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getTokensWithCompletionHandler:(void (^)(NSArray<SorawalletSoraTokenWhitelistDto *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getTokens(completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraTokensWhitelistManager.Companion")))
@interface SorawalletSoraTokensWhitelistManagerCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraTokensWhitelistManagerCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ConfigExplorerType")))
@interface SorawalletConfigExplorerType : SorawalletBase
- (instancetype)initWithFiat:(NSString *)fiat reward:(NSString *)reward sbapy:(NSString *)sbapy assets:(NSString *)assets __attribute__((swift_name("init(fiat:reward:sbapy:assets:)"))) __attribute__((objc_designated_initializer));
- (SorawalletConfigExplorerType *)doCopyFiat:(NSString *)fiat reward:(NSString *)reward sbapy:(NSString *)sbapy assets:(NSString *)assets __attribute__((swift_name("doCopy(fiat:reward:sbapy:assets:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *assets __attribute__((swift_name("assets")));
@property (readonly) NSString *fiat __attribute__((swift_name("fiat")));
@property (readonly) NSString *reward __attribute__((swift_name("reward")));
@property (readonly) NSString *sbapy __attribute__((swift_name("sbapy")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraConfig")))
@interface SorawalletSoraConfig : SorawalletBase
- (instancetype)initWithRemote:(BOOL)remote blockExplorerUrl:(NSString *)blockExplorerUrl blockExplorerType:(SorawalletConfigExplorerType *)blockExplorerType nodes:(NSArray<SorawalletSoraConfigNode *> *)nodes genesis:(NSString *)genesis joinUrl:(NSString *)joinUrl substrateTypesUrl:(NSString *)substrateTypesUrl soracard:(BOOL)soracard currencies:(NSArray<SorawalletSoraCurrency *> *)currencies __attribute__((swift_name("init(remote:blockExplorerUrl:blockExplorerType:nodes:genesis:joinUrl:substrateTypesUrl:soracard:currencies:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSoraConfig *)doCopyRemote:(BOOL)remote blockExplorerUrl:(NSString *)blockExplorerUrl blockExplorerType:(SorawalletConfigExplorerType *)blockExplorerType nodes:(NSArray<SorawalletSoraConfigNode *> *)nodes genesis:(NSString *)genesis joinUrl:(NSString *)joinUrl substrateTypesUrl:(NSString *)substrateTypesUrl soracard:(BOOL)soracard currencies:(NSArray<SorawalletSoraCurrency *> *)currencies __attribute__((swift_name("doCopy(remote:blockExplorerUrl:blockExplorerType:nodes:genesis:joinUrl:substrateTypesUrl:soracard:currencies:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletConfigExplorerType *blockExplorerType __attribute__((swift_name("blockExplorerType")));
@property (readonly) NSString *blockExplorerUrl __attribute__((swift_name("blockExplorerUrl")));
@property (readonly) NSArray<SorawalletSoraCurrency *> *currencies __attribute__((swift_name("currencies")));
@property (readonly) NSString *genesis __attribute__((swift_name("genesis")));
@property (readonly) NSString *joinUrl __attribute__((swift_name("joinUrl")));
@property (readonly) NSArray<SorawalletSoraConfigNode *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) BOOL remote __attribute__((swift_name("remote")));
@property (readonly) BOOL soracard __attribute__((swift_name("soracard")));
@property (readonly) NSString *substrateTypesUrl __attribute__((swift_name("substrateTypesUrl")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraConfigNode")))
@interface SorawalletSoraConfigNode : SorawalletBase
- (instancetype)initWithChain:(NSString *)chain name:(NSString *)name address:(NSString *)address __attribute__((swift_name("init(chain:name:address:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSoraConfigNode *)doCopyChain:(NSString *)chain name:(NSString *)name address:(NSString *)address __attribute__((swift_name("doCopy(chain:name:address:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *address __attribute__((swift_name("address")));
@property (readonly) NSString *chain __attribute__((swift_name("chain")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraCurrency")))
@interface SorawalletSoraCurrency : SorawalletBase
- (instancetype)initWithCode:(NSString *)code name:(NSString *)name sign:(NSString *)sign __attribute__((swift_name("init(code:name:sign:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSoraCurrency *)doCopyCode:(NSString *)code name:(NSString *)name sign:(NSString *)sign __attribute__((swift_name("doCopy(code:name:sign:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *code __attribute__((swift_name("code")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) NSString *sign __attribute__((swift_name("sign")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraRemoteConfigBuilder")))
@interface SorawalletSoraRemoteConfigBuilder : SorawalletBase
- (instancetype)initWithClient:(SorawalletSoramitsuNetworkClient *)client commonUrl:(NSString *)commonUrl mobileUrl:(NSString *)mobileUrl settings:(id<SorawalletMultiplatform_settingsSettings>)settings __attribute__((swift_name("init(client:commonUrl:mobileUrl:settings:)"))) __attribute__((objc_designated_initializer));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getConfigWithCompletionHandler:(void (^)(SorawalletSoraConfig * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("getConfig(completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraRemoteConfigProvider")))
@interface SorawalletSoraRemoteConfigProvider : SorawalletBase
- (instancetype)initWithClient:(SorawalletSoramitsuNetworkClient *)client commonUrl:(NSString *)commonUrl mobileUrl:(NSString *)mobileUrl __attribute__((swift_name("init(client:commonUrl:mobileUrl:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSoraRemoteConfigBuilder *)provide __attribute__((swift_name("provide()")));
@end

__attribute__((swift_name("BasicCases")))
@interface SorawalletBasicCases<T> : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (T _Nullable)getCaseCaseName:(NSString *)caseName __attribute__((swift_name("getCase(caseName:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (T _Nullable)provideInstanceCaseName:(NSString *)caseName __attribute__((swift_name("provideInstance(caseName:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletBlockExplorerInfo")))
@interface SorawalletSoraWalletBlockExplorerInfo : SorawalletBase
- (instancetype)initWithNetworkClient:(SorawalletSoramitsuNetworkClient *)networkClient soraRemoteConfigBuilder:(SorawalletSoraRemoteConfigBuilder *)soraRemoteConfigBuilder __attribute__((swift_name("init(networkClient:soraRemoteConfigBuilder:)"))) __attribute__((objc_designated_initializer));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getAssetsInfoTokenIds:(NSArray<NSString *> *)tokenIds timestamp:(int64_t)timestamp completionHandler:(void (^)(NSArray<SorawalletAssetsInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getAssetsInfo(tokenIds:timestamp:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getFiatWithCompletionHandler:(void (^)(NSArray<SorawalletFiatData *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getFiat(completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getReferrerRewardsAddress:(NSString *)address completionHandler:(void (^)(SorawalletReferrerRewardsInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getReferrerRewards(address:completionHandler:)")));

/**
 * @note This method converts instances of SoramitsuNetworkException, CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getSpApyWithCompletionHandler:(void (^)(NSArray<SorawalletSbApyInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getSpApy(completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FiatData")))
@interface SorawalletFiatData : SorawalletBase
- (instancetype)initWithId:(NSString *)id priceUsd:(SorawalletDouble * _Nullable)priceUsd __attribute__((swift_name("init(id:priceUsd:)"))) __attribute__((objc_designated_initializer));
- (SorawalletFiatData *)doCopyId:(NSString *)id priceUsd:(SorawalletDouble * _Nullable)priceUsd __attribute__((swift_name("doCopy(id:priceUsd:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) SorawalletDouble * _Nullable priceUsd __attribute__((swift_name("priceUsd")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2Response")))
@interface SorawalletSoraWalletFiatCase2Response : SorawalletBase
- (instancetype)initWithData:(SorawalletSoraWalletFiatCase2ResponseData *)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletFiatCase2ResponseCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletFiatCase2Response *)doCopyData:(SorawalletSoraWalletFiatCase2ResponseData *)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletFiatCase2ResponseData *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2Response.Companion")))
@interface SorawalletSoraWalletFiatCase2ResponseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletFiatCase2ResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2ResponseData")))
@interface SorawalletSoraWalletFiatCase2ResponseData : SorawalletBase
- (instancetype)initWithEntities:(SorawalletSoraWalletFiatCase2ResponseDataEntities *)entities __attribute__((swift_name("init(entities:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletFiatCase2ResponseDataCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletFiatCase2ResponseData *)doCopyEntities:(SorawalletSoraWalletFiatCase2ResponseDataEntities *)entities __attribute__((swift_name("doCopy(entities:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletFiatCase2ResponseDataEntities *entities __attribute__((swift_name("entities")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2ResponseData.Companion")))
@interface SorawalletSoraWalletFiatCase2ResponseDataCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletFiatCase2ResponseDataCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2ResponseDataEntities")))
@interface SorawalletSoraWalletFiatCase2ResponseDataEntities : SorawalletBase
- (instancetype)initWithNodes:(NSArray<SorawalletSoraWalletFiatCase2ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletFiatCase2ResponseDataEntitiesCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletFiatCase2ResponseDataEntities *)doCopyNodes:(NSArray<SorawalletSoraWalletFiatCase2ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletSoraWalletFiatCase2ResponseDataEntitiesNode *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) SorawalletResponsePageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2ResponseDataEntities.Companion")))
@interface SorawalletSoraWalletFiatCase2ResponseDataEntitiesCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletFiatCase2ResponseDataEntitiesCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2ResponseDataEntitiesNode")))
@interface SorawalletSoraWalletFiatCase2ResponseDataEntitiesNode : SorawalletBase
- (instancetype)initWithId:(NSString *)id priceUSD:(NSString *)priceUSD __attribute__((swift_name("init(id:priceUSD:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletFiatCase2ResponseDataEntitiesNodeCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletFiatCase2ResponseDataEntitiesNode *)doCopyId:(NSString *)id priceUSD:(NSString *)priceUSD __attribute__((swift_name("doCopy(id:priceUSD:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *priceUSD __attribute__((swift_name("priceUSD")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletFiatCase2ResponseDataEntitiesNode.Companion")))
@interface SorawalletSoraWalletFiatCase2ResponseDataEntitiesNodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletFiatCase2ResponseDataEntitiesNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsInfo")))
@interface SorawalletAssetsInfo : SorawalletBase
- (instancetype)initWithTokenId:(NSString *)tokenId liquidity:(NSString *)liquidity hourDelta:(SorawalletDouble * _Nullable)hourDelta __attribute__((swift_name("init(tokenId:liquidity:hourDelta:)"))) __attribute__((objc_designated_initializer));
- (SorawalletAssetsInfo *)doCopyTokenId:(NSString *)tokenId liquidity:(NSString *)liquidity hourDelta:(SorawalletDouble * _Nullable)hourDelta __attribute__((swift_name("doCopy(tokenId:liquidity:hourDelta:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletDouble * _Nullable hourDelta __attribute__((swift_name("hourDelta")));
@property (readonly) NSString *liquidity __attribute__((swift_name("liquidity")));
@property (readonly) NSString *tokenId __attribute__((swift_name("tokenId")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0Response")))
@interface SorawalletSoraWalletAssetsCase0Response : SorawalletBase
- (instancetype)initWithData:(SorawalletSoraWalletAssetsCase0ResponseData *)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0Response *)doCopyData:(SorawalletSoraWalletAssetsCase0ResponseData *)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletAssetsCase0ResponseData *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0Response.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseData")))
@interface SorawalletSoraWalletAssetsCase0ResponseData : SorawalletBase
- (instancetype)initWithEntities:(SorawalletSoraWalletAssetsCase0ResponseDataEntities *)entities __attribute__((swift_name("init(entities:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseDataCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0ResponseData *)doCopyEntities:(SorawalletSoraWalletAssetsCase0ResponseDataEntities *)entities __attribute__((swift_name("doCopy(entities:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletAssetsCase0ResponseDataEntities *entities __attribute__((swift_name("entities")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseData.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseDataCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntities")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntities : SorawalletBase
- (instancetype)initWithNodes:(NSArray<SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0ResponseDataEntities *)doCopyNodes:(NSArray<SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNode *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) SorawalletResponsePageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntities.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNode")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNode : SorawalletBase
- (instancetype)initWithId:(NSString *)id liquidity:(NSString *)liquidity periods:(SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHour *)periods __attribute__((swift_name("init(id:liquidity:periods:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNode *)doCopyId:(NSString *)id liquidity:(NSString *)liquidity periods:(SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHour *)periods __attribute__((swift_name("doCopy(id:liquidity:periods:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *liquidity __attribute__((swift_name("liquidity")));
@property (readonly) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHour *periods __attribute__((swift_name("periods")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNode.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNodeHour")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHour : SorawalletBase
- (instancetype)initWithNodes:(NSArray<SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode *> *)nodes __attribute__((swift_name("init(nodes:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHour *)doCopyNodes:(NSArray<SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode *> *)nodes __attribute__((swift_name("doCopy(nodes:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode *> *nodes __attribute__((swift_name("nodes")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNodeHour.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode : SorawalletBase
- (instancetype)initWithPrice:(SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice *)price __attribute__((swift_name("init(price:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodeCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode *)doCopyPrice:(SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice *)price __attribute__((swift_name("doCopy(price:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice *price __attribute__((swift_name("price")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNodeHourNode.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice : SorawalletBase
- (instancetype)initWithLow:(NSString *)low high:(NSString *)high open:(NSString *)open close:(NSString *)close __attribute__((swift_name("init(low:high:open:close:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePriceCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice *)doCopyLow:(NSString *)low high:(NSString *)high open:(NSString *)open close:(NSString *)close __attribute__((swift_name("doCopy(low:high:open:close:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *close __attribute__((swift_name("close")));
@property (readonly) NSString *high __attribute__((swift_name("high")));
@property (readonly) NSString *low __attribute__((swift_name("low")));
@property (readonly) NSString *open __attribute__((swift_name("open")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePrice.Companion")))
@interface SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePriceCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase0ResponseDataEntitiesNodeHourNodePriceCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1Response")))
@interface SorawalletSoraWalletAssetsCase1Response : SorawalletBase
- (instancetype)initWithData:(SorawalletSoraWalletAssetsCase1ResponseData *)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase1ResponseCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase1Response *)doCopyData:(SorawalletSoraWalletAssetsCase1ResponseData *)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletAssetsCase1ResponseData *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1Response.Companion")))
@interface SorawalletSoraWalletAssetsCase1ResponseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase1ResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseData")))
@interface SorawalletSoraWalletAssetsCase1ResponseData : SorawalletBase
- (instancetype)initWithEntities:(SorawalletSoraWalletAssetsCase1ResponseDataEntities *)entities __attribute__((swift_name("init(entities:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase1ResponseDataCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase1ResponseData *)doCopyEntities:(SorawalletSoraWalletAssetsCase1ResponseDataEntities *)entities __attribute__((swift_name("doCopy(entities:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletAssetsCase1ResponseDataEntities *entities __attribute__((swift_name("entities")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseData.Companion")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase1ResponseDataCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseDataEntities")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataEntities : SorawalletBase
- (instancetype)initWithNodes:(NSArray<SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase1ResponseDataEntities *)doCopyNodes:(NSArray<SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNode *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) SorawalletResponsePageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseDataEntities.Companion")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataEntitiesCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseDataEntitiesNode")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNode : SorawalletBase
- (instancetype)initWithNode:(SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHour *)node __attribute__((swift_name("init(node:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNode *)doCopyNode:(SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHour *)node __attribute__((swift_name("doCopy(node:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHour *node __attribute__((swift_name("node")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseDataEntitiesNode.Companion")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseDataEntitiesNodeHour")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHour : SorawalletBase
- (instancetype)initWithId:(NSString *)id priceChangeDay:(SorawalletDouble * _Nullable)priceChangeDay liquidity:(NSString * _Nullable)liquidity __attribute__((swift_name("init(id:priceChangeDay:liquidity:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHourCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHour *)doCopyId:(NSString *)id priceChangeDay:(SorawalletDouble * _Nullable)priceChangeDay liquidity:(NSString * _Nullable)liquidity __attribute__((swift_name("doCopy(id:priceChangeDay:liquidity:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable liquidity __attribute__((swift_name("liquidity")));
@property (readonly) SorawalletDouble * _Nullable priceChangeDay __attribute__((swift_name("priceChangeDay")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletAssetsCase1ResponseDataEntitiesNodeHour.Companion")))
@interface SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHourCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletAssetsCase1ResponseDataEntitiesNodeHourCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerReward")))
@interface SorawalletReferrerReward : SorawalletBase
- (instancetype)initWithReferral:(NSString *)referral amount:(NSString *)amount __attribute__((swift_name("init(referral:amount:)"))) __attribute__((objc_designated_initializer));
- (SorawalletReferrerReward *)doCopyReferral:(NSString *)referral amount:(NSString *)amount __attribute__((swift_name("doCopy(referral:amount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *amount __attribute__((swift_name("amount")));
@property (readonly) NSString *referral __attribute__((swift_name("referral")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardsInfo")))
@interface SorawalletReferrerRewardsInfo : SorawalletBase
- (instancetype)initWithRewards:(NSArray<SorawalletReferrerReward *> *)rewards __attribute__((swift_name("init(rewards:)"))) __attribute__((objc_designated_initializer));
- (SorawalletReferrerRewardsInfo *)doCopyRewards:(NSArray<SorawalletReferrerReward *> *)rewards __attribute__((swift_name("doCopy(rewards:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletReferrerReward *> *rewards __attribute__((swift_name("rewards")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1Response")))
@interface SorawalletSoraWalletReferrerCase1Response : SorawalletBase
- (instancetype)initWithData:(SorawalletSoraWalletReferrerCase1ResponseData *)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletReferrerCase1ResponseCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletReferrerCase1Response *)doCopyData:(SorawalletSoraWalletReferrerCase1ResponseData *)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletReferrerCase1ResponseData *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1Response.Companion")))
@interface SorawalletSoraWalletReferrerCase1ResponseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletReferrerCase1ResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1ResponseData")))
@interface SorawalletSoraWalletReferrerCase1ResponseData : SorawalletBase
- (instancetype)initWithReferrerRewards:(SorawalletSoraWalletReferrerCase1ResponseDataRewards *)referrerRewards __attribute__((swift_name("init(referrerRewards:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletReferrerCase1ResponseDataCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletReferrerCase1ResponseData *)doCopyReferrerRewards:(SorawalletSoraWalletReferrerCase1ResponseDataRewards *)referrerRewards __attribute__((swift_name("doCopy(referrerRewards:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletReferrerCase1ResponseDataRewards *referrerRewards __attribute__((swift_name("referrerRewards")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1ResponseData.Companion")))
@interface SorawalletSoraWalletReferrerCase1ResponseDataCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletReferrerCase1ResponseDataCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1ResponseDataRewards")))
@interface SorawalletSoraWalletReferrerCase1ResponseDataRewards : SorawalletBase
- (instancetype)initWithPageInfo:(SorawalletResponsePageInfo *)pageInfo nodes:(NSArray<SorawalletSoraWalletReferrerCase1ResponseDataRewardsNode *> *)nodes __attribute__((swift_name("init(pageInfo:nodes:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletReferrerCase1ResponseDataRewardsCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletReferrerCase1ResponseDataRewards *)doCopyPageInfo:(SorawalletResponsePageInfo *)pageInfo nodes:(NSArray<SorawalletSoraWalletReferrerCase1ResponseDataRewardsNode *> *)nodes __attribute__((swift_name("doCopy(pageInfo:nodes:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletSoraWalletReferrerCase1ResponseDataRewardsNode *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) SorawalletResponsePageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1ResponseDataRewards.Companion")))
@interface SorawalletSoraWalletReferrerCase1ResponseDataRewardsCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletReferrerCase1ResponseDataRewardsCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1ResponseDataRewardsNode")))
@interface SorawalletSoraWalletReferrerCase1ResponseDataRewardsNode : SorawalletBase
- (instancetype)initWithReferral:(NSString *)referral amount:(NSString *)amount __attribute__((swift_name("init(referral:amount:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletReferrerCase1ResponseDataRewardsNodeCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletReferrerCase1ResponseDataRewardsNode *)doCopyReferral:(NSString *)referral amount:(NSString *)amount __attribute__((swift_name("doCopy(referral:amount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *amount __attribute__((swift_name("amount")));
@property (readonly) NSString *referral __attribute__((swift_name("referral")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletReferrerCase1ResponseDataRewardsNode.Companion")))
@interface SorawalletSoraWalletReferrerCase1ResponseDataRewardsNodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletReferrerCase1ResponseDataRewardsNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SbApyInfo")))
@interface SorawalletSbApyInfo : SorawalletBase
- (instancetype)initWithId:(NSString *)id sbApy:(SorawalletDouble * _Nullable)sbApy __attribute__((swift_name("init(id:sbApy:)"))) __attribute__((objc_designated_initializer));
- (SorawalletSbApyInfo *)doCopyId:(NSString *)id sbApy:(SorawalletDouble * _Nullable)sbApy __attribute__((swift_name("doCopy(id:sbApy:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) SorawalletDouble * _Nullable sbApy __attribute__((swift_name("sbApy")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2Response")))
@interface SorawalletSoraWalletSbApyCase2Response : SorawalletBase
- (instancetype)initWithData:(SorawalletSoraWalletSbApyCase2ResponseData *)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletSbApyCase2ResponseCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletSbApyCase2Response *)doCopyData:(SorawalletSoraWalletSbApyCase2ResponseData *)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletSbApyCase2ResponseData *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2Response.Companion")))
@interface SorawalletSoraWalletSbApyCase2ResponseCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletSbApyCase2ResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2ResponseData")))
@interface SorawalletSoraWalletSbApyCase2ResponseData : SorawalletBase
- (instancetype)initWithEntities:(SorawalletSoraWalletSbApyCase2ResponseDataEntities *)entities __attribute__((swift_name("init(entities:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletSbApyCase2ResponseDataCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletSbApyCase2ResponseData *)doCopyEntities:(SorawalletSoraWalletSbApyCase2ResponseDataEntities *)entities __attribute__((swift_name("doCopy(entities:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletSoraWalletSbApyCase2ResponseDataEntities *entities __attribute__((swift_name("entities")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2ResponseData.Companion")))
@interface SorawalletSoraWalletSbApyCase2ResponseDataCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletSbApyCase2ResponseDataCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2ResponseDataEntities")))
@interface SorawalletSoraWalletSbApyCase2ResponseDataEntities : SorawalletBase
- (instancetype)initWithNodes:(NSArray<SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletSbApyCase2ResponseDataEntitiesCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletSbApyCase2ResponseDataEntities *)doCopyNodes:(NSArray<SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNode *> *)nodes pageInfo:(SorawalletResponsePageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNode *> *nodes __attribute__((swift_name("nodes")));
@property (readonly) SorawalletResponsePageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2ResponseDataEntities.Companion")))
@interface SorawalletSoraWalletSbApyCase2ResponseDataEntitiesCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletSbApyCase2ResponseDataEntitiesCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2ResponseDataEntitiesNode")))
@interface SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNode : SorawalletBase
- (instancetype)initWithId:(NSString *)id strategicBonusApy:(NSString * _Nullable)strategicBonusApy __attribute__((swift_name("init(id:strategicBonusApy:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNodeCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNode *)doCopyId:(NSString *)id strategicBonusApy:(NSString * _Nullable)strategicBonusApy __attribute__((swift_name("doCopy(id:strategicBonusApy:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable strategicBonusApy __attribute__((swift_name("strategicBonusApy")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraWalletSbApyCase2ResponseDataEntitiesNode.Companion")))
@interface SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletSoraWalletSbApyCase2ResponseDataEntitiesNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExpectInfoKt")))
@interface SorawalletExpectInfoKt : SorawalletBase
@property (class, readonly) NSString *platform_android __attribute__((swift_name("platform_android")));
@property (class, readonly) NSString *platform_ios __attribute__((swift_name("platform_ios")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ActualInfoKt")))
@interface SorawalletActualInfoKt : SorawalletBase
+ (NSString *)platform __attribute__((swift_name("platform()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TbdActualInfoIosKt")))
@interface SorawalletTbdActualInfoIosKt : SorawalletBase
+ (NSString *)shaA:(SorawalletKotlinByteArray *)a __attribute__((swift_name("sha(a:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoramitsuNetworkClientKt")))
@interface SorawalletSoramitsuNetworkClientKt : SorawalletBase
+ (id<SorawalletKtor_httpHeaders>)plus:(id<SorawalletKtor_httpHeaders>)receiver other:(id<SorawalletKtor_httpHeaders>)other __attribute__((swift_name("plus(_:other:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CommonSubQueryRequestKt")))
@interface SorawalletCommonSubQueryRequestKt : SorawalletBase
@property (class, readonly) NSString *varAfterCursor __attribute__((swift_name("varAfterCursor")));
@property (class, readonly) NSString *varCountRemote __attribute__((swift_name("varCountRemote")));
@property (class, readonly) NSString *varMyAddress __attribute__((swift_name("varMyAddress")));
@end

__attribute__((swift_name("RuntimeTransactionCallbacks")))
@protocol SorawalletRuntimeTransactionCallbacks
@required
- (void)afterCommitFunction:(void (^)(void))function __attribute__((swift_name("afterCommit(function:)")));
- (void)afterRollbackFunction:(void (^)(void))function __attribute__((swift_name("afterRollback(function:)")));
@end

__attribute__((swift_name("RuntimeTransactionWithoutReturn")))
@protocol SorawalletRuntimeTransactionWithoutReturn <SorawalletRuntimeTransactionCallbacks>
@required
- (void)rollback __attribute__((swift_name("rollback()")));
- (void)transactionBody:(void (^)(id<SorawalletRuntimeTransactionWithoutReturn>))body __attribute__((swift_name("transaction(body:)")));
@end

__attribute__((swift_name("RuntimeTransactionWithReturn")))
@protocol SorawalletRuntimeTransactionWithReturn <SorawalletRuntimeTransactionCallbacks>
@required
- (void)rollbackReturnValue:(id _Nullable)returnValue __attribute__((swift_name("rollback(returnValue:)")));
- (id _Nullable)transactionBody_:(id _Nullable (^)(id<SorawalletRuntimeTransactionWithReturn>))body __attribute__((swift_name("transaction(body_:)")));
@end

__attribute__((swift_name("RuntimeCloseable")))
@protocol SorawalletRuntimeCloseable
@required
- (void)close __attribute__((swift_name("close()")));
@end

__attribute__((swift_name("RuntimeSqlDriver")))
@protocol SorawalletRuntimeSqlDriver <SorawalletRuntimeCloseable>
@required
- (SorawalletRuntimeTransacterTransaction * _Nullable)currentTransaction __attribute__((swift_name("currentTransaction()")));
- (void)executeIdentifier:(SorawalletInt * _Nullable)identifier sql:(NSString *)sql parameters:(int32_t)parameters binders:(void (^ _Nullable)(id<SorawalletRuntimeSqlPreparedStatement>))binders __attribute__((swift_name("execute(identifier:sql:parameters:binders:)")));
- (id<SorawalletRuntimeSqlCursor>)executeQueryIdentifier:(SorawalletInt * _Nullable)identifier sql:(NSString *)sql parameters:(int32_t)parameters binders:(void (^ _Nullable)(id<SorawalletRuntimeSqlPreparedStatement>))binders __attribute__((swift_name("executeQuery(identifier:sql:parameters:binders:)")));
- (SorawalletRuntimeTransacterTransaction *)doNewTransaction __attribute__((swift_name("doNewTransaction()")));
@end

__attribute__((swift_name("RuntimeSqlDriverSchema")))
@protocol SorawalletRuntimeSqlDriverSchema
@required
- (void)createDriver:(id<SorawalletRuntimeSqlDriver>)driver __attribute__((swift_name("create(driver:)")));
- (void)migrateDriver:(id<SorawalletRuntimeSqlDriver>)driver oldVersion:(int32_t)oldVersion newVersion:(int32_t)newVersion __attribute__((swift_name("migrate(driver:oldVersion:newVersion:)")));
@property (readonly) int32_t version __attribute__((swift_name("version")));
@end

__attribute__((swift_name("RuntimeQuery")))
@interface SorawalletRuntimeQuery<__covariant RowType> : SorawalletBase
- (instancetype)initWithQueries:(NSMutableArray<SorawalletRuntimeQuery<id> *> *)queries mapper:(RowType (^)(id<SorawalletRuntimeSqlCursor>))mapper __attribute__((swift_name("init(queries:mapper:)"))) __attribute__((objc_designated_initializer));
- (void)addListenerListener:(id<SorawalletRuntimeQueryListener>)listener __attribute__((swift_name("addListener(listener:)")));
- (id<SorawalletRuntimeSqlCursor>)execute __attribute__((swift_name("execute()")));
- (NSArray<RowType> *)executeAsList __attribute__((swift_name("executeAsList()")));
- (RowType)executeAsOne __attribute__((swift_name("executeAsOne()")));
- (RowType _Nullable)executeAsOneOrNull __attribute__((swift_name("executeAsOneOrNull()")));
- (void)notifyDataChanged __attribute__((swift_name("notifyDataChanged()")));
- (void)removeListenerListener:(id<SorawalletRuntimeQueryListener>)listener __attribute__((swift_name("removeListener(listener:)")));
@property (readonly) RowType (^mapper)(id<SorawalletRuntimeSqlCursor>) __attribute__((swift_name("mapper")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializationStrategy")))
@protocol SorawalletKotlinx_serialization_coreSerializationStrategy
@required
- (void)serializeEncoder:(id<SorawalletKotlinx_serialization_coreEncoder>)encoder value:(id _Nullable)value __attribute__((swift_name("serialize(encoder:value:)")));
@property (readonly) id<SorawalletKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDeserializationStrategy")))
@protocol SorawalletKotlinx_serialization_coreDeserializationStrategy
@required
- (id _Nullable)deserializeDecoder:(id<SorawalletKotlinx_serialization_coreDecoder>)decoder __attribute__((swift_name("deserialize(decoder:)")));
@property (readonly) id<SorawalletKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreKSerializer")))
@protocol SorawalletKotlinx_serialization_coreKSerializer <SorawalletKotlinx_serialization_coreSerializationStrategy, SorawalletKotlinx_serialization_coreDeserializationStrategy>
@required
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlow")))
@protocol SorawalletKotlinx_coroutines_coreFlow
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)collectCollector:(id<SorawalletKotlinx_coroutines_coreFlowCollector>)collector completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("collect(collector:completionHandler:)")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngineFactory")))
@protocol SorawalletKtor_client_coreHttpClientEngineFactory
@required
- (id<SorawalletKtor_client_coreHttpClientEngine>)createBlock:(void (^)(SorawalletKtor_client_coreHttpClientEngineConfig *))block __attribute__((swift_name("create(block:)")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialFormat")))
@protocol SorawalletKotlinx_serialization_coreSerialFormat
@required
@property (readonly) SorawalletKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreStringFormat")))
@protocol SorawalletKotlinx_serialization_coreStringFormat <SorawalletKotlinx_serialization_coreSerialFormat>
@required
- (id _Nullable)decodeFromStringDeserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer string:(NSString *)string __attribute__((swift_name("decodeFromString(deserializer:string:)")));
- (NSString *)encodeToStringSerializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeToString(serializer:value:)")));
@end

__attribute__((swift_name("Kotlinx_serialization_jsonJson")))
@interface SorawalletKotlinx_serialization_jsonJson : SorawalletBase <SorawalletKotlinx_serialization_coreStringFormat>
@property (class, readonly, getter=companion) SorawalletKotlinx_serialization_jsonJsonDefault *companion __attribute__((swift_name("companion")));
- (id _Nullable)decodeFromJsonElementDeserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer element:(SorawalletKotlinx_serialization_jsonJsonElement *)element __attribute__((swift_name("decodeFromJsonElement(deserializer:element:)")));
- (id _Nullable)decodeFromStringString:(NSString *)string __attribute__((swift_name("decodeFromString(string:)")));
- (id _Nullable)decodeFromStringDeserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer string:(NSString *)string __attribute__((swift_name("decodeFromString(deserializer:string:)")));
- (SorawalletKotlinx_serialization_jsonJsonElement *)encodeToJsonElementSerializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeToJsonElement(serializer:value:)")));
- (NSString *)encodeToStringSerializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeToString(serializer:value:)")));
- (SorawalletKotlinx_serialization_jsonJsonElement *)parseToJsonElementString:(NSString *)string __attribute__((swift_name("parseToJsonElement(string:)")));
@property (readonly) SorawalletKotlinx_serialization_jsonJsonConfiguration *configuration __attribute__((swift_name("configuration")));
@property (readonly) SorawalletKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineScope")))
@protocol SorawalletKotlinx_coroutines_coreCoroutineScope
@required
@property (readonly) id<SorawalletKotlinCoroutineContext> coroutineContext __attribute__((swift_name("coroutineContext")));
@end

__attribute__((swift_name("Ktor_ioCloseable")))
@protocol SorawalletKtor_ioCloseable
@required
- (void)close __attribute__((swift_name("close()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpClient")))
@interface SorawalletKtor_client_coreHttpClient : SorawalletBase <SorawalletKotlinx_coroutines_coreCoroutineScope, SorawalletKtor_ioCloseable>
- (instancetype)initWithEngine:(id<SorawalletKtor_client_coreHttpClientEngine>)engine userConfig:(SorawalletKtor_client_coreHttpClientConfig<SorawalletKtor_client_coreHttpClientEngineConfig *> *)userConfig __attribute__((swift_name("init(engine:userConfig:)"))) __attribute__((objc_designated_initializer));
- (void)close __attribute__((swift_name("close()")));
- (SorawalletKtor_client_coreHttpClient *)configBlock:(void (^)(SorawalletKtor_client_coreHttpClientConfig<id> *))block __attribute__((swift_name("config(block:)")));
- (BOOL)isSupportedCapability:(id<SorawalletKtor_client_coreHttpClientEngineCapability>)capability __attribute__((swift_name("isSupported(capability:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<SorawalletKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) id<SorawalletKotlinCoroutineContext> coroutineContext __attribute__((swift_name("coroutineContext")));
@property (readonly) id<SorawalletKtor_client_coreHttpClientEngine> engine __attribute__((swift_name("engine")));
@property (readonly) SorawalletKtor_client_coreHttpClientEngineConfig *engineConfig __attribute__((swift_name("engineConfig")));
@property (readonly) SorawalletKtor_eventsEvents *monitor __attribute__((swift_name("monitor")));
@property (readonly) SorawalletKtor_client_coreHttpReceivePipeline *receivePipeline __attribute__((swift_name("receivePipeline")));
@property (readonly) SorawalletKtor_client_coreHttpRequestPipeline *requestPipeline __attribute__((swift_name("requestPipeline")));
@property (readonly) SorawalletKtor_client_coreHttpResponsePipeline *responsePipeline __attribute__((swift_name("responsePipeline")));
@property (readonly) SorawalletKtor_client_coreHttpSendPipeline *sendPipeline __attribute__((swift_name("sendPipeline")));
@end

__attribute__((swift_name("KotlinException")))
@interface SorawalletKotlinException : SorawalletKotlinThrowable
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinRuntimeException")))
@interface SorawalletKotlinRuntimeException : SorawalletKotlinException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinIllegalStateException")))
@interface SorawalletKotlinIllegalStateException : SorawalletKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.4")
*/
__attribute__((swift_name("KotlinCancellationException")))
@interface SorawalletKotlinCancellationException : SorawalletKotlinIllegalStateException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpMethod")))
@interface SorawalletKtor_httpHttpMethod : SorawalletBase
- (instancetype)initWithValue:(NSString *)value __attribute__((swift_name("init(value:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_httpHttpMethodCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKtor_httpHttpMethod *)doCopyValue:(NSString *)value __attribute__((swift_name("doCopy(value:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinPair")))
@interface SorawalletKotlinPair<__covariant A, __covariant B> : SorawalletBase
- (instancetype)initWithFirst:(A _Nullable)first second:(B _Nullable)second __attribute__((swift_name("init(first:second:)"))) __attribute__((objc_designated_initializer));
- (SorawalletKotlinPair<A, B> *)doCopyFirst:(A _Nullable)first second:(B _Nullable)second __attribute__((swift_name("doCopy(first:second:)")));
- (BOOL)equalsOther:(id _Nullable)other __attribute__((swift_name("equals(other:)")));
- (int32_t)hashCode __attribute__((swift_name("hashCode()")));
- (NSString *)toString __attribute__((swift_name("toString()")));
@property (readonly) A _Nullable first __attribute__((swift_name("first")));
@property (readonly) B _Nullable second __attribute__((swift_name("second")));
@end

__attribute__((swift_name("Ktor_httpHeaderValueWithParameters")))
@interface SorawalletKtor_httpHeaderValueWithParameters : SorawalletBase
- (instancetype)initWithContent:(NSString *)content parameters:(NSArray<SorawalletKtor_httpHeaderValueParam *> *)parameters __attribute__((swift_name("init(content:parameters:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_httpHeaderValueWithParametersCompanion *companion __attribute__((swift_name("companion")));
- (NSString * _Nullable)parameterName:(NSString *)name __attribute__((swift_name("parameter(name:)")));
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) NSString *content __attribute__((swift_name("content")));
@property (readonly) NSArray<SorawalletKtor_httpHeaderValueParam *> *parameters __attribute__((swift_name("parameters")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpContentType")))
@interface SorawalletKtor_httpContentType : SorawalletKtor_httpHeaderValueWithParameters
- (instancetype)initWithContentType:(NSString *)contentType contentSubtype:(NSString *)contentSubtype parameters:(NSArray<SorawalletKtor_httpHeaderValueParam *> *)parameters __attribute__((swift_name("init(contentType:contentSubtype:parameters:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithContent:(NSString *)content parameters:(NSArray<SorawalletKtor_httpHeaderValueParam *> *)parameters __attribute__((swift_name("init(content:parameters:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_httpContentTypeCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (BOOL)matchPattern:(SorawalletKtor_httpContentType *)pattern __attribute__((swift_name("match(pattern:)")));
- (BOOL)matchPattern_:(NSString *)pattern __attribute__((swift_name("match(pattern_:)")));
- (SorawalletKtor_httpContentType *)withParameterName:(NSString *)name value:(NSString *)value __attribute__((swift_name("withParameter(name:value:)")));
- (SorawalletKtor_httpContentType *)withoutParameters __attribute__((swift_name("withoutParameters()")));
@property (readonly) NSString *contentSubtype __attribute__((swift_name("contentSubtype")));
@property (readonly) NSString *contentType __attribute__((swift_name("contentType")));
@end

__attribute__((swift_name("Ktor_httpHttpMessage")))
@protocol SorawalletKtor_httpHttpMessage
@required
@property (readonly) id<SorawalletKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@end

__attribute__((swift_name("Ktor_client_coreHttpResponse")))
@interface SorawalletKtor_client_coreHttpResponse : SorawalletBase <SorawalletKtor_httpHttpMessage, SorawalletKotlinx_coroutines_coreCoroutineScope>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletKtor_client_coreHttpClientCall *call __attribute__((swift_name("call")));
@property (readonly) id<SorawalletKtor_ioByteReadChannel> content __attribute__((swift_name("content")));
@property (readonly) SorawalletKtor_utilsGMTDate *requestTime __attribute__((swift_name("requestTime")));
@property (readonly) SorawalletKtor_utilsGMTDate *responseTime __attribute__((swift_name("responseTime")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *status __attribute__((swift_name("status")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *version_ __attribute__((swift_name("version_")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinArray")))
@interface SorawalletKotlinArray<T> : SorawalletBase
+ (instancetype)arrayWithSize:(int32_t)size init:(T _Nullable (^)(SorawalletInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (T _Nullable)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (id<SorawalletKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(T _Nullable)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("KotlinIllegalArgumentException")))
@interface SorawalletKotlinIllegalArgumentException : SorawalletKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable(with=NormalClass(value=kotlinx/serialization/json/JsonElementSerializer))
*/
__attribute__((swift_name("Kotlinx_serialization_jsonJsonElement")))
@interface SorawalletKotlinx_serialization_jsonJsonElement : SorawalletBase
@property (class, readonly, getter=companion) SorawalletKotlinx_serialization_jsonJsonElementCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((swift_name("Multiplatform_settingsSettings")))
@protocol SorawalletMultiplatform_settingsSettings
@required
- (void)clear __attribute__((swift_name("clear()")));
- (BOOL)getBooleanKey:(NSString *)key defaultValue:(BOOL)defaultValue __attribute__((swift_name("getBoolean(key:defaultValue:)")));
- (SorawalletBoolean * _Nullable)getBooleanOrNullKey:(NSString *)key __attribute__((swift_name("getBooleanOrNull(key:)")));
- (double)getDoubleKey:(NSString *)key defaultValue:(double)defaultValue __attribute__((swift_name("getDouble(key:defaultValue:)")));
- (SorawalletDouble * _Nullable)getDoubleOrNullKey:(NSString *)key __attribute__((swift_name("getDoubleOrNull(key:)")));
- (float)getFloatKey:(NSString *)key defaultValue:(float)defaultValue __attribute__((swift_name("getFloat(key:defaultValue:)")));
- (SorawalletFloat * _Nullable)getFloatOrNullKey:(NSString *)key __attribute__((swift_name("getFloatOrNull(key:)")));
- (int32_t)getIntKey:(NSString *)key defaultValue:(int32_t)defaultValue __attribute__((swift_name("getInt(key:defaultValue:)")));
- (SorawalletInt * _Nullable)getIntOrNullKey:(NSString *)key __attribute__((swift_name("getIntOrNull(key:)")));
- (int64_t)getLongKey:(NSString *)key defaultValue:(int64_t)defaultValue __attribute__((swift_name("getLong(key:defaultValue:)")));
- (SorawalletLong * _Nullable)getLongOrNullKey:(NSString *)key __attribute__((swift_name("getLongOrNull(key:)")));
- (NSString *)getStringKey:(NSString *)key defaultValue:(NSString *)defaultValue __attribute__((swift_name("getString(key:defaultValue:)")));
- (NSString * _Nullable)getStringOrNullKey:(NSString *)key __attribute__((swift_name("getStringOrNull(key:)")));
- (BOOL)hasKeyKey:(NSString *)key __attribute__((swift_name("hasKey(key:)")));
- (void)putBooleanKey:(NSString *)key value:(BOOL)value __attribute__((swift_name("putBoolean(key:value:)")));
- (void)putDoubleKey:(NSString *)key value:(double)value __attribute__((swift_name("putDouble(key:value:)")));
- (void)putFloatKey:(NSString *)key value:(float)value __attribute__((swift_name("putFloat(key:value:)")));
- (void)putIntKey:(NSString *)key value:(int32_t)value __attribute__((swift_name("putInt(key:value:)")));
- (void)putLongKey:(NSString *)key value:(int64_t)value __attribute__((swift_name("putLong(key:value:)")));
- (void)putStringKey:(NSString *)key value:(NSString *)value __attribute__((swift_name("putString(key:value:)")));
- (void)removeKey:(NSString *)key __attribute__((swift_name("remove(key:)")));
@property (readonly) NSSet<NSString *> *keys __attribute__((swift_name("keys")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinByteArray")))
@interface SorawalletKotlinByteArray : SorawalletBase
+ (instancetype)arrayWithSize:(int32_t)size __attribute__((swift_name("init(size:)")));
+ (instancetype)arrayWithSize:(int32_t)size init:(SorawalletByte *(^)(SorawalletInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (int8_t)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (SorawalletKotlinByteIterator *)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(int8_t)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("Ktor_utilsStringValues")))
@protocol SorawalletKtor_utilsStringValues
@required
- (BOOL)containsName:(NSString *)name __attribute__((swift_name("contains(name:)")));
- (BOOL)containsName:(NSString *)name value:(NSString *)value __attribute__((swift_name("contains(name:value:)")));
- (NSSet<id<SorawalletKotlinMapEntry>> *)entries __attribute__((swift_name("entries()")));
- (void)forEachBody:(void (^)(NSString *, NSArray<NSString *> *))body __attribute__((swift_name("forEach(body:)")));
- (NSString * _Nullable)getName:(NSString *)name __attribute__((swift_name("get(name:)")));
- (NSArray<NSString *> * _Nullable)getAllName:(NSString *)name __attribute__((swift_name("getAll(name:)")));
- (BOOL)isEmpty __attribute__((swift_name("isEmpty()")));
- (NSSet<NSString *> *)names __attribute__((swift_name("names()")));
@property (readonly) BOOL caseInsensitiveName __attribute__((swift_name("caseInsensitiveName")));
@end

__attribute__((swift_name("Ktor_httpHeaders")))
@protocol SorawalletKtor_httpHeaders <SorawalletKtor_utilsStringValues>
@required
@end

__attribute__((swift_name("RuntimeTransacterTransaction")))
@interface SorawalletRuntimeTransacterTransaction : SorawalletBase <SorawalletRuntimeTransactionCallbacks>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)afterCommitFunction:(void (^)(void))function __attribute__((swift_name("afterCommit(function:)")));
- (void)afterRollbackFunction:(void (^)(void))function __attribute__((swift_name("afterRollback(function:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)endTransactionSuccessful:(BOOL)successful __attribute__((swift_name("endTransaction(successful:)")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) SorawalletRuntimeTransacterTransaction * _Nullable enclosingTransaction __attribute__((swift_name("enclosingTransaction")));
@end

__attribute__((swift_name("RuntimeSqlPreparedStatement")))
@protocol SorawalletRuntimeSqlPreparedStatement
@required
- (void)bindBytesIndex:(int32_t)index bytes:(SorawalletKotlinByteArray * _Nullable)bytes __attribute__((swift_name("bindBytes(index:bytes:)")));
- (void)bindDoubleIndex:(int32_t)index double:(SorawalletDouble * _Nullable)double_ __attribute__((swift_name("bindDouble(index:double:)")));
- (void)bindLongIndex:(int32_t)index long:(SorawalletLong * _Nullable)long_ __attribute__((swift_name("bindLong(index:long:)")));
- (void)bindStringIndex:(int32_t)index string:(NSString * _Nullable)string __attribute__((swift_name("bindString(index:string:)")));
@end

__attribute__((swift_name("RuntimeSqlCursor")))
@protocol SorawalletRuntimeSqlCursor <SorawalletRuntimeCloseable>
@required
- (SorawalletKotlinByteArray * _Nullable)getBytesIndex:(int32_t)index __attribute__((swift_name("getBytes(index:)")));
- (SorawalletDouble * _Nullable)getDoubleIndex:(int32_t)index __attribute__((swift_name("getDouble(index:)")));
- (SorawalletLong * _Nullable)getLongIndex:(int32_t)index __attribute__((swift_name("getLong(index:)")));
- (NSString * _Nullable)getStringIndex:(int32_t)index __attribute__((swift_name("getString(index:)")));
- (BOOL)next __attribute__((swift_name("next()")));
@end

__attribute__((swift_name("RuntimeQueryListener")))
@protocol SorawalletRuntimeQueryListener
@required
- (void)queryResultsChanged __attribute__((swift_name("queryResultsChanged()")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreEncoder")))
@protocol SorawalletKotlinx_serialization_coreEncoder
@required
- (id<SorawalletKotlinx_serialization_coreCompositeEncoder>)beginCollectionDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor collectionSize:(int32_t)collectionSize __attribute__((swift_name("beginCollection(descriptor:collectionSize:)")));
- (id<SorawalletKotlinx_serialization_coreCompositeEncoder>)beginStructureDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (void)encodeBooleanValue:(BOOL)value __attribute__((swift_name("encodeBoolean(value:)")));
- (void)encodeByteValue:(int8_t)value __attribute__((swift_name("encodeByte(value:)")));
- (void)encodeCharValue:(unichar)value __attribute__((swift_name("encodeChar(value:)")));
- (void)encodeDoubleValue:(double)value __attribute__((swift_name("encodeDouble(value:)")));
- (void)encodeEnumEnumDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)enumDescriptor index:(int32_t)index __attribute__((swift_name("encodeEnum(enumDescriptor:index:)")));
- (void)encodeFloatValue:(float)value __attribute__((swift_name("encodeFloat(value:)")));
- (id<SorawalletKotlinx_serialization_coreEncoder>)encodeInlineDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("encodeInline(descriptor:)")));
- (void)encodeIntValue:(int32_t)value __attribute__((swift_name("encodeInt(value:)")));
- (void)encodeLongValue:(int64_t)value __attribute__((swift_name("encodeLong(value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNotNullMark __attribute__((swift_name("encodeNotNullMark()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNull __attribute__((swift_name("encodeNull()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableValueSerializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableValue(serializer:value:)")));
- (void)encodeSerializableValueSerializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableValue(serializer:value:)")));
- (void)encodeShortValue:(int16_t)value __attribute__((swift_name("encodeShort(value:)")));
- (void)encodeStringValue:(NSString *)value __attribute__((swift_name("encodeString(value:)")));
@property (readonly) SorawalletKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialDescriptor")))
@protocol SorawalletKotlinx_serialization_coreSerialDescriptor
@required

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (NSArray<id<SorawalletKotlinAnnotation>> *)getElementAnnotationsIndex:(int32_t)index __attribute__((swift_name("getElementAnnotations(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SorawalletKotlinx_serialization_coreSerialDescriptor>)getElementDescriptorIndex:(int32_t)index __attribute__((swift_name("getElementDescriptor(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (int32_t)getElementIndexName:(NSString *)name __attribute__((swift_name("getElementIndex(name:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (NSString *)getElementNameIndex:(int32_t)index __attribute__((swift_name("getElementName(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)isElementOptionalIndex:(int32_t)index __attribute__((swift_name("isElementOptional(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSArray<id<SorawalletKotlinAnnotation>> *annotations __attribute__((swift_name("annotations")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) int32_t elementsCount __attribute__((swift_name("elementsCount")));
@property (readonly) BOOL isInline __attribute__((swift_name("isInline")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) BOOL isNullable __attribute__((swift_name("isNullable")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) SorawalletKotlinx_serialization_coreSerialKind *kind __attribute__((swift_name("kind")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSString *serialName __attribute__((swift_name("serialName")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDecoder")))
@protocol SorawalletKotlinx_serialization_coreDecoder
@required
- (id<SorawalletKotlinx_serialization_coreCompositeDecoder>)beginStructureDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (BOOL)decodeBoolean __attribute__((swift_name("decodeBoolean()")));
- (int8_t)decodeByte __attribute__((swift_name("decodeByte()")));
- (unichar)decodeChar __attribute__((swift_name("decodeChar()")));
- (double)decodeDouble __attribute__((swift_name("decodeDouble()")));
- (int32_t)decodeEnumEnumDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)enumDescriptor __attribute__((swift_name("decodeEnum(enumDescriptor:)")));
- (float)decodeFloat __attribute__((swift_name("decodeFloat()")));
- (id<SorawalletKotlinx_serialization_coreDecoder>)decodeInlineDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeInline(descriptor:)")));
- (int32_t)decodeInt __attribute__((swift_name("decodeInt()")));
- (int64_t)decodeLong __attribute__((swift_name("decodeLong()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeNotNullMark __attribute__((swift_name("decodeNotNullMark()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (SorawalletKotlinNothing * _Nullable)decodeNull __attribute__((swift_name("decodeNull()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableValueDeserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeNullableSerializableValue(deserializer:)")));
- (id _Nullable)decodeSerializableValueDeserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeSerializableValue(deserializer:)")));
- (int16_t)decodeShort __attribute__((swift_name("decodeShort()")));
- (NSString *)decodeString __attribute__((swift_name("decodeString()")));
@property (readonly) SorawalletKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlowCollector")))
@protocol SorawalletKotlinx_coroutines_coreFlowCollector
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitValue:(id _Nullable)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("emit(value:completionHandler:)")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngine")))
@protocol SorawalletKtor_client_coreHttpClientEngine <SorawalletKotlinx_coroutines_coreCoroutineScope, SorawalletKtor_ioCloseable>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeData:(SorawalletKtor_client_coreHttpRequestData *)data completionHandler:(void (^)(SorawalletKtor_client_coreHttpResponseData * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("execute(data:completionHandler:)")));
- (void)installClient:(SorawalletKtor_client_coreHttpClient *)client __attribute__((swift_name("install(client:)")));
@property (readonly) SorawalletKtor_client_coreHttpClientEngineConfig *config __attribute__((swift_name("config")));
@property (readonly) SorawalletKotlinx_coroutines_coreCoroutineDispatcher *dispatcher __attribute__((swift_name("dispatcher")));
@property (readonly) NSSet<id<SorawalletKtor_client_coreHttpClientEngineCapability>> *supportedCapabilities __attribute__((swift_name("supportedCapabilities")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngineConfig")))
@interface SorawalletKtor_client_coreHttpClientEngineConfig : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property BOOL pipelining __attribute__((swift_name("pipelining")));
@property SorawalletKtor_client_coreProxyConfig * _Nullable proxy __attribute__((swift_name("proxy")));
@property int32_t threadsCount __attribute__((swift_name("threadsCount")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializersModule")))
@interface SorawalletKotlinx_serialization_coreSerializersModule : SorawalletBase

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)dumpToCollector:(id<SorawalletKotlinx_serialization_coreSerializersModuleCollector>)collector __attribute__((swift_name("dumpTo(collector:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SorawalletKotlinx_serialization_coreKSerializer> _Nullable)getContextualKClass:(id<SorawalletKotlinKClass>)kClass typeArgumentsSerializers:(NSArray<id<SorawalletKotlinx_serialization_coreKSerializer>> *)typeArgumentsSerializers __attribute__((swift_name("getContextual(kClass:typeArgumentsSerializers:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SorawalletKotlinx_serialization_coreSerializationStrategy> _Nullable)getPolymorphicBaseClass:(id<SorawalletKotlinKClass>)baseClass value:(id)value __attribute__((swift_name("getPolymorphic(baseClass:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SorawalletKotlinx_serialization_coreDeserializationStrategy> _Nullable)getPolymorphicBaseClass:(id<SorawalletKotlinKClass>)baseClass serializedClassName:(NSString * _Nullable)serializedClassName __attribute__((swift_name("getPolymorphic(baseClass:serializedClassName:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJson.Default")))
@interface SorawalletKotlinx_serialization_jsonJsonDefault : SorawalletKotlinx_serialization_jsonJson
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)default_ __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKotlinx_serialization_jsonJsonDefault *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJsonConfiguration")))
@interface SorawalletKotlinx_serialization_jsonJsonConfiguration : SorawalletBase
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL allowSpecialFloatingPointValues __attribute__((swift_name("allowSpecialFloatingPointValues")));
@property (readonly) BOOL allowStructuredMapKeys __attribute__((swift_name("allowStructuredMapKeys")));
@property (readonly) NSString *classDiscriminator __attribute__((swift_name("classDiscriminator")));
@property (readonly) BOOL coerceInputValues __attribute__((swift_name("coerceInputValues")));
@property (readonly) BOOL encodeDefaults __attribute__((swift_name("encodeDefaults")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) BOOL explicitNulls __attribute__((swift_name("explicitNulls")));
@property (readonly) BOOL ignoreUnknownKeys __attribute__((swift_name("ignoreUnknownKeys")));
@property (readonly) BOOL isLenient __attribute__((swift_name("isLenient")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) id<SorawalletKotlinx_serialization_jsonJsonNamingStrategy> _Nullable namingStrategy __attribute__((swift_name("namingStrategy")));
@property (readonly) BOOL prettyPrint __attribute__((swift_name("prettyPrint")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSString *prettyPrintIndent __attribute__((swift_name("prettyPrintIndent")));
@property (readonly) BOOL useAlternativeNames __attribute__((swift_name("useAlternativeNames")));
@property (readonly) BOOL useArrayPolymorphism __attribute__((swift_name("useArrayPolymorphism")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinCoroutineContext")))
@protocol SorawalletKotlinCoroutineContext
@required
- (id _Nullable)foldInitial:(id _Nullable)initial operation:(id _Nullable (^)(id _Nullable, id<SorawalletKotlinCoroutineContextElement>))operation __attribute__((swift_name("fold(initial:operation:)")));
- (id<SorawalletKotlinCoroutineContextElement> _Nullable)getKey:(id<SorawalletKotlinCoroutineContextKey>)key __attribute__((swift_name("get(key:)")));
- (id<SorawalletKotlinCoroutineContext>)minusKeyKey:(id<SorawalletKotlinCoroutineContextKey>)key __attribute__((swift_name("minusKey(key:)")));
- (id<SorawalletKotlinCoroutineContext>)plusContext:(id<SorawalletKotlinCoroutineContext>)context __attribute__((swift_name("plus(context:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpClientConfig")))
@interface SorawalletKtor_client_coreHttpClientConfig<T> : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SorawalletKtor_client_coreHttpClientConfig<T> *)clone __attribute__((swift_name("clone()")));
- (void)engineBlock:(void (^)(T))block __attribute__((swift_name("engine(block:)")));
- (void)installClient:(SorawalletKtor_client_coreHttpClient *)client __attribute__((swift_name("install(client:)")));
- (void)installPlugin:(id<SorawalletKtor_client_coreHttpClientPlugin>)plugin configure:(void (^)(id))configure __attribute__((swift_name("install(plugin:configure:)")));
- (void)installKey:(NSString *)key block:(void (^)(SorawalletKtor_client_coreHttpClient *))block __attribute__((swift_name("install(key:block:)")));
- (void)plusAssignOther:(SorawalletKtor_client_coreHttpClientConfig<T> *)other __attribute__((swift_name("plusAssign(other:)")));
@property BOOL developmentMode __attribute__((swift_name("developmentMode")));
@property BOOL expectSuccess __attribute__((swift_name("expectSuccess")));
@property BOOL followRedirects __attribute__((swift_name("followRedirects")));
@property BOOL useDefaultTransformers __attribute__((swift_name("useDefaultTransformers")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngineCapability")))
@protocol SorawalletKtor_client_coreHttpClientEngineCapability
@required
@end

__attribute__((swift_name("Ktor_utilsAttributes")))
@protocol SorawalletKtor_utilsAttributes
@required
- (id)computeIfAbsentKey:(SorawalletKtor_utilsAttributeKey<id> *)key block:(id (^)(void))block __attribute__((swift_name("computeIfAbsent(key:block:)")));
- (BOOL)containsKey:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("contains(key:)")));
- (id)getKey_:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("get(key_:)")));
- (id _Nullable)getOrNullKey:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("getOrNull(key:)")));
- (void)putKey:(SorawalletKtor_utilsAttributeKey<id> *)key value:(id)value __attribute__((swift_name("put(key:value:)")));
- (void)removeKey_:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("remove(key_:)")));
- (id)takeKey:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("take(key:)")));
- (id _Nullable)takeOrNullKey:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("takeOrNull(key:)")));
@property (readonly) NSArray<SorawalletKtor_utilsAttributeKey<id> *> *allKeys __attribute__((swift_name("allKeys")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_eventsEvents")))
@interface SorawalletKtor_eventsEvents : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)raiseDefinition:(SorawalletKtor_eventsEventDefinition<id> *)definition value:(id _Nullable)value __attribute__((swift_name("raise(definition:value:)")));
- (id<SorawalletKotlinx_coroutines_coreDisposableHandle>)subscribeDefinition:(SorawalletKtor_eventsEventDefinition<id> *)definition handler:(void (^)(id _Nullable))handler __attribute__((swift_name("subscribe(definition:handler:)")));
- (void)unsubscribeDefinition:(SorawalletKtor_eventsEventDefinition<id> *)definition handler:(void (^)(id _Nullable))handler __attribute__((swift_name("unsubscribe(definition:handler:)")));
@end

__attribute__((swift_name("Ktor_utilsPipeline")))
@interface SorawalletKtor_utilsPipeline<TSubject, TContext> : SorawalletBase
- (instancetype)initWithPhase:(SorawalletKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<SorawalletKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhases:(SorawalletKotlinArray<SorawalletKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer));
- (void)addPhasePhase:(SorawalletKtor_utilsPipelinePhase *)phase __attribute__((swift_name("addPhase(phase:)")));
- (void)afterIntercepted __attribute__((swift_name("afterIntercepted()")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeContext:(TContext)context subject:(TSubject)subject completionHandler:(void (^)(TSubject _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("execute(context:subject:completionHandler:)")));
- (void)insertPhaseAfterReference:(SorawalletKtor_utilsPipelinePhase *)reference phase:(SorawalletKtor_utilsPipelinePhase *)phase __attribute__((swift_name("insertPhaseAfter(reference:phase:)")));
- (void)insertPhaseBeforeReference:(SorawalletKtor_utilsPipelinePhase *)reference phase:(SorawalletKtor_utilsPipelinePhase *)phase __attribute__((swift_name("insertPhaseBefore(reference:phase:)")));
- (void)interceptPhase:(SorawalletKtor_utilsPipelinePhase *)phase block:(id<SorawalletKotlinSuspendFunction2>)block __attribute__((swift_name("intercept(phase:block:)")));
- (NSArray<id<SorawalletKotlinSuspendFunction2>> *)interceptorsForPhasePhase:(SorawalletKtor_utilsPipelinePhase *)phase __attribute__((swift_name("interceptorsForPhase(phase:)")));
- (void)mergeFrom:(SorawalletKtor_utilsPipeline<TSubject, TContext> *)from __attribute__((swift_name("merge(from:)")));
- (void)mergePhasesFrom:(SorawalletKtor_utilsPipeline<TSubject, TContext> *)from __attribute__((swift_name("mergePhases(from:)")));
- (void)resetFromFrom:(SorawalletKtor_utilsPipeline<TSubject, TContext> *)from __attribute__((swift_name("resetFrom(from:)")));
@property (readonly) id<SorawalletKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@property (readonly, getter=isEmpty_) BOOL isEmpty __attribute__((swift_name("isEmpty")));
@property (readonly) NSArray<SorawalletKtor_utilsPipelinePhase *> *items __attribute__((swift_name("items")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpReceivePipeline")))
@interface SorawalletKtor_client_coreHttpReceivePipeline : SorawalletKtor_utilsPipeline<SorawalletKtor_client_coreHttpResponse *, SorawalletKotlinUnit *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhase:(SorawalletKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<SorawalletKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhases:(SorawalletKotlinArray<SorawalletKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_client_coreHttpReceivePipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestPipeline")))
@interface SorawalletKtor_client_coreHttpRequestPipeline : SorawalletKtor_utilsPipeline<id, SorawalletKtor_client_coreHttpRequestBuilder *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhase:(SorawalletKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<SorawalletKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhases:(SorawalletKotlinArray<SorawalletKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_client_coreHttpRequestPipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponsePipeline")))
@interface SorawalletKtor_client_coreHttpResponsePipeline : SorawalletKtor_utilsPipeline<SorawalletKtor_client_coreHttpResponseContainer *, SorawalletKtor_client_coreHttpClientCall *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhase:(SorawalletKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<SorawalletKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhases:(SorawalletKotlinArray<SorawalletKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_client_coreHttpResponsePipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpSendPipeline")))
@interface SorawalletKtor_client_coreHttpSendPipeline : SorawalletKtor_utilsPipeline<id, SorawalletKtor_client_coreHttpRequestBuilder *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhase:(SorawalletKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<SorawalletKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhases:(SorawalletKotlinArray<SorawalletKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_client_coreHttpSendPipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpMethod.Companion")))
@interface SorawalletKtor_httpHttpMethodCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpHttpMethodCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_httpHttpMethod *)parseMethod:(NSString *)method __attribute__((swift_name("parse(method:)")));
@property (readonly) NSArray<SorawalletKtor_httpHttpMethod *> *DefaultMethods __attribute__((swift_name("DefaultMethods")));
@property (readonly) SorawalletKtor_httpHttpMethod *Delete __attribute__((swift_name("Delete")));
@property (readonly) SorawalletKtor_httpHttpMethod *Get __attribute__((swift_name("Get")));
@property (readonly) SorawalletKtor_httpHttpMethod *Head __attribute__((swift_name("Head")));
@property (readonly) SorawalletKtor_httpHttpMethod *Options __attribute__((swift_name("Options")));
@property (readonly) SorawalletKtor_httpHttpMethod *Patch __attribute__((swift_name("Patch")));
@property (readonly) SorawalletKtor_httpHttpMethod *Post __attribute__((swift_name("Post")));
@property (readonly) SorawalletKtor_httpHttpMethod *Put __attribute__((swift_name("Put")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHeaderValueParam")))
@interface SorawalletKtor_httpHeaderValueParam : SorawalletBase
- (instancetype)initWithName:(NSString *)name value:(NSString *)value __attribute__((swift_name("init(name:value:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithName:(NSString *)name value:(NSString *)value escapeValue:(BOOL)escapeValue __attribute__((swift_name("init(name:value:escapeValue:)"))) __attribute__((objc_designated_initializer));
- (SorawalletKtor_httpHeaderValueParam *)doCopyName:(NSString *)name value:(NSString *)value escapeValue:(BOOL)escapeValue __attribute__((swift_name("doCopy(name:value:escapeValue:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL escapeValue __attribute__((swift_name("escapeValue")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHeaderValueWithParameters.Companion")))
@interface SorawalletKtor_httpHeaderValueWithParametersCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpHeaderValueWithParametersCompanion *shared __attribute__((swift_name("shared")));
- (id _Nullable)parseValue:(NSString *)value init:(id _Nullable (^)(NSString *, NSArray<SorawalletKtor_httpHeaderValueParam *> *))init __attribute__((swift_name("parse(value:init:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpContentType.Companion")))
@interface SorawalletKtor_httpContentTypeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpContentTypeCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_httpContentType *)parseValue:(NSString *)value __attribute__((swift_name("parse(value:)")));
@property (readonly) SorawalletKtor_httpContentType *Any __attribute__((swift_name("Any")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientCall")))
@interface SorawalletKtor_client_coreHttpClientCall : SorawalletBase <SorawalletKotlinx_coroutines_coreCoroutineScope>
- (instancetype)initWithClient:(SorawalletKtor_client_coreHttpClient *)client requestData:(SorawalletKtor_client_coreHttpRequestData *)requestData responseData:(SorawalletKtor_client_coreHttpResponseData *)responseData __attribute__((swift_name("init(client:requestData:responseData:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithClient:(SorawalletKtor_client_coreHttpClient *)client __attribute__((swift_name("init(client:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_client_coreHttpClientCallCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)bodyInfo:(SorawalletKtor_utilsTypeInfo *)info completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("body(info:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)bodyNullableInfo:(SorawalletKtor_utilsTypeInfo *)info completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("bodyNullable(info:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)getResponseContentWithCompletionHandler:(void (^)(id<SorawalletKtor_ioByteReadChannel> _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getResponseContent(completionHandler:)")));
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) BOOL allowDoubleReceive __attribute__((swift_name("allowDoubleReceive")));
@property (readonly) id<SorawalletKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) SorawalletKtor_client_coreHttpClient *client __attribute__((swift_name("client")));
@property (readonly) id<SorawalletKotlinCoroutineContext> coroutineContext __attribute__((swift_name("coroutineContext")));
@property id<SorawalletKtor_client_coreHttpRequest> request __attribute__((swift_name("request")));
@property SorawalletKtor_client_coreHttpResponse *response __attribute__((swift_name("response")));
@end

__attribute__((swift_name("Ktor_ioByteReadChannel")))
@protocol SorawalletKtor_ioByteReadChannel
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)awaitContentWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("awaitContent(completionHandler:)")));
- (BOOL)cancelCause:(SorawalletKotlinThrowable * _Nullable)cause __attribute__((swift_name("cancel(cause:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)discardMax:(int64_t)max completionHandler:(void (^)(SorawalletLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("discard(max:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)peekToDestination:(SorawalletKtor_ioMemory *)destination destinationOffset:(int64_t)destinationOffset offset:(int64_t)offset min:(int64_t)min max:(int64_t)max completionHandler:(void (^)(SorawalletLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("peekTo(destination:destinationOffset:offset:min:max:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(SorawalletKtor_ioChunkBuffer *)dst completionHandler:(void (^)(SorawalletInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(SorawalletKotlinByteArray *)dst offset:(int32_t)offset length:(int32_t)length completionHandler:(void (^)(SorawalletInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:offset:length:completionHandler:)")));
- (int32_t)readAvailableMin:(int32_t)min block:(void (^)(SorawalletKtor_ioBuffer *))block __attribute__((swift_name("readAvailable(min:block:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(void *)dst offset:(int32_t)offset length:(int32_t)length completionHandler_:(void (^)(SorawalletInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:offset:length:completionHandler_:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(void *)dst offset:(int64_t)offset length:(int64_t)length completionHandler__:(void (^)(SorawalletInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:offset:length:completionHandler__:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readBooleanWithCompletionHandler:(void (^)(SorawalletBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readBoolean(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readByteWithCompletionHandler:(void (^)(SorawalletByte * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readByte(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readDoubleWithCompletionHandler:(void (^)(SorawalletDouble * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readDouble(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFloatWithCompletionHandler:(void (^)(SorawalletFloat * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readFloat(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(SorawalletKtor_ioChunkBuffer *)dst n:(int32_t)n completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:n:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(SorawalletKotlinByteArray *)dst offset:(int32_t)offset length:(int32_t)length completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:offset:length:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(void *)dst offset:(int32_t)offset length:(int32_t)length completionHandler_:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:offset:length:completionHandler_:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(void *)dst offset:(int64_t)offset length:(int64_t)length completionHandler__:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:offset:length:completionHandler__:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readIntWithCompletionHandler:(void (^)(SorawalletInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readInt(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readLongWithCompletionHandler:(void (^)(SorawalletLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readLong(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readPacketSize:(int32_t)size completionHandler:(void (^)(SorawalletKtor_ioByteReadPacket * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readPacket(size:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readRemainingLimit:(int64_t)limit completionHandler:(void (^)(SorawalletKtor_ioByteReadPacket * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readRemaining(limit:completionHandler:)")));
- (void)readSessionConsumer:(void (^)(id<SorawalletKtor_ioReadSession>))consumer __attribute__((swift_name("readSession(consumer:)"))) __attribute__((deprecated("Use read { } instead.")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readShortWithCompletionHandler:(void (^)(SorawalletShort * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readShort(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readSuspendableSessionConsumer:(id<SorawalletKotlinSuspendFunction1>)consumer completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readSuspendableSession(consumer:completionHandler:)"))) __attribute__((deprecated("Use read { } instead.")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readUTF8LineLimit:(int32_t)limit completionHandler:(void (^)(NSString * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("readUTF8Line(limit:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readUTF8LineToOut:(id<SorawalletKotlinAppendable>)out limit:(int32_t)limit completionHandler:(void (^)(SorawalletBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readUTF8LineTo(out:limit:completionHandler:)")));
@property (readonly) int32_t availableForRead __attribute__((swift_name("availableForRead")));
@property (readonly) SorawalletKotlinThrowable * _Nullable closedCause __attribute__((swift_name("closedCause")));
@property (readonly) BOOL isClosedForRead __attribute__((swift_name("isClosedForRead")));
@property (readonly) BOOL isClosedForWrite __attribute__((swift_name("isClosedForWrite")));
@property (readonly) int64_t totalBytesRead __attribute__((swift_name("totalBytesRead")));
@end

__attribute__((swift_name("KotlinComparable")))
@protocol SorawalletKotlinComparable
@required
- (int32_t)compareToOther:(id _Nullable)other __attribute__((swift_name("compareTo(other:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsGMTDate")))
@interface SorawalletKtor_utilsGMTDate : SorawalletBase <SorawalletKotlinComparable>
@property (class, readonly, getter=companion) SorawalletKtor_utilsGMTDateCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(SorawalletKtor_utilsGMTDate *)other __attribute__((swift_name("compareTo(other:)")));
- (SorawalletKtor_utilsGMTDate *)doCopySeconds:(int32_t)seconds minutes:(int32_t)minutes hours:(int32_t)hours dayOfWeek:(SorawalletKtor_utilsWeekDay *)dayOfWeek dayOfMonth:(int32_t)dayOfMonth dayOfYear:(int32_t)dayOfYear month:(SorawalletKtor_utilsMonth *)month year:(int32_t)year timestamp:(int64_t)timestamp __attribute__((swift_name("doCopy(seconds:minutes:hours:dayOfWeek:dayOfMonth:dayOfYear:month:year:timestamp:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t dayOfMonth __attribute__((swift_name("dayOfMonth")));
@property (readonly) SorawalletKtor_utilsWeekDay *dayOfWeek __attribute__((swift_name("dayOfWeek")));
@property (readonly) int32_t dayOfYear __attribute__((swift_name("dayOfYear")));
@property (readonly) int32_t hours __attribute__((swift_name("hours")));
@property (readonly) int32_t minutes __attribute__((swift_name("minutes")));
@property (readonly) SorawalletKtor_utilsMonth *month __attribute__((swift_name("month")));
@property (readonly) int32_t seconds __attribute__((swift_name("seconds")));
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));
@property (readonly) int32_t year __attribute__((swift_name("year")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpStatusCode")))
@interface SorawalletKtor_httpHttpStatusCode : SorawalletBase <SorawalletKotlinComparable>
- (instancetype)initWithValue:(int32_t)value description:(NSString *)description __attribute__((swift_name("init(value:description:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_httpHttpStatusCodeCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(SorawalletKtor_httpHttpStatusCode *)other __attribute__((swift_name("compareTo(other:)")));
- (SorawalletKtor_httpHttpStatusCode *)doCopyValue:(int32_t)value description:(NSString *)description __attribute__((swift_name("doCopy(value:description:)")));
- (SorawalletKtor_httpHttpStatusCode *)descriptionValue:(NSString *)value __attribute__((swift_name("description(value:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *description_ __attribute__((swift_name("description_")));
@property (readonly) int32_t value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpProtocolVersion")))
@interface SorawalletKtor_httpHttpProtocolVersion : SorawalletBase
- (instancetype)initWithName:(NSString *)name major:(int32_t)major minor:(int32_t)minor __attribute__((swift_name("init(name:major:minor:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_httpHttpProtocolVersionCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKtor_httpHttpProtocolVersion *)doCopyName:(NSString *)name major:(int32_t)major minor:(int32_t)minor __attribute__((swift_name("doCopy(name:major:minor:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t major __attribute__((swift_name("major")));
@property (readonly) int32_t minor __attribute__((swift_name("minor")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((swift_name("KotlinIterator")))
@protocol SorawalletKotlinIterator
@required
- (BOOL)hasNext __attribute__((swift_name("hasNext()")));
- (id _Nullable)next_ __attribute__((swift_name("next_()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJsonElement.Companion")))
@interface SorawalletKotlinx_serialization_jsonJsonElementCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKotlinx_serialization_jsonJsonElementCompanion *shared __attribute__((swift_name("shared")));
- (id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((swift_name("KotlinByteIterator")))
@interface SorawalletKotlinByteIterator : SorawalletBase <SorawalletKotlinIterator>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SorawalletByte *)next_ __attribute__((swift_name("next_()")));
- (int8_t)nextByte __attribute__((swift_name("nextByte()")));
@end

__attribute__((swift_name("KotlinMapEntry")))
@protocol SorawalletKotlinMapEntry
@required
@property (readonly) id _Nullable key __attribute__((swift_name("key")));
@property (readonly) id _Nullable value __attribute__((swift_name("value")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeEncoder")))
@protocol SorawalletKotlinx_serialization_coreCompositeEncoder
@required
- (void)encodeBooleanElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(BOOL)value __attribute__((swift_name("encodeBooleanElement(descriptor:index:value:)")));
- (void)encodeByteElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int8_t)value __attribute__((swift_name("encodeByteElement(descriptor:index:value:)")));
- (void)encodeCharElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(unichar)value __attribute__((swift_name("encodeCharElement(descriptor:index:value:)")));
- (void)encodeDoubleElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(double)value __attribute__((swift_name("encodeDoubleElement(descriptor:index:value:)")));
- (void)encodeFloatElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(float)value __attribute__((swift_name("encodeFloatElement(descriptor:index:value:)")));
- (id<SorawalletKotlinx_serialization_coreEncoder>)encodeInlineElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("encodeInlineElement(descriptor:index:)")));
- (void)encodeIntElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int32_t)value __attribute__((swift_name("encodeIntElement(descriptor:index:value:)")));
- (void)encodeLongElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int64_t)value __attribute__((swift_name("encodeLongElement(descriptor:index:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeSerializableElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<SorawalletKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeShortElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int16_t)value __attribute__((swift_name("encodeShortElement(descriptor:index:value:)")));
- (void)encodeStringElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(NSString *)value __attribute__((swift_name("encodeStringElement(descriptor:index:value:)")));
- (void)endStructureDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)shouldEncodeElementDefaultDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("shouldEncodeElementDefault(descriptor:index:)")));
@property (readonly) SorawalletKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("KotlinAnnotation")))
@protocol SorawalletKotlinAnnotation
@required
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerialKind")))
@interface SorawalletKotlinx_serialization_coreSerialKind : SorawalletBase
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeDecoder")))
@protocol SorawalletKotlinx_serialization_coreCompositeDecoder
@required
- (BOOL)decodeBooleanElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeBooleanElement(descriptor:index:)")));
- (int8_t)decodeByteElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeByteElement(descriptor:index:)")));
- (unichar)decodeCharElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeCharElement(descriptor:index:)")));
- (int32_t)decodeCollectionSizeDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeCollectionSize(descriptor:)")));
- (double)decodeDoubleElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeDoubleElement(descriptor:index:)")));
- (int32_t)decodeElementIndexDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeElementIndex(descriptor:)")));
- (float)decodeFloatElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeFloatElement(descriptor:index:)")));
- (id<SorawalletKotlinx_serialization_coreDecoder>)decodeInlineElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeInlineElement(descriptor:index:)")));
- (int32_t)decodeIntElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeIntElement(descriptor:index:)")));
- (int64_t)decodeLongElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeLongElement(descriptor:index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeNullableSerializableElement(descriptor:index:deserializer:previousValue:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeSequentially __attribute__((swift_name("decodeSequentially()")));
- (id _Nullable)decodeSerializableElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeSerializableElement(descriptor:index:deserializer:previousValue:)")));
- (int16_t)decodeShortElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeShortElement(descriptor:index:)")));
- (NSString *)decodeStringElementDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeStringElement(descriptor:index:)")));
- (void)endStructureDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));
@property (readonly) SorawalletKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinNothing")))
@interface SorawalletKotlinNothing : SorawalletBase
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestData")))
@interface SorawalletKtor_client_coreHttpRequestData : SorawalletBase
- (instancetype)initWithUrl:(SorawalletKtor_httpUrl *)url method:(SorawalletKtor_httpHttpMethod *)method headers:(id<SorawalletKtor_httpHeaders>)headers body:(SorawalletKtor_httpOutgoingContent *)body executionContext:(id<SorawalletKotlinx_coroutines_coreJob>)executionContext attributes:(id<SorawalletKtor_utilsAttributes>)attributes __attribute__((swift_name("init(url:method:headers:body:executionContext:attributes:)"))) __attribute__((objc_designated_initializer));
- (id _Nullable)getCapabilityOrNullKey:(id<SorawalletKtor_client_coreHttpClientEngineCapability>)key __attribute__((swift_name("getCapabilityOrNull(key:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<SorawalletKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) SorawalletKtor_httpOutgoingContent *body __attribute__((swift_name("body")));
@property (readonly) id<SorawalletKotlinx_coroutines_coreJob> executionContext __attribute__((swift_name("executionContext")));
@property (readonly) id<SorawalletKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@property (readonly) SorawalletKtor_httpHttpMethod *method __attribute__((swift_name("method")));
@property (readonly) SorawalletKtor_httpUrl *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponseData")))
@interface SorawalletKtor_client_coreHttpResponseData : SorawalletBase
- (instancetype)initWithStatusCode:(SorawalletKtor_httpHttpStatusCode *)statusCode requestTime:(SorawalletKtor_utilsGMTDate *)requestTime headers:(id<SorawalletKtor_httpHeaders>)headers version:(SorawalletKtor_httpHttpProtocolVersion *)version body:(id)body callContext:(id<SorawalletKotlinCoroutineContext>)callContext __attribute__((swift_name("init(statusCode:requestTime:headers:version:body:callContext:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id body __attribute__((swift_name("body")));
@property (readonly) id<SorawalletKotlinCoroutineContext> callContext __attribute__((swift_name("callContext")));
@property (readonly) id<SorawalletKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@property (readonly) SorawalletKtor_utilsGMTDate *requestTime __attribute__((swift_name("requestTime")));
@property (readonly) SorawalletKtor_utilsGMTDate *responseTime __attribute__((swift_name("responseTime")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *statusCode __attribute__((swift_name("statusCode")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *version __attribute__((swift_name("version")));
@end

__attribute__((swift_name("KotlinCoroutineContextElement")))
@protocol SorawalletKotlinCoroutineContextElement <SorawalletKotlinCoroutineContext>
@required
@property (readonly) id<SorawalletKotlinCoroutineContextKey> key __attribute__((swift_name("key")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinAbstractCoroutineContextElement")))
@interface SorawalletKotlinAbstractCoroutineContextElement : SorawalletBase <SorawalletKotlinCoroutineContextElement>
- (instancetype)initWithKey:(id<SorawalletKotlinCoroutineContextKey>)key __attribute__((swift_name("init(key:)"))) __attribute__((objc_designated_initializer));
@property (readonly) id<SorawalletKotlinCoroutineContextKey> key __attribute__((swift_name("key")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinContinuationInterceptor")))
@protocol SorawalletKotlinContinuationInterceptor <SorawalletKotlinCoroutineContextElement>
@required
- (id<SorawalletKotlinContinuation>)interceptContinuationContinuation:(id<SorawalletKotlinContinuation>)continuation __attribute__((swift_name("interceptContinuation(continuation:)")));
- (void)releaseInterceptedContinuationContinuation:(id<SorawalletKotlinContinuation>)continuation __attribute__((swift_name("releaseInterceptedContinuation(continuation:)")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineDispatcher")))
@interface SorawalletKotlinx_coroutines_coreCoroutineDispatcher : SorawalletKotlinAbstractCoroutineContextElement <SorawalletKotlinContinuationInterceptor>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithKey:(id<SorawalletKotlinCoroutineContextKey>)key __attribute__((swift_name("init(key:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKotlinx_coroutines_coreCoroutineDispatcherKey *companion __attribute__((swift_name("companion")));
- (void)dispatchContext:(id<SorawalletKotlinCoroutineContext>)context block:(id<SorawalletKotlinx_coroutines_coreRunnable>)block __attribute__((swift_name("dispatch(context:block:)")));
- (void)dispatchYieldContext:(id<SorawalletKotlinCoroutineContext>)context block:(id<SorawalletKotlinx_coroutines_coreRunnable>)block __attribute__((swift_name("dispatchYield(context:block:)")));
- (id<SorawalletKotlinContinuation>)interceptContinuationContinuation:(id<SorawalletKotlinContinuation>)continuation __attribute__((swift_name("interceptContinuation(continuation:)")));
- (BOOL)isDispatchNeededContext:(id<SorawalletKotlinCoroutineContext>)context __attribute__((swift_name("isDispatchNeeded(context:)")));

/**
 * @note annotations
 *   kotlinx.coroutines.ExperimentalCoroutinesApi
*/
- (SorawalletKotlinx_coroutines_coreCoroutineDispatcher *)limitedParallelismParallelism:(int32_t)parallelism __attribute__((swift_name("limitedParallelism(parallelism:)")));
- (SorawalletKotlinx_coroutines_coreCoroutineDispatcher *)plusOther:(SorawalletKotlinx_coroutines_coreCoroutineDispatcher *)other __attribute__((swift_name("plus(other:)"))) __attribute__((unavailable("Operator '+' on two CoroutineDispatcher objects is meaningless. CoroutineDispatcher is a coroutine context element and `+` is a set-sum operator for coroutine contexts. The dispatcher to the right of `+` just replaces the dispatcher to the left.")));
- (void)releaseInterceptedContinuationContinuation:(id<SorawalletKotlinContinuation>)continuation __attribute__((swift_name("releaseInterceptedContinuation(continuation:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreProxyConfig")))
@interface SorawalletKtor_client_coreProxyConfig : SorawalletBase
- (instancetype)initWithUrl:(SorawalletKtor_httpUrl *)url __attribute__((swift_name("init(url:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletKtor_httpUrl *url __attribute__((swift_name("url")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerializersModuleCollector")))
@protocol SorawalletKotlinx_serialization_coreSerializersModuleCollector
@required
- (void)contextualKClass:(id<SorawalletKotlinKClass>)kClass provider:(id<SorawalletKotlinx_serialization_coreKSerializer> (^)(NSArray<id<SorawalletKotlinx_serialization_coreKSerializer>> *))provider __attribute__((swift_name("contextual(kClass:provider:)")));
- (void)contextualKClass:(id<SorawalletKotlinKClass>)kClass serializer:(id<SorawalletKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("contextual(kClass:serializer:)")));
- (void)polymorphicBaseClass:(id<SorawalletKotlinKClass>)baseClass actualClass:(id<SorawalletKotlinKClass>)actualClass actualSerializer:(id<SorawalletKotlinx_serialization_coreKSerializer>)actualSerializer __attribute__((swift_name("polymorphic(baseClass:actualClass:actualSerializer:)")));
- (void)polymorphicDefaultBaseClass:(id<SorawalletKotlinKClass>)baseClass defaultDeserializerProvider:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefault(baseClass:defaultDeserializerProvider:)"))) __attribute__((deprecated("Deprecated in favor of function with more precise name: polymorphicDefaultDeserializer")));
- (void)polymorphicDefaultDeserializerBaseClass:(id<SorawalletKotlinKClass>)baseClass defaultDeserializerProvider:(id<SorawalletKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefaultDeserializer(baseClass:defaultDeserializerProvider:)")));
- (void)polymorphicDefaultSerializerBaseClass:(id<SorawalletKotlinKClass>)baseClass defaultSerializerProvider:(id<SorawalletKotlinx_serialization_coreSerializationStrategy> _Nullable (^)(id))defaultSerializerProvider __attribute__((swift_name("polymorphicDefaultSerializer(baseClass:defaultSerializerProvider:)")));
@end

__attribute__((swift_name("KotlinKDeclarationContainer")))
@protocol SorawalletKotlinKDeclarationContainer
@required
@end

__attribute__((swift_name("KotlinKAnnotatedElement")))
@protocol SorawalletKotlinKAnnotatedElement
@required
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((swift_name("KotlinKClassifier")))
@protocol SorawalletKotlinKClassifier
@required
@end

__attribute__((swift_name("KotlinKClass")))
@protocol SorawalletKotlinKClass <SorawalletKotlinKDeclarationContainer, SorawalletKotlinKAnnotatedElement, SorawalletKotlinKClassifier>
@required

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
- (BOOL)isInstanceValue:(id _Nullable)value __attribute__((swift_name("isInstance(value:)")));
@property (readonly) NSString * _Nullable qualifiedName __attribute__((swift_name("qualifiedName")));
@property (readonly) NSString * _Nullable simpleName __attribute__((swift_name("simpleName")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_jsonJsonNamingStrategy")))
@protocol SorawalletKotlinx_serialization_jsonJsonNamingStrategy
@required
- (NSString *)serialNameForJsonDescriptor:(id<SorawalletKotlinx_serialization_coreSerialDescriptor>)descriptor elementIndex:(int32_t)elementIndex serialName:(NSString *)serialName __attribute__((swift_name("serialNameForJson(descriptor:elementIndex:serialName:)")));
@end

__attribute__((swift_name("KotlinCoroutineContextKey")))
@protocol SorawalletKotlinCoroutineContextKey
@required
@end

__attribute__((swift_name("Ktor_client_coreHttpClientPlugin")))
@protocol SorawalletKtor_client_coreHttpClientPlugin
@required
- (void)installPlugin:(id)plugin scope:(SorawalletKtor_client_coreHttpClient *)scope __attribute__((swift_name("install(plugin:scope:)")));
- (id)prepareBlock:(void (^)(id))block __attribute__((swift_name("prepare(block:)")));
@property (readonly) SorawalletKtor_utilsAttributeKey<id> *key __attribute__((swift_name("key")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsAttributeKey")))
@interface SorawalletKtor_utilsAttributeKey<T> : SorawalletBase
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((swift_name("Ktor_eventsEventDefinition")))
@interface SorawalletKtor_eventsEventDefinition<T> : SorawalletBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreDisposableHandle")))
@protocol SorawalletKotlinx_coroutines_coreDisposableHandle
@required
- (void)dispose __attribute__((swift_name("dispose()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsPipelinePhase")))
@interface SorawalletKtor_utilsPipelinePhase : SorawalletBase
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((swift_name("KotlinFunction")))
@protocol SorawalletKotlinFunction
@required
@end

__attribute__((swift_name("KotlinSuspendFunction2")))
@protocol SorawalletKotlinSuspendFunction2 <SorawalletKotlinFunction>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)invokeP1:(id _Nullable)p1 p2:(id _Nullable)p2 completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("invoke(p1:p2:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpReceivePipeline.Phases")))
@interface SorawalletKtor_client_coreHttpReceivePipelinePhases : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_client_coreHttpReceivePipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *After __attribute__((swift_name("After")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Before __attribute__((swift_name("Before")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinUnit")))
@interface SorawalletKotlinUnit : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)unit __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKotlinUnit *shared __attribute__((swift_name("shared")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestPipeline.Phases")))
@interface SorawalletKtor_client_coreHttpRequestPipelinePhases : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_client_coreHttpRequestPipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Before __attribute__((swift_name("Before")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Render __attribute__((swift_name("Render")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Send __attribute__((swift_name("Send")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Transform __attribute__((swift_name("Transform")));
@end

__attribute__((swift_name("Ktor_httpHttpMessageBuilder")))
@protocol SorawalletKtor_httpHttpMessageBuilder
@required
@property (readonly) SorawalletKtor_httpHeadersBuilder *headers __attribute__((swift_name("headers")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestBuilder")))
@interface SorawalletKtor_client_coreHttpRequestBuilder : SorawalletBase <SorawalletKtor_httpHttpMessageBuilder>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) SorawalletKtor_client_coreHttpRequestBuilderCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKtor_client_coreHttpRequestData *)build __attribute__((swift_name("build()")));
- (id _Nullable)getCapabilityOrNullKey:(id<SorawalletKtor_client_coreHttpClientEngineCapability>)key __attribute__((swift_name("getCapabilityOrNull(key:)")));
- (void)setAttributesBlock:(void (^)(id<SorawalletKtor_utilsAttributes>))block __attribute__((swift_name("setAttributes(block:)")));
- (void)setCapabilityKey:(id<SorawalletKtor_client_coreHttpClientEngineCapability>)key capability:(id)capability __attribute__((swift_name("setCapability(key:capability:)")));
- (SorawalletKtor_client_coreHttpRequestBuilder *)takeFromBuilder:(SorawalletKtor_client_coreHttpRequestBuilder *)builder __attribute__((swift_name("takeFrom(builder:)")));
- (SorawalletKtor_client_coreHttpRequestBuilder *)takeFromWithExecutionContextBuilder:(SorawalletKtor_client_coreHttpRequestBuilder *)builder __attribute__((swift_name("takeFromWithExecutionContext(builder:)")));
- (void)urlBlock:(void (^)(SorawalletKtor_httpURLBuilder *, SorawalletKtor_httpURLBuilder *))block __attribute__((swift_name("url(block:)")));
@property (readonly) id<SorawalletKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property id body __attribute__((swift_name("body")));
@property SorawalletKtor_utilsTypeInfo * _Nullable bodyType __attribute__((swift_name("bodyType")));
@property (readonly) id<SorawalletKotlinx_coroutines_coreJob> executionContext __attribute__((swift_name("executionContext")));
@property (readonly) SorawalletKtor_httpHeadersBuilder *headers __attribute__((swift_name("headers")));
@property SorawalletKtor_httpHttpMethod *method __attribute__((swift_name("method")));
@property (readonly) SorawalletKtor_httpURLBuilder *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponsePipeline.Phases")))
@interface SorawalletKtor_client_coreHttpResponsePipelinePhases : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_client_coreHttpResponsePipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *After __attribute__((swift_name("After")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Parse __attribute__((swift_name("Parse")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Receive __attribute__((swift_name("Receive")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Transform __attribute__((swift_name("Transform")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponseContainer")))
@interface SorawalletKtor_client_coreHttpResponseContainer : SorawalletBase
- (instancetype)initWithExpectedType:(SorawalletKtor_utilsTypeInfo *)expectedType response:(id)response __attribute__((swift_name("init(expectedType:response:)"))) __attribute__((objc_designated_initializer));
- (SorawalletKtor_client_coreHttpResponseContainer *)doCopyExpectedType:(SorawalletKtor_utilsTypeInfo *)expectedType response:(id)response __attribute__((swift_name("doCopy(expectedType:response:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SorawalletKtor_utilsTypeInfo *expectedType __attribute__((swift_name("expectedType")));
@property (readonly) id response __attribute__((swift_name("response")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpSendPipeline.Phases")))
@interface SorawalletKtor_client_coreHttpSendPipelinePhases : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_client_coreHttpSendPipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Before __attribute__((swift_name("Before")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Engine __attribute__((swift_name("Engine")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Monitoring __attribute__((swift_name("Monitoring")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *Receive __attribute__((swift_name("Receive")));
@property (readonly) SorawalletKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpClientCall.Companion")))
@interface SorawalletKtor_client_coreHttpClientCallCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_client_coreHttpClientCallCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_utilsAttributeKey<id> *CustomResponse __attribute__((swift_name("CustomResponse"))) __attribute__((unavailable("This is going to be removed. Please file a ticket with clarification why and what for do you need it.")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsTypeInfo")))
@interface SorawalletKtor_utilsTypeInfo : SorawalletBase
- (instancetype)initWithType:(id<SorawalletKotlinKClass>)type reifiedType:(id<SorawalletKotlinKType>)reifiedType kotlinType:(id<SorawalletKotlinKType> _Nullable)kotlinType __attribute__((swift_name("init(type:reifiedType:kotlinType:)"))) __attribute__((objc_designated_initializer));
- (SorawalletKtor_utilsTypeInfo *)doCopyType:(id<SorawalletKotlinKClass>)type reifiedType:(id<SorawalletKotlinKType>)reifiedType kotlinType:(id<SorawalletKotlinKType> _Nullable)kotlinType __attribute__((swift_name("doCopy(type:reifiedType:kotlinType:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<SorawalletKotlinKType> _Nullable kotlinType __attribute__((swift_name("kotlinType")));
@property (readonly) id<SorawalletKotlinKType> reifiedType __attribute__((swift_name("reifiedType")));
@property (readonly) id<SorawalletKotlinKClass> type __attribute__((swift_name("type")));
@end

__attribute__((swift_name("Ktor_client_coreHttpRequest")))
@protocol SorawalletKtor_client_coreHttpRequest <SorawalletKtor_httpHttpMessage, SorawalletKotlinx_coroutines_coreCoroutineScope>
@required
@property (readonly) id<SorawalletKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) SorawalletKtor_client_coreHttpClientCall *call __attribute__((swift_name("call")));
@property (readonly) SorawalletKtor_httpOutgoingContent *content __attribute__((swift_name("content")));
@property (readonly) SorawalletKtor_httpHttpMethod *method __attribute__((swift_name("method")));
@property (readonly) SorawalletKtor_httpUrl *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioMemory")))
@interface SorawalletKtor_ioMemory : SorawalletBase
- (instancetype)initWithPointer:(void *)pointer size:(int64_t)size __attribute__((swift_name("init(pointer:size:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_ioMemoryCompanion *companion __attribute__((swift_name("companion")));
- (void)doCopyToDestination:(SorawalletKtor_ioMemory *)destination offset:(int32_t)offset length:(int32_t)length destinationOffset:(int32_t)destinationOffset __attribute__((swift_name("doCopyTo(destination:offset:length:destinationOffset:)")));
- (void)doCopyToDestination:(SorawalletKtor_ioMemory *)destination offset:(int64_t)offset length:(int64_t)length destinationOffset_:(int64_t)destinationOffset __attribute__((swift_name("doCopyTo(destination:offset:length:destinationOffset_:)")));
- (int8_t)loadAtIndex:(int32_t)index __attribute__((swift_name("loadAt(index:)")));
- (int8_t)loadAtIndex_:(int64_t)index __attribute__((swift_name("loadAt(index_:)")));
- (SorawalletKtor_ioMemory *)sliceOffset:(int32_t)offset length:(int32_t)length __attribute__((swift_name("slice(offset:length:)")));
- (SorawalletKtor_ioMemory *)sliceOffset:(int64_t)offset length_:(int64_t)length __attribute__((swift_name("slice(offset:length_:)")));
- (void)storeAtIndex:(int32_t)index value:(int8_t)value __attribute__((swift_name("storeAt(index:value:)")));
- (void)storeAtIndex:(int64_t)index value_:(int8_t)value __attribute__((swift_name("storeAt(index:value_:)")));
@property (readonly) void *pointer __attribute__((swift_name("pointer")));
@property (readonly) int64_t size __attribute__((swift_name("size")));
@property (readonly) int32_t size32 __attribute__((swift_name("size32")));
@end

__attribute__((swift_name("Ktor_ioBuffer")))
@interface SorawalletKtor_ioBuffer : SorawalletBase
- (instancetype)initWithMemory:(SorawalletKtor_ioMemory *)memory __attribute__((swift_name("init(memory:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_ioBufferCompanion *companion __attribute__((swift_name("companion")));
- (void)commitWrittenCount:(int32_t)count __attribute__((swift_name("commitWritten(count:)")));
- (void)discardExactCount:(int32_t)count __attribute__((swift_name("discardExact(count:)")));
- (SorawalletKtor_ioBuffer *)duplicate __attribute__((swift_name("duplicate()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)duplicateToCopy:(SorawalletKtor_ioBuffer *)copy __attribute__((swift_name("duplicateTo(copy:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (void)reserveEndGapEndGap:(int32_t)endGap __attribute__((swift_name("reserveEndGap(endGap:)")));
- (void)reserveStartGapStartGap:(int32_t)startGap __attribute__((swift_name("reserveStartGap(startGap:)")));
- (void)reset __attribute__((swift_name("reset()")));
- (void)resetForRead __attribute__((swift_name("resetForRead()")));
- (void)resetForWrite __attribute__((swift_name("resetForWrite()")));
- (void)resetForWriteLimit:(int32_t)limit __attribute__((swift_name("resetForWrite(limit:)")));
- (void)rewindCount:(int32_t)count __attribute__((swift_name("rewind(count:)")));
- (NSString *)description __attribute__((swift_name("description()")));
- (int32_t)tryPeekByte __attribute__((swift_name("tryPeekByte()")));
- (int32_t)tryReadByte __attribute__((swift_name("tryReadByte()")));
- (void)writeByteValue:(int8_t)value __attribute__((swift_name("writeByte(value:)")));
@property (readonly) int32_t capacity __attribute__((swift_name("capacity")));
@property (readonly) int32_t endGap __attribute__((swift_name("endGap")));
@property (readonly) int32_t limit __attribute__((swift_name("limit")));
@property (readonly) SorawalletKtor_ioMemory *memory __attribute__((swift_name("memory")));
@property (readonly) int32_t readPosition __attribute__((swift_name("readPosition")));
@property (readonly) int32_t readRemaining __attribute__((swift_name("readRemaining")));
@property (readonly) int32_t startGap __attribute__((swift_name("startGap")));
@property (readonly) int32_t writePosition __attribute__((swift_name("writePosition")));
@property (readonly) int32_t writeRemaining __attribute__((swift_name("writeRemaining")));
@end

__attribute__((swift_name("Ktor_ioChunkBuffer")))
@interface SorawalletKtor_ioChunkBuffer : SorawalletKtor_ioBuffer
- (instancetype)initWithMemory:(SorawalletKtor_ioMemory *)memory origin:(SorawalletKtor_ioChunkBuffer * _Nullable)origin parentPool:(id<SorawalletKtor_ioObjectPool> _Nullable)parentPool __attribute__((swift_name("init(memory:origin:parentPool:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMemory:(SorawalletKtor_ioMemory *)memory __attribute__((swift_name("init(memory:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_ioChunkBufferCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKtor_ioChunkBuffer * _Nullable)cleanNext __attribute__((swift_name("cleanNext()")));
- (SorawalletKtor_ioChunkBuffer *)duplicate __attribute__((swift_name("duplicate()")));
- (void)releasePool:(id<SorawalletKtor_ioObjectPool>)pool __attribute__((swift_name("release(pool:)")));
- (void)reset __attribute__((swift_name("reset()")));
@property (getter=next__) SorawalletKtor_ioChunkBuffer * _Nullable next __attribute__((swift_name("next")));
@property (readonly) SorawalletKtor_ioChunkBuffer * _Nullable origin __attribute__((swift_name("origin")));
@property (readonly) int32_t referenceCount __attribute__((swift_name("referenceCount")));
@end

__attribute__((swift_name("Ktor_ioInput")))
@interface SorawalletKtor_ioInput : SorawalletBase <SorawalletKtor_ioCloseable>
- (instancetype)initWithHead:(SorawalletKtor_ioChunkBuffer *)head remaining:(int64_t)remaining pool:(id<SorawalletKtor_ioObjectPool>)pool __attribute__((swift_name("init(head:remaining:pool:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_ioInputCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)canRead __attribute__((swift_name("canRead()")));
- (void)close __attribute__((swift_name("close()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)closeSource __attribute__((swift_name("closeSource()")));
- (int32_t)discardN:(int32_t)n __attribute__((swift_name("discard(n:)")));
- (int64_t)discardN_:(int64_t)n __attribute__((swift_name("discard(n_:)")));
- (void)discardExactN:(int32_t)n __attribute__((swift_name("discardExact(n:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (SorawalletKtor_ioChunkBuffer * _Nullable)fill __attribute__((swift_name("fill()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (int32_t)fillDestination:(SorawalletKtor_ioMemory *)destination offset:(int32_t)offset length:(int32_t)length __attribute__((swift_name("fill(destination:offset:length:)")));
- (BOOL)hasBytesN:(int32_t)n __attribute__((swift_name("hasBytes(n:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)markNoMoreChunksAvailable __attribute__((swift_name("markNoMoreChunksAvailable()")));
- (int64_t)peekToDestination:(SorawalletKtor_ioMemory *)destination destinationOffset:(int64_t)destinationOffset offset:(int64_t)offset min:(int64_t)min max:(int64_t)max __attribute__((swift_name("peekTo(destination:destinationOffset:offset:min:max:)")));
- (int32_t)peekToBuffer:(SorawalletKtor_ioChunkBuffer *)buffer __attribute__((swift_name("peekTo(buffer:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (NSString *)readTextMin:(int32_t)min max:(int32_t)max __attribute__((swift_name("readText(min:max:)")));
- (int32_t)readTextOut:(id<SorawalletKotlinAppendable>)out min:(int32_t)min max:(int32_t)max __attribute__((swift_name("readText(out:min:max:)")));
- (NSString *)readTextExactExactCharacters:(int32_t)exactCharacters __attribute__((swift_name("readTextExact(exactCharacters:)")));
- (void)readTextExactOut:(id<SorawalletKotlinAppendable>)out exactCharacters:(int32_t)exactCharacters __attribute__((swift_name("readTextExact(out:exactCharacters:)")));
- (void)release_ __attribute__((swift_name("release()")));
- (int32_t)tryPeek __attribute__((swift_name("tryPeek()")));
@property (readonly) BOOL endOfInput __attribute__((swift_name("endOfInput")));
@property (readonly) id<SorawalletKtor_ioObjectPool> pool __attribute__((swift_name("pool")));
@property (readonly) int64_t remaining __attribute__((swift_name("remaining")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioByteReadPacket")))
@interface SorawalletKtor_ioByteReadPacket : SorawalletKtor_ioInput
- (instancetype)initWithHead:(SorawalletKtor_ioChunkBuffer *)head pool:(id<SorawalletKtor_ioObjectPool>)pool __attribute__((swift_name("init(head:pool:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithHead:(SorawalletKtor_ioChunkBuffer *)head remaining:(int64_t)remaining pool:(id<SorawalletKtor_ioObjectPool>)pool __attribute__((swift_name("init(head:remaining:pool:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_ioByteReadPacketCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)closeSource __attribute__((swift_name("closeSource()")));
- (SorawalletKtor_ioByteReadPacket *)doCopy __attribute__((swift_name("doCopy()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (SorawalletKtor_ioChunkBuffer * _Nullable)fill __attribute__((swift_name("fill()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (int32_t)fillDestination:(SorawalletKtor_ioMemory *)destination offset:(int32_t)offset length:(int32_t)length __attribute__((swift_name("fill(destination:offset:length:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Ktor_ioReadSession")))
@protocol SorawalletKtor_ioReadSession
@required
- (int32_t)discardN:(int32_t)n __attribute__((swift_name("discard(n:)")));
- (SorawalletKtor_ioChunkBuffer * _Nullable)requestAtLeast:(int32_t)atLeast __attribute__((swift_name("request(atLeast:)")));
@property (readonly) int32_t availableForRead __attribute__((swift_name("availableForRead")));
@end

__attribute__((swift_name("KotlinSuspendFunction1")))
@protocol SorawalletKotlinSuspendFunction1 <SorawalletKotlinFunction>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)invokeP1:(id _Nullable)p1 completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("invoke(p1:completionHandler:)")));
@end

__attribute__((swift_name("KotlinAppendable")))
@protocol SorawalletKotlinAppendable
@required
- (id<SorawalletKotlinAppendable>)appendValue:(unichar)value __attribute__((swift_name("append(value:)")));
- (id<SorawalletKotlinAppendable>)appendValue_:(id _Nullable)value __attribute__((swift_name("append(value_:)")));
- (id<SorawalletKotlinAppendable>)appendValue:(id _Nullable)value startIndex:(int32_t)startIndex endIndex:(int32_t)endIndex __attribute__((swift_name("append(value:startIndex:endIndex:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsGMTDate.Companion")))
@interface SorawalletKtor_utilsGMTDateCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_utilsGMTDateCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_utilsGMTDate *START __attribute__((swift_name("START")));
@end

__attribute__((swift_name("KotlinEnum")))
@interface SorawalletKotlinEnum<E> : SorawalletBase <SorawalletKotlinComparable>
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKotlinEnumCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(E)other __attribute__((swift_name("compareTo(other:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) int32_t ordinal __attribute__((swift_name("ordinal")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsWeekDay")))
@interface SorawalletKtor_utilsWeekDay : SorawalletKotlinEnum<SorawalletKtor_utilsWeekDay *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_utilsWeekDayCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *monday __attribute__((swift_name("monday")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *tuesday __attribute__((swift_name("tuesday")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *wednesday __attribute__((swift_name("wednesday")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *thursday __attribute__((swift_name("thursday")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *friday __attribute__((swift_name("friday")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *saturday __attribute__((swift_name("saturday")));
@property (class, readonly) SorawalletKtor_utilsWeekDay *sunday __attribute__((swift_name("sunday")));
+ (SorawalletKotlinArray<SorawalletKtor_utilsWeekDay *> *)values __attribute__((swift_name("values()")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsMonth")))
@interface SorawalletKtor_utilsMonth : SorawalletKotlinEnum<SorawalletKtor_utilsMonth *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SorawalletKtor_utilsMonthCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) SorawalletKtor_utilsMonth *january __attribute__((swift_name("january")));
@property (class, readonly) SorawalletKtor_utilsMonth *february __attribute__((swift_name("february")));
@property (class, readonly) SorawalletKtor_utilsMonth *march __attribute__((swift_name("march")));
@property (class, readonly) SorawalletKtor_utilsMonth *april __attribute__((swift_name("april")));
@property (class, readonly) SorawalletKtor_utilsMonth *may __attribute__((swift_name("may")));
@property (class, readonly) SorawalletKtor_utilsMonth *june __attribute__((swift_name("june")));
@property (class, readonly) SorawalletKtor_utilsMonth *july __attribute__((swift_name("july")));
@property (class, readonly) SorawalletKtor_utilsMonth *august __attribute__((swift_name("august")));
@property (class, readonly) SorawalletKtor_utilsMonth *september __attribute__((swift_name("september")));
@property (class, readonly) SorawalletKtor_utilsMonth *october __attribute__((swift_name("october")));
@property (class, readonly) SorawalletKtor_utilsMonth *november __attribute__((swift_name("november")));
@property (class, readonly) SorawalletKtor_utilsMonth *december __attribute__((swift_name("december")));
+ (SorawalletKotlinArray<SorawalletKtor_utilsMonth *> *)values __attribute__((swift_name("values()")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpStatusCode.Companion")))
@interface SorawalletKtor_httpHttpStatusCodeCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpHttpStatusCodeCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_httpHttpStatusCode *)fromValueValue:(int32_t)value __attribute__((swift_name("fromValue(value:)")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Accepted __attribute__((swift_name("Accepted")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *BadGateway __attribute__((swift_name("BadGateway")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *BadRequest __attribute__((swift_name("BadRequest")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Conflict __attribute__((swift_name("Conflict")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Continue __attribute__((swift_name("Continue")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Created __attribute__((swift_name("Created")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *ExpectationFailed __attribute__((swift_name("ExpectationFailed")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *FailedDependency __attribute__((swift_name("FailedDependency")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Forbidden __attribute__((swift_name("Forbidden")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Found __attribute__((swift_name("Found")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *GatewayTimeout __attribute__((swift_name("GatewayTimeout")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Gone __attribute__((swift_name("Gone")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *InsufficientStorage __attribute__((swift_name("InsufficientStorage")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *InternalServerError __attribute__((swift_name("InternalServerError")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *LengthRequired __attribute__((swift_name("LengthRequired")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Locked __attribute__((swift_name("Locked")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *MethodNotAllowed __attribute__((swift_name("MethodNotAllowed")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *MovedPermanently __attribute__((swift_name("MovedPermanently")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *MultiStatus __attribute__((swift_name("MultiStatus")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *MultipleChoices __attribute__((swift_name("MultipleChoices")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *NoContent __attribute__((swift_name("NoContent")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *NonAuthoritativeInformation __attribute__((swift_name("NonAuthoritativeInformation")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *NotAcceptable __attribute__((swift_name("NotAcceptable")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *NotFound __attribute__((swift_name("NotFound")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *NotImplemented __attribute__((swift_name("NotImplemented")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *NotModified __attribute__((swift_name("NotModified")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *OK __attribute__((swift_name("OK")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *PartialContent __attribute__((swift_name("PartialContent")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *PayloadTooLarge __attribute__((swift_name("PayloadTooLarge")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *PaymentRequired __attribute__((swift_name("PaymentRequired")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *PermanentRedirect __attribute__((swift_name("PermanentRedirect")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *PreconditionFailed __attribute__((swift_name("PreconditionFailed")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Processing __attribute__((swift_name("Processing")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *ProxyAuthenticationRequired __attribute__((swift_name("ProxyAuthenticationRequired")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *RequestHeaderFieldTooLarge __attribute__((swift_name("RequestHeaderFieldTooLarge")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *RequestTimeout __attribute__((swift_name("RequestTimeout")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *RequestURITooLong __attribute__((swift_name("RequestURITooLong")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *RequestedRangeNotSatisfiable __attribute__((swift_name("RequestedRangeNotSatisfiable")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *ResetContent __attribute__((swift_name("ResetContent")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *SeeOther __attribute__((swift_name("SeeOther")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *ServiceUnavailable __attribute__((swift_name("ServiceUnavailable")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *SwitchProxy __attribute__((swift_name("SwitchProxy")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *SwitchingProtocols __attribute__((swift_name("SwitchingProtocols")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *TemporaryRedirect __attribute__((swift_name("TemporaryRedirect")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *TooEarly __attribute__((swift_name("TooEarly")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *TooManyRequests __attribute__((swift_name("TooManyRequests")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *Unauthorized __attribute__((swift_name("Unauthorized")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *UnprocessableEntity __attribute__((swift_name("UnprocessableEntity")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *UnsupportedMediaType __attribute__((swift_name("UnsupportedMediaType")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *UpgradeRequired __attribute__((swift_name("UpgradeRequired")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *UseProxy __attribute__((swift_name("UseProxy")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *VariantAlsoNegotiates __attribute__((swift_name("VariantAlsoNegotiates")));
@property (readonly) SorawalletKtor_httpHttpStatusCode *VersionNotSupported __attribute__((swift_name("VersionNotSupported")));
@property (readonly) NSArray<SorawalletKtor_httpHttpStatusCode *> *allStatusCodes __attribute__((swift_name("allStatusCodes")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpProtocolVersion.Companion")))
@interface SorawalletKtor_httpHttpProtocolVersionCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpHttpProtocolVersionCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_httpHttpProtocolVersion *)fromValueName:(NSString *)name major:(int32_t)major minor:(int32_t)minor __attribute__((swift_name("fromValue(name:major:minor:)")));
- (SorawalletKtor_httpHttpProtocolVersion *)parseValue:(id)value __attribute__((swift_name("parse(value:)")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *HTTP_1_0 __attribute__((swift_name("HTTP_1_0")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *HTTP_1_1 __attribute__((swift_name("HTTP_1_1")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *HTTP_2_0 __attribute__((swift_name("HTTP_2_0")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *QUIC __attribute__((swift_name("QUIC")));
@property (readonly) SorawalletKtor_httpHttpProtocolVersion *SPDY_3 __attribute__((swift_name("SPDY_3")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpUrl")))
@interface SorawalletKtor_httpUrl : SorawalletBase
@property (class, readonly, getter=companion) SorawalletKtor_httpUrlCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *encodedFragment __attribute__((swift_name("encodedFragment")));
@property (readonly) NSString * _Nullable encodedPassword __attribute__((swift_name("encodedPassword")));
@property (readonly) NSString *encodedPath __attribute__((swift_name("encodedPath")));
@property (readonly) NSString *encodedPathAndQuery __attribute__((swift_name("encodedPathAndQuery")));
@property (readonly) NSString *encodedQuery __attribute__((swift_name("encodedQuery")));
@property (readonly) NSString * _Nullable encodedUser __attribute__((swift_name("encodedUser")));
@property (readonly) NSString *fragment __attribute__((swift_name("fragment")));
@property (readonly) NSString *host __attribute__((swift_name("host")));
@property (readonly) id<SorawalletKtor_httpParameters> parameters __attribute__((swift_name("parameters")));
@property (readonly) NSString * _Nullable password __attribute__((swift_name("password")));
@property (readonly) NSArray<NSString *> *pathSegments __attribute__((swift_name("pathSegments")));
@property (readonly) int32_t port __attribute__((swift_name("port")));
@property (readonly) SorawalletKtor_httpURLProtocol *protocol __attribute__((swift_name("protocol")));
@property (readonly) int32_t specifiedPort __attribute__((swift_name("specifiedPort")));
@property (readonly) BOOL trailingQuery __attribute__((swift_name("trailingQuery")));
@property (readonly) NSString * _Nullable user __attribute__((swift_name("user")));
@end

__attribute__((swift_name("Ktor_httpOutgoingContent")))
@interface SorawalletKtor_httpOutgoingContent : SorawalletBase
- (id _Nullable)getPropertyKey:(SorawalletKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("getProperty(key:)")));
- (void)setPropertyKey:(SorawalletKtor_utilsAttributeKey<id> *)key value:(id _Nullable)value __attribute__((swift_name("setProperty(key:value:)")));
- (id<SorawalletKtor_httpHeaders> _Nullable)trailers __attribute__((swift_name("trailers()")));
@property (readonly) SorawalletLong * _Nullable contentLength __attribute__((swift_name("contentLength")));
@property (readonly) SorawalletKtor_httpContentType * _Nullable contentType __attribute__((swift_name("contentType")));
@property (readonly) id<SorawalletKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@property (readonly) SorawalletKtor_httpHttpStatusCode * _Nullable status __attribute__((swift_name("status")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreJob")))
@protocol SorawalletKotlinx_coroutines_coreJob <SorawalletKotlinCoroutineContextElement>
@required
- (id<SorawalletKotlinx_coroutines_coreChildHandle>)attachChildChild:(id<SorawalletKotlinx_coroutines_coreChildJob>)child __attribute__((swift_name("attachChild(child:)")));
- (void)cancelCause_:(SorawalletKotlinCancellationException * _Nullable)cause __attribute__((swift_name("cancel(cause_:)")));
- (SorawalletKotlinCancellationException *)getCancellationException __attribute__((swift_name("getCancellationException()")));
- (id<SorawalletKotlinx_coroutines_coreDisposableHandle>)invokeOnCompletionOnCancelling:(BOOL)onCancelling invokeImmediately:(BOOL)invokeImmediately handler:(void (^)(SorawalletKotlinThrowable * _Nullable))handler __attribute__((swift_name("invokeOnCompletion(onCancelling:invokeImmediately:handler:)")));
- (id<SorawalletKotlinx_coroutines_coreDisposableHandle>)invokeOnCompletionHandler:(void (^)(SorawalletKotlinThrowable * _Nullable))handler __attribute__((swift_name("invokeOnCompletion(handler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)joinWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("join(completionHandler:)")));
- (id<SorawalletKotlinx_coroutines_coreJob>)plusOther_:(id<SorawalletKotlinx_coroutines_coreJob>)other __attribute__((swift_name("plus(other_:)"))) __attribute__((unavailable("Operator '+' on two Job objects is meaningless. Job is a coroutine context element and `+` is a set-sum operator for coroutine contexts. The job to the right of `+` just replaces the job the left of `+`.")));
- (BOOL)start __attribute__((swift_name("start()")));
@property (readonly) id<SorawalletKotlinSequence> children __attribute__((swift_name("children")));
@property (readonly) BOOL isActive __attribute__((swift_name("isActive")));
@property (readonly) BOOL isCancelled __attribute__((swift_name("isCancelled")));
@property (readonly) BOOL isCompleted __attribute__((swift_name("isCompleted")));
@property (readonly) id<SorawalletKotlinx_coroutines_coreSelectClause0> onJoin __attribute__((swift_name("onJoin")));

/**
 * @note annotations
 *   kotlinx.coroutines.ExperimentalCoroutinesApi
*/
@property (readonly) id<SorawalletKotlinx_coroutines_coreJob> _Nullable parent __attribute__((swift_name("parent")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinContinuation")))
@protocol SorawalletKotlinContinuation
@required
- (void)resumeWithResult:(id _Nullable)result __attribute__((swift_name("resumeWith(result:)")));
@property (readonly) id<SorawalletKotlinCoroutineContext> context __attribute__((swift_name("context")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
 *   kotlin.ExperimentalStdlibApi
*/
__attribute__((swift_name("KotlinAbstractCoroutineContextKey")))
@interface SorawalletKotlinAbstractCoroutineContextKey<B, E> : SorawalletBase <SorawalletKotlinCoroutineContextKey>
- (instancetype)initWithBaseKey:(id<SorawalletKotlinCoroutineContextKey>)baseKey safeCast:(E _Nullable (^)(id<SorawalletKotlinCoroutineContextElement>))safeCast __attribute__((swift_name("init(baseKey:safeCast:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.ExperimentalStdlibApi
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineDispatcher.Key")))
@interface SorawalletKotlinx_coroutines_coreCoroutineDispatcherKey : SorawalletKotlinAbstractCoroutineContextKey<id<SorawalletKotlinContinuationInterceptor>, SorawalletKotlinx_coroutines_coreCoroutineDispatcher *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithBaseKey:(id<SorawalletKotlinCoroutineContextKey>)baseKey safeCast:(id<SorawalletKotlinCoroutineContextElement> _Nullable (^)(id<SorawalletKotlinCoroutineContextElement>))safeCast __attribute__((swift_name("init(baseKey:safeCast:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)key __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKotlinx_coroutines_coreCoroutineDispatcherKey *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreRunnable")))
@protocol SorawalletKotlinx_coroutines_coreRunnable
@required
- (void)run __attribute__((swift_name("run()")));
@end

__attribute__((swift_name("Ktor_utilsStringValuesBuilder")))
@protocol SorawalletKtor_utilsStringValuesBuilder
@required
- (void)appendName:(NSString *)name value:(NSString *)value __attribute__((swift_name("append(name:value:)")));
- (void)appendAllStringValues:(id<SorawalletKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendAll(stringValues:)")));
- (void)appendAllName:(NSString *)name values:(id)values __attribute__((swift_name("appendAll(name:values:)")));
- (void)appendMissingStringValues:(id<SorawalletKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendMissing(stringValues:)")));
- (void)appendMissingName:(NSString *)name values:(id)values __attribute__((swift_name("appendMissing(name:values:)")));
- (id<SorawalletKtor_utilsStringValues>)build __attribute__((swift_name("build()")));
- (void)clear __attribute__((swift_name("clear()")));
- (BOOL)containsName:(NSString *)name __attribute__((swift_name("contains(name:)")));
- (BOOL)containsName:(NSString *)name value:(NSString *)value __attribute__((swift_name("contains(name:value:)")));
- (NSSet<id<SorawalletKotlinMapEntry>> *)entries __attribute__((swift_name("entries()")));
- (NSString * _Nullable)getName:(NSString *)name __attribute__((swift_name("get(name:)")));
- (NSArray<NSString *> * _Nullable)getAllName:(NSString *)name __attribute__((swift_name("getAll(name:)")));
- (BOOL)isEmpty __attribute__((swift_name("isEmpty()")));
- (NSSet<NSString *> *)names __attribute__((swift_name("names()")));
- (void)removeName:(NSString *)name __attribute__((swift_name("remove(name:)")));
- (BOOL)removeName:(NSString *)name value:(NSString *)value __attribute__((swift_name("remove(name:value:)")));
- (void)removeKeysWithNoEntries __attribute__((swift_name("removeKeysWithNoEntries()")));
- (void)setName:(NSString *)name value:(NSString *)value __attribute__((swift_name("set(name:value:)")));
@property (readonly) BOOL caseInsensitiveName __attribute__((swift_name("caseInsensitiveName")));
@end

__attribute__((swift_name("Ktor_utilsStringValuesBuilderImpl")))
@interface SorawalletKtor_utilsStringValuesBuilderImpl : SorawalletBase <SorawalletKtor_utilsStringValuesBuilder>
- (instancetype)initWithCaseInsensitiveName:(BOOL)caseInsensitiveName size:(int32_t)size __attribute__((swift_name("init(caseInsensitiveName:size:)"))) __attribute__((objc_designated_initializer));
- (void)appendName:(NSString *)name value:(NSString *)value __attribute__((swift_name("append(name:value:)")));
- (void)appendAllStringValues:(id<SorawalletKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendAll(stringValues:)")));
- (void)appendAllName:(NSString *)name values:(id)values __attribute__((swift_name("appendAll(name:values:)")));
- (void)appendMissingStringValues:(id<SorawalletKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendMissing(stringValues:)")));
- (void)appendMissingName:(NSString *)name values:(id)values __attribute__((swift_name("appendMissing(name:values:)")));
- (id<SorawalletKtor_utilsStringValues>)build __attribute__((swift_name("build()")));
- (void)clear __attribute__((swift_name("clear()")));
- (BOOL)containsName:(NSString *)name __attribute__((swift_name("contains(name:)")));
- (BOOL)containsName:(NSString *)name value:(NSString *)value __attribute__((swift_name("contains(name:value:)")));
- (NSSet<id<SorawalletKotlinMapEntry>> *)entries __attribute__((swift_name("entries()")));
- (NSString * _Nullable)getName:(NSString *)name __attribute__((swift_name("get(name:)")));
- (NSArray<NSString *> * _Nullable)getAllName:(NSString *)name __attribute__((swift_name("getAll(name:)")));
- (BOOL)isEmpty __attribute__((swift_name("isEmpty()")));
- (NSSet<NSString *> *)names __attribute__((swift_name("names()")));
- (void)removeName:(NSString *)name __attribute__((swift_name("remove(name:)")));
- (BOOL)removeName:(NSString *)name value:(NSString *)value __attribute__((swift_name("remove(name:value:)")));
- (void)removeKeysWithNoEntries __attribute__((swift_name("removeKeysWithNoEntries()")));
- (void)setName:(NSString *)name value:(NSString *)value __attribute__((swift_name("set(name:value:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateNameName:(NSString *)name __attribute__((swift_name("validateName(name:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateValueValue:(NSString *)value __attribute__((swift_name("validateValue(value:)")));
@property (readonly) BOOL caseInsensitiveName __attribute__((swift_name("caseInsensitiveName")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) SorawalletMutableDictionary<NSString *, NSMutableArray<NSString *> *> *values __attribute__((swift_name("values")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHeadersBuilder")))
@interface SorawalletKtor_httpHeadersBuilder : SorawalletKtor_utilsStringValuesBuilderImpl
- (instancetype)initWithSize:(int32_t)size __attribute__((swift_name("init(size:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCaseInsensitiveName:(BOOL)caseInsensitiveName size:(int32_t)size __attribute__((swift_name("init(caseInsensitiveName:size:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (id<SorawalletKtor_httpHeaders>)build __attribute__((swift_name("build()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateNameName:(NSString *)name __attribute__((swift_name("validateName(name:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateValueValue:(NSString *)value __attribute__((swift_name("validateValue(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestBuilder.Companion")))
@interface SorawalletKtor_client_coreHttpRequestBuilderCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_client_coreHttpRequestBuilderCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLBuilder")))
@interface SorawalletKtor_httpURLBuilder : SorawalletBase
- (instancetype)initWithProtocol:(SorawalletKtor_httpURLProtocol *)protocol host:(NSString *)host port:(int32_t)port user:(NSString * _Nullable)user password:(NSString * _Nullable)password pathSegments:(NSArray<NSString *> *)pathSegments parameters:(id<SorawalletKtor_httpParameters>)parameters fragment:(NSString *)fragment trailingQuery:(BOOL)trailingQuery __attribute__((swift_name("init(protocol:host:port:user:password:pathSegments:parameters:fragment:trailingQuery:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_httpURLBuilderCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKtor_httpUrl *)build __attribute__((swift_name("build()")));
- (NSString *)buildString __attribute__((swift_name("buildString()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property NSString *encodedFragment __attribute__((swift_name("encodedFragment")));
@property id<SorawalletKtor_httpParametersBuilder> encodedParameters __attribute__((swift_name("encodedParameters")));
@property NSString * _Nullable encodedPassword __attribute__((swift_name("encodedPassword")));
@property NSArray<NSString *> *encodedPathSegments __attribute__((swift_name("encodedPathSegments")));
@property NSString * _Nullable encodedUser __attribute__((swift_name("encodedUser")));
@property NSString *fragment __attribute__((swift_name("fragment")));
@property NSString *host __attribute__((swift_name("host")));
@property (readonly) id<SorawalletKtor_httpParametersBuilder> parameters __attribute__((swift_name("parameters")));
@property NSString * _Nullable password __attribute__((swift_name("password")));
@property NSArray<NSString *> *pathSegments __attribute__((swift_name("pathSegments")));
@property int32_t port __attribute__((swift_name("port")));
@property SorawalletKtor_httpURLProtocol *protocol __attribute__((swift_name("protocol")));
@property BOOL trailingQuery __attribute__((swift_name("trailingQuery")));
@property NSString * _Nullable user __attribute__((swift_name("user")));
@end

__attribute__((swift_name("KotlinKType")))
@protocol SorawalletKotlinKType
@required

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
@property (readonly) NSArray<SorawalletKotlinKTypeProjection *> *arguments __attribute__((swift_name("arguments")));

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
@property (readonly) id<SorawalletKotlinKClassifier> _Nullable classifier __attribute__((swift_name("classifier")));
@property (readonly) BOOL isMarkedNullable __attribute__((swift_name("isMarkedNullable")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioMemory.Companion")))
@interface SorawalletKtor_ioMemoryCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_ioMemoryCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_ioMemory *Empty __attribute__((swift_name("Empty")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioBuffer.Companion")))
@interface SorawalletKtor_ioBufferCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_ioBufferCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_ioBuffer *Empty __attribute__((swift_name("Empty")));
@property (readonly) int32_t ReservedSize __attribute__((swift_name("ReservedSize")));
@end

__attribute__((swift_name("Ktor_ioObjectPool")))
@protocol SorawalletKtor_ioObjectPool <SorawalletKtor_ioCloseable>
@required
- (id)borrow __attribute__((swift_name("borrow()")));
- (void)dispose __attribute__((swift_name("dispose()")));
- (void)recycleInstance:(id)instance __attribute__((swift_name("recycle(instance:)")));
@property (readonly) int32_t capacity __attribute__((swift_name("capacity")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioChunkBuffer.Companion")))
@interface SorawalletKtor_ioChunkBufferCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_ioChunkBufferCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_ioChunkBuffer *Empty __attribute__((swift_name("Empty")));
@property (readonly) id<SorawalletKtor_ioObjectPool> EmptyPool __attribute__((swift_name("EmptyPool")));
@property (readonly) id<SorawalletKtor_ioObjectPool> Pool __attribute__((swift_name("Pool")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioInput.Companion")))
@interface SorawalletKtor_ioInputCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_ioInputCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioByteReadPacket.Companion")))
@interface SorawalletKtor_ioByteReadPacketCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_ioByteReadPacketCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) SorawalletKtor_ioByteReadPacket *Empty __attribute__((swift_name("Empty")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinEnumCompanion")))
@interface SorawalletKotlinEnumCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKotlinEnumCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsWeekDay.Companion")))
@interface SorawalletKtor_utilsWeekDayCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_utilsWeekDayCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_utilsWeekDay *)fromOrdinal:(int32_t)ordinal __attribute__((swift_name("from(ordinal:)")));
- (SorawalletKtor_utilsWeekDay *)fromValue:(NSString *)value __attribute__((swift_name("from(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsMonth.Companion")))
@interface SorawalletKtor_utilsMonthCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_utilsMonthCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_utilsMonth *)fromOrdinal:(int32_t)ordinal __attribute__((swift_name("from(ordinal:)")));
- (SorawalletKtor_utilsMonth *)fromValue:(NSString *)value __attribute__((swift_name("from(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpUrl.Companion")))
@interface SorawalletKtor_httpUrlCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpUrlCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Ktor_httpParameters")))
@protocol SorawalletKtor_httpParameters <SorawalletKtor_utilsStringValues>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLProtocol")))
@interface SorawalletKtor_httpURLProtocol : SorawalletBase
- (instancetype)initWithName:(NSString *)name defaultPort:(int32_t)defaultPort __attribute__((swift_name("init(name:defaultPort:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKtor_httpURLProtocolCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKtor_httpURLProtocol *)doCopyName:(NSString *)name defaultPort:(int32_t)defaultPort __attribute__((swift_name("doCopy(name:defaultPort:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t defaultPort __attribute__((swift_name("defaultPort")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreChildHandle")))
@protocol SorawalletKotlinx_coroutines_coreChildHandle <SorawalletKotlinx_coroutines_coreDisposableHandle>
@required
- (BOOL)childCancelledCause:(SorawalletKotlinThrowable *)cause __attribute__((swift_name("childCancelled(cause:)")));
@property (readonly) id<SorawalletKotlinx_coroutines_coreJob> _Nullable parent __attribute__((swift_name("parent")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreChildJob")))
@protocol SorawalletKotlinx_coroutines_coreChildJob <SorawalletKotlinx_coroutines_coreJob>
@required
- (void)parentCancelledParentJob:(id<SorawalletKotlinx_coroutines_coreParentJob>)parentJob __attribute__((swift_name("parentCancelled(parentJob:)")));
@end

__attribute__((swift_name("KotlinSequence")))
@protocol SorawalletKotlinSequence
@required
- (id<SorawalletKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreSelectClause")))
@protocol SorawalletKotlinx_coroutines_coreSelectClause
@required
@property (readonly) id clauseObject __attribute__((swift_name("clauseObject")));
@property (readonly) SorawalletKotlinUnit *(^(^ _Nullable onCancellationConstructor)(id<SorawalletKotlinx_coroutines_coreSelectInstance>, id _Nullable, id _Nullable))(SorawalletKotlinThrowable *) __attribute__((swift_name("onCancellationConstructor")));
@property (readonly) id _Nullable (^processResFunc)(id, id _Nullable, id _Nullable) __attribute__((swift_name("processResFunc")));
@property (readonly) void (^regFunc)(id, id<SorawalletKotlinx_coroutines_coreSelectInstance>, id _Nullable) __attribute__((swift_name("regFunc")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreSelectClause0")))
@protocol SorawalletKotlinx_coroutines_coreSelectClause0 <SorawalletKotlinx_coroutines_coreSelectClause>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLBuilder.Companion")))
@interface SorawalletKtor_httpURLBuilderCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpURLBuilderCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Ktor_httpParametersBuilder")))
@protocol SorawalletKtor_httpParametersBuilder <SorawalletKtor_utilsStringValuesBuilder>
@required
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinKTypeProjection")))
@interface SorawalletKotlinKTypeProjection : SorawalletBase
- (instancetype)initWithVariance:(SorawalletKotlinKVariance * _Nullable)variance type:(id<SorawalletKotlinKType> _Nullable)type __attribute__((swift_name("init(variance:type:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SorawalletKotlinKTypeProjectionCompanion *companion __attribute__((swift_name("companion")));
- (SorawalletKotlinKTypeProjection *)doCopyVariance:(SorawalletKotlinKVariance * _Nullable)variance type:(id<SorawalletKotlinKType> _Nullable)type __attribute__((swift_name("doCopy(variance:type:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<SorawalletKotlinKType> _Nullable type __attribute__((swift_name("type")));
@property (readonly) SorawalletKotlinKVariance * _Nullable variance __attribute__((swift_name("variance")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLProtocol.Companion")))
@interface SorawalletKtor_httpURLProtocolCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKtor_httpURLProtocolCompanion *shared __attribute__((swift_name("shared")));
- (SorawalletKtor_httpURLProtocol *)createOrDefaultName:(NSString *)name __attribute__((swift_name("createOrDefault(name:)")));
@property (readonly) SorawalletKtor_httpURLProtocol *HTTP __attribute__((swift_name("HTTP")));
@property (readonly) SorawalletKtor_httpURLProtocol *HTTPS __attribute__((swift_name("HTTPS")));
@property (readonly) SorawalletKtor_httpURLProtocol *SOCKS __attribute__((swift_name("SOCKS")));
@property (readonly) SorawalletKtor_httpURLProtocol *WS __attribute__((swift_name("WS")));
@property (readonly) SorawalletKtor_httpURLProtocol *WSS __attribute__((swift_name("WSS")));
@property (readonly) NSDictionary<NSString *, SorawalletKtor_httpURLProtocol *> *byName __attribute__((swift_name("byName")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreParentJob")))
@protocol SorawalletKotlinx_coroutines_coreParentJob <SorawalletKotlinx_coroutines_coreJob>
@required
- (SorawalletKotlinCancellationException *)getChildJobCancellationCause __attribute__((swift_name("getChildJobCancellationCause()")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreSelectInstance")))
@protocol SorawalletKotlinx_coroutines_coreSelectInstance
@required
- (void)disposeOnCompletionDisposableHandle:(id<SorawalletKotlinx_coroutines_coreDisposableHandle>)disposableHandle __attribute__((swift_name("disposeOnCompletion(disposableHandle:)")));
- (void)selectInRegistrationPhaseInternalResult:(id _Nullable)internalResult __attribute__((swift_name("selectInRegistrationPhase(internalResult:)")));
- (BOOL)trySelectClauseObject:(id)clauseObject result:(id _Nullable)result __attribute__((swift_name("trySelect(clauseObject:result:)")));
@property (readonly) id<SorawalletKotlinCoroutineContext> context __attribute__((swift_name("context")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinKVariance")))
@interface SorawalletKotlinKVariance : SorawalletKotlinEnum<SorawalletKotlinKVariance *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SorawalletKotlinKVariance *invariant __attribute__((swift_name("invariant")));
@property (class, readonly) SorawalletKotlinKVariance *in __attribute__((swift_name("in")));
@property (class, readonly) SorawalletKotlinKVariance *out __attribute__((swift_name("out")));
+ (SorawalletKotlinArray<SorawalletKotlinKVariance *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SorawalletKotlinKVariance *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinKTypeProjection.Companion")))
@interface SorawalletKotlinKTypeProjectionCompanion : SorawalletBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SorawalletKotlinKTypeProjectionCompanion *shared __attribute__((swift_name("shared")));

/**
 * @note annotations
 *   kotlin.jvm.JvmStatic
*/
- (SorawalletKotlinKTypeProjection *)contravariantType:(id<SorawalletKotlinKType>)type __attribute__((swift_name("contravariant(type:)")));

/**
 * @note annotations
 *   kotlin.jvm.JvmStatic
*/
- (SorawalletKotlinKTypeProjection *)covariantType:(id<SorawalletKotlinKType>)type __attribute__((swift_name("covariant(type:)")));

/**
 * @note annotations
 *   kotlin.jvm.JvmStatic
*/
- (SorawalletKotlinKTypeProjection *)invariantType:(id<SorawalletKotlinKType>)type __attribute__((swift_name("invariant(type:)")));
@property (readonly) SorawalletKotlinKTypeProjection *STAR __attribute__((swift_name("STAR")));
@end

#pragma pop_macro("_Nullable_result")
#pragma clang diagnostic pop
NS_ASSUME_NONNULL_END
