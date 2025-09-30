#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@class XNetworkingExtrinsicParam, XNetworkingExtrinsics, XNetworkingSignerInfo, XNetworkingSoraHistoryDatabaseCompanion, XNetworkingRuntimeQuery<__covariant RowType>, XNetworkingApy, XNetworkingAssetInfo, XNetworkingFiat, XNetworkingReferralReward, XNetworkingUnbonding, XNetworkingUnbondingDelegationAction, XNetworkingKotlinEnumCompanion, XNetworkingKotlinEnum<E>, XNetworkingKotlinArray<T>, XNetworkingBlockExplorerRepository, XNetworkingConfigDAO, XNetworkingRestClient, XNetworkingApolloClientStore, XNetworkingApyFetcher, XNetworkingAssetInfoFetcher, XNetworkingFiatFetcher, XNetworkingReferralRewardFetcher, XNetworkingUnbondingFetcher, XNetworkingValidatorsFetcher, XNetworkingExternalApiType, XNetworkingStakingOption, XNetworkingKotlinx_serialization_jsonJsonElement, XNetworkingKotlinThrowable, XNetworkingKotlinException, XNetworkingKotlinRuntimeException, XNetworkingExternalApiDAOException, XNetworkingExternalApiTypeCompanion, XNetworkingExternalApiTypeEtherScan, XNetworkingExternalApiTypeGiantSquid, XNetworkingExternalApiTypeGitHub, XNetworkingExternalApiTypeOkLink, XNetworkingExternalApiTypeReef, XNetworkingExternalApiTypeSora, XNetworkingExternalApiTypeSubQuery, XNetworkingExternalApiTypeSubSquid, XNetworkingExternalApiTypeUnknown, XNetworkingExternalApiTypeZeta, XNetworkingConfigParser, XNetworkingKotlinx_serialization_jsonJson, XNetworkingTxHistoryItem, XNetworkingTxHistoryInfo, XNetworkingChainInfo, XNetworkingTxFilter, XNetworkingTxHistoryResult<R>, XNetworkingTxHistoryItemParam, XNetworkingTxHistoryItemNested, XNetworkingPackedCursorCompanion, XNetworkingTxHistoryRepository, XNetworkingExpectActualDBDriverFactory, XNetworkingHistoryInfoRemoteLoader, XNetworkingSoraSubSquidResponseHistoryElementsConnection, XNetworkingSoraSubSquidResponseCompanion, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdge, XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfo, XNetworkingSoraSubSquidResponseHistoryElementsConnectionCompanion, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNode, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeCompanion, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResult, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeCompanion, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultError, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultCompanion, XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultErrorCompanion, XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfoCompanion, XNetworkingApollo_apiCustomScalarAdapters, XNetworkingKeyValuePreferences, XNetworkingExpectActualKeyValuePreferencesEngineFactory, XNetworkingAbstractRestServerRequest<T>, XNetworkingAbstractRestServerRequestWithBody<Response>, XNetworkingRestClientContentType, XNetworkingAbstractRestClientConfig, XNetworkingRestClientException, XNetworkingGraphQLSerializableRequestWrapperCompanion, XNetworkingApollo_apiCompiledField, XNetworkingApollo_apiOptional<__covariant V>, XNetworkingGetAssetsInfoQueryCompanion, XNetworkingGetAssetsInfoQuery, XNetworkingGetAssetsInfoQueryData, XNetworkingQueryBuilder, XNetworkingGetAssetsInfoQueryData1, XNetworkingGetAssetsInfoQueryEdge, XNetworkingGetAssetsInfoQueryPageInfo, XNetworkingGetAssetsInfoQueryNode, XNetworkingGetFiatDataQueryCompanion, XNetworkingGetFiatDataQuery, XNetworkingGetFiatDataQueryData, XNetworkingGetFiatDataQueryEntities, XNetworkingGetFiatDataQueryPageInfo, XNetworkingGetFiatDataQueryNode, XNetworkingHistoryElementsOrderBy, XNetworkingHistoryElementFilter, XNetworkingGetMainnetHistoryElementsQueryCompanion, XNetworkingGetMainnetHistoryElementsQuery, XNetworkingGetMainnetHistoryElementsQueryData, XNetworkingGetMainnetHistoryElementsQueryHistoryElements, XNetworkingGetMainnetHistoryElementsQueryPageInfo, XNetworkingGetMainnetHistoryElementsQueryNode, XNetworkingGetReferrerRewardsQueryCompanion, XNetworkingGetReferrerRewardsQuery, XNetworkingGetReferrerRewardsQueryData, XNetworkingGetReferrerRewardsQueryEntities, XNetworkingGetReferrerRewardsQueryPageInfo, XNetworkingGetReferrerRewardsQueryNode, XNetworkingGetSbApyInfoQueryCompanion, XNetworkingGetSbApyInfoQuery, XNetworkingGetSbApyInfoQueryData, XNetworkingGetSbApyInfoQueryData1, XNetworkingGetSbApyInfoQueryPageInfo, XNetworkingGetSbApyInfoQueryEdge, XNetworkingGetSbApyInfoQueryNode, XNetworkingGetAssetsInfoQuery_ResponseAdapter, XNetworkingGetAssetsInfoQuery_ResponseAdapterData, XNetworkingGetAssetsInfoQuery_ResponseAdapterData1, XNetworkingGetAssetsInfoQuery_ResponseAdapterEdge, XNetworkingGetAssetsInfoQuery_ResponseAdapterNode, XNetworkingGetAssetsInfoQuery_ResponseAdapterPageInfo, XNetworkingGetAssetsInfoQuery_VariablesAdapter, XNetworkingGetFiatDataQuery_ResponseAdapter, XNetworkingGetFiatDataQuery_ResponseAdapterData, XNetworkingGetFiatDataQuery_ResponseAdapterEntities, XNetworkingGetFiatDataQuery_ResponseAdapterNode, XNetworkingGetFiatDataQuery_ResponseAdapterPageInfo, XNetworkingGetFiatDataQuery_VariablesAdapter, XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapter, XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterData, XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterHistoryElements, XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterNode, XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterPageInfo, XNetworkingGetMainnetHistoryElementsQuery_VariablesAdapter, XNetworkingGetReferrerRewardsQuery_ResponseAdapter, XNetworkingGetReferrerRewardsQuery_ResponseAdapterData, XNetworkingGetReferrerRewardsQuery_ResponseAdapterEntities, XNetworkingGetReferrerRewardsQuery_ResponseAdapterNode, XNetworkingGetReferrerRewardsQuery_ResponseAdapterPageInfo, XNetworkingGetReferrerRewardsQuery_VariablesAdapter, XNetworkingGetSbApyInfoQuery_ResponseAdapter, XNetworkingGetSbApyInfoQuery_ResponseAdapterData, XNetworkingGetSbApyInfoQuery_ResponseAdapterData1, XNetworkingGetSbApyInfoQuery_ResponseAdapterEdge, XNetworkingGetSbApyInfoQuery_ResponseAdapterNode, XNetworkingGetSbApyInfoQuery_ResponseAdapterPageInfo, XNetworkingGetSbApyInfoQuery_VariablesAdapter, XNetworking__Schema, XNetworkingApollo_apiObjectType, XNetworkingApollo_apiCompiledNamedType, XNetworkingGetAssetsInfoQuerySelections, XNetworkingApollo_apiCompiledSelection, XNetworkingGetFiatDataQuerySelections, XNetworkingGetMainnetHistoryElementsQuerySelections, XNetworkingGetReferrerRewardsQuerySelections, XNetworkingGetSbApyInfoQuerySelections, XNetworkingAccountCompanion, XNetworkingAccountBuilder, XNetworkingApollo_apiObjectBuilder<__covariant T>, XNetworkingAssetCompanion, XNetworkingAssetBuilder, XNetworkingAssetSnapshotCompanion, XNetworkingAssetSnapshotBuilder, XNetworkingAssetsConnectionCompanion, XNetworkingAssetsConnectionBuilder, XNetworkingAssetsEdgeCompanion, XNetworkingAssetsEdgeBuilder, XNetworkingBigFloatCompanion, XNetworkingApollo_apiCustomScalarType, XNetworkingBigFloatFilter, XNetworkingCursorCompanion, XNetworkingGraphQLBooleanCompanion, XNetworkingGraphQLFloatCompanion, XNetworkingGraphQLIDCompanion, XNetworkingGraphQLIntCompanion, XNetworkingGraphQLStringCompanion, XNetworkingHistoryElementCompanion, XNetworkingHistoryElementBuilder, XNetworkingStringFilter, XNetworkingJSONFilter, XNetworkingIntFilter, XNetworkingHistoryElementsConnectionCompanion, XNetworkingHistoryElementsConnectionBuilder, XNetworkingHistoryElementsOrderByCompanion, XNetworkingApollo_apiEnumType, XNetworkingJSONCompanion, XNetworkingNetworkSnapshotCompanion, XNetworkingNetworkSnapshotBuilder, XNetworkingNetworkStatCompanion, XNetworkingNetworkStatBuilder, XNetworkingNodeCompanion, XNetworkingOtherNodeBuilder, XNetworkingApollo_apiInterfaceType, XNetworkingPageInfoCompanion, XNetworkingPageInfoBuilder, XNetworkingPoolXYKCompanion, XNetworkingPoolXYKBuilder, XNetworkingPoolXyksConnectionCompanion, XNetworkingPoolXyksConnectionBuilder, XNetworkingPoolXyksEdgeCompanion, XNetworkingPoolXyksEdgeBuilder, XNetworkingQueryCompanion, XNetworkingApollo_apiCompiledArgumentDefinition, XNetworkingReferrerRewardCompanion, XNetworkingReferrerRewardBuilder, XNetworkingReferrerRewardsConnectionCompanion, XNetworkingReferrerRewardsConnectionBuilder, XNetworkingBigFloatFilter_InputAdapter, XNetworkingHistoryElementFilter_InputAdapter, XNetworkingHistoryElementsOrderBy_ResponseAdapter, XNetworkingIntFilter_InputAdapter, XNetworkingJSONFilter_InputAdapter, XNetworkingStringFilter_InputAdapter, XNetworkingHistoryElementsOrderBy_, XNetworkingGetWestendHistoryElementsQueryCompanion, XNetworkingGetWestendHistoryElementsQuery, XNetworkingGetWestendHistoryElementsQueryData, XNetworkingQueryBuilder_, XNetworkingGetWestendHistoryElementsQueryHistoryElements, XNetworkingGetWestendHistoryElementsQueryPageInfo, XNetworkingGetWestendHistoryElementsQueryNode, XNetworkingGetWestendHistoryElementsQuery_ResponseAdapter, XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterData, XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterHistoryElements, XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterNode, XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterPageInfo, XNetworkingGetWestendHistoryElementsQuery_VariablesAdapter, XNetworking__Schema_, XNetworkingGetWestendHistoryElementsQuerySelections, XNetworkingAccumulatedRewardCompanion, XNetworkingAccumulatedRewardBuilder, XNetworkingAccumulatedStakeCompanion, XNetworkingAccumulatedStakeBuilder, XNetworkingBigFloat_Companion, XNetworkingCursor_Companion, XNetworkingEraValidatorInfoCompanion, XNetworkingEraValidatorInfoBuilder, XNetworkingErrorEventCompanion, XNetworkingErrorEventBuilder, XNetworkingGraphQLBoolean_Companion, XNetworkingGraphQLFloat_Companion, XNetworkingGraphQLID_Companion, XNetworkingGraphQLInt_Companion, XNetworkingGraphQLString_Companion, XNetworkingHistoryElement_Companion, XNetworkingHistoryElementBuilder_, XNetworkingHistoryElementsConnection_Companion, XNetworkingHistoryElementsConnectionBuilder_, XNetworkingHistoryElementsOrderBy_Companion, XNetworkingJSON_Companion, XNetworkingNode_Companion, XNetworkingOtherNodeBuilder_, XNetworkingPageInfo_Companion, XNetworkingPageInfoBuilder_, XNetworkingQuery_Companion, XNetworkingStakeChangeCompanion, XNetworkingStakeChangeBuilder, XNetworkingHistoryElementsOrderBy_ResponseAdapter_, XNetworkingPackedCursor, XNetworkingKotlinx_coroutines_coreDispatchers, XNetworkingKotlinx_coroutines_coreCoroutineDispatcher, XNetworkingKotlinx_coroutines_coreMainCoroutineDispatcher, XNetworkingKotlinx_serialization_jsonJsonElementCompanion, XNetworkingRuntimeTransacterTransaction, XNetworkingKotlinIllegalStateException, XNetworkingKotlinx_serialization_coreSerializersModule, XNetworkingKotlinx_serialization_jsonJsonDefault, XNetworkingKotlinx_serialization_jsonJsonConfiguration, XNetworkingKotlinNothing, XNetworkingApollo_apiJsonNumber, XNetworkingApollo_apiJsonReaderToken, XNetworkingApollo_apiCustomScalarAdaptersKey, XNetworkingApollo_apiError, XNetworkingApollo_apiCustomScalarAdaptersBuilder, XNetworkingApollo_apiDeferredFragmentIdentifier, XNetworkingApollo_apiExecutableVariables, XNetworkingApollo_apiCompiledArgument, XNetworkingApollo_apiCompiledFieldBuilder, XNetworkingApollo_apiCompiledCondition, XNetworkingApollo_apiCompiledType, XNetworkingApollo_apiOptionalCompanion, XNetworkingApollo_apiFakeResolverContext, XNetworkingApollo_apiObjectTypeBuilder, XNetworkingApollo_apiInterfaceTypeBuilder, XNetworkingApollo_apiCompiledArgumentDefinitionBuilder, XNetworkingKotlinAbstractCoroutineContextElement, XNetworkingKotlinx_coroutines_coreCoroutineDispatcherKey, XNetworkingKotlinByteArray, XNetworkingKotlinx_serialization_coreSerialKind, XNetworkingApollo_apiErrorLocation, XNetworkingApollo_apiOptionalAbsent, XNetworkingApollo_apiOptionalPresent<V>, XNetworkingKotlinAbstractCoroutineContextKey<B, E>, XNetworkingKotlinByteIterator, XNetworkingOkioByteString, XNetworkingOkioBuffer, XNetworkingOkioTimeout, XNetworkingOkioByteStringCompanion, XNetworkingOkioBufferUnsafeCursor, XNetworkingOkioTimeoutCompanion, NSData;

@protocol XNetworkingSoraHistoryDatabaseQueries, XNetworkingRuntimeTransactionWithoutReturn, XNetworkingRuntimeTransactionWithReturn, XNetworkingRuntimeTransacter, XNetworkingSoraHistoryDatabase, XNetworkingRuntimeSqlDriver, XNetworkingRuntimeSqlDriverSchema, XNetworkingKotlinComparable, XNetworkingHistoryItemsFilter, XNetworkingKotlinx_serialization_coreKSerializer, XNetworkingApollo_apiQuery, XNetworkingApollo_apiQueryData, XNetworkingApollo_apiJsonReader, XNetworkingApollo_apiJsonWriter, XNetworkingApollo_apiAdapter, XNetworkingKotlinx_coroutines_coreFlow, XNetworkingApollo_apiExecutable, XNetworkingApollo_apiOperation, XNetworkingApollo_apiFakeResolver, XNetworkingApollo_apiExecutableData, XNetworkingApollo_apiOperationData, XNetworkingApollo_apiBuilderFactory, XNetworkingApollo_apiBuilderScope, XNetworkingRuntimeTransactionCallbacks, XNetworkingRuntimeSqlPreparedStatement, XNetworkingRuntimeSqlCursor, XNetworkingRuntimeCloseable, XNetworkingRuntimeQueryListener, XNetworkingKotlinIterator, XNetworkingKotlinx_serialization_coreDeserializationStrategy, XNetworkingKotlinx_serialization_coreSerializationStrategy, XNetworkingKotlinx_serialization_coreSerialFormat, XNetworkingKotlinx_serialization_coreStringFormat, XNetworkingKotlinx_serialization_coreEncoder, XNetworkingKotlinx_serialization_coreSerialDescriptor, XNetworkingKotlinx_serialization_coreDecoder, XNetworkingOkioCloseable, XNetworkingApollo_apiExecutionContextKey, XNetworkingApollo_apiExecutionContextElement, XNetworkingApollo_apiExecutionContext, XNetworkingApollo_apiUpload, XNetworkingKotlinx_coroutines_coreFlowCollector, XNetworkingKotlinCoroutineContextKey, XNetworkingKotlinCoroutineContextElement, XNetworkingKotlinCoroutineContext, XNetworkingKotlinContinuation, XNetworkingKotlinContinuationInterceptor, XNetworkingKotlinx_coroutines_coreRunnable, XNetworkingKotlinx_serialization_coreSerializersModuleCollector, XNetworkingKotlinKClass, XNetworkingKotlinx_serialization_jsonJsonNamingStrategy, XNetworkingKotlinx_serialization_coreCompositeEncoder, XNetworkingKotlinAnnotation, XNetworkingKotlinx_serialization_coreCompositeDecoder, XNetworkingOkioBufferedSink, XNetworkingKotlinKDeclarationContainer, XNetworkingKotlinKAnnotatedElement, XNetworkingKotlinKClassifier, XNetworkingOkioSource, XNetworkingOkioSink, XNetworkingOkioBufferedSource;

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
@interface XNetworkingBase : NSObject
- (instancetype)init __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (void)initialize __attribute__((objc_requires_super));
@end

@interface XNetworkingBase (XNetworkingBaseCopying) <NSCopying>
@end

__attribute__((swift_name("KotlinMutableSet")))
@interface XNetworkingMutableSet<ObjectType> : NSMutableSet<ObjectType>
@end

__attribute__((swift_name("KotlinMutableDictionary")))
@interface XNetworkingMutableDictionary<KeyType, ObjectType> : NSMutableDictionary<KeyType, ObjectType>
@end

@interface NSError (NSErrorXNetworkingKotlinException)
@property (readonly) id _Nullable kotlinException;
@end

__attribute__((swift_name("KotlinNumber")))
@interface XNetworkingNumber : NSNumber
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
@interface XNetworkingByte : XNetworkingNumber
- (instancetype)initWithChar:(char)value;
+ (instancetype)numberWithChar:(char)value;
@end

__attribute__((swift_name("KotlinUByte")))
@interface XNetworkingUByte : XNetworkingNumber
- (instancetype)initWithUnsignedChar:(unsigned char)value;
+ (instancetype)numberWithUnsignedChar:(unsigned char)value;
@end

__attribute__((swift_name("KotlinShort")))
@interface XNetworkingShort : XNetworkingNumber
- (instancetype)initWithShort:(short)value;
+ (instancetype)numberWithShort:(short)value;
@end

__attribute__((swift_name("KotlinUShort")))
@interface XNetworkingUShort : XNetworkingNumber
- (instancetype)initWithUnsignedShort:(unsigned short)value;
+ (instancetype)numberWithUnsignedShort:(unsigned short)value;
@end

__attribute__((swift_name("KotlinInt")))
@interface XNetworkingInt : XNetworkingNumber
- (instancetype)initWithInt:(int)value;
+ (instancetype)numberWithInt:(int)value;
@end

__attribute__((swift_name("KotlinUInt")))
@interface XNetworkingUInt : XNetworkingNumber
- (instancetype)initWithUnsignedInt:(unsigned int)value;
+ (instancetype)numberWithUnsignedInt:(unsigned int)value;
@end

__attribute__((swift_name("KotlinLong")))
@interface XNetworkingLong : XNetworkingNumber
- (instancetype)initWithLongLong:(long long)value;
+ (instancetype)numberWithLongLong:(long long)value;
@end

__attribute__((swift_name("KotlinULong")))
@interface XNetworkingULong : XNetworkingNumber
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value;
@end

__attribute__((swift_name("KotlinFloat")))
@interface XNetworkingFloat : XNetworkingNumber
- (instancetype)initWithFloat:(float)value;
+ (instancetype)numberWithFloat:(float)value;
@end

__attribute__((swift_name("KotlinDouble")))
@interface XNetworkingDouble : XNetworkingNumber
- (instancetype)initWithDouble:(double)value;
+ (instancetype)numberWithDouble:(double)value;
@end

__attribute__((swift_name("KotlinBoolean")))
@interface XNetworkingBoolean : XNetworkingNumber
- (instancetype)initWithBool:(BOOL)value;
+ (instancetype)numberWithBool:(BOOL)value;
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExtrinsicParam")))
@interface XNetworkingExtrinsicParam : XNetworkingBase
- (instancetype)initWithExtrinsicHash:(NSString *)extrinsicHash paramName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("init(extrinsicHash:paramName:paramValue:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingExtrinsicParam *)doCopyExtrinsicHash:(NSString *)extrinsicHash paramName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("doCopy(extrinsicHash:paramName:paramValue:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *extrinsicHash __attribute__((swift_name("extrinsicHash")));
@property (readonly) NSString *paramName __attribute__((swift_name("paramName")));
@property (readonly) NSString *paramValue __attribute__((swift_name("paramValue")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Extrinsics")))
@interface XNetworkingExtrinsics : XNetworkingBase
- (instancetype)initWithTxHash:(NSString *)txHash signAddress:(NSString *)signAddress blockHash:(NSString * _Nullable)blockHash module:(NSString *)module method:(NSString *)method networkFee:(NSString *)networkFee timestamp:(int64_t)timestamp success:(BOOL)success batch:(BOOL)batch parentHash:(NSString * _Nullable)parentHash networkName:(NSString *)networkName __attribute__((swift_name("init(txHash:signAddress:blockHash:module:method:networkFee:timestamp:success:batch:parentHash:networkName:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingExtrinsics *)doCopyTxHash:(NSString *)txHash signAddress:(NSString *)signAddress blockHash:(NSString * _Nullable)blockHash module:(NSString *)module method:(NSString *)method networkFee:(NSString *)networkFee timestamp:(int64_t)timestamp success:(BOOL)success batch:(BOOL)batch parentHash:(NSString * _Nullable)parentHash networkName:(NSString *)networkName __attribute__((swift_name("doCopy(txHash:signAddress:blockHash:module:method:networkFee:timestamp:success:batch:parentHash:networkName:)")));
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
@interface XNetworkingSignerInfo : XNetworkingBase
- (instancetype)initWithSignAddress:(NSString *)signAddress topTime:(int64_t)topTime oldTime:(int64_t)oldTime oldCursor:(NSString * _Nullable)oldCursor endReached:(BOOL)endReached networkName:(NSString *)networkName __attribute__((swift_name("init(signAddress:topTime:oldTime:oldCursor:endReached:networkName:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingSignerInfo *)doCopySignAddress:(NSString *)signAddress topTime:(int64_t)topTime oldTime:(int64_t)oldTime oldCursor:(NSString * _Nullable)oldCursor endReached:(BOOL)endReached networkName:(NSString *)networkName __attribute__((swift_name("doCopy(signAddress:topTime:oldTime:oldCursor:endReached:networkName:)")));
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
@protocol XNetworkingRuntimeTransacter
@required
- (void)transactionNoEnclosing:(BOOL)noEnclosing body:(void (^)(id<XNetworkingRuntimeTransactionWithoutReturn>))body __attribute__((swift_name("transaction(noEnclosing:body:)")));
- (id _Nullable)transactionWithResultNoEnclosing:(BOOL)noEnclosing bodyWithReturn:(id _Nullable (^)(id<XNetworkingRuntimeTransactionWithReturn>))bodyWithReturn __attribute__((swift_name("transactionWithResult(noEnclosing:bodyWithReturn:)")));
@end

__attribute__((swift_name("SoraHistoryDatabase")))
@protocol XNetworkingSoraHistoryDatabase <XNetworkingRuntimeTransacter>
@required
@property (readonly) id<XNetworkingSoraHistoryDatabaseQueries> soraHistoryDatabaseQueries __attribute__((swift_name("soraHistoryDatabaseQueries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraHistoryDatabaseCompanion")))
@interface XNetworkingSoraHistoryDatabaseCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraHistoryDatabaseCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingSoraHistoryDatabase>)invokeDriver:(id<XNetworkingRuntimeSqlDriver>)driver __attribute__((swift_name("invoke(driver:)")));
@property (readonly) id<XNetworkingRuntimeSqlDriverSchema> Schema __attribute__((swift_name("Schema")));
@end

__attribute__((swift_name("SoraHistoryDatabaseQueries")))
@protocol XNetworkingSoraHistoryDatabaseQueries <XNetworkingRuntimeTransacter>
@required
- (void)insertExtrinsicTxHash:(NSString *)txHash signAddress:(NSString *)signAddress networkName:(NSString *)networkName blockHash:(NSString * _Nullable)blockHash module:(NSString *)module method:(NSString *)method networkFee:(NSString *)networkFee timestamp:(int64_t)timestamp success:(BOOL)success batch:(BOOL)batch parentHash:(NSString * _Nullable)parentHash __attribute__((swift_name("insertExtrinsic(txHash:signAddress:networkName:blockHash:module:method:networkFee:timestamp:success:batch:parentHash:)")));
- (void)insertExtrinsicParamExtrinsicHash:(NSString *)extrinsicHash paramName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("insertExtrinsicParam(extrinsicHash:paramName:paramValue:)")));
- (void)insertSignerInfoSignAddress:(NSString *)signAddress networkName:(NSString *)networkName topTime:(int64_t)topTime oldTime:(int64_t)oldTime oldCursor:(NSString * _Nullable)oldCursor endReached:(BOOL)endReached __attribute__((swift_name("insertSignerInfo(signAddress:networkName:topTime:oldTime:oldCursor:endReached:)")));
- (void)insertSignerInfoFullSignerInfo:(XNetworkingSignerInfo *)SignerInfo __attribute__((swift_name("insertSignerInfoFull(SignerInfo:)")));
- (void)removeAllExtrinsics __attribute__((swift_name("removeAllExtrinsics()")));
- (void)removeAllSignerInfo __attribute__((swift_name("removeAllSignerInfo()")));
- (void)removeExtrinsicsAddress:(NSString *)address network:(NSString *)network __attribute__((swift_name("removeExtrinsics(address:network:)")));
- (void)removeSignerInfoAddress:(NSString *)address network:(NSString *)network __attribute__((swift_name("removeSignerInfo(address:network:)")));
- (XNetworkingRuntimeQuery<XNetworkingExtrinsics *> *)selectExtrinsicHash:(NSString *)hash address:(NSString *)address network:(NSString *)network __attribute__((swift_name("selectExtrinsic(hash:address:network:)")));
- (XNetworkingRuntimeQuery<id> *)selectExtrinsicHash:(NSString *)hash address:(NSString *)address network:(NSString *)network mapper:(id (^)(NSString *, NSString *, NSString * _Nullable, NSString *, NSString *, NSString *, XNetworkingLong *, XNetworkingBoolean *, XNetworkingBoolean *, NSString * _Nullable, NSString *))mapper __attribute__((swift_name("selectExtrinsic(hash:address:network:mapper:)")));
- (XNetworkingRuntimeQuery<XNetworkingExtrinsicParam *> *)selectExtrinsicParamsExtrinsicHash:(NSString *)extrinsicHash __attribute__((swift_name("selectExtrinsicParams(extrinsicHash:)")));
- (XNetworkingRuntimeQuery<id> *)selectExtrinsicParamsExtrinsicHash:(NSString *)extrinsicHash mapper:(id (^)(NSString *, NSString *, NSString *))mapper __attribute__((swift_name("selectExtrinsicParams(extrinsicHash:mapper:)")));
- (XNetworkingRuntimeQuery<XNetworkingExtrinsics *> *)selectExtrinsicsNestedParentHash:(NSString * _Nullable)parentHash __attribute__((swift_name("selectExtrinsicsNested(parentHash:)")));
- (XNetworkingRuntimeQuery<id> *)selectExtrinsicsNestedParentHash:(NSString * _Nullable)parentHash mapper:(id (^)(NSString *, NSString *, NSString * _Nullable, NSString *, NSString *, NSString *, XNetworkingLong *, XNetworkingBoolean *, XNetworkingBoolean *, NSString * _Nullable, NSString *))mapper __attribute__((swift_name("selectExtrinsicsNested(parentHash:mapper:)")));
- (XNetworkingRuntimeQuery<XNetworkingExtrinsics *> *)selectExtrinsicsPagedAddress:(NSString *)address network:(NSString *)network limit:(int64_t)limit offset:(int64_t)offset __attribute__((swift_name("selectExtrinsicsPaged(address:network:limit:offset:)")));
- (XNetworkingRuntimeQuery<id> *)selectExtrinsicsPagedAddress:(NSString *)address network:(NSString *)network limit:(int64_t)limit offset:(int64_t)offset mapper:(id (^)(NSString *, NSString *, NSString * _Nullable, NSString *, NSString *, NSString *, XNetworkingLong *, XNetworkingBoolean *, XNetworkingBoolean *, NSString * _Nullable, NSString *))mapper __attribute__((swift_name("selectExtrinsicsPaged(address:network:limit:offset:mapper:)")));
- (XNetworkingRuntimeQuery<XNetworkingSignerInfo *> *)selectSignerInfoAddress:(NSString *)address network:(NSString *)network __attribute__((swift_name("selectSignerInfo(address:network:)")));
- (XNetworkingRuntimeQuery<id> *)selectSignerInfoAddress:(NSString *)address network:(NSString *)network mapper:(id (^)(NSString *, XNetworkingLong *, XNetworkingLong *, NSString * _Nullable, XNetworkingBoolean *, NSString *))mapper __attribute__((swift_name("selectSignerInfo(address:network:mapper:)")));
- (XNetworkingRuntimeQuery<NSString *> *)selectTransfersPeersNetwork:(NSString *)network query:(NSString *)query __attribute__((swift_name("selectTransfersPeers(network:query:)")));
@end

__attribute__((swift_name("BlockExplorerRepository")))
@interface XNetworkingBlockExplorerRepository : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getApyChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getApy(chainId:selectedCandidates:completionHandler:)")));

/**
 * @note This method converts instances of ApolloException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getAssetsInfoChainId:(NSString *)chainId tokenIds:(NSArray<NSString *> *)tokenIds timeStamp:(int32_t)timeStamp completionHandler:(void (^)(NSArray<XNetworkingAssetInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getAssetsInfo(chainId:tokenIds:timeStamp:completionHandler:)")));

/**
 * @note This method converts instances of ApolloException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getFiatChainId:(NSString *)chainId completionHandler:(void (^)(NSArray<XNetworkingFiat *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getFiat(chainId:completionHandler:)")));

/**
 * @note This method converts instances of ApolloException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getReferralRewardChainId:(NSString *)chainId address:(NSString *)address completionHandler:(void (^)(NSArray<XNetworkingReferralReward *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getReferralReward(chainId:address:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getUnbondingsListChainId:(NSString *)chainId delegatorAddress:(NSString *)delegatorAddress collatorAddress:(NSString *)collatorAddress completionHandler:(void (^)(NSArray<XNetworkingUnbonding *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getUnbondingsList(chainId:delegatorAddress:collatorAddress:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getValidatorsListChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getValidatorsList(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((swift_name("ApyFetcher")))
@interface XNetworkingApyFetcher : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:selectedCandidates:completionHandler:)")));
@end

__attribute__((swift_name("AssetInfoFetcher")))
@interface XNetworkingAssetInfoFetcher : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId tokenIds:(NSArray<NSString *> *)tokenIds timeStamp:(int32_t)timeStamp completionHandler:(void (^)(NSArray<XNetworkingAssetInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:tokenIds:timeStamp:completionHandler:)")));
@end

__attribute__((swift_name("FiatFetcher")))
@interface XNetworkingFiatFetcher : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId completionHandler:(void (^)(NSArray<XNetworkingFiat *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:completionHandler:)")));
@end

__attribute__((swift_name("ReferralRewardFetcher")))
@interface XNetworkingReferralRewardFetcher : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId address:(NSString *)address completionHandler:(void (^)(NSArray<XNetworkingReferralReward *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:address:completionHandler:)")));
@end

__attribute__((swift_name("UnbondingFetcher")))
@interface XNetworkingUnbondingFetcher : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId delegatorAddress:(NSString *)delegatorAddress collatorAddress:(NSString *)collatorAddress completionHandler:(void (^)(NSArray<XNetworkingUnbonding *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:delegatorAddress:collatorAddress:completionHandler:)")));
@end

__attribute__((swift_name("ValidatorsFetcher")))
@interface XNetworkingValidatorsFetcher : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apy")))
@interface XNetworkingApy : XNetworkingBase
- (instancetype)initWithId:(NSString *)id value:(NSString * _Nullable)value __attribute__((swift_name("init(id:value:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApy *)doCopyId:(NSString *)id value:(NSString * _Nullable)value __attribute__((swift_name("doCopy(id:value:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetInfo")))
@interface XNetworkingAssetInfo : XNetworkingBase
- (instancetype)initWithId:(NSString *)id liquidity:(NSString *)liquidity previousPrice:(XNetworkingDouble * _Nullable)previousPrice __attribute__((swift_name("init(id:liquidity:previousPrice:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingAssetInfo *)doCopyId:(NSString *)id liquidity:(NSString *)liquidity previousPrice:(XNetworkingDouble * _Nullable)previousPrice __attribute__((swift_name("doCopy(id:liquidity:previousPrice:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *liquidity __attribute__((swift_name("liquidity")));
@property (readonly) XNetworkingDouble * _Nullable previousPrice __attribute__((swift_name("previousPrice")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Fiat")))
@interface XNetworkingFiat : XNetworkingBase
- (instancetype)initWithId:(NSString *)id priceUSD:(NSString *)priceUSD __attribute__((swift_name("init(id:priceUSD:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingFiat *)doCopyId:(NSString *)id priceUSD:(NSString *)priceUSD __attribute__((swift_name("doCopy(id:priceUSD:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *priceUSD __attribute__((swift_name("priceUSD")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferralReward")))
@interface XNetworkingReferralReward : XNetworkingBase
- (instancetype)initWithReferral:(NSString *)referral amount:(NSString *)amount __attribute__((swift_name("init(referral:amount:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingReferralReward *)doCopyReferral:(NSString *)referral amount:(NSString *)amount __attribute__((swift_name("doCopy(referral:amount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *amount __attribute__((swift_name("amount")));
@property (readonly) NSString *referral __attribute__((swift_name("referral")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Unbonding")))
@interface XNetworkingUnbonding : XNetworkingBase
- (instancetype)initWithAmount:(NSString *)amount timestamp:(NSString *)timestamp type:(XNetworkingUnbondingDelegationAction * _Nullable)type __attribute__((swift_name("init(amount:timestamp:type:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingUnbonding *)doCopyAmount:(NSString *)amount timestamp:(NSString *)timestamp type:(XNetworkingUnbondingDelegationAction * _Nullable)type __attribute__((swift_name("doCopy(amount:timestamp:type:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *amount __attribute__((swift_name("amount")));
@property (readonly) NSString *timestamp __attribute__((swift_name("timestamp")));
@property (readonly) XNetworkingUnbondingDelegationAction * _Nullable type __attribute__((swift_name("type")));
@end

__attribute__((swift_name("KotlinComparable")))
@protocol XNetworkingKotlinComparable
@required
- (int32_t)compareToOther:(id _Nullable)other __attribute__((swift_name("compareTo(other:)")));
@end

__attribute__((swift_name("KotlinEnum")))
@interface XNetworkingKotlinEnum<E> : XNetworkingBase <XNetworkingKotlinComparable>
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingKotlinEnumCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(E)other __attribute__((swift_name("compareTo(other:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) int32_t ordinal __attribute__((swift_name("ordinal")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Unbonding.DelegationAction")))
@interface XNetworkingUnbondingDelegationAction : XNetworkingKotlinEnum<XNetworkingUnbondingDelegationAction *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) XNetworkingUnbondingDelegationAction *stake __attribute__((swift_name("stake")));
@property (class, readonly) XNetworkingUnbondingDelegationAction *unstake __attribute__((swift_name("unstake")));
@property (class, readonly) XNetworkingUnbondingDelegationAction *reward __attribute__((swift_name("reward")));
@property (class, readonly) XNetworkingUnbondingDelegationAction *delegate __attribute__((swift_name("delegate")));
@property (class, readonly) XNetworkingUnbondingDelegationAction *other __attribute__((swift_name("other")));
+ (XNetworkingKotlinArray<XNetworkingUnbondingDelegationAction *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingUnbondingDelegationAction *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BlockExplorerRepositoryImpl")))
@interface XNetworkingBlockExplorerRepositoryImpl : XNetworkingBlockExplorerRepository
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore __attribute__((swift_name("init(configDAO:restClient:apolloClientStore:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithApyFetcher:(XNetworkingApyFetcher *)apyFetcher assetInfoFetcher:(XNetworkingAssetInfoFetcher *)assetInfoFetcher fiatFetcher:(XNetworkingFiatFetcher *)fiatFetcher referralRewardFetcher:(XNetworkingReferralRewardFetcher *)referralRewardFetcher unbondingFetcher:(XNetworkingUnbondingFetcher *)unbondingFetcher validatorsFetcher:(XNetworkingValidatorsFetcher *)validatorsFetcher __attribute__((swift_name("init(apyFetcher:assetInfoFetcher:fiatFetcher:referralRewardFetcher:unbondingFetcher:validatorsFetcher:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getApyChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getApy(chainId:selectedCandidates:completionHandler:)")));

/**
 * @note This method converts instances of ApolloException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getAssetsInfoChainId:(NSString *)chainId tokenIds:(NSArray<NSString *> *)tokenIds timeStamp:(int32_t)timeStamp completionHandler:(void (^)(NSArray<XNetworkingAssetInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getAssetsInfo(chainId:tokenIds:timeStamp:completionHandler:)")));

/**
 * @note This method converts instances of ApolloException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getFiatChainId:(NSString *)chainId completionHandler:(void (^)(NSArray<XNetworkingFiat *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getFiat(chainId:completionHandler:)")));

/**
 * @note This method converts instances of ApolloException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getReferralRewardChainId:(NSString *)chainId address:(NSString *)address completionHandler:(void (^)(NSArray<XNetworkingReferralReward *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getReferralReward(chainId:address:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getUnbondingsListChainId:(NSString *)chainId delegatorAddress:(NSString *)delegatorAddress collatorAddress:(NSString *)collatorAddress completionHandler:(void (^)(NSArray<XNetworkingUnbonding *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getUnbondingsList(chainId:delegatorAddress:collatorAddress:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getValidatorsListChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getValidatorsList(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ApyFetcherFacade")))
@interface XNetworkingApyFetcherFacade : XNetworkingApyFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore __attribute__((swift_name("init(configDAO:restClient:apolloClientStore:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:selectedCandidates:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraApyFetcher")))
@interface XNetworkingSoraApyFetcher : XNetworkingApyFetcher
- (instancetype)initWithApolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore configDAO:(XNetworkingConfigDAO *)configDAO __attribute__((swift_name("init(apolloClientStore:configDAO:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:selectedCandidates:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryApyFetcher")))
@interface XNetworkingSubQueryApyFetcher : XNetworkingApyFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:selectedCandidates:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubSquidApyFetcher")))
@interface XNetworkingSubSquidApyFetcher : XNetworkingApyFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId selectedCandidates:(NSArray<NSString *> * _Nullable)selectedCandidates completionHandler:(void (^)(NSArray<XNetworkingApy *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:selectedCandidates:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetInfoFetcherFacade")))
@interface XNetworkingAssetInfoFetcherFacade : XNetworkingAssetInfoFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore __attribute__((swift_name("init(configDAO:apolloClientStore:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId tokenIds:(NSArray<NSString *> *)tokenIds timeStamp:(int32_t)timeStamp completionHandler:(void (^)(NSArray<XNetworkingAssetInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:tokenIds:timeStamp:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraAssetInfoFetcher")))
@interface XNetworkingSoraAssetInfoFetcher : XNetworkingAssetInfoFetcher
- (instancetype)initWithApolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore configDAO:(XNetworkingConfigDAO *)configDAO __attribute__((swift_name("init(apolloClientStore:configDAO:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId tokenIds:(NSArray<NSString *> *)tokenIds timeStamp:(int32_t)timeStamp completionHandler:(void (^)(NSArray<XNetworkingAssetInfo *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:tokenIds:timeStamp:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FiatFetcherFacade")))
@interface XNetworkingFiatFetcherFacade : XNetworkingFiatFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore __attribute__((swift_name("init(configDAO:apolloClientStore:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId completionHandler:(void (^)(NSArray<XNetworkingFiat *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraFiatFetcher")))
@interface XNetworkingSoraFiatFetcher : XNetworkingFiatFetcher
- (instancetype)initWithApolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore configDAO:(XNetworkingConfigDAO *)configDAO __attribute__((swift_name("init(apolloClientStore:configDAO:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId completionHandler:(void (^)(NSArray<XNetworkingFiat *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferralRewardFetcherFacade")))
@interface XNetworkingReferralRewardFetcherFacade : XNetworkingReferralRewardFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore __attribute__((swift_name("init(configDAO:apolloClientStore:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId address:(NSString *)address completionHandler:(void (^)(NSArray<XNetworkingReferralReward *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:address:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraReferralRewardsFetcher")))
@interface XNetworkingSoraReferralRewardsFetcher : XNetworkingReferralRewardFetcher
- (instancetype)initWithApolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore configDAO:(XNetworkingConfigDAO *)configDAO __attribute__((swift_name("init(apolloClientStore:configDAO:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, IllegalStateException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId address:(NSString *)address completionHandler:(void (^)(NSArray<XNetworkingReferralReward *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:address:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("UnbondingFetcherFacade")))
@interface XNetworkingUnbondingFetcherFacade : XNetworkingUnbondingFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId delegatorAddress:(NSString *)delegatorAddress collatorAddress:(NSString *)collatorAddress completionHandler:(void (^)(NSArray<XNetworkingUnbonding *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:delegatorAddress:collatorAddress:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryUnbondingFetcher")))
@interface XNetworkingSubQueryUnbondingFetcher : XNetworkingUnbondingFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId delegatorAddress:(NSString *)delegatorAddress collatorAddress:(NSString *)collatorAddress completionHandler:(void (^)(NSArray<XNetworkingUnbonding *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:delegatorAddress:collatorAddress:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubSquidUnbondingFetcher")))
@interface XNetworkingSubSquidUnbondingFetcher : XNetworkingUnbondingFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId delegatorAddress:(NSString *)delegatorAddress collatorAddress:(NSString *)collatorAddress completionHandler:(void (^)(NSArray<XNetworkingUnbonding *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:delegatorAddress:collatorAddress:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ValidatorsFetcherFacade")))
@interface XNetworkingValidatorsFetcherFacade : XNetworkingValidatorsFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraValidatorsFetcher")))
@interface XNetworkingSoraValidatorsFetcher : XNetworkingValidatorsFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryValidatorsFetcher")))
@interface XNetworkingSubQueryValidatorsFetcher : XNetworkingValidatorsFetcher
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubSquidValidatorsFetcher")))
@interface XNetworkingSubSquidValidatorsFetcher : XNetworkingValidatorsFetcher
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of RestClientException, CancellationException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)fetchChainId:(NSString *)chainId stashAccountAddress:(NSString *)stashAccountAddress historicalRange:(NSArray<NSString *> *)historicalRange completionHandler:(void (^)(NSArray<NSString *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("fetch(chainId:stashAccountAddress:historicalRange:completionHandler:)")));
@end

__attribute__((swift_name("ConfigDAO")))
@interface XNetworkingConfigDAO : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)historyTypeChainId:(NSString *)chainId completionHandler:(void (^)(XNetworkingExternalApiType * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("historyType(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)historyUrlChainId:(NSString *)chainId completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("historyUrl(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)stakingChainId:(NSString *)chainId completionHandler:(void (^)(XNetworkingStakingOption * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("staking(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)stakingTypeChainId:(NSString *)chainId completionHandler:(void (^)(XNetworkingExternalApiType * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("stakingType(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)stakingUrlChainId:(NSString *)chainId completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("stakingUrl(chainId:completionHandler:)")));
@end

__attribute__((swift_name("ConfigParser")))
@interface XNetworkingConfigParser : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of IllegalArgumentException, RestClientException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getChainObjectByIdChainId:(NSString *)chainId completionHandler:(void (^)(NSDictionary<NSString *, XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getChainObjectById(chainId:completionHandler:)")));
@end

__attribute__((swift_name("KotlinThrowable")))
@interface XNetworkingKotlinThrowable : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));

/**
 * @note annotations
 *   kotlin.experimental.ExperimentalNativeApi
*/
- (XNetworkingKotlinArray<NSString *> *)getStackTrace __attribute__((swift_name("getStackTrace()")));
- (void)printStackTrace __attribute__((swift_name("printStackTrace()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingKotlinThrowable * _Nullable cause __attribute__((swift_name("cause")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
- (NSError *)asError __attribute__((swift_name("asError()")));
@end

__attribute__((swift_name("KotlinException")))
@interface XNetworkingKotlinException : XNetworkingKotlinThrowable
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinRuntimeException")))
@interface XNetworkingKotlinRuntimeException : XNetworkingKotlinException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("ExternalApiDAOException")))
@interface XNetworkingExternalApiDAOException : XNetworkingKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiDAOException.NullType")))
@interface XNetworkingExternalApiDAOExceptionNullType : XNetworkingExternalApiDAOException
- (instancetype)initWithChainId:(NSString *)chainId __attribute__((swift_name("init(chainId:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiDAOException.NullUrl")))
@interface XNetworkingExternalApiDAOExceptionNullUrl : XNetworkingExternalApiDAOException
- (instancetype)initWithChainId:(NSString *)chainId __attribute__((swift_name("init(chainId:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("ExternalApiType")))
@interface XNetworkingExternalApiType : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingExternalApiTypeCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.Companion")))
@interface XNetworkingExternalApiTypeCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingExternalApiType * _Nullable)valueOfValue:(NSString * _Nullable)value __attribute__((swift_name("valueOf(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.EtherScan")))
@interface XNetworkingExternalApiTypeEtherScan : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)etherScan __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeEtherScan *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.GiantSquid")))
@interface XNetworkingExternalApiTypeGiantSquid : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)giantSquid __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeGiantSquid *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.GitHub")))
@interface XNetworkingExternalApiTypeGitHub : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)gitHub __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeGitHub *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.OkLink")))
@interface XNetworkingExternalApiTypeOkLink : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)okLink __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeOkLink *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.Reef")))
@interface XNetworkingExternalApiTypeReef : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)reef __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeReef *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.Sora")))
@interface XNetworkingExternalApiTypeSora : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)sora __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeSora *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.SubQuery")))
@interface XNetworkingExternalApiTypeSubQuery : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)subQuery __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeSubQuery *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.SubSquid")))
@interface XNetworkingExternalApiTypeSubSquid : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)subSquid __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeSubSquid *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.Unknown")))
@interface XNetworkingExternalApiTypeUnknown : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)unknown __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeUnknown *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExternalApiType.Zeta")))
@interface XNetworkingExternalApiTypeZeta : XNetworkingExternalApiType
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (instancetype)zeta __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingExternalApiTypeZeta *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StakingOption")))
@interface XNetworkingStakingOption : XNetworkingKotlinEnum<XNetworkingStakingOption *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) XNetworkingStakingOption *relaychain __attribute__((swift_name("relaychain")));
@property (class, readonly) XNetworkingStakingOption *parachain __attribute__((swift_name("parachain")));
+ (XNetworkingKotlinArray<XNetworkingStakingOption *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingStakingOption *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SuperWalletConfigDAOImpl")))
@interface XNetworkingSuperWalletConfigDAOImpl : XNetworkingConfigDAO
- (instancetype)initWithConfigParser:(XNetworkingConfigParser *)configParser __attribute__((swift_name("init(configParser:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)historyTypeChainId:(NSString *)chainId completionHandler:(void (^)(XNetworkingExternalApiType * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("historyType(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)historyUrlChainId:(NSString *)chainId completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("historyUrl(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)stakingChainId:(NSString *)chainId completionHandler:(void (^)(XNetworkingStakingOption * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("staking(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)stakingTypeChainId:(NSString *)chainId completionHandler:(void (^)(XNetworkingExternalApiType * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("stakingType(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, RestClientException, ExternalApiDAOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)stakingUrlChainId:(NSString *)chainId completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("stakingUrl(chainId:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JsonConfigParserImpl")))
@interface XNetworkingJsonConfigParserImpl : XNetworkingConfigParser
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of IllegalArgumentException, RestClientException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getChainObjectByIdChainId:(NSString *)chainId completionHandler:(void (^)(NSDictionary<NSString *, XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getChainObjectById(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)replaceJsonJson:(XNetworkingKotlinx_serialization_jsonJsonElement *)json completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("replaceJson(json:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("RemoteConfigParserImpl")))
@interface XNetworkingRemoteConfigParserImpl : XNetworkingConfigParser
- (instancetype)initWithRestClient:(XNetworkingRestClient *)restClient chainsRequestUrl:(NSString *)chainsRequestUrl __attribute__((swift_name("init(restClient:chainsRequestUrl:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of IllegalArgumentException, RestClientException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getChainObjectByIdChainId:(NSString *)chainId completionHandler:(void (^)(NSDictionary<NSString *, XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getChainObjectById(chainId:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StringConfigParserImpl")))
@interface XNetworkingStringConfigParserImpl : XNetworkingConfigParser
- (instancetype)initWithJson:(XNetworkingKotlinx_serialization_jsonJson *)json __attribute__((swift_name("init(json:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of IllegalArgumentException, RestClientException, CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getChainObjectByIdChainId:(NSString *)chainId completionHandler:(void (^)(NSDictionary<NSString *, XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getChainObjectById(chainId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)replaceStringJsonValue:(NSString *)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("replaceStringJson(value:completionHandler:)")));
@end

__attribute__((swift_name("HistoryItemsFilter")))
@protocol XNetworkingHistoryItemsFilter
@required
- (NSArray<XNetworkingTxHistoryItem *> *)filterCachedHistoryItems:(NSArray<XNetworkingTxHistoryItem *> *)receiver __attribute__((swift_name("filterCachedHistoryItems(_:)")));
- (NSArray<XNetworkingTxHistoryItem *> *)filterPagedHistoryItems:(NSArray<XNetworkingTxHistoryItem *> *)receiver __attribute__((swift_name("filterPagedHistoryItems(_:)")));
@end

__attribute__((swift_name("TxHistoryRepository")))
@interface XNetworkingTxHistoryRepository : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)clearAllData __attribute__((swift_name("clearAllData()")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)clearDataAddress:(NSString *)address chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("clearData(address:chainId:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingTxHistoryInfo * _Nullable)getTransactionCachedTxHash:(NSString *)txHash address:(NSString *)address chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("getTransactionCached(txHash:address:chainId:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSArray<XNetworkingTxHistoryItem *> * _Nullable)getTransactionHistoryCachedCount:(int32_t)count address:(NSString *)address chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("getTransactionHistoryCached(count:address:chainId:)")));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getTransactionHistoryPagedAddress:(NSString *)address page:(int64_t)page pageCount:(int32_t)pageCount chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryResult<XNetworkingTxHistoryItem *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getTransactionHistoryPaged(address:page:pageCount:chainInfo:filters:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSArray<NSString *> * _Nullable)getTransactionPeersQuery:(NSString *)query chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("getTransactionPeers(query:chainId:)")));
@end

__attribute__((swift_name("HistoryInfoRemoteLoader")))
@interface XNetworkingHistoryInfoRemoteLoader : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((swift_name("ChainInfo")))
@interface XNetworkingChainInfo : XNetworkingBase
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainInfo.Ethereum")))
@interface XNetworkingChainInfoEthereum : XNetworkingChainInfo
- (instancetype)initWithChainId:(NSString *)chainId contractAddress:(NSString *)contractAddress ethereumType:(NSString * _Nullable)ethereumType apiKey:(NSString *)apiKey __attribute__((swift_name("init(chainId:contractAddress:ethereumType:apiKey:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *apiKey __attribute__((swift_name("apiKey")));
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@property (readonly) NSString *contractAddress __attribute__((swift_name("contractAddress")));
@property (readonly) NSString * _Nullable ethereumType __attribute__((swift_name("ethereumType")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainInfo.OkLink")))
@interface XNetworkingChainInfoOkLink : XNetworkingChainInfo
- (instancetype)initWithChainId:(NSString *)chainId symbol:(NSString *)symbol apiKey:(NSString *)apiKey __attribute__((swift_name("init(chainId:symbol:apiKey:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *apiKey __attribute__((swift_name("apiKey")));
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@property (readonly) NSString *symbol __attribute__((swift_name("symbol")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainInfo.Simple")))
@interface XNetworkingChainInfoSimple : XNetworkingChainInfo
- (instancetype)initWithChainId:(NSString *)chainId __attribute__((swift_name("init(chainId:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainInfo.Zeta")))
@interface XNetworkingChainInfoZeta : XNetworkingChainInfo
- (instancetype)initWithChainId:(NSString *)chainId contractAddress:(NSString *)contractAddress ethereumType:(NSString * _Nullable)ethereumType __attribute__((swift_name("init(chainId:contractAddress:ethereumType:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@property (readonly) NSString *contractAddress __attribute__((swift_name("contractAddress")));
@property (readonly) NSString * _Nullable ethereumType __attribute__((swift_name("ethereumType")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxFilter")))
@interface XNetworkingTxFilter : XNetworkingKotlinEnum<XNetworkingTxFilter *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) XNetworkingTxFilter *extrinsic __attribute__((swift_name("extrinsic")));
@property (class, readonly) XNetworkingTxFilter *reward __attribute__((swift_name("reward")));
@property (class, readonly) XNetworkingTxFilter *transfer __attribute__((swift_name("transfer")));
+ (XNetworkingKotlinArray<XNetworkingTxFilter *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingTxFilter *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryInfo")))
@interface XNetworkingTxHistoryInfo : XNetworkingBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached items:(NSArray<XNetworkingTxHistoryItem *> *)items __attribute__((swift_name("init(endCursor:endReached:items:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingTxHistoryInfo *)doCopyEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached items:(NSArray<XNetworkingTxHistoryItem *> *)items __attribute__((swift_name("doCopy(endCursor:endReached:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL endReached __attribute__((swift_name("endReached")));
@property (readonly) NSArray<XNetworkingTxHistoryItem *> *items __attribute__((swift_name("items")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryItem")))
@interface XNetworkingTxHistoryItem : XNetworkingBase
- (instancetype)initWithId:(NSString *)id blockHash:(NSString *)blockHash module:(NSString *)module method:(NSString *)method timestamp:(NSString *)timestamp networkFee:(NSString *)networkFee success:(BOOL)success data:(NSArray<XNetworkingTxHistoryItemParam *> * _Nullable)data nestedData:(NSArray<XNetworkingTxHistoryItemNested *> * _Nullable)nestedData __attribute__((swift_name("init(id:blockHash:module:method:timestamp:networkFee:success:data:nestedData:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingTxHistoryItem *)doCopyId:(NSString *)id blockHash:(NSString *)blockHash module:(NSString *)module method:(NSString *)method timestamp:(NSString *)timestamp networkFee:(NSString *)networkFee success:(BOOL)success data:(NSArray<XNetworkingTxHistoryItemParam *> * _Nullable)data nestedData:(NSArray<XNetworkingTxHistoryItemNested *> * _Nullable)nestedData __attribute__((swift_name("doCopy(id:blockHash:module:method:timestamp:networkFee:success:data:nestedData:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *blockHash __attribute__((swift_name("blockHash")));
@property (readonly) NSArray<XNetworkingTxHistoryItemParam *> * _Nullable data __attribute__((swift_name("data")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@property (readonly) NSArray<XNetworkingTxHistoryItemNested *> * _Nullable nestedData __attribute__((swift_name("nestedData")));
@property (readonly) NSString *networkFee __attribute__((swift_name("networkFee")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@property (readonly) NSString *timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryItemNested")))
@interface XNetworkingTxHistoryItemNested : XNetworkingBase
- (instancetype)initWithModule:(NSString *)module method:(NSString *)method hash:(NSString *)hash data:(NSArray<XNetworkingTxHistoryItemParam *> *)data __attribute__((swift_name("init(module:method:hash:data:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingTxHistoryItemNested *)doCopyModule:(NSString *)module method:(NSString *)method hash:(NSString *)hash data:(NSArray<XNetworkingTxHistoryItemParam *> *)data __attribute__((swift_name("doCopy(module:method:hash:data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<XNetworkingTxHistoryItemParam *> *data __attribute__((swift_name("data")));
@property (readonly, getter=hash_) NSString *hash __attribute__((swift_name("hash")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryItemParam")))
@interface XNetworkingTxHistoryItemParam : XNetworkingBase
- (instancetype)initWithParamName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("init(paramName:paramValue:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingTxHistoryItemParam *)doCopyParamName:(NSString *)paramName paramValue:(NSString *)paramValue __attribute__((swift_name("doCopy(paramName:paramValue:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *paramName __attribute__((swift_name("paramName")));
@property (readonly) NSString *paramValue __attribute__((swift_name("paramValue")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryResult")))
@interface XNetworkingTxHistoryResult<R> : XNetworkingBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached page:(int64_t)page items:(NSArray<id> *)items errorMessage:(NSString * _Nullable)errorMessage __attribute__((swift_name("init(endCursor:endReached:page:items:errorMessage:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingTxHistoryResult<R> *)doCopyEndCursor:(NSString * _Nullable)endCursor endReached:(BOOL)endReached page:(int64_t)page items:(NSArray<id> *)items errorMessage:(NSString * _Nullable)errorMessage __attribute__((swift_name("doCopy(endCursor:endReached:page:items:errorMessage:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL endReached __attribute__((swift_name("endReached")));
@property (readonly) NSString * _Nullable errorMessage __attribute__((swift_name("errorMessage")));
@property (readonly) NSArray<id> *items __attribute__((swift_name("items")));
@property (readonly) int64_t page __attribute__((swift_name("page")));
@end

__attribute__((swift_name("PackedCursor")))
@interface XNetworkingPackedCursor : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingPackedCursorCompanion *companion __attribute__((swift_name("companion")));
- (NSString * _Nullable)getKey:(NSString *)key __attribute__((swift_name("get(key:)")));
- (NSString * _Nullable)pack __attribute__((swift_name("pack()")));
- (void)setKey:(NSString *)key cursor:(NSString * _Nullable)cursor __attribute__((swift_name("set(key:cursor:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PackedCursor.Companion")))
@interface XNetworkingPackedCursorCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingPackedCursorCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TxHistoryRepositoryImpl")))
@interface XNetworkingTxHistoryRepositoryImpl : XNetworkingTxHistoryRepository <XNetworkingHistoryItemsFilter>
- (instancetype)initWithDatabaseDriverFactory:(XNetworkingExpectActualDBDriverFactory *)databaseDriverFactory historyInfoRemoteLoader:(XNetworkingHistoryInfoRemoteLoader *)historyInfoRemoteLoader historyItemsFilter:(id<XNetworkingHistoryItemsFilter>)historyItemsFilter __attribute__((swift_name("init(databaseDriverFactory:historyInfoRemoteLoader:historyItemsFilter:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithDatabaseDriverFactory:(XNetworkingExpectActualDBDriverFactory *)databaseDriverFactory configDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient historyItemsFilter:(id<XNetworkingHistoryItemsFilter>)historyItemsFilter __attribute__((swift_name("init(databaseDriverFactory:configDAO:restClient:historyItemsFilter:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithDatabaseDriverFactory:(XNetworkingExpectActualDBDriverFactory *)databaseDriverFactory configDAO:(XNetworkingConfigDAO *)configDAO apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore restClient:(XNetworkingRestClient *)restClient historyItemsFilter:(id<XNetworkingHistoryItemsFilter>)historyItemsFilter __attribute__((swift_name("init(databaseDriverFactory:configDAO:apolloClientStore:restClient:historyItemsFilter:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (void)clearAllData __attribute__((swift_name("clearAllData()")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)clearDataAddress:(NSString *)address chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("clearData(address:chainId:)")));
- (NSArray<XNetworkingTxHistoryItem *> *)filterCachedHistoryItems:(NSArray<XNetworkingTxHistoryItem *> *)receiver __attribute__((swift_name("filterCachedHistoryItems(_:)")));
- (NSArray<XNetworkingTxHistoryItem *> *)filterPagedHistoryItems:(NSArray<XNetworkingTxHistoryItem *> *)receiver __attribute__((swift_name("filterPagedHistoryItems(_:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingTxHistoryInfo * _Nullable)getTransactionCachedTxHash:(NSString *)txHash address:(NSString *)address chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("getTransactionCached(txHash:address:chainId:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSArray<XNetworkingTxHistoryItem *> * _Nullable)getTransactionHistoryCachedCount:(int32_t)count address:(NSString *)address chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("getTransactionHistoryCached(count:address:chainId:)")));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getTransactionHistoryPagedAddress:(NSString *)address page:(int64_t)page pageCount:(int32_t)pageCount chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryResult<XNetworkingTxHistoryItem *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getTransactionHistoryPaged(address:page:pageCount:chainInfo:filters:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException, IllegalArgumentException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSArray<NSString *> * _Nullable)getTransactionPeersQuery:(NSString *)query chainId:(NSString *)chainId error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("getTransactionPeers(query:chainId:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExpectActualDBDriverFactory")))
@interface XNetworkingExpectActualDBDriverFactory : XNetworkingBase
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryInfoRemoteLoaderFacade")))
@interface XNetworkingHistoryInfoRemoteLoaderFacade : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO apolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:apolloClientStore:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EtherScanHistoryInfoRemoteLoader")))
@interface XNetworkingEtherScanHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GiantSquidHistoryInfoRemoteLoader")))
@interface XNetworkingGiantSquidHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkLinkHistoryInfoRemoteLoader")))
@interface XNetworkingOkLinkHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReefHistoryInfoRemoteLoader")))
@interface XNetworkingReefHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubQueryHistoryInfoRemoteLoader")))
@interface XNetworkingSoraSubQueryHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithApolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore configDAO:(XNetworkingConfigDAO *)configDAO __attribute__((swift_name("init(apolloClientStore:configDAO:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidHistoryInfoRemoteLoader")))
@interface XNetworkingSoraSubSquidHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse")))
@interface XNetworkingSoraSubSquidResponse : XNetworkingBase
- (instancetype)initWithHistoryElementsConnection:(XNetworkingSoraSubSquidResponseHistoryElementsConnection *)historyElementsConnection __attribute__((swift_name("init(historyElementsConnection:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) XNetworkingSoraSubSquidResponseHistoryElementsConnection *historyElementsConnection __attribute__((swift_name("historyElementsConnection")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.Companion")))
@interface XNetworkingSoraSubSquidResponseCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnection")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnection : XNetworkingBase
- (instancetype)initWithEdges:(NSArray<XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdge *> *)edges pageInfo:(XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfo *)pageInfo __attribute__((swift_name("init(edges:pageInfo:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseHistoryElementsConnectionCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) NSArray<XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdge *> *edges __attribute__((swift_name("edges")));
@property (readonly) XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionCompanion")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseHistoryElementsConnectionCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdge")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdge : XNetworkingBase
- (instancetype)initWithNode:(XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNode *)node __attribute__((swift_name("init(node:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNode *node __attribute__((swift_name("node")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeCompanion")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeNode")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNode : XNetworkingBase
- (instancetype)initWithId:(NSString *)id timestamp:(NSString *)timestamp networkFee:(NSString * _Nullable)networkFee module:(NSString *)module method:(NSString *)method execution:(XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResult * _Nullable)execution address:(NSString *)address blockHash:(NSString *)blockHash data:(XNetworkingKotlinx_serialization_jsonJsonElement *)data __attribute__((swift_name("init(id:timestamp:networkFee:module:method:execution:address:blockHash:data:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) NSString *address __attribute__((swift_name("address")));
@property (readonly) NSString *blockHash __attribute__((swift_name("blockHash")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonElement *data __attribute__((swift_name("data")));
@property (readonly) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResult * _Nullable execution __attribute__((swift_name("execution")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) NSString *module __attribute__((swift_name("module")));
@property (readonly) NSString * _Nullable networkFee __attribute__((swift_name("networkFee")));
@property (readonly) NSString *timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeNodeCompanion")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeNodeExecutionResult")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResult : XNetworkingBase
- (instancetype)initWithSuccess:(BOOL)success error:(XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultError * _Nullable)error __attribute__((swift_name("init(success:error:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultError * _Nullable error __attribute__((swift_name("error")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeNodeExecutionResultCompanion")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeNodeExecutionResultError")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultError : XNetworkingBase
- (instancetype)initWithModuleErrorId:(NSString * _Nullable)moduleErrorId moduleErrorIndex:(XNetworkingInt * _Nullable)moduleErrorIndex nonModuleErrorMessage:(NSString * _Nullable)nonModuleErrorMessage __attribute__((swift_name("init(moduleErrorId:moduleErrorIndex:nonModuleErrorMessage:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultErrorCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) NSString * _Nullable moduleErrorId __attribute__((swift_name("moduleErrorId")));
@property (readonly) XNetworkingInt * _Nullable moduleErrorIndex __attribute__((swift_name("moduleErrorIndex")));
@property (readonly) NSString * _Nullable nonModuleErrorMessage __attribute__((swift_name("nonModuleErrorMessage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionEdgeNodeExecutionResultErrorCompanion")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultErrorCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseHistoryElementsConnectionEdgeNodeExecutionResultErrorCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionPageInfo")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfo : XNetworkingBase
- (instancetype)initWithHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("init(hasNextPage:endCursor:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfoCompanion *companion __attribute__((swift_name("companion")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SoraSubSquidResponse.HistoryElementsConnectionPageInfoCompanion")))
@interface XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfoCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingSoraSubSquidResponseHistoryElementsConnectionPageInfoCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryHistoryInfoRemoteLoader")))
@interface XNetworkingSubQueryHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubSquidHistoryInfoRemoteLoader")))
@interface XNetworkingSubSquidHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WestendHistoryInfoRemoteLoader")))
@interface XNetworkingWestendHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithApolloClientStore:(XNetworkingApolloClientStore *)apolloClientStore configDAO:(XNetworkingConfigDAO *)configDAO __attribute__((swift_name("init(apolloClientStore:configDAO:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ZetaHistoryInfoRemoteLoader")))
@interface XNetworkingZetaHistoryInfoRemoteLoader : XNetworkingHistoryInfoRemoteLoader
- (instancetype)initWithConfigDAO:(XNetworkingConfigDAO *)configDAO restClient:(XNetworkingRestClient *)restClient __attribute__((swift_name("init(configDAO:restClient:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of ApolloException, RestClientException, CancellationException, ExternalApiDAOException, IllegalArgumentException, IllegalStateException, NullPointerException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)loadHistoryInfoPageCount:(int32_t)pageCount cursor:(NSString * _Nullable)cursor signAddress:(NSString *)signAddress chainInfo:(XNetworkingChainInfo *)chainInfo filters:(NSSet<XNetworkingTxFilter *> *)filters completionHandler:(void (^)(XNetworkingTxHistoryInfo * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("loadHistoryInfo(pageCount:cursor:signAddress:chainInfo:filters:completionHandler:)")));
@end

__attribute__((swift_name("ApolloClientStore")))
@interface XNetworkingApolloClientStore : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)queryServerUrl:(NSString *)serverUrl query:(id<XNetworkingApollo_apiQuery>)query completionHandler:(void (^)(id<XNetworkingApollo_apiQueryData> _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("query(serverUrl:query:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ApolloClientStoreImpl")))
@interface XNetworkingApolloClientStoreImpl : XNetworkingApolloClientStore
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)queryServerUrl:(NSString *)serverUrl query:(id<XNetworkingApollo_apiQuery>)query completionHandler:(void (^)(id<XNetworkingApollo_apiQueryData> _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("query(serverUrl:query:completionHandler:)")));
@end

__attribute__((swift_name("Apollo_apiAdapter")))
@protocol XNetworkingApollo_apiAdapter
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(id _Nullable)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSONAdapter")))
@interface XNetworkingJSONAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingKotlinx_serialization_jsonJsonElement *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((swift_name("KeyValuePreferences")))
@interface XNetworkingKeyValuePreferences : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearField:(NSString *)field completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clear(field:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearAllWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clearAll(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getBooleanField:(NSString *)field defaultValue:(BOOL)defaultValue completionHandler:(void (^)(XNetworkingBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getBoolean(field:defaultValue:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getLongField:(NSString *)field defaultValue:(int64_t)defaultValue completionHandler:(void (^)(XNetworkingLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getLong(field:defaultValue:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getSerializableSerializer:(id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer field:(NSString *)field completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("getSerializable(serializer:field:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getStringField:(NSString *)field completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getString(field:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putBooleanField:(NSString *)field value:(BOOL)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putBoolean(field:value:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putLongField:(NSString *)field value:(int64_t)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putLong(field:value:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putSerializableSerializer:(id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer field:(NSString *)field value:(id _Nullable)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putSerializable(serializer:field:value:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putStringField:(NSString *)field value:(NSString *)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putString(field:value:completionHandler:)")));
@property (readonly) id<XNetworkingKotlinx_coroutines_coreFlow> dataFlow __attribute__((swift_name("dataFlow")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KeyValuePreferencesImpl")))
@interface XNetworkingKeyValuePreferencesImpl : XNetworkingKeyValuePreferences
- (instancetype)initWithKeyValuePreferencesEngine:(XNetworkingExpectActualKeyValuePreferencesEngineFactory *)keyValuePreferencesEngine __attribute__((swift_name("init(keyValuePreferencesEngine:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearField:(NSString *)field completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clear(field:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearAllWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clearAll(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getBooleanField:(NSString *)field defaultValue:(BOOL)defaultValue completionHandler:(void (^)(XNetworkingBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getBoolean(field:defaultValue:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getLongField:(NSString *)field defaultValue:(int64_t)defaultValue completionHandler:(void (^)(XNetworkingLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getLong(field:defaultValue:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getSerializableSerializer:(id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer field:(NSString *)field completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("getSerializable(serializer:field:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getStringField:(NSString *)field completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getString(field:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putBooleanField:(NSString *)field value:(BOOL)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putBoolean(field:value:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putLongField:(NSString *)field value:(int64_t)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putLong(field:value:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putSerializableSerializer:(id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer field:(NSString *)field value:(id _Nullable)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putSerializable(serializer:field:value:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)putStringField:(NSString *)field value:(NSString *)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("putString(field:value:completionHandler:)")));
@property (readonly) id<XNetworkingKotlinx_coroutines_coreFlow> dataFlow __attribute__((swift_name("dataFlow")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExpectActualKeyValuePreferencesEngineFactory")))
@interface XNetworkingExpectActualKeyValuePreferencesEngineFactory : XNetworkingBase
- (instancetype)initWithPreferencesName:(NSString *)preferencesName __attribute__((swift_name("init(preferencesName:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("RestClient")))
@interface XNetworkingRestClient : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getAsStringRequest:(XNetworkingAbstractRestServerRequest<NSString *> *)request completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getAsString(request:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)postAsStringRequest:(XNetworkingAbstractRestServerRequestWithBody<NSString *> *)request completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("postAsString(request:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("RestClient.ContentType")))
@interface XNetworkingRestClientContentType : XNetworkingKotlinEnum<XNetworkingRestClientContentType *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) XNetworkingRestClientContentType *json __attribute__((swift_name("json")));
@property (class, readonly) XNetworkingRestClientContentType *none __attribute__((swift_name("none")));
+ (XNetworkingKotlinArray<XNetworkingRestClientContentType *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingRestClientContentType *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((swift_name("AbstractRestClientConfig")))
@interface XNetworkingAbstractRestClientConfig : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (int64_t)getConnectTimeoutMillis __attribute__((swift_name("getConnectTimeoutMillis()")));
- (XNetworkingKotlinx_serialization_jsonJson *)getOrCreateJsonConfig __attribute__((swift_name("getOrCreateJsonConfig()")));
- (int64_t)getRequestTimeoutMillis __attribute__((swift_name("getRequestTimeoutMillis()")));
- (int64_t)getSocketTimeoutMillis __attribute__((swift_name("getSocketTimeoutMillis()")));
- (BOOL)isLoggingEnabled __attribute__((swift_name("isLoggingEnabled()")));
@end

__attribute__((swift_name("AbstractRestClientConfig.AbstractWebSocketClientConfig")))
@interface XNetworkingAbstractRestClientConfigAbstractWebSocketClientConfig : XNetworkingAbstractRestClientConfig
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (int64_t)getMaxFrameSize __attribute__((swift_name("getMaxFrameSize()")));
- (int64_t)getPingInterval __attribute__((swift_name("getPingInterval()")));
@end

__attribute__((swift_name("AbstractRestServerRequest")))
@interface XNetworkingAbstractRestServerRequest<T> : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
@property (readonly) NSString * _Nullable bearerToken __attribute__((swift_name("bearerToken")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable headers __attribute__((swift_name("headers")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable queryParams __attribute__((swift_name("queryParams")));
@property (readonly) XNetworkingRestClientContentType *responseContentType __attribute__((swift_name("responseContentType")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@property (readonly) NSString * _Nullable userAgent __attribute__((swift_name("userAgent")));
@end

__attribute__((swift_name("AbstractRestServerRequestWithBody")))
@interface XNetworkingAbstractRestServerRequestWithBody<Response> : XNetworkingAbstractRestServerRequest<Response>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
@property (readonly) id body __attribute__((swift_name("body")));
@property (readonly) XNetworkingRestClientContentType *requestContentType __attribute__((swift_name("requestContentType")));
@end

__attribute__((swift_name("RestClientException")))
@interface XNetworkingRestClientException : XNetworkingKotlinThrowable
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("RestClientException.WhileSerialization")))
@interface XNetworkingRestClientExceptionWhileSerialization : XNetworkingRestClientException
- (instancetype)initWithMessage:(NSString *)message error:(XNetworkingKotlinThrowable * _Nullable)error __attribute__((swift_name("init(message:error:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("RestClientException.WithCode")))
@interface XNetworkingRestClientExceptionWithCode : XNetworkingRestClientException
- (instancetype)initWithCode:(int32_t)code message:(NSString *)message error:(XNetworkingKotlinThrowable * _Nullable)error __attribute__((swift_name("init(code:message:error:)"))) __attribute__((objc_designated_initializer));
@property (readonly) int32_t code __attribute__((swift_name("code")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("RestClientImpl")))
@interface XNetworkingRestClientImpl : XNetworkingRestClient
- (instancetype)initWithRestClientConfig:(XNetworkingAbstractRestClientConfig *)restClientConfig __attribute__((swift_name("init(restClientConfig:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getAsStringRequest:(XNetworkingAbstractRestServerRequest<NSString *> *)request completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getAsString(request:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)postAsStringRequest:(XNetworkingAbstractRestServerRequestWithBody<NSString *> *)request completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("postAsString(request:completionHandler:)")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLSerializableRequestWrapper")))
@interface XNetworkingGraphQLSerializableRequestWrapper : XNetworkingBase
- (instancetype)initWithQuery:(NSString *)query __attribute__((swift_name("init(query:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGraphQLSerializableRequestWrapperCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
@property (readonly) NSString *query __attribute__((swift_name("query")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLSerializableRequestWrapper.Companion")))
@interface XNetworkingGraphQLSerializableRequestWrapperCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLSerializableRequestWrapperCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JsonGetRequest")))
@interface XNetworkingJsonGetRequest : XNetworkingAbstractRestServerRequest<NSString *>
- (instancetype)initWithUrl:(NSString *)url headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers queryParams:(NSDictionary<NSString *, NSString *> * _Nullable)queryParams __attribute__((swift_name("init(url:headers:queryParams:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable headers __attribute__((swift_name("headers")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable queryParams __attribute__((swift_name("queryParams")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JsonPostRequest")))
@interface XNetworkingJsonPostRequest : XNetworkingAbstractRestServerRequestWithBody<NSString *>
- (instancetype)initWithUrl:(NSString *)url body:(id)body __attribute__((swift_name("init(url:body:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
@property (readonly) id body __attribute__((swift_name("body")));
@property (readonly) XNetworkingRestClientContentType *requestContentType __attribute__((swift_name("requestContentType")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@end

__attribute__((swift_name("Apollo_apiExecutable")))
@protocol XNetworkingApollo_apiExecutable
@required
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((swift_name("Apollo_apiOperation")))
@protocol XNetworkingApollo_apiOperation <XNetworkingApollo_apiExecutable>
@required
- (NSString *)document __attribute__((swift_name("document()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
@end

__attribute__((swift_name("Apollo_apiQuery")))
@protocol XNetworkingApollo_apiQuery <XNetworkingApollo_apiOperation>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery")))
@interface XNetworkingGetAssetsInfoQuery : XNetworkingBase <XNetworkingApollo_apiQuery>
- (instancetype)initWithCursor:(NSString *)cursor tokenIds:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)tokenIds __attribute__((swift_name("init(cursor:tokenIds:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGetAssetsInfoQueryCompanion *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingGetAssetsInfoQuery *)doCopyCursor:(NSString *)cursor tokenIds:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)tokenIds __attribute__((swift_name("doCopy(cursor:tokenIds:)")));
- (NSString *)document __attribute__((swift_name("document()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *cursor __attribute__((swift_name("cursor")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *tokenIds __attribute__((swift_name("tokenIds")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery.Companion")))
@interface XNetworkingGetAssetsInfoQueryCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingGetAssetsInfoQueryData *)DataResolver:(id<XNetworkingApollo_apiFakeResolver>)resolver block:(void (^)(XNetworkingQueryBuilder *))block __attribute__((swift_name("Data(resolver:block:)")));
@property (readonly) NSString *OPERATION_DOCUMENT __attribute__((swift_name("OPERATION_DOCUMENT")));
@property (readonly) NSString *OPERATION_ID __attribute__((swift_name("OPERATION_ID")));
@property (readonly) NSString *OPERATION_NAME __attribute__((swift_name("OPERATION_NAME")));
@end

__attribute__((swift_name("Apollo_apiExecutableData")))
@protocol XNetworkingApollo_apiExecutableData
@required
@end

__attribute__((swift_name("Apollo_apiOperationData")))
@protocol XNetworkingApollo_apiOperationData <XNetworkingApollo_apiExecutableData>
@required
@end

__attribute__((swift_name("Apollo_apiQueryData")))
@protocol XNetworkingApollo_apiQueryData <XNetworkingApollo_apiOperationData>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery.Data")))
@interface XNetworkingGetAssetsInfoQueryData : XNetworkingBase <XNetworkingApollo_apiQueryData>
- (instancetype)initWithData:(XNetworkingGetAssetsInfoQueryData1 * _Nullable)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetAssetsInfoQueryData *)doCopyData:(XNetworkingGetAssetsInfoQueryData1 * _Nullable)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetAssetsInfoQueryData1 * _Nullable data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery.Data1")))
@interface XNetworkingGetAssetsInfoQueryData1 : XNetworkingBase
- (instancetype)initWithEdges:(NSArray<XNetworkingGetAssetsInfoQueryEdge *> *)edges pageInfo:(XNetworkingGetAssetsInfoQueryPageInfo *)pageInfo __attribute__((swift_name("init(edges:pageInfo:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetAssetsInfoQueryData1 *)doCopyEdges:(NSArray<XNetworkingGetAssetsInfoQueryEdge *> *)edges pageInfo:(XNetworkingGetAssetsInfoQueryPageInfo *)pageInfo __attribute__((swift_name("doCopy(edges:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<XNetworkingGetAssetsInfoQueryEdge *> *edges __attribute__((swift_name("edges")));
@property (readonly) XNetworkingGetAssetsInfoQueryPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery.Edge")))
@interface XNetworkingGetAssetsInfoQueryEdge : XNetworkingBase
- (instancetype)initWithNode:(XNetworkingGetAssetsInfoQueryNode * _Nullable)node __attribute__((swift_name("init(node:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetAssetsInfoQueryEdge *)doCopyNode:(XNetworkingGetAssetsInfoQueryNode * _Nullable)node __attribute__((swift_name("doCopy(node:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetAssetsInfoQueryNode * _Nullable node __attribute__((swift_name("node")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery.Node")))
@interface XNetworkingGetAssetsInfoQueryNode : XNetworkingBase
- (instancetype)initWithId:(NSString * _Nullable)id liquidity:(NSString * _Nullable)liquidity priceChangeDay:(NSString * _Nullable)priceChangeDay __attribute__((swift_name("init(id:liquidity:priceChangeDay:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetAssetsInfoQueryNode *)doCopyId:(NSString * _Nullable)id liquidity:(NSString * _Nullable)liquidity priceChangeDay:(NSString * _Nullable)priceChangeDay __attribute__((swift_name("doCopy(id:liquidity:priceChangeDay:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable liquidity __attribute__((swift_name("liquidity")));
@property (readonly) NSString * _Nullable priceChangeDay __attribute__((swift_name("priceChangeDay")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery.PageInfo")))
@interface XNetworkingGetAssetsInfoQueryPageInfo : XNetworkingBase
- (instancetype)initWithHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("init(hasNextPage:endCursor:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetAssetsInfoQueryPageInfo *)doCopyHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("doCopy(hasNextPage:endCursor:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery")))
@interface XNetworkingGetFiatDataQuery : XNetworkingBase <XNetworkingApollo_apiQuery>
- (instancetype)initWithPageCount:(int32_t)pageCount cursor:(NSString *)cursor __attribute__((swift_name("init(pageCount:cursor:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGetFiatDataQueryCompanion *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingGetFiatDataQuery *)doCopyPageCount:(int32_t)pageCount cursor:(NSString *)cursor __attribute__((swift_name("doCopy(pageCount:cursor:)")));
- (NSString *)document __attribute__((swift_name("document()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *cursor __attribute__((swift_name("cursor")));
@property (readonly) int32_t pageCount __attribute__((swift_name("pageCount")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery.Companion")))
@interface XNetworkingGetFiatDataQueryCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingGetFiatDataQueryData *)DataResolver:(id<XNetworkingApollo_apiFakeResolver>)resolver block:(void (^)(XNetworkingQueryBuilder *))block __attribute__((swift_name("Data(resolver:block:)")));
@property (readonly) NSString *OPERATION_DOCUMENT __attribute__((swift_name("OPERATION_DOCUMENT")));
@property (readonly) NSString *OPERATION_ID __attribute__((swift_name("OPERATION_ID")));
@property (readonly) NSString *OPERATION_NAME __attribute__((swift_name("OPERATION_NAME")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery.Data")))
@interface XNetworkingGetFiatDataQueryData : XNetworkingBase <XNetworkingApollo_apiQueryData>
- (instancetype)initWithEntities:(XNetworkingGetFiatDataQueryEntities * _Nullable)entities __attribute__((swift_name("init(entities:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetFiatDataQueryData *)doCopyEntities:(XNetworkingGetFiatDataQueryEntities * _Nullable)entities __attribute__((swift_name("doCopy(entities:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetFiatDataQueryEntities * _Nullable entities __attribute__((swift_name("entities")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery.Entities")))
@interface XNetworkingGetFiatDataQueryEntities : XNetworkingBase
- (instancetype)initWithNodes:(NSArray<id> *)nodes pageInfo:(XNetworkingGetFiatDataQueryPageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetFiatDataQueryEntities *)doCopyNodes:(NSArray<id> *)nodes pageInfo:(XNetworkingGetFiatDataQueryPageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSArray<XNetworkingGetFiatDataQueryNode *> *)nodesFilterNotNull __attribute__((swift_name("nodesFilterNotNull()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property (readonly) XNetworkingGetFiatDataQueryPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery.Node")))
@interface XNetworkingGetFiatDataQueryNode : XNetworkingBase
- (instancetype)initWithId:(NSString * _Nullable)id priceUSD:(NSString * _Nullable)priceUSD __attribute__((swift_name("init(id:priceUSD:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetFiatDataQueryNode *)doCopyId:(NSString * _Nullable)id priceUSD:(NSString * _Nullable)priceUSD __attribute__((swift_name("doCopy(id:priceUSD:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable priceUSD __attribute__((swift_name("priceUSD")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery.PageInfo")))
@interface XNetworkingGetFiatDataQueryPageInfo : XNetworkingBase
- (instancetype)initWithHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("init(hasNextPage:endCursor:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetFiatDataQueryPageInfo *)doCopyHasNextPage:(BOOL)hasNextPage endCursor:(NSString * _Nullable)endCursor __attribute__((swift_name("doCopy(hasNextPage:endCursor:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery")))
@interface XNetworkingGetMainnetHistoryElementsQuery : XNetworkingBase <XNetworkingApollo_apiQuery>
- (instancetype)initWithPageCount:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)pageCount cursor:(XNetworkingApollo_apiOptional<NSString *> *)cursor orderBy:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementsOrderBy *> *> *)orderBy filter:(XNetworkingApollo_apiOptional<XNetworkingHistoryElementFilter *> *)filter __attribute__((swift_name("init(pageCount:cursor:orderBy:filter:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGetMainnetHistoryElementsQueryCompanion *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingGetMainnetHistoryElementsQuery *)doCopyPageCount:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)pageCount cursor:(XNetworkingApollo_apiOptional<NSString *> *)cursor orderBy:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementsOrderBy *> *> *)orderBy filter:(XNetworkingApollo_apiOptional<XNetworkingHistoryElementFilter *> *)filter __attribute__((swift_name("doCopy(pageCount:cursor:orderBy:filter:)")));
- (NSString *)document __attribute__((swift_name("document()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *cursor __attribute__((swift_name("cursor")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingHistoryElementFilter *> *filter __attribute__((swift_name("filter")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementsOrderBy *> *> *orderBy __attribute__((swift_name("orderBy")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *pageCount __attribute__((swift_name("pageCount")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery.Companion")))
@interface XNetworkingGetMainnetHistoryElementsQueryCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingGetMainnetHistoryElementsQueryData *)DataResolver:(id<XNetworkingApollo_apiFakeResolver>)resolver block:(void (^)(XNetworkingQueryBuilder *))block __attribute__((swift_name("Data(resolver:block:)")));
@property (readonly) NSString *OPERATION_DOCUMENT __attribute__((swift_name("OPERATION_DOCUMENT")));
@property (readonly) NSString *OPERATION_ID __attribute__((swift_name("OPERATION_ID")));
@property (readonly) NSString *OPERATION_NAME __attribute__((swift_name("OPERATION_NAME")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery.Data")))
@interface XNetworkingGetMainnetHistoryElementsQueryData : XNetworkingBase <XNetworkingApollo_apiQueryData>
- (instancetype)initWithHistoryElements:(XNetworkingGetMainnetHistoryElementsQueryHistoryElements * _Nullable)historyElements __attribute__((swift_name("init(historyElements:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetMainnetHistoryElementsQueryData *)doCopyHistoryElements:(XNetworkingGetMainnetHistoryElementsQueryHistoryElements * _Nullable)historyElements __attribute__((swift_name("doCopy(historyElements:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetMainnetHistoryElementsQueryHistoryElements * _Nullable historyElements __attribute__((swift_name("historyElements")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery.HistoryElements")))
@interface XNetworkingGetMainnetHistoryElementsQueryHistoryElements : XNetworkingBase
- (instancetype)initWithNodes:(NSArray<id> *)nodes pageInfo:(XNetworkingGetMainnetHistoryElementsQueryPageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetMainnetHistoryElementsQueryHistoryElements *)doCopyNodes:(NSArray<id> *)nodes pageInfo:(XNetworkingGetMainnetHistoryElementsQueryPageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSArray<XNetworkingGetMainnetHistoryElementsQueryNode *> *)nodesFilterNotNull __attribute__((swift_name("nodesFilterNotNull()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property (readonly) XNetworkingGetMainnetHistoryElementsQueryPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery.Node")))
@interface XNetworkingGetMainnetHistoryElementsQueryNode : XNetworkingBase
- (instancetype)initWithId:(NSString * _Nullable)id blockHash:(NSString * _Nullable)blockHash module:(NSString * _Nullable)module method:(NSString * _Nullable)method address:(NSString * _Nullable)address networkFee:(NSString * _Nullable)networkFee execution:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)execution timestamp:(XNetworkingInt * _Nullable)timestamp data:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)data __attribute__((swift_name("init(id:blockHash:module:method:address:networkFee:execution:timestamp:data:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetMainnetHistoryElementsQueryNode *)doCopyId:(NSString * _Nullable)id blockHash:(NSString * _Nullable)blockHash module:(NSString * _Nullable)module method:(NSString * _Nullable)method address:(NSString * _Nullable)address networkFee:(NSString * _Nullable)networkFee execution:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)execution timestamp:(XNetworkingInt * _Nullable)timestamp data:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)data __attribute__((swift_name("doCopy(id:blockHash:module:method:address:networkFee:execution:timestamp:data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable address __attribute__((swift_name("address")));
@property (readonly) NSString * _Nullable blockHash __attribute__((swift_name("blockHash")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable data __attribute__((swift_name("data")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable execution __attribute__((swift_name("execution")));
@property (readonly) NSString * _Nullable id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable method __attribute__((swift_name("method")));
@property (readonly) NSString * _Nullable module __attribute__((swift_name("module")));
@property (readonly) NSString * _Nullable networkFee __attribute__((swift_name("networkFee")));
@property (readonly) XNetworkingInt * _Nullable timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery.PageInfo")))
@interface XNetworkingGetMainnetHistoryElementsQueryPageInfo : XNetworkingBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("init(endCursor:hasNextPage:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetMainnetHistoryElementsQueryPageInfo *)doCopyEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("doCopy(endCursor:hasNextPage:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery")))
@interface XNetworkingGetReferrerRewardsQuery : XNetworkingBase <XNetworkingApollo_apiQuery>
- (instancetype)initWithPageCount:(int32_t)pageCount cursor:(NSString *)cursor address:(NSString *)address __attribute__((swift_name("init(pageCount:cursor:address:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGetReferrerRewardsQueryCompanion *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingGetReferrerRewardsQuery *)doCopyPageCount:(int32_t)pageCount cursor:(NSString *)cursor address:(NSString *)address __attribute__((swift_name("doCopy(pageCount:cursor:address:)")));
- (NSString *)document __attribute__((swift_name("document()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *address __attribute__((swift_name("address")));
@property (readonly) NSString *cursor __attribute__((swift_name("cursor")));
@property (readonly) int32_t pageCount __attribute__((swift_name("pageCount")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery.Companion")))
@interface XNetworkingGetReferrerRewardsQueryCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingGetReferrerRewardsQueryData *)DataResolver:(id<XNetworkingApollo_apiFakeResolver>)resolver block:(void (^)(XNetworkingQueryBuilder *))block __attribute__((swift_name("Data(resolver:block:)")));
@property (readonly) NSString *OPERATION_DOCUMENT __attribute__((swift_name("OPERATION_DOCUMENT")));
@property (readonly) NSString *OPERATION_ID __attribute__((swift_name("OPERATION_ID")));
@property (readonly) NSString *OPERATION_NAME __attribute__((swift_name("OPERATION_NAME")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery.Data")))
@interface XNetworkingGetReferrerRewardsQueryData : XNetworkingBase <XNetworkingApollo_apiQueryData>
- (instancetype)initWithEntities:(XNetworkingGetReferrerRewardsQueryEntities * _Nullable)entities __attribute__((swift_name("init(entities:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetReferrerRewardsQueryData *)doCopyEntities:(XNetworkingGetReferrerRewardsQueryEntities * _Nullable)entities __attribute__((swift_name("doCopy(entities:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetReferrerRewardsQueryEntities * _Nullable entities __attribute__((swift_name("entities")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery.Entities")))
@interface XNetworkingGetReferrerRewardsQueryEntities : XNetworkingBase
- (instancetype)initWithNodes:(NSArray<id> *)nodes pageInfo:(XNetworkingGetReferrerRewardsQueryPageInfo *)pageInfo __attribute__((swift_name("init(nodes:pageInfo:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetReferrerRewardsQueryEntities *)doCopyNodes:(NSArray<id> *)nodes pageInfo:(XNetworkingGetReferrerRewardsQueryPageInfo *)pageInfo __attribute__((swift_name("doCopy(nodes:pageInfo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSArray<XNetworkingGetReferrerRewardsQueryNode *> *)nodesFilterNotNull __attribute__((swift_name("nodesFilterNotNull()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property (readonly) XNetworkingGetReferrerRewardsQueryPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery.Node")))
@interface XNetworkingGetReferrerRewardsQueryNode : XNetworkingBase
- (instancetype)initWithReferral:(NSString * _Nullable)referral amount:(NSString * _Nullable)amount __attribute__((swift_name("init(referral:amount:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetReferrerRewardsQueryNode *)doCopyReferral:(NSString * _Nullable)referral amount:(NSString * _Nullable)amount __attribute__((swift_name("doCopy(referral:amount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable amount __attribute__((swift_name("amount")));
@property (readonly) NSString * _Nullable referral __attribute__((swift_name("referral")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery.PageInfo")))
@interface XNetworkingGetReferrerRewardsQueryPageInfo : XNetworkingBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("init(endCursor:hasNextPage:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetReferrerRewardsQueryPageInfo *)doCopyEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("doCopy(endCursor:hasNextPage:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery")))
@interface XNetworkingGetSbApyInfoQuery : XNetworkingBase <XNetworkingApollo_apiQuery>
- (instancetype)initWithCursor:(NSString *)cursor __attribute__((swift_name("init(cursor:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGetSbApyInfoQueryCompanion *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingGetSbApyInfoQuery *)doCopyCursor:(NSString *)cursor __attribute__((swift_name("doCopy(cursor:)")));
- (NSString *)document __attribute__((swift_name("document()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *cursor __attribute__((swift_name("cursor")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery.Companion")))
@interface XNetworkingGetSbApyInfoQueryCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingGetSbApyInfoQueryData *)DataResolver:(id<XNetworkingApollo_apiFakeResolver>)resolver block:(void (^)(XNetworkingQueryBuilder *))block __attribute__((swift_name("Data(resolver:block:)")));
@property (readonly) NSString *OPERATION_DOCUMENT __attribute__((swift_name("OPERATION_DOCUMENT")));
@property (readonly) NSString *OPERATION_ID __attribute__((swift_name("OPERATION_ID")));
@property (readonly) NSString *OPERATION_NAME __attribute__((swift_name("OPERATION_NAME")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery.Data")))
@interface XNetworkingGetSbApyInfoQueryData : XNetworkingBase <XNetworkingApollo_apiQueryData>
- (instancetype)initWithData:(XNetworkingGetSbApyInfoQueryData1 * _Nullable)data __attribute__((swift_name("init(data:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetSbApyInfoQueryData *)doCopyData:(XNetworkingGetSbApyInfoQueryData1 * _Nullable)data __attribute__((swift_name("doCopy(data:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetSbApyInfoQueryData1 * _Nullable data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery.Data1")))
@interface XNetworkingGetSbApyInfoQueryData1 : XNetworkingBase
- (instancetype)initWithPageInfo:(XNetworkingGetSbApyInfoQueryPageInfo *)pageInfo edges:(NSArray<XNetworkingGetSbApyInfoQueryEdge *> *)edges __attribute__((swift_name("init(pageInfo:edges:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetSbApyInfoQueryData1 *)doCopyPageInfo:(XNetworkingGetSbApyInfoQueryPageInfo *)pageInfo edges:(NSArray<XNetworkingGetSbApyInfoQueryEdge *> *)edges __attribute__((swift_name("doCopy(pageInfo:edges:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<XNetworkingGetSbApyInfoQueryEdge *> *edges __attribute__((swift_name("edges")));
@property (readonly) XNetworkingGetSbApyInfoQueryPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery.Edge")))
@interface XNetworkingGetSbApyInfoQueryEdge : XNetworkingBase
- (instancetype)initWithNode:(XNetworkingGetSbApyInfoQueryNode * _Nullable)node __attribute__((swift_name("init(node:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetSbApyInfoQueryEdge *)doCopyNode:(XNetworkingGetSbApyInfoQueryNode * _Nullable)node __attribute__((swift_name("doCopy(node:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetSbApyInfoQueryNode * _Nullable node __attribute__((swift_name("node")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery.Node")))
@interface XNetworkingGetSbApyInfoQueryNode : XNetworkingBase
- (instancetype)initWithId:(NSString * _Nullable)id strategicBonusApy:(NSString * _Nullable)strategicBonusApy __attribute__((swift_name("init(id:strategicBonusApy:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetSbApyInfoQueryNode *)doCopyId:(NSString * _Nullable)id strategicBonusApy:(NSString * _Nullable)strategicBonusApy __attribute__((swift_name("doCopy(id:strategicBonusApy:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable strategicBonusApy __attribute__((swift_name("strategicBonusApy")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery.PageInfo")))
@interface XNetworkingGetSbApyInfoQueryPageInfo : XNetworkingBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("init(endCursor:hasNextPage:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetSbApyInfoQueryPageInfo *)doCopyEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("doCopy(endCursor:hasNextPage:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_ResponseAdapter")))
@interface XNetworkingGetAssetsInfoQuery_ResponseAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getAssetsInfoQuery_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_ResponseAdapter *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_ResponseAdapter.Data")))
@interface XNetworkingGetAssetsInfoQuery_ResponseAdapterData : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_ResponseAdapterData *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetAssetsInfoQueryData * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetAssetsInfoQueryData *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_ResponseAdapter.Data1")))
@interface XNetworkingGetAssetsInfoQuery_ResponseAdapterData1 : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data1 __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_ResponseAdapterData1 *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetAssetsInfoQueryData1 * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetAssetsInfoQueryData1 *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_ResponseAdapter.Edge")))
@interface XNetworkingGetAssetsInfoQuery_ResponseAdapterEdge : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)edge __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_ResponseAdapterEdge *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetAssetsInfoQueryEdge * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetAssetsInfoQueryEdge *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_ResponseAdapter.Node")))
@interface XNetworkingGetAssetsInfoQuery_ResponseAdapterNode : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)node __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_ResponseAdapterNode *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetAssetsInfoQueryNode * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetAssetsInfoQueryNode *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_ResponseAdapter.PageInfo")))
@interface XNetworkingGetAssetsInfoQuery_ResponseAdapterPageInfo : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)pageInfo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_ResponseAdapterPageInfo *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetAssetsInfoQueryPageInfo * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetAssetsInfoQueryPageInfo *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuery_VariablesAdapter")))
@interface XNetworkingGetAssetsInfoQuery_VariablesAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getAssetsInfoQuery_VariablesAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuery_VariablesAdapter *shared __attribute__((swift_name("shared")));
- (void)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer value:(XNetworkingGetAssetsInfoQuery *)value customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues __attribute__((swift_name("serializeVariables(writer:value:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery_ResponseAdapter")))
@interface XNetworkingGetFiatDataQuery_ResponseAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getFiatDataQuery_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuery_ResponseAdapter *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery_ResponseAdapter.Data")))
@interface XNetworkingGetFiatDataQuery_ResponseAdapterData : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuery_ResponseAdapterData *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetFiatDataQueryData * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetFiatDataQueryData *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery_ResponseAdapter.Entities")))
@interface XNetworkingGetFiatDataQuery_ResponseAdapterEntities : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)entities __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuery_ResponseAdapterEntities *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetFiatDataQueryEntities * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetFiatDataQueryEntities *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery_ResponseAdapter.Node")))
@interface XNetworkingGetFiatDataQuery_ResponseAdapterNode : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)node __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuery_ResponseAdapterNode *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetFiatDataQueryNode * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetFiatDataQueryNode *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery_ResponseAdapter.PageInfo")))
@interface XNetworkingGetFiatDataQuery_ResponseAdapterPageInfo : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)pageInfo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuery_ResponseAdapterPageInfo *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetFiatDataQueryPageInfo * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetFiatDataQueryPageInfo *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuery_VariablesAdapter")))
@interface XNetworkingGetFiatDataQuery_VariablesAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getFiatDataQuery_VariablesAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuery_VariablesAdapter *shared __attribute__((swift_name("shared")));
- (void)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer value:(XNetworkingGetFiatDataQuery *)value customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues __attribute__((swift_name("serializeVariables(writer:value:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery_ResponseAdapter")))
@interface XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getMainnetHistoryElementsQuery_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapter *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery_ResponseAdapter.Data")))
@interface XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterData : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterData *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetMainnetHistoryElementsQueryData * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetMainnetHistoryElementsQueryData *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery_ResponseAdapter.HistoryElements")))
@interface XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterHistoryElements : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)historyElements __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterHistoryElements *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetMainnetHistoryElementsQueryHistoryElements * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetMainnetHistoryElementsQueryHistoryElements *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery_ResponseAdapter.Node")))
@interface XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterNode : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)node __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterNode *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetMainnetHistoryElementsQueryNode * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetMainnetHistoryElementsQueryNode *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery_ResponseAdapter.PageInfo")))
@interface XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterPageInfo : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)pageInfo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuery_ResponseAdapterPageInfo *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetMainnetHistoryElementsQueryPageInfo * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetMainnetHistoryElementsQueryPageInfo *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuery_VariablesAdapter")))
@interface XNetworkingGetMainnetHistoryElementsQuery_VariablesAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getMainnetHistoryElementsQuery_VariablesAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuery_VariablesAdapter *shared __attribute__((swift_name("shared")));
- (void)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer value:(XNetworkingGetMainnetHistoryElementsQuery *)value customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues __attribute__((swift_name("serializeVariables(writer:value:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery_ResponseAdapter")))
@interface XNetworkingGetReferrerRewardsQuery_ResponseAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getReferrerRewardsQuery_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuery_ResponseAdapter *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery_ResponseAdapter.Data")))
@interface XNetworkingGetReferrerRewardsQuery_ResponseAdapterData : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuery_ResponseAdapterData *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetReferrerRewardsQueryData * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetReferrerRewardsQueryData *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery_ResponseAdapter.Entities")))
@interface XNetworkingGetReferrerRewardsQuery_ResponseAdapterEntities : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)entities __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuery_ResponseAdapterEntities *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetReferrerRewardsQueryEntities * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetReferrerRewardsQueryEntities *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery_ResponseAdapter.Node")))
@interface XNetworkingGetReferrerRewardsQuery_ResponseAdapterNode : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)node __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuery_ResponseAdapterNode *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetReferrerRewardsQueryNode * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetReferrerRewardsQueryNode *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery_ResponseAdapter.PageInfo")))
@interface XNetworkingGetReferrerRewardsQuery_ResponseAdapterPageInfo : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)pageInfo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuery_ResponseAdapterPageInfo *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetReferrerRewardsQueryPageInfo * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetReferrerRewardsQueryPageInfo *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuery_VariablesAdapter")))
@interface XNetworkingGetReferrerRewardsQuery_VariablesAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getReferrerRewardsQuery_VariablesAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuery_VariablesAdapter *shared __attribute__((swift_name("shared")));
- (void)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer value:(XNetworkingGetReferrerRewardsQuery *)value customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues __attribute__((swift_name("serializeVariables(writer:value:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_ResponseAdapter")))
@interface XNetworkingGetSbApyInfoQuery_ResponseAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getSbApyInfoQuery_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_ResponseAdapter *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_ResponseAdapter.Data")))
@interface XNetworkingGetSbApyInfoQuery_ResponseAdapterData : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_ResponseAdapterData *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetSbApyInfoQueryData * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetSbApyInfoQueryData *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_ResponseAdapter.Data1")))
@interface XNetworkingGetSbApyInfoQuery_ResponseAdapterData1 : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data1 __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_ResponseAdapterData1 *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetSbApyInfoQueryData1 * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetSbApyInfoQueryData1 *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_ResponseAdapter.Edge")))
@interface XNetworkingGetSbApyInfoQuery_ResponseAdapterEdge : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)edge __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_ResponseAdapterEdge *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetSbApyInfoQueryEdge * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetSbApyInfoQueryEdge *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_ResponseAdapter.Node")))
@interface XNetworkingGetSbApyInfoQuery_ResponseAdapterNode : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)node __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_ResponseAdapterNode *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetSbApyInfoQueryNode * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetSbApyInfoQueryNode *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_ResponseAdapter.PageInfo")))
@interface XNetworkingGetSbApyInfoQuery_ResponseAdapterPageInfo : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)pageInfo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_ResponseAdapterPageInfo *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetSbApyInfoQueryPageInfo * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetSbApyInfoQueryPageInfo *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuery_VariablesAdapter")))
@interface XNetworkingGetSbApyInfoQuery_VariablesAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getSbApyInfoQuery_VariablesAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuery_VariablesAdapter *shared __attribute__((swift_name("shared")));
- (void)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer value:(XNetworkingGetSbApyInfoQuery *)value customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues __attribute__((swift_name("serializeVariables(writer:value:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("__Schema")))
@interface XNetworking__Schema : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)__Schema __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworking__Schema *shared __attribute__((swift_name("shared")));
- (NSArray<XNetworkingApollo_apiObjectType *> *)possibleTypesType:(XNetworkingApollo_apiCompiledNamedType *)type __attribute__((swift_name("possibleTypes(type:)")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledNamedType *> *all __attribute__((swift_name("all")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetAssetsInfoQuerySelections")))
@interface XNetworkingGetAssetsInfoQuerySelections : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getAssetsInfoQuerySelections __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetAssetsInfoQuerySelections *shared __attribute__((swift_name("shared")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *__root __attribute__((swift_name("__root")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetFiatDataQuerySelections")))
@interface XNetworkingGetFiatDataQuerySelections : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getFiatDataQuerySelections __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetFiatDataQuerySelections *shared __attribute__((swift_name("shared")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *__root __attribute__((swift_name("__root")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetMainnetHistoryElementsQuerySelections")))
@interface XNetworkingGetMainnetHistoryElementsQuerySelections : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getMainnetHistoryElementsQuerySelections __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetMainnetHistoryElementsQuerySelections *shared __attribute__((swift_name("shared")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *__root __attribute__((swift_name("__root")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetReferrerRewardsQuerySelections")))
@interface XNetworkingGetReferrerRewardsQuerySelections : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getReferrerRewardsQuerySelections __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetReferrerRewardsQuerySelections *shared __attribute__((swift_name("shared")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *__root __attribute__((swift_name("__root")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetSbApyInfoQuerySelections")))
@interface XNetworkingGetSbApyInfoQuerySelections : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getSbApyInfoQuerySelections __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetSbApyInfoQuerySelections *shared __attribute__((swift_name("shared")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *__root __attribute__((swift_name("__root")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Account")))
@interface XNetworkingAccount : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAccountCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((swift_name("Apollo_apiBuilderFactory")))
@protocol XNetworkingApollo_apiBuilderFactory
@required
- (id _Nullable)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Account.Companion")))
@interface XNetworkingAccountCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAccountCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAccountBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((swift_name("Apollo_apiBuilderScope")))
@protocol XNetworkingApollo_apiBuilderScope
@required
@property (readonly) XNetworkingApollo_apiCustomScalarAdapters *customScalarAdapters __attribute__((swift_name("customScalarAdapters")));
@end

__attribute__((swift_name("Apollo_apiObjectBuilder")))
@interface XNetworkingApollo_apiObjectBuilder<__covariant T> : XNetworkingBase <XNetworkingApollo_apiBuilderScope>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
- (void)setKey:(NSString *)key value:(id _Nullable)value __attribute__((swift_name("set(key:value:)")));
@property (readonly) XNetworkingMutableDictionary<NSString *, id> *__fields __attribute__((swift_name("__fields")));
@property NSString *__typename __attribute__((swift_name("__typename")));
@property (readonly) XNetworkingApollo_apiCustomScalarAdapters *customScalarAdapters __attribute__((swift_name("customScalarAdapters")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccountBuilder")))
@interface XNetworkingAccountBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AccountMap")))
@interface XNetworkingAccountMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Asset")))
@interface XNetworkingAsset : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAssetCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Asset.Companion")))
@interface XNetworkingAssetCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAssetCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAssetBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetBuilder")))
@interface XNetworkingAssetBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString *id __attribute__((swift_name("id")));
@property NSString *liquidity __attribute__((swift_name("liquidity")));
@property NSString *priceChangeDay __attribute__((swift_name("priceChangeDay")));
@property NSString *priceUSD __attribute__((swift_name("priceUSD")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AssetMap")))
@interface XNetworkingAssetMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetSnapshot")))
@interface XNetworkingAssetSnapshot : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAssetSnapshotCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetSnapshot.Companion")))
@interface XNetworkingAssetSnapshotCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAssetSnapshotCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAssetSnapshotBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetSnapshotBuilder")))
@interface XNetworkingAssetSnapshotBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AssetSnapshotMap")))
@interface XNetworkingAssetSnapshotMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsConnection")))
@interface XNetworkingAssetsConnection : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAssetsConnectionCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsConnection.Companion")))
@interface XNetworkingAssetsConnectionCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAssetsConnectionCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAssetsConnectionBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsConnectionBuilder")))
@interface XNetworkingAssetsConnectionBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSArray<NSDictionary<NSString *, id> *> *edges __attribute__((swift_name("edges")));
@property NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property NSDictionary<NSString *, id> *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AssetsConnectionMap")))
@interface XNetworkingAssetsConnectionMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsEdge")))
@interface XNetworkingAssetsEdge : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAssetsEdgeCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsEdge.Companion")))
@interface XNetworkingAssetsEdgeCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAssetsEdgeCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAssetsEdgeBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsEdgeBuilder")))
@interface XNetworkingAssetsEdgeBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSDictionary<NSString *, id> * _Nullable node __attribute__((swift_name("node")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AssetsEdgeMap")))
@interface XNetworkingAssetsEdgeMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BigFloat")))
@interface XNetworkingBigFloat : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingBigFloatCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BigFloat.Companion")))
@interface XNetworkingBigFloatCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingBigFloatCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BigFloatFilter")))
@interface XNetworkingBigFloatFilter : XNetworkingBase
- (instancetype)initWithIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<NSString *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<NSString *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<NSString *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanOrEqualTo __attribute__((swift_name("init(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingBigFloatFilter *)doCopyIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<NSString *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<NSString *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<NSString *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanOrEqualTo __attribute__((swift_name("doCopy(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *distinctFrom __attribute__((swift_name("distinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *equalTo __attribute__((swift_name("equalTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *greaterThan __attribute__((swift_name("greaterThan")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *greaterThanOrEqualTo __attribute__((swift_name("greaterThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *in __attribute__((swift_name("in")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingBoolean *> *isNull __attribute__((swift_name("isNull")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *lessThan __attribute__((swift_name("lessThan")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *lessThanOrEqualTo __attribute__((swift_name("lessThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notDistinctFrom __attribute__((swift_name("notDistinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notEqualTo __attribute__((swift_name("notEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *notIn __attribute__((swift_name("notIn")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Cursor")))
@interface XNetworkingCursor : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingCursorCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Cursor.Companion")))
@interface XNetworkingCursorCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingCursorCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLBoolean")))
@interface XNetworkingGraphQLBoolean : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLBooleanCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLBoolean.Companion")))
@interface XNetworkingGraphQLBooleanCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLBooleanCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLFloat")))
@interface XNetworkingGraphQLFloat : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLFloatCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLFloat.Companion")))
@interface XNetworkingGraphQLFloatCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLFloatCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLID")))
@interface XNetworkingGraphQLID : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLIDCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLID.Companion")))
@interface XNetworkingGraphQLIDCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLIDCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLInt")))
@interface XNetworkingGraphQLInt : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLIntCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLInt.Companion")))
@interface XNetworkingGraphQLIntCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLIntCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLString")))
@interface XNetworkingGraphQLString : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLStringCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLString.Companion")))
@interface XNetworkingGraphQLStringCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLStringCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElement")))
@interface XNetworkingHistoryElement : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingHistoryElementCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElement.Companion")))
@interface XNetworkingHistoryElementCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingHistoryElementBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementBuilder")))
@interface XNetworkingHistoryElementBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString *address __attribute__((swift_name("address")));
@property NSString *blockHash __attribute__((swift_name("blockHash")));
@property XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable data __attribute__((swift_name("data")));
@property XNetworkingKotlinx_serialization_jsonJsonElement *execution __attribute__((swift_name("execution")));
@property NSString *id __attribute__((swift_name("id")));
@property NSString *method __attribute__((swift_name("method")));
@property NSString *module __attribute__((swift_name("module")));
@property NSString *networkFee __attribute__((swift_name("networkFee")));
@property int32_t timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementFilter")))
@interface XNetworkingHistoryElementFilter : XNetworkingBase
- (instancetype)initWithId:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)id blockHeight:(XNetworkingApollo_apiOptional<XNetworkingBigFloatFilter *> *)blockHeight blockHash:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)blockHash module:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)module method:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)method address:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)address networkFee:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)networkFee execution:(XNetworkingApollo_apiOptional<XNetworkingJSONFilter *> *)execution timestamp:(XNetworkingApollo_apiOptional<XNetworkingIntFilter *> *)timestamp data:(XNetworkingApollo_apiOptional<XNetworkingJSONFilter *> *)data and:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementFilter *> *> *)and_ or:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementFilter *> *> *)or_ not:(XNetworkingApollo_apiOptional<XNetworkingHistoryElementFilter *> *)not_ __attribute__((swift_name("init(id:blockHeight:blockHash:module:method:address:networkFee:execution:timestamp:data:and:or:not:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingHistoryElementFilter *)doCopyId:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)id blockHeight:(XNetworkingApollo_apiOptional<XNetworkingBigFloatFilter *> *)blockHeight blockHash:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)blockHash module:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)module method:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)method address:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)address networkFee:(XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *)networkFee execution:(XNetworkingApollo_apiOptional<XNetworkingJSONFilter *> *)execution timestamp:(XNetworkingApollo_apiOptional<XNetworkingIntFilter *> *)timestamp data:(XNetworkingApollo_apiOptional<XNetworkingJSONFilter *> *)data and:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementFilter *> *> *)and_ or:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementFilter *> *> *)or_ not:(XNetworkingApollo_apiOptional<XNetworkingHistoryElementFilter *> *)not_ __attribute__((swift_name("doCopy(id:blockHeight:blockHash:module:method:address:networkFee:execution:timestamp:data:and:or:not:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *address __attribute__((swift_name("address")));
@property (readonly, getter=and) XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementFilter *> *> *and_ __attribute__((swift_name("and_")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *blockHash __attribute__((swift_name("blockHash")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingBigFloatFilter *> *blockHeight __attribute__((swift_name("blockHeight")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingJSONFilter *> *data __attribute__((swift_name("data")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingJSONFilter *> *execution __attribute__((swift_name("execution")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *id __attribute__((swift_name("id")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *method __attribute__((swift_name("method")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *module __attribute__((swift_name("module")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingStringFilter *> *networkFee __attribute__((swift_name("networkFee")));
@property (readonly, getter=not) XNetworkingApollo_apiOptional<XNetworkingHistoryElementFilter *> *not_ __attribute__((swift_name("not_")));
@property (readonly, getter=or) XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementFilter *> *> *or_ __attribute__((swift_name("or_")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingIntFilter *> *timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("HistoryElementMap")))
@interface XNetworkingHistoryElementMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnection")))
@interface XNetworkingHistoryElementsConnection : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingHistoryElementsConnectionCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnection.Companion")))
@interface XNetworkingHistoryElementsConnectionCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementsConnectionCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingHistoryElementsConnectionBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnectionBuilder")))
@interface XNetworkingHistoryElementsConnectionBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property NSDictionary<NSString *, id> *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("HistoryElementsConnectionMap")))
@interface XNetworkingHistoryElementsConnectionMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsOrderBy")))
@interface XNetworkingHistoryElementsOrderBy : XNetworkingKotlinEnum<XNetworkingHistoryElementsOrderBy *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) XNetworkingHistoryElementsOrderByCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *natural __attribute__((swift_name("natural")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *idAsc __attribute__((swift_name("idAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *idDesc __attribute__((swift_name("idDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *blockHeightAsc __attribute__((swift_name("blockHeightAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *blockHeightDesc __attribute__((swift_name("blockHeightDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *blockHashAsc __attribute__((swift_name("blockHashAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *blockHashDesc __attribute__((swift_name("blockHashDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *moduleAsc __attribute__((swift_name("moduleAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *moduleDesc __attribute__((swift_name("moduleDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *methodAsc __attribute__((swift_name("methodAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *methodDesc __attribute__((swift_name("methodDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *addressAsc __attribute__((swift_name("addressAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *addressDesc __attribute__((swift_name("addressDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *networkFeeAsc __attribute__((swift_name("networkFeeAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *networkFeeDesc __attribute__((swift_name("networkFeeDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *executionAsc __attribute__((swift_name("executionAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *executionDesc __attribute__((swift_name("executionDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *timestampAsc __attribute__((swift_name("timestampAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *timestampDesc __attribute__((swift_name("timestampDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *dataAsc __attribute__((swift_name("dataAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *dataDesc __attribute__((swift_name("dataDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *primaryKeyAsc __attribute__((swift_name("primaryKeyAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *primaryKeyDesc __attribute__((swift_name("primaryKeyDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdCountAsc __attribute__((swift_name("accountsByLatestHistoryElementIdCountAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdCountDesc __attribute__((swift_name("accountsByLatestHistoryElementIdCountDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdSumIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdSumIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdSumIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdSumIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdSumLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdSumLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdSumLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdSumLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdDistinctCountIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdDistinctCountIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdDistinctCountIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdDistinctCountIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdDistinctCountLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdDistinctCountLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdDistinctCountLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdDistinctCountLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMinIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdMinIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMinIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdMinIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMinLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdMinLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMinLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdMinLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMaxIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdMaxIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMaxIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdMaxIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMaxLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdMaxLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdMaxLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdMaxLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdAverageIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdAverageIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdAverageIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdAverageIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdAverageLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdAverageLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdAverageLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdAverageLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevSampleIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevSampleIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevSampleIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevSampleIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevSampleLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevSampleLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevSampleLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevSampleLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevPopulationIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevPopulationIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevPopulationIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevPopulationIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevPopulationLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevPopulationLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdStddevPopulationLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdStddevPopulationLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVarianceSampleIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdVarianceSampleIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVarianceSampleIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdVarianceSampleIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVarianceSampleLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdVarianceSampleLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVarianceSampleLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdVarianceSampleLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVariancePopulationIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdVariancePopulationIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVariancePopulationIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdVariancePopulationIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVariancePopulationLatestHistoryElementIdAsc __attribute__((swift_name("accountsByLatestHistoryElementIdVariancePopulationLatestHistoryElementIdAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *accountsByLatestHistoryElementIdVariancePopulationLatestHistoryElementIdDesc __attribute__((swift_name("accountsByLatestHistoryElementIdVariancePopulationLatestHistoryElementIdDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy *unknown __attribute__((swift_name("unknown")));
+ (XNetworkingKotlinArray<XNetworkingHistoryElementsOrderBy *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingHistoryElementsOrderBy *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *rawValue __attribute__((swift_name("rawValue")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsOrderBy.Companion")))
@interface XNetworkingHistoryElementsOrderByCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementsOrderByCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingKotlinArray<XNetworkingHistoryElementsOrderBy *> *)knownValues __attribute__((swift_name("knownValues()"))) __attribute__((deprecated("Use knownEntries instead")));
- (XNetworkingHistoryElementsOrderBy *)safeValueOfRawValue:(NSString *)rawValue __attribute__((swift_name("safeValueOf(rawValue:)")));
@property (readonly) NSArray<XNetworkingHistoryElementsOrderBy *> *knownEntries __attribute__((swift_name("knownEntries")));
@property (readonly) XNetworkingApollo_apiEnumType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("IntFilter")))
@interface XNetworkingIntFilter : XNetworkingBase
- (instancetype)initWithIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<XNetworkingInt *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<XNetworkingInt *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)greaterThanOrEqualTo __attribute__((swift_name("init(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingIntFilter *)doCopyIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<XNetworkingInt *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<XNetworkingInt *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingInt *> *)greaterThanOrEqualTo __attribute__((swift_name("doCopy(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *distinctFrom __attribute__((swift_name("distinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *equalTo __attribute__((swift_name("equalTo")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *greaterThan __attribute__((swift_name("greaterThan")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *greaterThanOrEqualTo __attribute__((swift_name("greaterThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<XNetworkingInt *> *> *in __attribute__((swift_name("in")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingBoolean *> *isNull __attribute__((swift_name("isNull")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *lessThan __attribute__((swift_name("lessThan")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *lessThanOrEqualTo __attribute__((swift_name("lessThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *notDistinctFrom __attribute__((swift_name("notDistinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingInt *> *notEqualTo __attribute__((swift_name("notEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<XNetworkingInt *> *> *notIn __attribute__((swift_name("notIn")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSON")))
@interface XNetworkingJSON : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingJSONCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSON.Companion")))
@interface XNetworkingJSONCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingJSONCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSONFilter")))
@interface XNetworkingJSONFilter : XNetworkingBase
- (instancetype)initWithIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)greaterThanOrEqualTo contains:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)contains containsKey:(XNetworkingApollo_apiOptional<NSString *> *)containsKey containsAllKeys:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)containsAllKeys containsAnyKeys:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)containsAnyKeys containedBy:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)containedBy __attribute__((swift_name("init(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:contains:containsKey:containsAllKeys:containsAnyKeys:containedBy:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingJSONFilter *)doCopyIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)greaterThanOrEqualTo contains:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)contains containsKey:(XNetworkingApollo_apiOptional<NSString *> *)containsKey containsAllKeys:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)containsAllKeys containsAnyKeys:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)containsAnyKeys containedBy:(XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *)containedBy __attribute__((swift_name("doCopy(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:contains:containsKey:containsAllKeys:containsAnyKeys:containedBy:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *containedBy __attribute__((swift_name("containedBy")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *contains __attribute__((swift_name("contains")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *containsAllKeys __attribute__((swift_name("containsAllKeys")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *containsAnyKeys __attribute__((swift_name("containsAnyKeys")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *containsKey __attribute__((swift_name("containsKey")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *distinctFrom __attribute__((swift_name("distinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *equalTo __attribute__((swift_name("equalTo")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *greaterThan __attribute__((swift_name("greaterThan")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *greaterThanOrEqualTo __attribute__((swift_name("greaterThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> *> *in __attribute__((swift_name("in")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingBoolean *> *isNull __attribute__((swift_name("isNull")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *lessThan __attribute__((swift_name("lessThan")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *lessThanOrEqualTo __attribute__((swift_name("lessThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *notDistinctFrom __attribute__((swift_name("notDistinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingKotlinx_serialization_jsonJsonElement *> *notEqualTo __attribute__((swift_name("notEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> *> *notIn __attribute__((swift_name("notIn")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkSnapshot")))
@interface XNetworkingNetworkSnapshot : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingNetworkSnapshotCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkSnapshot.Companion")))
@interface XNetworkingNetworkSnapshotCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingNetworkSnapshotCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingNetworkSnapshotBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkSnapshotBuilder")))
@interface XNetworkingNetworkSnapshotBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("NetworkSnapshotMap")))
@interface XNetworkingNetworkSnapshotMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkStat")))
@interface XNetworkingNetworkStat : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingNetworkStatCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkStat.Companion")))
@interface XNetworkingNetworkStatCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingNetworkStatCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingNetworkStatBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkStatBuilder")))
@interface XNetworkingNetworkStatBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("NetworkStatMap")))
@interface XNetworkingNetworkStatMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Node")))
@interface XNetworkingNode : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingNodeCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Node.Companion")))
@interface XNetworkingNodeCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingNodeCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingOtherNodeBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiInterfaceType *type __attribute__((swift_name("type")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("NodeMap")))
@protocol XNetworkingNodeMap
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OtherNodeBuilder")))
@interface XNetworkingOtherNodeBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("OtherNodeMap")))
@interface XNetworkingOtherNodeMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfo")))
@interface XNetworkingPageInfo : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingPageInfoCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfo.Companion")))
@interface XNetworkingPageInfoCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingPageInfoCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingPageInfoBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfoBuilder")))
@interface XNetworkingPageInfoBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("PageInfoMap")))
@interface XNetworkingPageInfoMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXYK")))
@interface XNetworkingPoolXYK : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingPoolXYKCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXYK.Companion")))
@interface XNetworkingPoolXYKCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingPoolXYKCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingPoolXYKBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXYKBuilder")))
@interface XNetworkingPoolXYKBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString *id __attribute__((swift_name("id")));
@property NSString * _Nullable strategicBonusApy __attribute__((swift_name("strategicBonusApy")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("PoolXYKMap")))
@interface XNetworkingPoolXYKMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksConnection")))
@interface XNetworkingPoolXyksConnection : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingPoolXyksConnectionCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksConnection.Companion")))
@interface XNetworkingPoolXyksConnectionCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingPoolXyksConnectionCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingPoolXyksConnectionBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksConnectionBuilder")))
@interface XNetworkingPoolXyksConnectionBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSArray<NSDictionary<NSString *, id> *> *edges __attribute__((swift_name("edges")));
@property NSDictionary<NSString *, id> *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("PoolXyksConnectionMap")))
@interface XNetworkingPoolXyksConnectionMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksEdge")))
@interface XNetworkingPoolXyksEdge : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingPoolXyksEdgeCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksEdge.Companion")))
@interface XNetworkingPoolXyksEdgeCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingPoolXyksEdgeCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingPoolXyksEdgeBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksEdgeBuilder")))
@interface XNetworkingPoolXyksEdgeBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSDictionary<NSString *, id> * _Nullable node __attribute__((swift_name("node")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("PoolXyksEdgeMap")))
@interface XNetworkingPoolXyksEdgeMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Query")))
@interface XNetworkingQuery : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingQueryCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Query.Companion")))
@interface XNetworkingQueryCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingQueryBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__assets_after __attribute__((swift_name("__assets_after")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__assets_filter __attribute__((swift_name("__assets_filter")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__assets_first __attribute__((swift_name("__assets_first")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_after __attribute__((swift_name("__historyElements_after")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_filter __attribute__((swift_name("__historyElements_filter")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_first __attribute__((swift_name("__historyElements_first")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_orderBy __attribute__((swift_name("__historyElements_orderBy")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__poolXYKs_after __attribute__((swift_name("__poolXYKs_after")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__poolXYKs_filter __attribute__((swift_name("__poolXYKs_filter")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__poolXYKs_first __attribute__((swift_name("__poolXYKs_first")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__referrerRewards_before __attribute__((swift_name("__referrerRewards_before")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__referrerRewards_filter __attribute__((swift_name("__referrerRewards_filter")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__referrerRewards_first __attribute__((swift_name("__referrerRewards_first")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("QueryBuilder")))
@interface XNetworkingQueryBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSDictionary<NSString *, id> * _Nullable assets __attribute__((swift_name("assets")));
@property NSDictionary<NSString *, id> * _Nullable historyElements __attribute__((swift_name("historyElements")));
@property NSDictionary<NSString *, id> * _Nullable poolXYKs __attribute__((swift_name("poolXYKs")));
@property NSDictionary<NSString *, id> * _Nullable referrerRewards __attribute__((swift_name("referrerRewards")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("QueryMap")))
@interface XNetworkingQueryMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerReward")))
@interface XNetworkingReferrerReward : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingReferrerRewardCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerReward.Companion")))
@interface XNetworkingReferrerRewardCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingReferrerRewardCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingReferrerRewardBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardBuilder")))
@interface XNetworkingReferrerRewardBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString *amount __attribute__((swift_name("amount")));
@property NSString *referral __attribute__((swift_name("referral")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("ReferrerRewardMap")))
@interface XNetworkingReferrerRewardMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardsConnection")))
@interface XNetworkingReferrerRewardsConnection : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingReferrerRewardsConnectionCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardsConnection.Companion")))
@interface XNetworkingReferrerRewardsConnectionCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingReferrerRewardsConnectionCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingReferrerRewardsConnectionBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardsConnectionBuilder")))
@interface XNetworkingReferrerRewardsConnectionBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property NSDictionary<NSString *, id> *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("ReferrerRewardsConnectionMap")))
@interface XNetworkingReferrerRewardsConnectionMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StringFilter")))
@interface XNetworkingStringFilter : XNetworkingBase
- (instancetype)initWithIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<NSString *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<NSString *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<NSString *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanOrEqualTo includes:(XNetworkingApollo_apiOptional<NSString *> *)includes notIncludes:(XNetworkingApollo_apiOptional<NSString *> *)notIncludes includesInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)includesInsensitive notIncludesInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notIncludesInsensitive startsWith:(XNetworkingApollo_apiOptional<NSString *> *)startsWith notStartsWith:(XNetworkingApollo_apiOptional<NSString *> *)notStartsWith startsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)startsWithInsensitive notStartsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notStartsWithInsensitive endsWith:(XNetworkingApollo_apiOptional<NSString *> *)endsWith notEndsWith:(XNetworkingApollo_apiOptional<NSString *> *)notEndsWith endsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)endsWithInsensitive notEndsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notEndsWithInsensitive like:(XNetworkingApollo_apiOptional<NSString *> *)like notLike:(XNetworkingApollo_apiOptional<NSString *> *)notLike likeInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)likeInsensitive notLikeInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notLikeInsensitive equalToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)equalToInsensitive notEqualToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notEqualToInsensitive distinctFromInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)distinctFromInsensitive notDistinctFromInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notDistinctFromInsensitive inInsensitive:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)inInsensitive notInInsensitive:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)notInInsensitive lessThanInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)lessThanInsensitive lessThanOrEqualToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)lessThanOrEqualToInsensitive greaterThanInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanInsensitive greaterThanOrEqualToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanOrEqualToInsensitive __attribute__((swift_name("init(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:includes:notIncludes:includesInsensitive:notIncludesInsensitive:startsWith:notStartsWith:startsWithInsensitive:notStartsWithInsensitive:endsWith:notEndsWith:endsWithInsensitive:notEndsWithInsensitive:like:notLike:likeInsensitive:notLikeInsensitive:equalToInsensitive:notEqualToInsensitive:distinctFromInsensitive:notDistinctFromInsensitive:inInsensitive:notInInsensitive:lessThanInsensitive:lessThanOrEqualToInsensitive:greaterThanInsensitive:greaterThanOrEqualToInsensitive:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingStringFilter *)doCopyIsNull:(XNetworkingApollo_apiOptional<XNetworkingBoolean *> *)isNull equalTo:(XNetworkingApollo_apiOptional<NSString *> *)equalTo notEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)notEqualTo distinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)distinctFrom notDistinctFrom:(XNetworkingApollo_apiOptional<NSString *> *)notDistinctFrom in:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)in notIn:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)notIn lessThan:(XNetworkingApollo_apiOptional<NSString *> *)lessThan lessThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)lessThanOrEqualTo greaterThan:(XNetworkingApollo_apiOptional<NSString *> *)greaterThan greaterThanOrEqualTo:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanOrEqualTo includes:(XNetworkingApollo_apiOptional<NSString *> *)includes notIncludes:(XNetworkingApollo_apiOptional<NSString *> *)notIncludes includesInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)includesInsensitive notIncludesInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notIncludesInsensitive startsWith:(XNetworkingApollo_apiOptional<NSString *> *)startsWith notStartsWith:(XNetworkingApollo_apiOptional<NSString *> *)notStartsWith startsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)startsWithInsensitive notStartsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notStartsWithInsensitive endsWith:(XNetworkingApollo_apiOptional<NSString *> *)endsWith notEndsWith:(XNetworkingApollo_apiOptional<NSString *> *)notEndsWith endsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)endsWithInsensitive notEndsWithInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notEndsWithInsensitive like:(XNetworkingApollo_apiOptional<NSString *> *)like notLike:(XNetworkingApollo_apiOptional<NSString *> *)notLike likeInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)likeInsensitive notLikeInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notLikeInsensitive equalToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)equalToInsensitive notEqualToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notEqualToInsensitive distinctFromInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)distinctFromInsensitive notDistinctFromInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)notDistinctFromInsensitive inInsensitive:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)inInsensitive notInInsensitive:(XNetworkingApollo_apiOptional<NSArray<NSString *> *> *)notInInsensitive lessThanInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)lessThanInsensitive lessThanOrEqualToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)lessThanOrEqualToInsensitive greaterThanInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanInsensitive greaterThanOrEqualToInsensitive:(XNetworkingApollo_apiOptional<NSString *> *)greaterThanOrEqualToInsensitive __attribute__((swift_name("doCopy(isNull:equalTo:notEqualTo:distinctFrom:notDistinctFrom:in:notIn:lessThan:lessThanOrEqualTo:greaterThan:greaterThanOrEqualTo:includes:notIncludes:includesInsensitive:notIncludesInsensitive:startsWith:notStartsWith:startsWithInsensitive:notStartsWithInsensitive:endsWith:notEndsWith:endsWithInsensitive:notEndsWithInsensitive:like:notLike:likeInsensitive:notLikeInsensitive:equalToInsensitive:notEqualToInsensitive:distinctFromInsensitive:notDistinctFromInsensitive:inInsensitive:notInInsensitive:lessThanInsensitive:lessThanOrEqualToInsensitive:greaterThanInsensitive:greaterThanOrEqualToInsensitive:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *distinctFrom __attribute__((swift_name("distinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *distinctFromInsensitive __attribute__((swift_name("distinctFromInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *endsWith __attribute__((swift_name("endsWith")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *endsWithInsensitive __attribute__((swift_name("endsWithInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *equalTo __attribute__((swift_name("equalTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *equalToInsensitive __attribute__((swift_name("equalToInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *greaterThan __attribute__((swift_name("greaterThan")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *greaterThanInsensitive __attribute__((swift_name("greaterThanInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *greaterThanOrEqualTo __attribute__((swift_name("greaterThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *greaterThanOrEqualToInsensitive __attribute__((swift_name("greaterThanOrEqualToInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *in __attribute__((swift_name("in")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *inInsensitive __attribute__((swift_name("inInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *includes __attribute__((swift_name("includes")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *includesInsensitive __attribute__((swift_name("includesInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<XNetworkingBoolean *> *isNull __attribute__((swift_name("isNull")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *lessThan __attribute__((swift_name("lessThan")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *lessThanInsensitive __attribute__((swift_name("lessThanInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *lessThanOrEqualTo __attribute__((swift_name("lessThanOrEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *lessThanOrEqualToInsensitive __attribute__((swift_name("lessThanOrEqualToInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *like __attribute__((swift_name("like")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *likeInsensitive __attribute__((swift_name("likeInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notDistinctFrom __attribute__((swift_name("notDistinctFrom")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notDistinctFromInsensitive __attribute__((swift_name("notDistinctFromInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notEndsWith __attribute__((swift_name("notEndsWith")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notEndsWithInsensitive __attribute__((swift_name("notEndsWithInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notEqualTo __attribute__((swift_name("notEqualTo")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notEqualToInsensitive __attribute__((swift_name("notEqualToInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *notIn __attribute__((swift_name("notIn")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<NSString *> *> *notInInsensitive __attribute__((swift_name("notInInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notIncludes __attribute__((swift_name("notIncludes")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notIncludesInsensitive __attribute__((swift_name("notIncludesInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notLike __attribute__((swift_name("notLike")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notLikeInsensitive __attribute__((swift_name("notLikeInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notStartsWith __attribute__((swift_name("notStartsWith")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *notStartsWithInsensitive __attribute__((swift_name("notStartsWithInsensitive")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *startsWith __attribute__((swift_name("startsWith")));
@property (readonly) XNetworkingApollo_apiOptional<NSString *> *startsWithInsensitive __attribute__((swift_name("startsWithInsensitive")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BigFloatFilter_InputAdapter")))
@interface XNetworkingBigFloatFilter_InputAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)bigFloatFilter_InputAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingBigFloatFilter_InputAdapter *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingBigFloatFilter * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingBigFloatFilter *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementFilter_InputAdapter")))
@interface XNetworkingHistoryElementFilter_InputAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)historyElementFilter_InputAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementFilter_InputAdapter *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingHistoryElementFilter * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingHistoryElementFilter *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsOrderBy_ResponseAdapter")))
@interface XNetworkingHistoryElementsOrderBy_ResponseAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)historyElementsOrderBy_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementsOrderBy_ResponseAdapter *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingHistoryElementsOrderBy * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingHistoryElementsOrderBy *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("IntFilter_InputAdapter")))
@interface XNetworkingIntFilter_InputAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)intFilter_InputAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingIntFilter_InputAdapter *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingIntFilter * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingIntFilter *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSONFilter_InputAdapter")))
@interface XNetworkingJSONFilter_InputAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)jSONFilter_InputAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingJSONFilter_InputAdapter *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingJSONFilter * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingJSONFilter *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StringFilter_InputAdapter")))
@interface XNetworkingStringFilter_InputAdapter : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)stringFilter_InputAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingStringFilter_InputAdapter *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingStringFilter * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingStringFilter *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery")))
@interface XNetworkingGetWestendHistoryElementsQuery : XNetworkingBase <XNetworkingApollo_apiQuery>
- (instancetype)initWithPageCount:(int32_t)pageCount cursor:(NSString *)cursor address:(NSString *)address orderBy:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementsOrderBy_ *> *> *)orderBy __attribute__((swift_name("init(pageCount:cursor:address:orderBy:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) XNetworkingGetWestendHistoryElementsQueryCompanion *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("adapter()")));
- (XNetworkingGetWestendHistoryElementsQuery *)doCopyPageCount:(int32_t)pageCount cursor:(NSString *)cursor address:(NSString *)address orderBy:(XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementsOrderBy_ *> *> *)orderBy __attribute__((swift_name("doCopy(pageCount:cursor:address:orderBy:)")));
- (NSString *)document __attribute__((swift_name("document()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)id __attribute__((swift_name("id()")));
- (NSString *)name_ __attribute__((swift_name("name()")));
- (XNetworkingApollo_apiCompiledField *)rootField __attribute__((swift_name("rootField()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("serializeVariables(writer:customScalarAdapters:withDefaultValues:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *address __attribute__((swift_name("address")));
@property (readonly) NSString *cursor __attribute__((swift_name("cursor")));
@property (readonly) XNetworkingApollo_apiOptional<NSArray<XNetworkingHistoryElementsOrderBy_ *> *> *orderBy __attribute__((swift_name("orderBy")));
@property (readonly) int32_t pageCount __attribute__((swift_name("pageCount")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery.Companion")))
@interface XNetworkingGetWestendHistoryElementsQueryCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQueryCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingGetWestendHistoryElementsQueryData *)DataResolver:(id<XNetworkingApollo_apiFakeResolver>)resolver block:(void (^)(XNetworkingQueryBuilder_ *))block __attribute__((swift_name("Data(resolver:block:)")));
@property (readonly) NSString *OPERATION_DOCUMENT __attribute__((swift_name("OPERATION_DOCUMENT")));
@property (readonly) NSString *OPERATION_ID __attribute__((swift_name("OPERATION_ID")));
@property (readonly) NSString *OPERATION_NAME __attribute__((swift_name("OPERATION_NAME")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery.Data")))
@interface XNetworkingGetWestendHistoryElementsQueryData : XNetworkingBase <XNetworkingApollo_apiQueryData>
- (instancetype)initWithHistoryElements:(XNetworkingGetWestendHistoryElementsQueryHistoryElements * _Nullable)historyElements __attribute__((swift_name("init(historyElements:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetWestendHistoryElementsQueryData *)doCopyHistoryElements:(XNetworkingGetWestendHistoryElementsQueryHistoryElements * _Nullable)historyElements __attribute__((swift_name("doCopy(historyElements:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) XNetworkingGetWestendHistoryElementsQueryHistoryElements * _Nullable historyElements __attribute__((swift_name("historyElements")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery.HistoryElements")))
@interface XNetworkingGetWestendHistoryElementsQueryHistoryElements : XNetworkingBase
- (instancetype)initWithPageInfo:(XNetworkingGetWestendHistoryElementsQueryPageInfo *)pageInfo nodes:(NSArray<id> *)nodes __attribute__((swift_name("init(pageInfo:nodes:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetWestendHistoryElementsQueryHistoryElements *)doCopyPageInfo:(XNetworkingGetWestendHistoryElementsQueryPageInfo *)pageInfo nodes:(NSArray<id> *)nodes __attribute__((swift_name("doCopy(pageInfo:nodes:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSArray<XNetworkingGetWestendHistoryElementsQueryNode *> *)nodesFilterNotNull __attribute__((swift_name("nodesFilterNotNull()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property (readonly) XNetworkingGetWestendHistoryElementsQueryPageInfo *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery.Node")))
@interface XNetworkingGetWestendHistoryElementsQueryNode : XNetworkingBase
- (instancetype)initWithId:(NSString * _Nullable)id timestamp:(NSString * _Nullable)timestamp address:(NSString * _Nullable)address reward:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)reward transfer:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)transfer extrinsic:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)extrinsic __attribute__((swift_name("init(id:timestamp:address:reward:transfer:extrinsic:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetWestendHistoryElementsQueryNode *)doCopyId:(NSString * _Nullable)id timestamp:(NSString * _Nullable)timestamp address:(NSString * _Nullable)address reward:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)reward transfer:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)transfer extrinsic:(XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable)extrinsic __attribute__((swift_name("doCopy(id:timestamp:address:reward:transfer:extrinsic:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable address __attribute__((swift_name("address")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable extrinsic __attribute__((swift_name("extrinsic")));
@property (readonly) NSString * _Nullable id __attribute__((swift_name("id")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable reward __attribute__((swift_name("reward")));
@property (readonly) NSString * _Nullable timestamp __attribute__((swift_name("timestamp")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable transfer __attribute__((swift_name("transfer")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery.PageInfo")))
@interface XNetworkingGetWestendHistoryElementsQueryPageInfo : XNetworkingBase
- (instancetype)initWithEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("init(endCursor:hasNextPage:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingGetWestendHistoryElementsQueryPageInfo *)doCopyEndCursor:(NSString * _Nullable)endCursor hasNextPage:(BOOL)hasNextPage __attribute__((swift_name("doCopy(endCursor:hasNextPage:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property (readonly) BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery_ResponseAdapter")))
@interface XNetworkingGetWestendHistoryElementsQuery_ResponseAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getWestendHistoryElementsQuery_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuery_ResponseAdapter *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery_ResponseAdapter.Data")))
@interface XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterData : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)data __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterData *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetWestendHistoryElementsQueryData * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetWestendHistoryElementsQueryData *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery_ResponseAdapter.HistoryElements")))
@interface XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterHistoryElements : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)historyElements __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterHistoryElements *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetWestendHistoryElementsQueryHistoryElements * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetWestendHistoryElementsQueryHistoryElements *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery_ResponseAdapter.Node")))
@interface XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterNode : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)node __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterNode *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetWestendHistoryElementsQueryNode * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetWestendHistoryElementsQueryNode *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery_ResponseAdapter.PageInfo")))
@interface XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterPageInfo : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)pageInfo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuery_ResponseAdapterPageInfo *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingGetWestendHistoryElementsQueryPageInfo * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingGetWestendHistoryElementsQueryPageInfo *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@property (readonly) NSArray<NSString *> *RESPONSE_NAMES __attribute__((swift_name("RESPONSE_NAMES")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuery_VariablesAdapter")))
@interface XNetworkingGetWestendHistoryElementsQuery_VariablesAdapter : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getWestendHistoryElementsQuery_VariablesAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuery_VariablesAdapter *shared __attribute__((swift_name("shared")));
- (void)serializeVariablesWriter:(id<XNetworkingApollo_apiJsonWriter>)writer value:(XNetworkingGetWestendHistoryElementsQuery *)value customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters withDefaultValues:(BOOL)withDefaultValues __attribute__((swift_name("serializeVariables(writer:value:customScalarAdapters:withDefaultValues:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("__Schema_")))
@interface XNetworking__Schema_ : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)__Schema __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworking__Schema_ *shared __attribute__((swift_name("shared")));
- (NSArray<XNetworkingApollo_apiObjectType *> *)possibleTypesType:(XNetworkingApollo_apiCompiledNamedType *)type __attribute__((swift_name("possibleTypes(type:)")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledNamedType *> *all __attribute__((swift_name("all")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GetWestendHistoryElementsQuerySelections")))
@interface XNetworkingGetWestendHistoryElementsQuerySelections : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)getWestendHistoryElementsQuerySelections __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGetWestendHistoryElementsQuerySelections *shared __attribute__((swift_name("shared")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *__root __attribute__((swift_name("__root")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedReward")))
@interface XNetworkingAccumulatedReward : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAccumulatedRewardCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedReward.Companion")))
@interface XNetworkingAccumulatedRewardCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAccumulatedRewardCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAccumulatedRewardBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedRewardBuilder")))
@interface XNetworkingAccumulatedRewardBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AccumulatedRewardMap")))
@interface XNetworkingAccumulatedRewardMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedStake")))
@interface XNetworkingAccumulatedStake : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingAccumulatedStakeCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedStake.Companion")))
@interface XNetworkingAccumulatedStakeCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingAccumulatedStakeCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingAccumulatedStakeBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedStakeBuilder")))
@interface XNetworkingAccumulatedStakeBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("AccumulatedStakeMap")))
@interface XNetworkingAccumulatedStakeMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BigFloat_")))
@interface XNetworkingBigFloat_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingBigFloat_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BigFloat_.Companion")))
@interface XNetworkingBigFloat_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingBigFloat_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Cursor_")))
@interface XNetworkingCursor_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingCursor_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Cursor_.Companion")))
@interface XNetworkingCursor_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingCursor_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EraValidatorInfo")))
@interface XNetworkingEraValidatorInfo : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingEraValidatorInfoCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EraValidatorInfo.Companion")))
@interface XNetworkingEraValidatorInfoCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingEraValidatorInfoCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingEraValidatorInfoBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EraValidatorInfoBuilder")))
@interface XNetworkingEraValidatorInfoBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("EraValidatorInfoMap")))
@interface XNetworkingEraValidatorInfoMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ErrorEvent")))
@interface XNetworkingErrorEvent : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingErrorEventCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ErrorEvent.Companion")))
@interface XNetworkingErrorEventCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingErrorEventCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingErrorEventBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ErrorEventBuilder")))
@interface XNetworkingErrorEventBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("ErrorEventMap")))
@interface XNetworkingErrorEventMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLBoolean_")))
@interface XNetworkingGraphQLBoolean_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLBoolean_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLBoolean_.Companion")))
@interface XNetworkingGraphQLBoolean_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLBoolean_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLFloat_")))
@interface XNetworkingGraphQLFloat_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLFloat_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLFloat_.Companion")))
@interface XNetworkingGraphQLFloat_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLFloat_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLID_")))
@interface XNetworkingGraphQLID_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLID_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLID_.Companion")))
@interface XNetworkingGraphQLID_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLID_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLInt_")))
@interface XNetworkingGraphQLInt_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLInt_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLInt_.Companion")))
@interface XNetworkingGraphQLInt_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLInt_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLString_")))
@interface XNetworkingGraphQLString_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingGraphQLString_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GraphQLString_.Companion")))
@interface XNetworkingGraphQLString_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingGraphQLString_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElement_")))
@interface XNetworkingHistoryElement_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingHistoryElement_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElement_.Companion")))
@interface XNetworkingHistoryElement_Companion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElement_Companion *shared __attribute__((swift_name("shared")));
- (XNetworkingHistoryElementBuilder_ *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementBuilder_")))
@interface XNetworkingHistoryElementBuilder_ : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString *address __attribute__((swift_name("address")));
@property XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable extrinsic __attribute__((swift_name("extrinsic")));
@property NSString *id __attribute__((swift_name("id")));
@property XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable reward __attribute__((swift_name("reward")));
@property NSString *timestamp __attribute__((swift_name("timestamp")));
@property XNetworkingKotlinx_serialization_jsonJsonElement * _Nullable transfer __attribute__((swift_name("transfer")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("HistoryElementMap_")))
@interface XNetworkingHistoryElementMap_ : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnection_")))
@interface XNetworkingHistoryElementsConnection_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingHistoryElementsConnection_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnection_.Companion")))
@interface XNetworkingHistoryElementsConnection_Companion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementsConnection_Companion *shared __attribute__((swift_name("shared")));
- (XNetworkingHistoryElementsConnectionBuilder_ *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnectionBuilder_")))
@interface XNetworkingHistoryElementsConnectionBuilder_ : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSArray<id> *nodes __attribute__((swift_name("nodes")));
@property NSDictionary<NSString *, id> *pageInfo __attribute__((swift_name("pageInfo")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("HistoryElementsConnectionMap_")))
@interface XNetworkingHistoryElementsConnectionMap_ : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsOrderBy_")))
@interface XNetworkingHistoryElementsOrderBy_ : XNetworkingKotlinEnum<XNetworkingHistoryElementsOrderBy_ *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) XNetworkingHistoryElementsOrderBy_Companion *companion __attribute__((swift_name("companion")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *natural __attribute__((swift_name("natural")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *idAsc __attribute__((swift_name("idAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *idDesc __attribute__((swift_name("idDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *blockNumberAsc __attribute__((swift_name("blockNumberAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *blockNumberDesc __attribute__((swift_name("blockNumberDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *extrinsicIdxAsc __attribute__((swift_name("extrinsicIdxAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *extrinsicIdxDesc __attribute__((swift_name("extrinsicIdxDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *extrinsicHashAsc __attribute__((swift_name("extrinsicHashAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *extrinsicHashDesc __attribute__((swift_name("extrinsicHashDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *timestampAsc __attribute__((swift_name("timestampAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *timestampDesc __attribute__((swift_name("timestampDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *addressAsc __attribute__((swift_name("addressAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *addressDesc __attribute__((swift_name("addressDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *rewardAsc __attribute__((swift_name("rewardAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *rewardDesc __attribute__((swift_name("rewardDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *extrinsicAsc __attribute__((swift_name("extrinsicAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *extrinsicDesc __attribute__((swift_name("extrinsicDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *transferAsc __attribute__((swift_name("transferAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *transferDesc __attribute__((swift_name("transferDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *primaryKeyAsc __attribute__((swift_name("primaryKeyAsc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *primaryKeyDesc __attribute__((swift_name("primaryKeyDesc")));
@property (class, readonly) XNetworkingHistoryElementsOrderBy_ *unknown __attribute__((swift_name("unknown")));
+ (XNetworkingKotlinArray<XNetworkingHistoryElementsOrderBy_ *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingHistoryElementsOrderBy_ *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *rawValue __attribute__((swift_name("rawValue")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsOrderBy_.Companion")))
@interface XNetworkingHistoryElementsOrderBy_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementsOrderBy_Companion *shared __attribute__((swift_name("shared")));
- (XNetworkingKotlinArray<XNetworkingHistoryElementsOrderBy_ *> *)knownValues __attribute__((swift_name("knownValues()"))) __attribute__((deprecated("Use knownEntries instead")));
- (XNetworkingHistoryElementsOrderBy_ *)safeValueOfRawValue:(NSString *)rawValue __attribute__((swift_name("safeValueOf(rawValue:)")));
@property (readonly) NSArray<XNetworkingHistoryElementsOrderBy_ *> *knownEntries __attribute__((swift_name("knownEntries")));
@property (readonly) XNetworkingApollo_apiEnumType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSON_")))
@interface XNetworkingJSON_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingJSON_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JSON_.Companion")))
@interface XNetworkingJSON_Companion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingJSON_Companion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Node_")))
@interface XNetworkingNode_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingNode_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Node_.Companion")))
@interface XNetworkingNode_Companion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingNode_Companion *shared __attribute__((swift_name("shared")));
- (XNetworkingOtherNodeBuilder_ *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiInterfaceType *type __attribute__((swift_name("type")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("NodeMap_")))
@protocol XNetworkingNodeMap_
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OtherNodeBuilder_")))
@interface XNetworkingOtherNodeBuilder_ : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("OtherNodeMap_")))
@interface XNetworkingOtherNodeMap_ : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfo_")))
@interface XNetworkingPageInfo_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingPageInfo_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfo_.Companion")))
@interface XNetworkingPageInfo_Companion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingPageInfo_Companion *shared __attribute__((swift_name("shared")));
- (XNetworkingPageInfoBuilder_ *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfoBuilder_")))
@interface XNetworkingPageInfoBuilder_ : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSString * _Nullable endCursor __attribute__((swift_name("endCursor")));
@property BOOL hasNextPage __attribute__((swift_name("hasNextPage")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("PageInfoMap_")))
@interface XNetworkingPageInfoMap_ : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Query_")))
@interface XNetworkingQuery_ : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingQuery_Companion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Query_.Companion")))
@interface XNetworkingQuery_Companion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingQuery_Companion *shared __attribute__((swift_name("shared")));
- (XNetworkingQueryBuilder_ *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_after __attribute__((swift_name("__historyElements_after")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_filter __attribute__((swift_name("__historyElements_filter")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_first __attribute__((swift_name("__historyElements_first")));
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *__historyElements_orderBy __attribute__((swift_name("__historyElements_orderBy")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("QueryBuilder_")))
@interface XNetworkingQueryBuilder_ : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@property NSDictionary<NSString *, id> * _Nullable historyElements __attribute__((swift_name("historyElements")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("QueryMap_")))
@interface XNetworkingQueryMap_ : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StakeChange")))
@interface XNetworkingStakeChange : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingStakeChangeCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StakeChange.Companion")))
@interface XNetworkingStakeChangeCompanion : XNetworkingBase <XNetworkingApollo_apiBuilderFactory>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingStakeChangeCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingStakeChangeBuilder *)doNewBuilderCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("doNewBuilder(customScalarAdapters:)")));
@property (readonly) XNetworkingApollo_apiObjectType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StakeChangeBuilder")))
@interface XNetworkingStakeChangeBuilder : XNetworkingApollo_apiObjectBuilder<NSDictionary<NSString *, id> *>
- (instancetype)initWithCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("init(customScalarAdapters:)"))) __attribute__((objc_designated_initializer));
- (NSDictionary<NSString *, id> *)build __attribute__((swift_name("build()")));
@end

__attribute__((unavailable("can't be imported")))
__attribute__((swift_name("StakeChangeMap")))
@interface XNetworkingStakeChangeMap : NSObject
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsOrderBy_ResponseAdapter_")))
@interface XNetworkingHistoryElementsOrderBy_ResponseAdapter_ : XNetworkingBase <XNetworkingApollo_apiAdapter>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)historyElementsOrderBy_ResponseAdapter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingHistoryElementsOrderBy_ResponseAdapter_ *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingHistoryElementsOrderBy_ * _Nullable)fromJsonReader:(id<XNetworkingApollo_apiJsonReader>)reader customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("fromJson(reader:customScalarAdapters:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)toJsonWriter:(id<XNetworkingApollo_apiJsonWriter>)writer customScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters value:(XNetworkingHistoryElementsOrderBy_ *)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("toJson(writer:customScalarAdapters:value:)")));
@end

@interface XNetworkingPackedCursorCompanion (Extensions)
- (XNetworkingPackedCursor *)createCursor:(NSString * _Nullable)cursor __attribute__((swift_name("create(cursor:)")));
@end

@interface XNetworkingRestClient (Extensions)

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getAsStringUrl:(NSString *)url completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getAsString(url:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)postAsStringUrl:(NSString *)url body:(id)body completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("postAsString(url:body:completionHandler:)")));
@end

@interface XNetworkingRestClientException (Extensions)
- (NSString *)parseToError __attribute__((swift_name("parseToError()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_coroutines_coreDispatchers")))
@interface XNetworkingKotlinx_coroutines_coreDispatchers : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)dispatchers __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingKotlinx_coroutines_coreDispatchers *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *Default __attribute__((swift_name("Default")));
@property (readonly) XNetworkingKotlinx_coroutines_coreMainCoroutineDispatcher *Main __attribute__((swift_name("Main")));
@property (readonly) XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *Unconfined __attribute__((swift_name("Unconfined")));
@end

@interface XNetworkingKotlinx_coroutines_coreDispatchers (Extensions)
@property (readonly) XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *CommonIO __attribute__((swift_name("CommonIO")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable(with=NormalClass(value=kotlinx/serialization/json/JsonElementSerializer))
*/
__attribute__((swift_name("Kotlinx_serialization_jsonJsonElement")))
@interface XNetworkingKotlinx_serialization_jsonJsonElement : XNetworkingBase
@property (class, readonly, getter=companion) XNetworkingKotlinx_serialization_jsonJsonElementCompanion *companion __attribute__((swift_name("companion")));
@end

@interface XNetworkingKotlinx_serialization_jsonJsonElement (Extensions)
- (NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable)arrayOrNullKey:(NSString *)key __attribute__((swift_name("arrayOrNull(key:)")));
- (NSString * _Nullable)fieldOrNullKey:(NSString *)key __attribute__((swift_name("fieldOrNull(key:)")));
- (NSDictionary<NSString *, XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable)objectOrNullKey:(NSString *)key __attribute__((swift_name("objectOrNull(key:)")));
- (NSString * _Nullable)primitiveOrNull __attribute__((swift_name("primitiveOrNull()")));
@property (readonly) NSArray<XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable asJsonArrayNullable __attribute__((swift_name("asJsonArrayNullable")));
@property (readonly) NSDictionary<NSString *, XNetworkingKotlinx_serialization_jsonJsonElement *> * _Nullable asJsonObjectNullable __attribute__((swift_name("asJsonObjectNullable")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccountKt")))
@interface XNetworkingAccountKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAccount:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAccountBuilder *))block __attribute__((swift_name("buildAccount(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedRewardKt")))
@interface XNetworkingAccumulatedRewardKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAccumulatedReward:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAccumulatedRewardBuilder *))block __attribute__((swift_name("buildAccumulatedReward(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AccumulatedStakeKt")))
@interface XNetworkingAccumulatedStakeKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAccumulatedStake:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAccumulatedStakeBuilder *))block __attribute__((swift_name("buildAccumulatedStake(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetKt")))
@interface XNetworkingAssetKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAsset:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAssetBuilder *))block __attribute__((swift_name("buildAsset(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetSnapshotKt")))
@interface XNetworkingAssetSnapshotKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAssetSnapshot:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAssetSnapshotBuilder *))block __attribute__((swift_name("buildAssetSnapshot(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsConnectionKt")))
@interface XNetworkingAssetsConnectionKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAssetsConnection:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAssetsConnectionBuilder *))block __attribute__((swift_name("buildAssetsConnection(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AssetsEdgeKt")))
@interface XNetworkingAssetsEdgeKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildAssetsEdge:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingAssetsEdgeBuilder *))block __attribute__((swift_name("buildAssetsEdge(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EraValidatorInfoKt")))
@interface XNetworkingEraValidatorInfoKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildEraValidatorInfo:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingEraValidatorInfoBuilder *))block __attribute__((swift_name("buildEraValidatorInfo(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ErrorEventKt")))
@interface XNetworkingErrorEventKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildErrorEvent:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingErrorEventBuilder *))block __attribute__((swift_name("buildErrorEvent(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementKt")))
@interface XNetworkingHistoryElementKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildHistoryElement:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingHistoryElementBuilder *))block __attribute__((swift_name("buildHistoryElement(_:block:)")));
+ (NSDictionary<NSString *, id> *)buildHistoryElement:(id<XNetworkingApollo_apiBuilderScope>)receiver block_:(void (^)(XNetworkingHistoryElementBuilder_ *))block __attribute__((swift_name("buildHistoryElement(_:block_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HistoryElementsConnectionKt")))
@interface XNetworkingHistoryElementsConnectionKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildHistoryElementsConnection:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingHistoryElementsConnectionBuilder *))block __attribute__((swift_name("buildHistoryElementsConnection(_:block:)")));
+ (NSDictionary<NSString *, id> *)buildHistoryElementsConnection:(id<XNetworkingApollo_apiBuilderScope>)receiver block_:(void (^)(XNetworkingHistoryElementsConnectionBuilder_ *))block __attribute__((swift_name("buildHistoryElementsConnection(_:block_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("JsonExtsKt")))
@interface XNetworkingJsonExtsKt : XNetworkingBase
+ (XNetworkingKotlinx_serialization_jsonJson *)createJsonIsPrettyPrintEnabled:(BOOL)isPrettyPrintEnabled isLenient:(BOOL)isLenient shouldIgnoreUnknownKeys:(BOOL)shouldIgnoreUnknownKeys __attribute__((swift_name("createJson(isPrettyPrintEnabled:isLenient:shouldIgnoreUnknownKeys:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinExtsKt")))
@interface XNetworkingKotlinExtsKt : XNetworkingBase
+ (XNetworkingKotlinEnum * _Nullable)enumValueOfNullableType:(NSString * _Nullable)type __attribute__((swift_name("enumValueOfNullable(type:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkSnapshotKt")))
@interface XNetworkingNetworkSnapshotKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildNetworkSnapshot:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingNetworkSnapshotBuilder *))block __attribute__((swift_name("buildNetworkSnapshot(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NetworkStatKt")))
@interface XNetworkingNetworkStatKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildNetworkStat:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingNetworkStatBuilder *))block __attribute__((swift_name("buildNetworkStat(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NodeKt")))
@interface XNetworkingNodeKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildOtherNode:(id<XNetworkingApollo_apiBuilderScope>)receiver typename:(NSString *)typename_ block:(void (^)(XNetworkingOtherNodeBuilder *))block __attribute__((swift_name("buildOtherNode(_:typename:block:)")));
+ (NSDictionary<NSString *, id> *)buildOtherNode:(id<XNetworkingApollo_apiBuilderScope>)receiver typename:(NSString *)typename_ block_:(void (^)(XNetworkingOtherNodeBuilder_ *))block __attribute__((swift_name("buildOtherNode(_:typename:block_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PageInfoKt")))
@interface XNetworkingPageInfoKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildPageInfo:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingPageInfoBuilder *))block __attribute__((swift_name("buildPageInfo(_:block:)")));
+ (NSDictionary<NSString *, id> *)buildPageInfo:(id<XNetworkingApollo_apiBuilderScope>)receiver block_:(void (^)(XNetworkingPageInfoBuilder_ *))block __attribute__((swift_name("buildPageInfo(_:block_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXYKKt")))
@interface XNetworkingPoolXYKKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildPoolXYK:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingPoolXYKBuilder *))block __attribute__((swift_name("buildPoolXYK(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksConnectionKt")))
@interface XNetworkingPoolXyksConnectionKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildPoolXyksConnection:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingPoolXyksConnectionBuilder *))block __attribute__((swift_name("buildPoolXyksConnection(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PoolXyksEdgeKt")))
@interface XNetworkingPoolXyksEdgeKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildPoolXyksEdge:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingPoolXyksEdgeBuilder *))block __attribute__((swift_name("buildPoolXyksEdge(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("QueryKt")))
@interface XNetworkingQueryKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildQuery:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingQueryBuilder *))block __attribute__((swift_name("buildQuery(_:block:)")));
+ (NSDictionary<NSString *, id> *)buildQuery:(id<XNetworkingApollo_apiBuilderScope>)receiver block_:(void (^)(XNetworkingQueryBuilder_ *))block __attribute__((swift_name("buildQuery(_:block_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardKt")))
@interface XNetworkingReferrerRewardKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildReferrerReward:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingReferrerRewardBuilder *))block __attribute__((swift_name("buildReferrerReward(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ReferrerRewardsConnectionKt")))
@interface XNetworkingReferrerRewardsConnectionKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildReferrerRewardsConnection:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingReferrerRewardsConnectionBuilder *))block __attribute__((swift_name("buildReferrerRewardsConnection(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StakeChangeKt")))
@interface XNetworkingStakeChangeKt : XNetworkingBase
+ (NSDictionary<NSString *, id> *)buildStakeChange:(id<XNetworkingApollo_apiBuilderScope>)receiver block:(void (^)(XNetworkingStakeChangeBuilder *))block __attribute__((swift_name("buildStakeChange(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubQueryInternalsKt")))
@interface XNetworkingSubQueryInternalsKt : XNetworkingBase
@property (class, readonly) XNetworkingRestClientContentType *requestContentType __attribute__((swift_name("requestContentType")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("__CustomScalarAdaptersKt")))
@interface XNetworking__CustomScalarAdaptersKt : XNetworkingBase
@property (class, readonly) XNetworkingApollo_apiCustomScalarAdapters *__CustomScalarAdapters __attribute__((swift_name("__CustomScalarAdapters")));
@property (class, readonly) XNetworkingApollo_apiCustomScalarAdapters *__CustomScalarAdapters_ __attribute__((swift_name("__CustomScalarAdapters_")));
@end

__attribute__((swift_name("RuntimeTransactionCallbacks")))
@protocol XNetworkingRuntimeTransactionCallbacks
@required
- (void)afterCommitFunction:(void (^)(void))function __attribute__((swift_name("afterCommit(function:)")));
- (void)afterRollbackFunction:(void (^)(void))function __attribute__((swift_name("afterRollback(function:)")));
@end

__attribute__((swift_name("RuntimeTransactionWithoutReturn")))
@protocol XNetworkingRuntimeTransactionWithoutReturn <XNetworkingRuntimeTransactionCallbacks>
@required
- (void)rollback __attribute__((swift_name("rollback()")));
- (void)transactionBody:(void (^)(id<XNetworkingRuntimeTransactionWithoutReturn>))body __attribute__((swift_name("transaction(body:)")));
@end

__attribute__((swift_name("RuntimeTransactionWithReturn")))
@protocol XNetworkingRuntimeTransactionWithReturn <XNetworkingRuntimeTransactionCallbacks>
@required
- (void)rollbackReturnValue:(id _Nullable)returnValue __attribute__((swift_name("rollback(returnValue:)")));
- (id _Nullable)transactionBody_:(id _Nullable (^)(id<XNetworkingRuntimeTransactionWithReturn>))body __attribute__((swift_name("transaction(body_:)")));
@end

__attribute__((swift_name("RuntimeCloseable")))
@protocol XNetworkingRuntimeCloseable
@required
- (void)close __attribute__((swift_name("close()")));
@end

__attribute__((swift_name("RuntimeSqlDriver")))
@protocol XNetworkingRuntimeSqlDriver <XNetworkingRuntimeCloseable>
@required
- (XNetworkingRuntimeTransacterTransaction * _Nullable)currentTransaction __attribute__((swift_name("currentTransaction()")));
- (void)executeIdentifier:(XNetworkingInt * _Nullable)identifier sql:(NSString *)sql parameters:(int32_t)parameters binders:(void (^ _Nullable)(id<XNetworkingRuntimeSqlPreparedStatement>))binders __attribute__((swift_name("execute(identifier:sql:parameters:binders:)")));
- (id<XNetworkingRuntimeSqlCursor>)executeQueryIdentifier:(XNetworkingInt * _Nullable)identifier sql:(NSString *)sql parameters:(int32_t)parameters binders:(void (^ _Nullable)(id<XNetworkingRuntimeSqlPreparedStatement>))binders __attribute__((swift_name("executeQuery(identifier:sql:parameters:binders:)")));
- (XNetworkingRuntimeTransacterTransaction *)doNewTransaction __attribute__((swift_name("doNewTransaction()")));
@end

__attribute__((swift_name("RuntimeSqlDriverSchema")))
@protocol XNetworkingRuntimeSqlDriverSchema
@required
- (void)createDriver:(id<XNetworkingRuntimeSqlDriver>)driver __attribute__((swift_name("create(driver:)")));
- (void)migrateDriver:(id<XNetworkingRuntimeSqlDriver>)driver oldVersion:(int32_t)oldVersion newVersion:(int32_t)newVersion __attribute__((swift_name("migrate(driver:oldVersion:newVersion:)")));
@property (readonly) int32_t version __attribute__((swift_name("version")));
@end

__attribute__((swift_name("RuntimeQuery")))
@interface XNetworkingRuntimeQuery<__covariant RowType> : XNetworkingBase
- (instancetype)initWithQueries:(NSMutableArray<XNetworkingRuntimeQuery<id> *> *)queries mapper:(RowType (^)(id<XNetworkingRuntimeSqlCursor>))mapper __attribute__((swift_name("init(queries:mapper:)"))) __attribute__((objc_designated_initializer));
- (void)addListenerListener:(id<XNetworkingRuntimeQueryListener>)listener __attribute__((swift_name("addListener(listener:)")));
- (id<XNetworkingRuntimeSqlCursor>)execute __attribute__((swift_name("execute()")));
- (NSArray<RowType> *)executeAsList __attribute__((swift_name("executeAsList()")));
- (RowType)executeAsOne __attribute__((swift_name("executeAsOne()")));
- (RowType _Nullable)executeAsOneOrNull __attribute__((swift_name("executeAsOneOrNull()")));
- (void)notifyDataChanged __attribute__((swift_name("notifyDataChanged()")));
- (void)removeListenerListener:(id<XNetworkingRuntimeQueryListener>)listener __attribute__((swift_name("removeListener(listener:)")));
@property (readonly) RowType (^mapper)(id<XNetworkingRuntimeSqlCursor>) __attribute__((swift_name("mapper")));
@end

__attribute__((swift_name("KotlinIllegalStateException")))
@interface XNetworkingKotlinIllegalStateException : XNetworkingKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.4")
*/
__attribute__((swift_name("KotlinCancellationException")))
@interface XNetworkingKotlinCancellationException : XNetworkingKotlinIllegalStateException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinIllegalArgumentException")))
@interface XNetworkingKotlinIllegalArgumentException : XNetworkingKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinNullPointerException")))
@interface XNetworkingKotlinNullPointerException : XNetworkingKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end

__attribute__((swift_name("Apollo_apiApolloException")))
@interface XNetworkingApollo_apiApolloException : XNetworkingKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinEnumCompanion")))
@interface XNetworkingKotlinEnumCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingKotlinEnumCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinArray")))
@interface XNetworkingKotlinArray<T> : XNetworkingBase
+ (instancetype)arrayWithSize:(int32_t)size init:(T _Nullable (^)(XNetworkingInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (T _Nullable)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (id<XNetworkingKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(T _Nullable)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialFormat")))
@protocol XNetworkingKotlinx_serialization_coreSerialFormat
@required
@property (readonly) XNetworkingKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreStringFormat")))
@protocol XNetworkingKotlinx_serialization_coreStringFormat <XNetworkingKotlinx_serialization_coreSerialFormat>
@required
- (id _Nullable)decodeFromStringDeserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer string:(NSString *)string __attribute__((swift_name("decodeFromString(deserializer:string:)")));
- (NSString *)encodeToStringSerializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeToString(serializer:value:)")));
@end

__attribute__((swift_name("Kotlinx_serialization_jsonJson")))
@interface XNetworkingKotlinx_serialization_jsonJson : XNetworkingBase <XNetworkingKotlinx_serialization_coreStringFormat>
@property (class, readonly, getter=companion) XNetworkingKotlinx_serialization_jsonJsonDefault *companion __attribute__((swift_name("companion")));
- (id _Nullable)decodeFromJsonElementDeserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer element:(XNetworkingKotlinx_serialization_jsonJsonElement *)element __attribute__((swift_name("decodeFromJsonElement(deserializer:element:)")));
- (id _Nullable)decodeFromStringString:(NSString *)string __attribute__((swift_name("decodeFromString(string:)")));
- (id _Nullable)decodeFromStringDeserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer string:(NSString *)string __attribute__((swift_name("decodeFromString(deserializer:string:)")));
- (XNetworkingKotlinx_serialization_jsonJsonElement *)encodeToJsonElementSerializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeToJsonElement(serializer:value:)")));
- (NSString *)encodeToStringSerializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeToString(serializer:value:)")));
- (XNetworkingKotlinx_serialization_jsonJsonElement *)parseToJsonElementString:(NSString *)string __attribute__((swift_name("parseToJsonElement(string:)")));
@property (readonly) XNetworkingKotlinx_serialization_jsonJsonConfiguration *configuration __attribute__((swift_name("configuration")));
@property (readonly) XNetworkingKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializationStrategy")))
@protocol XNetworkingKotlinx_serialization_coreSerializationStrategy
@required
- (void)serializeEncoder:(id<XNetworkingKotlinx_serialization_coreEncoder>)encoder value:(id _Nullable)value __attribute__((swift_name("serialize(encoder:value:)")));
@property (readonly) id<XNetworkingKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDeserializationStrategy")))
@protocol XNetworkingKotlinx_serialization_coreDeserializationStrategy
@required
- (id _Nullable)deserializeDecoder:(id<XNetworkingKotlinx_serialization_coreDecoder>)decoder __attribute__((swift_name("deserialize(decoder:)")));
@property (readonly) id<XNetworkingKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreKSerializer")))
@protocol XNetworkingKotlinx_serialization_coreKSerializer <XNetworkingKotlinx_serialization_coreSerializationStrategy, XNetworkingKotlinx_serialization_coreDeserializationStrategy>
@required
@end

__attribute__((swift_name("OkioIOException")))
@interface XNetworkingOkioIOException : XNetworkingKotlinException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(XNetworkingKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end

__attribute__((swift_name("OkioCloseable")))
@protocol XNetworkingOkioCloseable
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));
@end

__attribute__((swift_name("Apollo_apiJsonReader")))
@protocol XNetworkingApollo_apiJsonReader <XNetworkingOkioCloseable>
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonReader> _Nullable)beginArrayAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("beginArray()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonReader> _Nullable)beginObjectAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("beginObject()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonReader> _Nullable)endArrayAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("endArray()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonReader> _Nullable)endObjectAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("endObject()")));
- (NSArray<id> *)getPath __attribute__((swift_name("getPath()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)hasNextAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("hasNext()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)nextBooleanAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextBoolean()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (double)nextDoubleAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextDouble()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int32_t)nextIntAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextInt()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)nextLongAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextLong()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSString * _Nullable)nextNameAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextName()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingKotlinNothing * _Nullable)nextNullAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextNull()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingApollo_apiJsonNumber * _Nullable)nextNumberAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextNumber()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSString * _Nullable)nextStringAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nextString()"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (XNetworkingApollo_apiJsonReaderToken * _Nullable)peekAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("peek()")));
- (void)rewind __attribute__((swift_name("rewind()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int32_t)selectNameNames:(NSArray<NSString *> *)names error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("selectName(names:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)skipValueAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("skipValue()")));
@end

__attribute__((swift_name("Apollo_apiExecutionContext")))
@protocol XNetworkingApollo_apiExecutionContext
@required
- (id _Nullable)foldInitial:(id _Nullable)initial operation:(id _Nullable (^)(id _Nullable, id<XNetworkingApollo_apiExecutionContextElement>))operation __attribute__((swift_name("fold(initial:operation:)")));
- (id<XNetworkingApollo_apiExecutionContextElement> _Nullable)getKey_:(id<XNetworkingApollo_apiExecutionContextKey>)key __attribute__((swift_name("get(key_:)")));
- (id<XNetworkingApollo_apiExecutionContext>)minusKeyKey:(id<XNetworkingApollo_apiExecutionContextKey>)key __attribute__((swift_name("minusKey(key:)")));
- (id<XNetworkingApollo_apiExecutionContext>)plusContext:(id<XNetworkingApollo_apiExecutionContext>)context __attribute__((swift_name("plus(context:)")));
@end

__attribute__((swift_name("Apollo_apiExecutionContextElement")))
@protocol XNetworkingApollo_apiExecutionContextElement <XNetworkingApollo_apiExecutionContext>
@required
@property (readonly) id<XNetworkingApollo_apiExecutionContextKey> key __attribute__((swift_name("key")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCustomScalarAdapters")))
@interface XNetworkingApollo_apiCustomScalarAdapters : XNetworkingBase <XNetworkingApollo_apiExecutionContextElement>
@property (class, readonly, getter=companion) XNetworkingApollo_apiCustomScalarAdaptersKey *companion __attribute__((swift_name("companion")));
- (id<XNetworkingApollo_apiAdapter> _Nullable)adapterForName:(NSString *)name __attribute__((swift_name("adapterFor(name:)")));

/**
 * @note annotations
 *   com.apollographql.apollo.annotations.ApolloExperimental
*/
- (XNetworkingApollo_apiError * _Nullable)firstErrorStartingWithPath:(NSArray<id> *)path __attribute__((swift_name("firstErrorStartingWith(path:)")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)doNewBuilder __attribute__((swift_name("doNewBuilder()")));
- (id<XNetworkingApollo_apiAdapter>)responseAdapterForCustomScalar:(XNetworkingApollo_apiCustomScalarType *)customScalar __attribute__((swift_name("responseAdapterFor(customScalar:)")));
@property (readonly) NSSet<XNetworkingApollo_apiDeferredFragmentIdentifier *> * _Nullable deferredFragmentIdentifiers __attribute__((swift_name("deferredFragmentIdentifiers")));
@property (readonly) NSArray<XNetworkingApollo_apiError *> * _Nullable errors __attribute__((swift_name("errors")));
@property (readonly) NSSet<NSString *> * _Nullable falseVariables __attribute__((swift_name("falseVariables")));
@property (readonly) id<XNetworkingApollo_apiExecutionContextKey> key __attribute__((swift_name("key")));
@end

__attribute__((swift_name("Apollo_apiJsonWriter")))
@protocol XNetworkingApollo_apiJsonWriter <XNetworkingOkioCloseable>
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)beginArrayAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("beginArray()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)beginObjectAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("beginObject()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)endArrayAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("endArray()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)endObjectAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("endObject()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)flushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("flush()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)nameName:(NSString *)name error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("name(name:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)nullValueAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("nullValue()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(id<XNetworkingApollo_apiUpload>)value error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(XNetworkingApollo_apiJsonNumber *)value error_:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value_:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(BOOL)value error__:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value__:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(double)value error___:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value___:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(int32_t)value error____:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value____:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(int64_t)value error_____:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value_____:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<XNetworkingApollo_apiJsonWriter> _Nullable)valueValue:(NSString *)value error______:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("value(value______:)")));
@property (readonly) NSString *path __attribute__((swift_name("path")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlow")))
@protocol XNetworkingKotlinx_coroutines_coreFlow
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)collectCollector:(id<XNetworkingKotlinx_coroutines_coreFlowCollector>)collector completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("collect(collector:completionHandler:)")));
@end

__attribute__((swift_name("Apollo_apiCompiledSelection")))
@interface XNetworkingApollo_apiCompiledSelection : XNetworkingBase
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCompiledField")))
@interface XNetworkingApollo_apiCompiledField : XNetworkingApollo_apiCompiledSelection
- (XNetworkingApollo_apiOptional<id> *)argumentValueName:(NSString *)name variables:(XNetworkingApollo_apiExecutableVariables *)variables __attribute__((swift_name("argumentValue(name:variables:)")));

/**
 * @note annotations
 *   com.apollographql.apollo.annotations.ApolloExperimental
*/
- (NSDictionary<NSString *, id> *)argumentValuesVariables:(XNetworkingApollo_apiExecutableVariables *)variables filter:(XNetworkingBoolean *(^)(XNetworkingApollo_apiCompiledArgument *))filter __attribute__((swift_name("argumentValues(variables:filter:)")));
- (NSString *)nameWithArgumentsVariables:(XNetworkingApollo_apiExecutableVariables *)variables __attribute__((swift_name("nameWithArguments(variables:)")));
- (XNetworkingApollo_apiCompiledFieldBuilder *)doNewBuilder __attribute__((swift_name("doNewBuilder()")));
- (id _Nullable)resolveArgumentName:(NSString *)name variables:(XNetworkingApollo_apiExecutableVariables *)variables __attribute__((swift_name("resolveArgument(name:variables:)"))) __attribute__((deprecated("This function does not distinguish between null and absent arguments. Use argumentValue instead")));
@property (readonly) NSString * _Nullable alias __attribute__((swift_name("alias")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledArgument *> *arguments __attribute__((swift_name("arguments")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledCondition *> *condition __attribute__((swift_name("condition")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) NSString *responseName __attribute__((swift_name("responseName")));
@property (readonly) NSArray<XNetworkingApollo_apiCompiledSelection *> *selections __attribute__((swift_name("selections")));
@property (readonly) XNetworkingApollo_apiCompiledType *type __attribute__((swift_name("type")));
@end

__attribute__((swift_name("Apollo_apiOptional")))
@interface XNetworkingApollo_apiOptional<__covariant V> : XNetworkingBase
@property (class, readonly, getter=companion) XNetworkingApollo_apiOptionalCompanion *companion __attribute__((swift_name("companion")));
- (V _Nullable)getOrNull __attribute__((swift_name("getOrNull()")));
- (V _Nullable)getOrThrow __attribute__((swift_name("getOrThrow()")));
@end

__attribute__((swift_name("Apollo_apiFakeResolver")))
@protocol XNetworkingApollo_apiFakeResolver
@required
- (id)resolveLeafContext:(XNetworkingApollo_apiFakeResolverContext *)context __attribute__((swift_name("resolveLeaf(context:)")));
- (int32_t)resolveListSizeContext:(XNetworkingApollo_apiFakeResolverContext *)context __attribute__((swift_name("resolveListSize(context:)")));
- (BOOL)resolveMaybeNullContext:(XNetworkingApollo_apiFakeResolverContext *)context __attribute__((swift_name("resolveMaybeNull(context:)")));
- (NSString *)resolveTypenameContext:(XNetworkingApollo_apiFakeResolverContext *)context __attribute__((swift_name("resolveTypename(context:)")));
- (NSString * _Nullable)stableIdForObjectObj:(NSDictionary<NSString *, id> *)obj mergedField:(XNetworkingApollo_apiCompiledField *)mergedField __attribute__((swift_name("stableIdForObject(obj:mergedField:)")));
@end

__attribute__((swift_name("Apollo_apiCompiledType")))
@interface XNetworkingApollo_apiCompiledType : XNetworkingBase
- (XNetworkingApollo_apiCompiledNamedType *)leafType __attribute__((swift_name("leafType()"))) __attribute__((deprecated("Use rawType instead")));
- (XNetworkingApollo_apiCompiledNamedType *)rawType __attribute__((swift_name("rawType()")));
@end

__attribute__((swift_name("Apollo_apiCompiledNamedType")))
@interface XNetworkingApollo_apiCompiledNamedType : XNetworkingApollo_apiCompiledType
- (XNetworkingApollo_apiCompiledNamedType *)leafType __attribute__((swift_name("leafType()"))) __attribute__((deprecated("Use rawType instead")));
- (XNetworkingApollo_apiCompiledNamedType *)rawType __attribute__((swift_name("rawType()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiObjectType")))
@interface XNetworkingApollo_apiObjectType : XNetworkingApollo_apiCompiledNamedType
- (XNetworkingApollo_apiObjectTypeBuilder *)doNewBuilder __attribute__((swift_name("doNewBuilder()")));
@property (readonly) NSArray<NSString *> *embeddedFields __attribute__((swift_name("embeddedFields")));
@property (readonly) NSArray<XNetworkingApollo_apiInterfaceType *> *implements __attribute__((swift_name("implements")));
@property (readonly) NSArray<NSString *> *keyFields __attribute__((swift_name("keyFields")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCustomScalarType")))
@interface XNetworkingApollo_apiCustomScalarType : XNetworkingApollo_apiCompiledNamedType
- (instancetype)initWithName:(NSString *)name className:(NSString *)className __attribute__((swift_name("init(name:className:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *className __attribute__((swift_name("className")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiEnumType")))
@interface XNetworkingApollo_apiEnumType : XNetworkingApollo_apiCompiledNamedType
- (instancetype)initWithName:(NSString *)name values:(NSArray<NSString *> *)values __attribute__((swift_name("init(name:values:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSArray<NSString *> *values __attribute__((swift_name("values")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiInterfaceType")))
@interface XNetworkingApollo_apiInterfaceType : XNetworkingApollo_apiCompiledNamedType
- (XNetworkingApollo_apiInterfaceTypeBuilder *)doNewBuilder __attribute__((swift_name("doNewBuilder()")));
@property (readonly) NSArray<NSString *> *embeddedFields __attribute__((swift_name("embeddedFields")));
@property (readonly) NSArray<XNetworkingApollo_apiInterfaceType *> *implements __attribute__((swift_name("implements")));
@property (readonly) NSArray<NSString *> *keyFields __attribute__((swift_name("keyFields")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCompiledArgumentDefinition")))
@interface XNetworkingApollo_apiCompiledArgumentDefinition : XNetworkingBase
- (XNetworkingApollo_apiCompiledArgumentDefinitionBuilder *)doNewBuilder __attribute__((swift_name("doNewBuilder()")));
@property (readonly) BOOL isKey __attribute__((swift_name("isKey")));

/**
 * @note annotations
 *   com.apollographql.apollo.annotations.ApolloExperimental
*/
@property (readonly) BOOL isPagination __attribute__((swift_name("isPagination")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinCoroutineContext")))
@protocol XNetworkingKotlinCoroutineContext
@required
- (id _Nullable)foldInitial:(id _Nullable)initial operation_:(id _Nullable (^)(id _Nullable, id<XNetworkingKotlinCoroutineContextElement>))operation __attribute__((swift_name("fold(initial:operation_:)")));
- (id<XNetworkingKotlinCoroutineContextElement> _Nullable)getKey__:(id<XNetworkingKotlinCoroutineContextKey>)key __attribute__((swift_name("get(key__:)")));
- (id<XNetworkingKotlinCoroutineContext>)minusKeyKey_:(id<XNetworkingKotlinCoroutineContextKey>)key __attribute__((swift_name("minusKey(key_:)")));
- (id<XNetworkingKotlinCoroutineContext>)plusContext_:(id<XNetworkingKotlinCoroutineContext>)context __attribute__((swift_name("plus(context_:)")));
@end

__attribute__((swift_name("KotlinCoroutineContextElement")))
@protocol XNetworkingKotlinCoroutineContextElement <XNetworkingKotlinCoroutineContext>
@required
@property (readonly) id<XNetworkingKotlinCoroutineContextKey> key __attribute__((swift_name("key")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinAbstractCoroutineContextElement")))
@interface XNetworkingKotlinAbstractCoroutineContextElement : XNetworkingBase <XNetworkingKotlinCoroutineContextElement>
- (instancetype)initWithKey:(id<XNetworkingKotlinCoroutineContextKey>)key __attribute__((swift_name("init(key:)"))) __attribute__((objc_designated_initializer));
@property (readonly) id<XNetworkingKotlinCoroutineContextKey> key __attribute__((swift_name("key")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinContinuationInterceptor")))
@protocol XNetworkingKotlinContinuationInterceptor <XNetworkingKotlinCoroutineContextElement>
@required
- (id<XNetworkingKotlinContinuation>)interceptContinuationContinuation:(id<XNetworkingKotlinContinuation>)continuation __attribute__((swift_name("interceptContinuation(continuation:)")));
- (void)releaseInterceptedContinuationContinuation:(id<XNetworkingKotlinContinuation>)continuation __attribute__((swift_name("releaseInterceptedContinuation(continuation:)")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineDispatcher")))
@interface XNetworkingKotlinx_coroutines_coreCoroutineDispatcher : XNetworkingKotlinAbstractCoroutineContextElement <XNetworkingKotlinContinuationInterceptor>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithKey:(id<XNetworkingKotlinCoroutineContextKey>)key __attribute__((swift_name("init(key:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) XNetworkingKotlinx_coroutines_coreCoroutineDispatcherKey *companion __attribute__((swift_name("companion")));
- (void)dispatchContext:(id<XNetworkingKotlinCoroutineContext>)context block:(id<XNetworkingKotlinx_coroutines_coreRunnable>)block __attribute__((swift_name("dispatch(context:block:)")));
- (void)dispatchYieldContext:(id<XNetworkingKotlinCoroutineContext>)context block:(id<XNetworkingKotlinx_coroutines_coreRunnable>)block __attribute__((swift_name("dispatchYield(context:block:)")));
- (id<XNetworkingKotlinContinuation>)interceptContinuationContinuation:(id<XNetworkingKotlinContinuation>)continuation __attribute__((swift_name("interceptContinuation(continuation:)")));
- (BOOL)isDispatchNeededContext:(id<XNetworkingKotlinCoroutineContext>)context __attribute__((swift_name("isDispatchNeeded(context:)")));

/**
 * @note annotations
 *   kotlinx.coroutines.ExperimentalCoroutinesApi
*/
- (XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *)limitedParallelismParallelism:(int32_t)parallelism __attribute__((swift_name("limitedParallelism(parallelism:)")));
- (XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *)plusOther:(XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *)other __attribute__((swift_name("plus(other:)"))) __attribute__((unavailable("Operator '+' on two CoroutineDispatcher objects is meaningless. CoroutineDispatcher is a coroutine context element and `+` is a set-sum operator for coroutine contexts. The dispatcher to the right of `+` just replaces the dispatcher to the left.")));
- (void)releaseInterceptedContinuationContinuation:(id<XNetworkingKotlinContinuation>)continuation __attribute__((swift_name("releaseInterceptedContinuation(continuation:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreMainCoroutineDispatcher")))
@interface XNetworkingKotlinx_coroutines_coreMainCoroutineDispatcher : XNetworkingKotlinx_coroutines_coreCoroutineDispatcher
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *)limitedParallelismParallelism:(int32_t)parallelism __attribute__((swift_name("limitedParallelism(parallelism:)")));
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (NSString * _Nullable)toStringInternalImpl __attribute__((swift_name("toStringInternalImpl()")));
@property (readonly) XNetworkingKotlinx_coroutines_coreMainCoroutineDispatcher *immediate __attribute__((swift_name("immediate")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJsonElement.Companion")))
@interface XNetworkingKotlinx_serialization_jsonJsonElementCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingKotlinx_serialization_jsonJsonElementCompanion *shared __attribute__((swift_name("shared")));
- (id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((swift_name("RuntimeTransacterTransaction")))
@interface XNetworkingRuntimeTransacterTransaction : XNetworkingBase <XNetworkingRuntimeTransactionCallbacks>
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
@property (readonly) XNetworkingRuntimeTransacterTransaction * _Nullable enclosingTransaction __attribute__((swift_name("enclosingTransaction")));
@end

__attribute__((swift_name("RuntimeSqlPreparedStatement")))
@protocol XNetworkingRuntimeSqlPreparedStatement
@required
- (void)bindBytesIndex:(int32_t)index bytes:(XNetworkingKotlinByteArray * _Nullable)bytes __attribute__((swift_name("bindBytes(index:bytes:)")));
- (void)bindDoubleIndex:(int32_t)index double:(XNetworkingDouble * _Nullable)double_ __attribute__((swift_name("bindDouble(index:double:)")));
- (void)bindLongIndex:(int32_t)index long:(XNetworkingLong * _Nullable)long_ __attribute__((swift_name("bindLong(index:long:)")));
- (void)bindStringIndex:(int32_t)index string:(NSString * _Nullable)string __attribute__((swift_name("bindString(index:string:)")));
@end

__attribute__((swift_name("RuntimeSqlCursor")))
@protocol XNetworkingRuntimeSqlCursor <XNetworkingRuntimeCloseable>
@required
- (XNetworkingKotlinByteArray * _Nullable)getBytesIndex:(int32_t)index __attribute__((swift_name("getBytes(index:)")));
- (XNetworkingDouble * _Nullable)getDoubleIndex:(int32_t)index __attribute__((swift_name("getDouble(index:)")));
- (XNetworkingLong * _Nullable)getLongIndex:(int32_t)index __attribute__((swift_name("getLong(index:)")));
- (NSString * _Nullable)getStringIndex:(int32_t)index __attribute__((swift_name("getString(index:)")));
- (BOOL)next __attribute__((swift_name("next()")));
@end

__attribute__((swift_name("RuntimeQueryListener")))
@protocol XNetworkingRuntimeQueryListener
@required
- (void)queryResultsChanged __attribute__((swift_name("queryResultsChanged()")));
@end

__attribute__((swift_name("KotlinIterator")))
@protocol XNetworkingKotlinIterator
@required
- (BOOL)hasNext __attribute__((swift_name("hasNext_()")));
- (id _Nullable)next_ __attribute__((swift_name("next_()")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializersModule")))
@interface XNetworkingKotlinx_serialization_coreSerializersModule : XNetworkingBase

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)dumpToCollector:(id<XNetworkingKotlinx_serialization_coreSerializersModuleCollector>)collector __attribute__((swift_name("dumpTo(collector:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<XNetworkingKotlinx_serialization_coreKSerializer> _Nullable)getContextualKClass:(id<XNetworkingKotlinKClass>)kClass typeArgumentsSerializers:(NSArray<id<XNetworkingKotlinx_serialization_coreKSerializer>> *)typeArgumentsSerializers __attribute__((swift_name("getContextual(kClass:typeArgumentsSerializers:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<XNetworkingKotlinx_serialization_coreSerializationStrategy> _Nullable)getPolymorphicBaseClass:(id<XNetworkingKotlinKClass>)baseClass value:(id)value __attribute__((swift_name("getPolymorphic(baseClass:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<XNetworkingKotlinx_serialization_coreDeserializationStrategy> _Nullable)getPolymorphicBaseClass:(id<XNetworkingKotlinKClass>)baseClass serializedClassName:(NSString * _Nullable)serializedClassName __attribute__((swift_name("getPolymorphic(baseClass:serializedClassName:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJson.Default")))
@interface XNetworkingKotlinx_serialization_jsonJsonDefault : XNetworkingKotlinx_serialization_jsonJson
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)default_ __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingKotlinx_serialization_jsonJsonDefault *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJsonConfiguration")))
@interface XNetworkingKotlinx_serialization_jsonJsonConfiguration : XNetworkingBase
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
@property (readonly) id<XNetworkingKotlinx_serialization_jsonJsonNamingStrategy> _Nullable namingStrategy __attribute__((swift_name("namingStrategy")));
@property (readonly) BOOL prettyPrint __attribute__((swift_name("prettyPrint")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSString *prettyPrintIndent __attribute__((swift_name("prettyPrintIndent")));
@property (readonly) BOOL useAlternativeNames __attribute__((swift_name("useAlternativeNames")));
@property (readonly) BOOL useArrayPolymorphism __attribute__((swift_name("useArrayPolymorphism")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreEncoder")))
@protocol XNetworkingKotlinx_serialization_coreEncoder
@required
- (id<XNetworkingKotlinx_serialization_coreCompositeEncoder>)beginCollectionDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor collectionSize:(int32_t)collectionSize __attribute__((swift_name("beginCollection(descriptor:collectionSize:)")));
- (id<XNetworkingKotlinx_serialization_coreCompositeEncoder>)beginStructureDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (void)encodeBooleanValue:(BOOL)value __attribute__((swift_name("encodeBoolean(value:)")));
- (void)encodeByteValue:(int8_t)value __attribute__((swift_name("encodeByte(value:)")));
- (void)encodeCharValue:(unichar)value __attribute__((swift_name("encodeChar(value:)")));
- (void)encodeDoubleValue:(double)value __attribute__((swift_name("encodeDouble(value:)")));
- (void)encodeEnumEnumDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)enumDescriptor index:(int32_t)index __attribute__((swift_name("encodeEnum(enumDescriptor:index:)")));
- (void)encodeFloatValue:(float)value __attribute__((swift_name("encodeFloat(value:)")));
- (id<XNetworkingKotlinx_serialization_coreEncoder>)encodeInlineDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("encodeInline(descriptor:)")));
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
- (void)encodeNullableSerializableValueSerializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableValue(serializer:value:)")));
- (void)encodeSerializableValueSerializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableValue(serializer:value:)")));
- (void)encodeShortValue:(int16_t)value __attribute__((swift_name("encodeShort(value:)")));
- (void)encodeStringValue:(NSString *)value __attribute__((swift_name("encodeString(value:)")));
@property (readonly) XNetworkingKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialDescriptor")))
@protocol XNetworkingKotlinx_serialization_coreSerialDescriptor
@required

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (NSArray<id<XNetworkingKotlinAnnotation>> *)getElementAnnotationsIndex:(int32_t)index __attribute__((swift_name("getElementAnnotations(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)getElementDescriptorIndex:(int32_t)index __attribute__((swift_name("getElementDescriptor(index:)")));

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
@property (readonly) NSArray<id<XNetworkingKotlinAnnotation>> *annotations __attribute__((swift_name("annotations")));

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
@property (readonly) XNetworkingKotlinx_serialization_coreSerialKind *kind __attribute__((swift_name("kind")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSString *serialName __attribute__((swift_name("serialName")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDecoder")))
@protocol XNetworkingKotlinx_serialization_coreDecoder
@required
- (id<XNetworkingKotlinx_serialization_coreCompositeDecoder>)beginStructureDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (BOOL)decodeBoolean __attribute__((swift_name("decodeBoolean()")));
- (int8_t)decodeByte __attribute__((swift_name("decodeByte()")));
- (unichar)decodeChar __attribute__((swift_name("decodeChar()")));
- (double)decodeDouble __attribute__((swift_name("decodeDouble()")));
- (int32_t)decodeEnumEnumDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)enumDescriptor __attribute__((swift_name("decodeEnum(enumDescriptor:)")));
- (float)decodeFloat __attribute__((swift_name("decodeFloat()")));
- (id<XNetworkingKotlinx_serialization_coreDecoder>)decodeInlineDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeInline(descriptor:)")));
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
- (XNetworkingKotlinNothing * _Nullable)decodeNull __attribute__((swift_name("decodeNull()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableValueDeserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeNullableSerializableValue(deserializer:)")));
- (id _Nullable)decodeSerializableValueDeserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeSerializableValue(deserializer:)")));
- (int16_t)decodeShort __attribute__((swift_name("decodeShort()")));
- (NSString *)decodeString __attribute__((swift_name("decodeString()")));
@property (readonly) XNetworkingKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinNothing")))
@interface XNetworkingKotlinNothing : XNetworkingBase
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiJsonNumber")))
@interface XNetworkingApollo_apiJsonNumber : XNetworkingBase
- (instancetype)initWithValue:(NSString *)value __attribute__((swift_name("init(value:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiJsonReaderToken")))
@interface XNetworkingApollo_apiJsonReaderToken : XNetworkingKotlinEnum<XNetworkingApollo_apiJsonReaderToken *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *beginArray __attribute__((swift_name("beginArray")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *endArray __attribute__((swift_name("endArray")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *beginObject __attribute__((swift_name("beginObject")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *endObject __attribute__((swift_name("endObject")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *name __attribute__((swift_name("name")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *string __attribute__((swift_name("string")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *number __attribute__((swift_name("number")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *long_ __attribute__((swift_name("long_")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *boolean __attribute__((swift_name("boolean")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *null __attribute__((swift_name("null")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *endDocument __attribute__((swift_name("endDocument")));
@property (class, readonly) XNetworkingApollo_apiJsonReaderToken *any __attribute__((swift_name("any")));
+ (XNetworkingKotlinArray<XNetworkingApollo_apiJsonReaderToken *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<XNetworkingApollo_apiJsonReaderToken *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((swift_name("Apollo_apiExecutionContextKey")))
@protocol XNetworkingApollo_apiExecutionContextKey
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCustomScalarAdapters.Key")))
@interface XNetworkingApollo_apiCustomScalarAdaptersKey : XNetworkingBase <XNetworkingApollo_apiExecutionContextKey>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)key __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingApollo_apiCustomScalarAdaptersKey *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingApollo_apiCustomScalarAdapters *Empty __attribute__((swift_name("Empty")));

/**
 * @note annotations
 *   com.apollographql.apollo.annotations.ApolloExperimental
*/
@property (readonly) XNetworkingApollo_apiCustomScalarAdapters *PassThrough __attribute__((swift_name("PassThrough")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiError")))
@interface XNetworkingApollo_apiError : XNetworkingBase
- (instancetype)initWithMessage:(NSString *)message locations:(NSArray<XNetworkingApollo_apiErrorLocation *> * _Nullable)locations path:(NSArray<id> * _Nullable)path extensions:(NSDictionary<NSString *, id> * _Nullable)extensions nonStandardFields:(NSDictionary<NSString *, id> * _Nullable)nonStandardFields __attribute__((swift_name("init(message:locations:path:extensions:nonStandardFields:)"))) __attribute__((objc_designated_initializer)) __attribute__((deprecated("Use Error.Builder instead")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSDictionary<NSString *, id> * _Nullable extensions __attribute__((swift_name("extensions")));
@property (readonly) NSArray<XNetworkingApollo_apiErrorLocation *> * _Nullable locations __attribute__((swift_name("locations")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@property (readonly) NSDictionary<NSString *, id> * _Nullable nonStandardFields __attribute__((swift_name("nonStandardFields")));
@property (readonly) NSArray<id> * _Nullable path __attribute__((swift_name("path")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCustomScalarAdapters.Builder")))
@interface XNetworkingApollo_apiCustomScalarAdaptersBuilder : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)addCustomScalarType:(XNetworkingApollo_apiCustomScalarType *)customScalarType customScalarAdapter:(id<XNetworkingApollo_apiAdapter>)customScalarAdapter __attribute__((swift_name("add(customScalarType:customScalarAdapter:)")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)addName:(NSString *)name adapter:(id<XNetworkingApollo_apiAdapter>)adapter __attribute__((swift_name("add(name:adapter:)")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)addAllCustomScalarAdapters:(XNetworkingApollo_apiCustomScalarAdapters *)customScalarAdapters __attribute__((swift_name("addAll(customScalarAdapters:)")));
- (XNetworkingApollo_apiCustomScalarAdapters *)build __attribute__((swift_name("build()")));
- (void)clear __attribute__((swift_name("clear()")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)deferredFragmentIdentifiersDeferredFragmentIdentifiers:(NSSet<XNetworkingApollo_apiDeferredFragmentIdentifier *> * _Nullable)deferredFragmentIdentifiers __attribute__((swift_name("deferredFragmentIdentifiers(deferredFragmentIdentifiers:)")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)errorsErrors:(NSArray<XNetworkingApollo_apiError *> * _Nullable)errors __attribute__((swift_name("errors(errors:)")));
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)falseVariablesFalseVariables:(NSSet<NSString *> * _Nullable)falseVariables __attribute__((swift_name("falseVariables(falseVariables:)")));

/**
 * @note annotations
 *   com.apollographql.apollo.annotations.ApolloExperimental
*/
- (XNetworkingApollo_apiCustomScalarAdaptersBuilder *)unsafeUnsafe:(BOOL)unsafe __attribute__((swift_name("unsafe(unsafe:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiDeferredFragmentIdentifier")))
@interface XNetworkingApollo_apiDeferredFragmentIdentifier : XNetworkingBase
- (instancetype)initWithPath:(NSArray<id> *)path label:(NSString * _Nullable)label __attribute__((swift_name("init(path:label:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiDeferredFragmentIdentifier *)doCopyPath:(NSArray<id> *)path label:(NSString * _Nullable)label __attribute__((swift_name("doCopy(path:label:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable label __attribute__((swift_name("label")));
@property (readonly) NSArray<id> *path __attribute__((swift_name("path")));
@end

__attribute__((swift_name("Apollo_apiUpload")))
@protocol XNetworkingApollo_apiUpload
@required
- (void)writeToSink:(id<XNetworkingOkioBufferedSink>)sink __attribute__((swift_name("writeTo(sink:)")));
@property (readonly) int64_t contentLength __attribute__((swift_name("contentLength")));
@property (readonly) NSString *contentType __attribute__((swift_name("contentType")));
@property (readonly) NSString * _Nullable fileName __attribute__((swift_name("fileName")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlowCollector")))
@protocol XNetworkingKotlinx_coroutines_coreFlowCollector
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitValue:(id _Nullable)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("emit(value:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiExecutableVariables")))
@interface XNetworkingApollo_apiExecutableVariables : XNetworkingBase
- (instancetype)initWithValueMap:(NSDictionary<NSString *, id> *)valueMap __attribute__((swift_name("init(valueMap:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSDictionary<NSString *, id> *valueMap __attribute__((swift_name("valueMap")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCompiledArgument")))
@interface XNetworkingApollo_apiCompiledArgument : XNetworkingBase
@property (readonly) XNetworkingApollo_apiCompiledArgumentDefinition *definition __attribute__((swift_name("definition")));
@property (readonly) BOOL isKey __attribute__((swift_name("isKey"))) __attribute__((deprecated("Use definition.isKey instead")));
@property (readonly) NSString *name __attribute__((swift_name("name"))) __attribute__((deprecated("Use definition.name instead")));
@property (readonly) XNetworkingApollo_apiOptional<id> *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCompiledField.Builder")))
@interface XNetworkingApollo_apiCompiledFieldBuilder : XNetworkingBase
- (instancetype)initWithCompiledField:(XNetworkingApollo_apiCompiledField *)compiledField __attribute__((swift_name("init(compiledField:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithName:(NSString *)name type:(XNetworkingApollo_apiCompiledType *)type __attribute__((swift_name("init(name:type:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiCompiledFieldBuilder *)aliasAlias:(NSString * _Nullable)alias __attribute__((swift_name("alias(alias:)")));
- (XNetworkingApollo_apiCompiledFieldBuilder *)argumentsArguments:(NSArray<XNetworkingApollo_apiCompiledArgument *> *)arguments __attribute__((swift_name("arguments(arguments:)")));
- (XNetworkingApollo_apiCompiledField *)build __attribute__((swift_name("build()")));
- (XNetworkingApollo_apiCompiledFieldBuilder *)conditionCondition:(NSArray<XNetworkingApollo_apiCompiledCondition *> *)condition __attribute__((swift_name("condition(condition:)")));
- (XNetworkingApollo_apiCompiledFieldBuilder *)selectionsSelections:(NSArray<XNetworkingApollo_apiCompiledSelection *> *)selections __attribute__((swift_name("selections(selections:)")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) XNetworkingApollo_apiCompiledType *type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCompiledCondition")))
@interface XNetworkingApollo_apiCompiledCondition : XNetworkingBase
- (instancetype)initWithName:(NSString *)name inverted:(BOOL)inverted __attribute__((swift_name("init(name:inverted:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiCompiledCondition *)doCopyName:(NSString *)name inverted:(BOOL)inverted __attribute__((swift_name("doCopy(name:inverted:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL inverted __attribute__((swift_name("inverted")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiOptionalCompanion")))
@interface XNetworkingApollo_apiOptionalCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingApollo_apiOptionalCompanion *shared __attribute__((swift_name("shared")));

/**
 * @note annotations
 *   kotlin.jvm.JvmStatic
*/
- (XNetworkingApollo_apiOptionalAbsent *)absent __attribute__((swift_name("absent()")));

/**
 * @note annotations
 *   kotlin.jvm.JvmStatic
*/
- (XNetworkingApollo_apiOptionalPresent<id> *)presentValue:(id _Nullable)value __attribute__((swift_name("present(value:)")));

/**
 * @note annotations
 *   kotlin.jvm.JvmStatic
*/
- (XNetworkingApollo_apiOptional<id> *)presentIfNotNullValue:(id _Nullable)value __attribute__((swift_name("presentIfNotNull(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiFakeResolverContext")))
@interface XNetworkingApollo_apiFakeResolverContext : XNetworkingBase
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) XNetworkingApollo_apiCompiledField *mergedField __attribute__((swift_name("mergedField")));
@property (readonly) NSArray<id> *path __attribute__((swift_name("path")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiObjectType.Builder")))
@interface XNetworkingApollo_apiObjectTypeBuilder : XNetworkingBase
- (instancetype)initWithObjectType:(XNetworkingApollo_apiObjectType *)objectType __attribute__((swift_name("init(objectType:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiObjectType *)build __attribute__((swift_name("build()")));
- (XNetworkingApollo_apiObjectTypeBuilder *)embeddedFieldsEmbeddedFields:(NSArray<NSString *> *)embeddedFields __attribute__((swift_name("embeddedFields(embeddedFields:)")));
- (XNetworkingApollo_apiObjectTypeBuilder *)interfacesImplements:(NSArray<XNetworkingApollo_apiInterfaceType *> *)implements __attribute__((swift_name("interfaces(implements:)")));
- (XNetworkingApollo_apiObjectTypeBuilder *)keyFieldsKeyFields:(NSArray<NSString *> *)keyFields __attribute__((swift_name("keyFields(keyFields:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiInterfaceType.Builder")))
@interface XNetworkingApollo_apiInterfaceTypeBuilder : XNetworkingBase
- (instancetype)initWithInterfaceType:(XNetworkingApollo_apiInterfaceType *)interfaceType __attribute__((swift_name("init(interfaceType:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiInterfaceType *)build __attribute__((swift_name("build()")));
- (XNetworkingApollo_apiInterfaceTypeBuilder *)embeddedFieldsEmbeddedFields:(NSArray<NSString *> *)embeddedFields __attribute__((swift_name("embeddedFields(embeddedFields:)")));
- (XNetworkingApollo_apiInterfaceTypeBuilder *)interfacesImplements:(NSArray<XNetworkingApollo_apiInterfaceType *> *)implements __attribute__((swift_name("interfaces(implements:)")));
- (XNetworkingApollo_apiInterfaceTypeBuilder *)keyFieldsKeyFields:(NSArray<NSString *> *)keyFields __attribute__((swift_name("keyFields(keyFields:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiCompiledArgumentDefinition.Builder")))
@interface XNetworkingApollo_apiCompiledArgumentDefinitionBuilder : XNetworkingBase
- (instancetype)initWithArgumentDefinition:(XNetworkingApollo_apiCompiledArgumentDefinition *)argumentDefinition __attribute__((swift_name("init(argumentDefinition:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiCompiledArgumentDefinition *)build __attribute__((swift_name("build()")));
- (XNetworkingApollo_apiCompiledArgumentDefinitionBuilder *)isKeyIsKey:(BOOL)isKey __attribute__((swift_name("isKey(isKey:)")));

/**
 * @note annotations
 *   com.apollographql.apollo.annotations.ApolloExperimental
*/
- (XNetworkingApollo_apiCompiledArgumentDefinitionBuilder *)isPaginationIsPagination:(BOOL)isPagination __attribute__((swift_name("isPagination(isPagination:)")));
@end

__attribute__((swift_name("KotlinCoroutineContextKey")))
@protocol XNetworkingKotlinCoroutineContextKey
@required
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinContinuation")))
@protocol XNetworkingKotlinContinuation
@required
- (void)resumeWithResult:(id _Nullable)result __attribute__((swift_name("resumeWith(result:)")));
@property (readonly) id<XNetworkingKotlinCoroutineContext> context __attribute__((swift_name("context")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
 *   kotlin.ExperimentalStdlibApi
*/
__attribute__((swift_name("KotlinAbstractCoroutineContextKey")))
@interface XNetworkingKotlinAbstractCoroutineContextKey<B, E> : XNetworkingBase <XNetworkingKotlinCoroutineContextKey>
- (instancetype)initWithBaseKey:(id<XNetworkingKotlinCoroutineContextKey>)baseKey safeCast:(E _Nullable (^)(id<XNetworkingKotlinCoroutineContextElement>))safeCast __attribute__((swift_name("init(baseKey:safeCast:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.ExperimentalStdlibApi
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineDispatcher.Key")))
@interface XNetworkingKotlinx_coroutines_coreCoroutineDispatcherKey : XNetworkingKotlinAbstractCoroutineContextKey<id<XNetworkingKotlinContinuationInterceptor>, XNetworkingKotlinx_coroutines_coreCoroutineDispatcher *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithBaseKey:(id<XNetworkingKotlinCoroutineContextKey>)baseKey safeCast:(id<XNetworkingKotlinCoroutineContextElement> _Nullable (^)(id<XNetworkingKotlinCoroutineContextElement>))safeCast __attribute__((swift_name("init(baseKey:safeCast:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)key __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingKotlinx_coroutines_coreCoroutineDispatcherKey *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreRunnable")))
@protocol XNetworkingKotlinx_coroutines_coreRunnable
@required
- (void)run __attribute__((swift_name("run()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinByteArray")))
@interface XNetworkingKotlinByteArray : XNetworkingBase
+ (instancetype)arrayWithSize:(int32_t)size __attribute__((swift_name("init(size:)")));
+ (instancetype)arrayWithSize:(int32_t)size init:(XNetworkingByte *(^)(XNetworkingInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (int8_t)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (XNetworkingKotlinByteIterator *)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(int8_t)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerializersModuleCollector")))
@protocol XNetworkingKotlinx_serialization_coreSerializersModuleCollector
@required
- (void)contextualKClass:(id<XNetworkingKotlinKClass>)kClass provider:(id<XNetworkingKotlinx_serialization_coreKSerializer> (^)(NSArray<id<XNetworkingKotlinx_serialization_coreKSerializer>> *))provider __attribute__((swift_name("contextual(kClass:provider:)")));
- (void)contextualKClass:(id<XNetworkingKotlinKClass>)kClass serializer:(id<XNetworkingKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("contextual(kClass:serializer:)")));
- (void)polymorphicBaseClass:(id<XNetworkingKotlinKClass>)baseClass actualClass:(id<XNetworkingKotlinKClass>)actualClass actualSerializer:(id<XNetworkingKotlinx_serialization_coreKSerializer>)actualSerializer __attribute__((swift_name("polymorphic(baseClass:actualClass:actualSerializer:)")));
- (void)polymorphicDefaultBaseClass:(id<XNetworkingKotlinKClass>)baseClass defaultDeserializerProvider:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefault(baseClass:defaultDeserializerProvider:)"))) __attribute__((deprecated("Deprecated in favor of function with more precise name: polymorphicDefaultDeserializer")));
- (void)polymorphicDefaultDeserializerBaseClass:(id<XNetworkingKotlinKClass>)baseClass defaultDeserializerProvider:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefaultDeserializer(baseClass:defaultDeserializerProvider:)")));
- (void)polymorphicDefaultSerializerBaseClass:(id<XNetworkingKotlinKClass>)baseClass defaultSerializerProvider:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy> _Nullable (^)(id))defaultSerializerProvider __attribute__((swift_name("polymorphicDefaultSerializer(baseClass:defaultSerializerProvider:)")));
@end

__attribute__((swift_name("KotlinKDeclarationContainer")))
@protocol XNetworkingKotlinKDeclarationContainer
@required
@end

__attribute__((swift_name("KotlinKAnnotatedElement")))
@protocol XNetworkingKotlinKAnnotatedElement
@required
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((swift_name("KotlinKClassifier")))
@protocol XNetworkingKotlinKClassifier
@required
@end

__attribute__((swift_name("KotlinKClass")))
@protocol XNetworkingKotlinKClass <XNetworkingKotlinKDeclarationContainer, XNetworkingKotlinKAnnotatedElement, XNetworkingKotlinKClassifier>
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
@protocol XNetworkingKotlinx_serialization_jsonJsonNamingStrategy
@required
- (NSString *)serialNameForJsonDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor elementIndex:(int32_t)elementIndex serialName:(NSString *)serialName __attribute__((swift_name("serialNameForJson(descriptor:elementIndex:serialName:)")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeEncoder")))
@protocol XNetworkingKotlinx_serialization_coreCompositeEncoder
@required
- (void)encodeBooleanElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(BOOL)value __attribute__((swift_name("encodeBooleanElement(descriptor:index:value:)")));
- (void)encodeByteElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int8_t)value __attribute__((swift_name("encodeByteElement(descriptor:index:value:)")));
- (void)encodeCharElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(unichar)value __attribute__((swift_name("encodeCharElement(descriptor:index:value:)")));
- (void)encodeDoubleElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(double)value __attribute__((swift_name("encodeDoubleElement(descriptor:index:value:)")));
- (void)encodeFloatElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(float)value __attribute__((swift_name("encodeFloatElement(descriptor:index:value:)")));
- (id<XNetworkingKotlinx_serialization_coreEncoder>)encodeInlineElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("encodeInlineElement(descriptor:index:)")));
- (void)encodeIntElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int32_t)value __attribute__((swift_name("encodeIntElement(descriptor:index:value:)")));
- (void)encodeLongElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int64_t)value __attribute__((swift_name("encodeLongElement(descriptor:index:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeSerializableElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<XNetworkingKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeShortElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int16_t)value __attribute__((swift_name("encodeShortElement(descriptor:index:value:)")));
- (void)encodeStringElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(NSString *)value __attribute__((swift_name("encodeStringElement(descriptor:index:value:)")));
- (void)endStructureDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)shouldEncodeElementDefaultDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("shouldEncodeElementDefault(descriptor:index:)")));
@property (readonly) XNetworkingKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("KotlinAnnotation")))
@protocol XNetworkingKotlinAnnotation
@required
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerialKind")))
@interface XNetworkingKotlinx_serialization_coreSerialKind : XNetworkingBase
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeDecoder")))
@protocol XNetworkingKotlinx_serialization_coreCompositeDecoder
@required
- (BOOL)decodeBooleanElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeBooleanElement(descriptor:index:)")));
- (int8_t)decodeByteElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeByteElement(descriptor:index:)")));
- (unichar)decodeCharElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeCharElement(descriptor:index:)")));
- (int32_t)decodeCollectionSizeDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeCollectionSize(descriptor:)")));
- (double)decodeDoubleElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeDoubleElement(descriptor:index:)")));
- (int32_t)decodeElementIndexDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeElementIndex(descriptor:)")));
- (float)decodeFloatElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeFloatElement(descriptor:index:)")));
- (id<XNetworkingKotlinx_serialization_coreDecoder>)decodeInlineElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeInlineElement(descriptor:index:)")));
- (int32_t)decodeIntElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeIntElement(descriptor:index:)")));
- (int64_t)decodeLongElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeLongElement(descriptor:index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeNullableSerializableElement(descriptor:index:deserializer:previousValue:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeSequentially __attribute__((swift_name("decodeSequentially()")));
- (id _Nullable)decodeSerializableElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<XNetworkingKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeSerializableElement(descriptor:index:deserializer:previousValue:)")));
- (int16_t)decodeShortElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeShortElement(descriptor:index:)")));
- (NSString *)decodeStringElementDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeStringElement(descriptor:index:)")));
- (void)endStructureDescriptor:(id<XNetworkingKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));
@property (readonly) XNetworkingKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiError.Location")))
@interface XNetworkingApollo_apiErrorLocation : XNetworkingBase
- (instancetype)initWithLine:(int32_t)line column:(int32_t)column __attribute__((swift_name("init(line:column:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t column __attribute__((swift_name("column")));
@property (readonly) int32_t line __attribute__((swift_name("line")));
@end

__attribute__((swift_name("OkioSink")))
@protocol XNetworkingOkioSink <XNetworkingOkioCloseable>
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)flushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("flush()")));
- (XNetworkingOkioTimeout *)timeout __attribute__((swift_name("timeout()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)writeSource:(XNetworkingOkioBuffer *)source byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("write(source:byteCount_:)")));
@end

__attribute__((swift_name("OkioBufferedSink")))
@protocol XNetworkingOkioBufferedSink <XNetworkingOkioSink>
@required
- (id<XNetworkingOkioBufferedSink>)emit __attribute__((swift_name("emit()")));
- (id<XNetworkingOkioBufferedSink>)emitCompleteSegments __attribute__((swift_name("emitCompleteSegments()")));
- (id<XNetworkingOkioBufferedSink>)writeSource:(XNetworkingKotlinByteArray *)source __attribute__((swift_name("write(source:)")));
- (id<XNetworkingOkioBufferedSink>)writeByteString:(XNetworkingOkioByteString *)byteString __attribute__((swift_name("write(byteString:)")));
- (id<XNetworkingOkioBufferedSink>)writeSource:(id<XNetworkingOkioSource>)source byteCount:(int64_t)byteCount __attribute__((swift_name("write(source:byteCount:)")));
- (id<XNetworkingOkioBufferedSink>)writeSource:(XNetworkingKotlinByteArray *)source offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(source:offset:byteCount:)")));
- (id<XNetworkingOkioBufferedSink>)writeByteString:(XNetworkingOkioByteString *)byteString offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(byteString:offset:byteCount:)")));
- (int64_t)writeAllSource:(id<XNetworkingOkioSource>)source __attribute__((swift_name("writeAll(source:)")));
- (id<XNetworkingOkioBufferedSink>)writeByteB:(int32_t)b __attribute__((swift_name("writeByte(b:)")));
- (id<XNetworkingOkioBufferedSink>)writeDecimalLongV:(int64_t)v __attribute__((swift_name("writeDecimalLong(v:)")));
- (id<XNetworkingOkioBufferedSink>)writeHexadecimalUnsignedLongV:(int64_t)v __attribute__((swift_name("writeHexadecimalUnsignedLong(v:)")));
- (id<XNetworkingOkioBufferedSink>)writeIntI:(int32_t)i __attribute__((swift_name("writeInt(i:)")));
- (id<XNetworkingOkioBufferedSink>)writeIntLeI:(int32_t)i __attribute__((swift_name("writeIntLe(i:)")));
- (id<XNetworkingOkioBufferedSink>)writeLongV:(int64_t)v __attribute__((swift_name("writeLong(v:)")));
- (id<XNetworkingOkioBufferedSink>)writeLongLeV:(int64_t)v __attribute__((swift_name("writeLongLe(v:)")));
- (id<XNetworkingOkioBufferedSink>)writeShortS:(int32_t)s __attribute__((swift_name("writeShort(s:)")));
- (id<XNetworkingOkioBufferedSink>)writeShortLeS:(int32_t)s __attribute__((swift_name("writeShortLe(s:)")));
- (id<XNetworkingOkioBufferedSink>)writeUtf8String:(NSString *)string __attribute__((swift_name("writeUtf8(string:)")));
- (id<XNetworkingOkioBufferedSink>)writeUtf8String:(NSString *)string beginIndex:(int32_t)beginIndex endIndex:(int32_t)endIndex __attribute__((swift_name("writeUtf8(string:beginIndex:endIndex:)")));
- (id<XNetworkingOkioBufferedSink>)writeUtf8CodePointCodePoint:(int32_t)codePoint __attribute__((swift_name("writeUtf8CodePoint(codePoint:)")));
@property (readonly) XNetworkingOkioBuffer *buffer __attribute__((swift_name("buffer")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiOptionalAbsent")))
@interface XNetworkingApollo_apiOptionalAbsent : XNetworkingApollo_apiOptional<XNetworkingKotlinNothing *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)absent __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingApollo_apiOptionalAbsent *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Apollo_apiOptionalPresent")))
@interface XNetworkingApollo_apiOptionalPresent<V> : XNetworkingApollo_apiOptional<V>
- (instancetype)initWithValue:(V _Nullable)value __attribute__((swift_name("init(value:)"))) __attribute__((objc_designated_initializer));
- (XNetworkingApollo_apiOptionalPresent<V> *)doCopyValue:(V _Nullable)value __attribute__((swift_name("doCopy(value:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) V _Nullable value __attribute__((swift_name("value")));
@end

__attribute__((swift_name("KotlinByteIterator")))
@interface XNetworkingKotlinByteIterator : XNetworkingBase <XNetworkingKotlinIterator>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (XNetworkingByte *)next_ __attribute__((swift_name("next_()")));
- (int8_t)nextByte __attribute__((swift_name("nextByte()")));
@end

__attribute__((swift_name("OkioByteString")))
@interface XNetworkingOkioByteString : XNetworkingBase <XNetworkingKotlinComparable>
@property (class, readonly, getter=companion) XNetworkingOkioByteStringCompanion *companion __attribute__((swift_name("companion")));
- (NSString *)base64 __attribute__((swift_name("base64()")));
- (NSString *)base64Url __attribute__((swift_name("base64Url()")));
- (int32_t)compareToOther:(XNetworkingOkioByteString *)other __attribute__((swift_name("compareTo(other:)")));
- (void)doCopyIntoOffset:(int32_t)offset target:(XNetworkingKotlinByteArray *)target targetOffset:(int32_t)targetOffset byteCount:(int32_t)byteCount __attribute__((swift_name("doCopyInto(offset:target:targetOffset:byteCount:)")));
- (BOOL)endsWithSuffix:(XNetworkingKotlinByteArray *)suffix __attribute__((swift_name("endsWith(suffix:)")));
- (BOOL)endsWithSuffix_:(XNetworkingOkioByteString *)suffix __attribute__((swift_name("endsWith(suffix_:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (int8_t)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)hex __attribute__((swift_name("hex()")));
- (XNetworkingOkioByteString *)hmacSha1Key:(XNetworkingOkioByteString *)key __attribute__((swift_name("hmacSha1(key:)")));
- (XNetworkingOkioByteString *)hmacSha256Key:(XNetworkingOkioByteString *)key __attribute__((swift_name("hmacSha256(key:)")));
- (XNetworkingOkioByteString *)hmacSha512Key:(XNetworkingOkioByteString *)key __attribute__((swift_name("hmacSha512(key:)")));
- (int32_t)indexOfOther:(XNetworkingKotlinByteArray *)other fromIndex:(int32_t)fromIndex __attribute__((swift_name("indexOf(other:fromIndex:)")));
- (int32_t)indexOfOther:(XNetworkingOkioByteString *)other fromIndex_:(int32_t)fromIndex __attribute__((swift_name("indexOf(other:fromIndex_:)")));
- (int32_t)lastIndexOfOther:(XNetworkingKotlinByteArray *)other fromIndex:(int32_t)fromIndex __attribute__((swift_name("lastIndexOf(other:fromIndex:)")));
- (int32_t)lastIndexOfOther:(XNetworkingOkioByteString *)other fromIndex_:(int32_t)fromIndex __attribute__((swift_name("lastIndexOf(other:fromIndex_:)")));
- (XNetworkingOkioByteString *)md5 __attribute__((swift_name("md5()")));
- (BOOL)rangeEqualsOffset:(int32_t)offset other:(XNetworkingKotlinByteArray *)other otherOffset:(int32_t)otherOffset byteCount:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:other:otherOffset:byteCount:)")));
- (BOOL)rangeEqualsOffset:(int32_t)offset other:(XNetworkingOkioByteString *)other otherOffset:(int32_t)otherOffset byteCount_:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:other:otherOffset:byteCount_:)")));
- (XNetworkingOkioByteString *)sha1 __attribute__((swift_name("sha1()")));
- (XNetworkingOkioByteString *)sha256 __attribute__((swift_name("sha256()")));
- (XNetworkingOkioByteString *)sha512 __attribute__((swift_name("sha512()")));
- (BOOL)startsWithPrefix:(XNetworkingKotlinByteArray *)prefix __attribute__((swift_name("startsWith(prefix:)")));
- (BOOL)startsWithPrefix_:(XNetworkingOkioByteString *)prefix __attribute__((swift_name("startsWith(prefix_:)")));
- (XNetworkingOkioByteString *)substringBeginIndex:(int32_t)beginIndex endIndex:(int32_t)endIndex __attribute__((swift_name("substring(beginIndex:endIndex:)")));
- (XNetworkingOkioByteString *)toAsciiLowercase __attribute__((swift_name("toAsciiLowercase()")));
- (XNetworkingOkioByteString *)toAsciiUppercase __attribute__((swift_name("toAsciiUppercase()")));
- (XNetworkingKotlinByteArray *)toByteArray __attribute__((swift_name("toByteArray()")));
- (NSString *)description __attribute__((swift_name("description()")));
- (NSString *)utf8 __attribute__((swift_name("utf8()")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("OkioSource")))
@protocol XNetworkingOkioSource <XNetworkingOkioCloseable>
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)readSink:(XNetworkingOkioBuffer *)sink byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("read(sink:byteCount:)"))) __attribute__((swift_error(nonnull_error)));
- (XNetworkingOkioTimeout *)timeout __attribute__((swift_name("timeout()")));
@end

__attribute__((swift_name("OkioBufferedSource")))
@protocol XNetworkingOkioBufferedSource <XNetworkingOkioSource>
@required
- (BOOL)exhausted __attribute__((swift_name("exhausted()")));
- (int64_t)indexOfB:(int8_t)b __attribute__((swift_name("indexOf(b:)")));
- (int64_t)indexOfBytes:(XNetworkingOkioByteString *)bytes __attribute__((swift_name("indexOf(bytes:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(b:fromIndex:)")));
- (int64_t)indexOfBytes:(XNetworkingOkioByteString *)bytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(bytes:fromIndex:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex toIndex:(int64_t)toIndex __attribute__((swift_name("indexOf(b:fromIndex:toIndex:)")));
- (int64_t)indexOfElementTargetBytes:(XNetworkingOkioByteString *)targetBytes __attribute__((swift_name("indexOfElement(targetBytes:)")));
- (int64_t)indexOfElementTargetBytes:(XNetworkingOkioByteString *)targetBytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOfElement(targetBytes:fromIndex:)")));
- (id<XNetworkingOkioBufferedSource>)peek __attribute__((swift_name("peek_()")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(XNetworkingOkioByteString *)bytes __attribute__((swift_name("rangeEquals(offset:bytes:)")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(XNetworkingOkioByteString *)bytes bytesOffset:(int32_t)bytesOffset byteCount:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:bytes:bytesOffset:byteCount:)")));
- (int32_t)readSink:(XNetworkingKotlinByteArray *)sink __attribute__((swift_name("read(sink:)")));
- (int32_t)readSink:(XNetworkingKotlinByteArray *)sink offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("read(sink:offset:byteCount:)")));
- (int64_t)readAllSink:(id<XNetworkingOkioSink>)sink __attribute__((swift_name("readAll(sink:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (XNetworkingKotlinByteArray *)readByteArray __attribute__((swift_name("readByteArray()")));
- (XNetworkingKotlinByteArray *)readByteArrayByteCount:(int64_t)byteCount __attribute__((swift_name("readByteArray(byteCount:)")));
- (XNetworkingOkioByteString *)readByteString __attribute__((swift_name("readByteString()")));
- (XNetworkingOkioByteString *)readByteStringByteCount:(int64_t)byteCount __attribute__((swift_name("readByteString(byteCount:)")));
- (int64_t)readDecimalLong __attribute__((swift_name("readDecimalLong()")));
- (void)readFullySink:(XNetworkingKotlinByteArray *)sink __attribute__((swift_name("readFully(sink:)")));
- (void)readFullySink:(XNetworkingOkioBuffer *)sink byteCount:(int64_t)byteCount __attribute__((swift_name("readFully(sink:byteCount:)")));
- (int64_t)readHexadecimalUnsignedLong __attribute__((swift_name("readHexadecimalUnsignedLong()")));
- (int32_t)readInt __attribute__((swift_name("readInt()")));
- (int32_t)readIntLe __attribute__((swift_name("readIntLe()")));
- (int64_t)readLong __attribute__((swift_name("readLong()")));
- (int64_t)readLongLe __attribute__((swift_name("readLongLe()")));
- (int16_t)readShort __attribute__((swift_name("readShort()")));
- (int16_t)readShortLe __attribute__((swift_name("readShortLe()")));
- (NSString *)readUtf8 __attribute__((swift_name("readUtf8()")));
- (NSString *)readUtf8ByteCount:(int64_t)byteCount __attribute__((swift_name("readUtf8(byteCount:)")));
- (int32_t)readUtf8CodePoint __attribute__((swift_name("readUtf8CodePoint()")));
- (NSString * _Nullable)readUtf8Line __attribute__((swift_name("readUtf8Line()")));
- (NSString *)readUtf8LineStrict __attribute__((swift_name("readUtf8LineStrict()")));
- (NSString *)readUtf8LineStrictLimit:(int64_t)limit __attribute__((swift_name("readUtf8LineStrict(limit:)")));
- (BOOL)requestByteCount:(int64_t)byteCount __attribute__((swift_name("request(byteCount:)")));
- (void)requireByteCount:(int64_t)byteCount __attribute__((swift_name("require(byteCount:)")));
- (int32_t)selectOptions:(NSArray<XNetworkingOkioByteString *> *)options __attribute__((swift_name("select(options:)")));
- (id _Nullable)selectOptions_:(NSArray<id> *)options __attribute__((swift_name("select(options_:)")));
- (void)skipByteCount:(int64_t)byteCount __attribute__((swift_name("skip(byteCount:)")));
@property (readonly) XNetworkingOkioBuffer *buffer __attribute__((swift_name("buffer")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioBuffer")))
@interface XNetworkingOkioBuffer : XNetworkingBase <XNetworkingOkioBufferedSource, XNetworkingOkioBufferedSink>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)clear __attribute__((swift_name("clear()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));
- (int64_t)completeSegmentByteCount __attribute__((swift_name("completeSegmentByteCount()")));
- (XNetworkingOkioBuffer *)doCopy __attribute__((swift_name("doCopy()")));
- (XNetworkingOkioBuffer *)doCopyToOut:(XNetworkingOkioBuffer *)out offset:(int64_t)offset __attribute__((swift_name("doCopyTo(out:offset:)")));
- (XNetworkingOkioBuffer *)doCopyToOut:(XNetworkingOkioBuffer *)out offset:(int64_t)offset byteCount:(int64_t)byteCount __attribute__((swift_name("doCopyTo(out:offset:byteCount:)")));
- (XNetworkingOkioBuffer *)emit __attribute__((swift_name("emit()")));
- (XNetworkingOkioBuffer *)emitCompleteSegments __attribute__((swift_name("emitCompleteSegments()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (BOOL)exhausted __attribute__((swift_name("exhausted()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)flushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("flush()")));
- (int8_t)getPos:(int64_t)pos __attribute__((swift_name("get(pos:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (XNetworkingOkioByteString *)hmacSha1Key:(XNetworkingOkioByteString *)key __attribute__((swift_name("hmacSha1(key:)")));
- (XNetworkingOkioByteString *)hmacSha256Key:(XNetworkingOkioByteString *)key __attribute__((swift_name("hmacSha256(key:)")));
- (XNetworkingOkioByteString *)hmacSha512Key:(XNetworkingOkioByteString *)key __attribute__((swift_name("hmacSha512(key:)")));
- (int64_t)indexOfB:(int8_t)b __attribute__((swift_name("indexOf(b:)")));
- (int64_t)indexOfBytes:(XNetworkingOkioByteString *)bytes __attribute__((swift_name("indexOf(bytes:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(b:fromIndex:)")));
- (int64_t)indexOfBytes:(XNetworkingOkioByteString *)bytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(bytes:fromIndex:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex toIndex:(int64_t)toIndex __attribute__((swift_name("indexOf(b:fromIndex:toIndex:)")));
- (int64_t)indexOfElementTargetBytes:(XNetworkingOkioByteString *)targetBytes __attribute__((swift_name("indexOfElement(targetBytes:)")));
- (int64_t)indexOfElementTargetBytes:(XNetworkingOkioByteString *)targetBytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOfElement(targetBytes:fromIndex:)")));
- (XNetworkingOkioByteString *)md5 __attribute__((swift_name("md5()")));
- (id<XNetworkingOkioBufferedSource>)peek __attribute__((swift_name("peek_()")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(XNetworkingOkioByteString *)bytes __attribute__((swift_name("rangeEquals(offset:bytes:)")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(XNetworkingOkioByteString *)bytes bytesOffset:(int32_t)bytesOffset byteCount:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:bytes:bytesOffset:byteCount:)")));
- (int32_t)readSink:(XNetworkingKotlinByteArray *)sink __attribute__((swift_name("read(sink:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)readSink:(XNetworkingOkioBuffer *)sink byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("read(sink:byteCount:)"))) __attribute__((swift_error(nonnull_error)));
- (int32_t)readSink:(XNetworkingKotlinByteArray *)sink offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("read(sink:offset:byteCount:)")));
- (int64_t)readAllSink:(id<XNetworkingOkioSink>)sink __attribute__((swift_name("readAll(sink:)")));
- (XNetworkingOkioBufferUnsafeCursor *)readAndWriteUnsafeUnsafeCursor:(XNetworkingOkioBufferUnsafeCursor *)unsafeCursor __attribute__((swift_name("readAndWriteUnsafe(unsafeCursor:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (XNetworkingKotlinByteArray *)readByteArray __attribute__((swift_name("readByteArray()")));
- (XNetworkingKotlinByteArray *)readByteArrayByteCount:(int64_t)byteCount __attribute__((swift_name("readByteArray(byteCount:)")));
- (XNetworkingOkioByteString *)readByteString __attribute__((swift_name("readByteString()")));
- (XNetworkingOkioByteString *)readByteStringByteCount:(int64_t)byteCount __attribute__((swift_name("readByteString(byteCount:)")));
- (int64_t)readDecimalLong __attribute__((swift_name("readDecimalLong()")));
- (void)readFullySink:(XNetworkingKotlinByteArray *)sink __attribute__((swift_name("readFully(sink:)")));
- (void)readFullySink:(XNetworkingOkioBuffer *)sink byteCount:(int64_t)byteCount __attribute__((swift_name("readFully(sink:byteCount:)")));
- (int64_t)readHexadecimalUnsignedLong __attribute__((swift_name("readHexadecimalUnsignedLong()")));
- (int32_t)readInt __attribute__((swift_name("readInt()")));
- (int32_t)readIntLe __attribute__((swift_name("readIntLe()")));
- (int64_t)readLong __attribute__((swift_name("readLong()")));
- (int64_t)readLongLe __attribute__((swift_name("readLongLe()")));
- (int16_t)readShort __attribute__((swift_name("readShort()")));
- (int16_t)readShortLe __attribute__((swift_name("readShortLe()")));
- (XNetworkingOkioBufferUnsafeCursor *)readUnsafeUnsafeCursor:(XNetworkingOkioBufferUnsafeCursor *)unsafeCursor __attribute__((swift_name("readUnsafe(unsafeCursor:)")));
- (NSString *)readUtf8 __attribute__((swift_name("readUtf8()")));
- (NSString *)readUtf8ByteCount:(int64_t)byteCount __attribute__((swift_name("readUtf8(byteCount:)")));
- (int32_t)readUtf8CodePoint __attribute__((swift_name("readUtf8CodePoint()")));
- (NSString * _Nullable)readUtf8Line __attribute__((swift_name("readUtf8Line()")));
- (NSString *)readUtf8LineStrict __attribute__((swift_name("readUtf8LineStrict()")));
- (NSString *)readUtf8LineStrictLimit:(int64_t)limit __attribute__((swift_name("readUtf8LineStrict(limit:)")));
- (BOOL)requestByteCount:(int64_t)byteCount __attribute__((swift_name("request(byteCount:)")));
- (void)requireByteCount:(int64_t)byteCount __attribute__((swift_name("require(byteCount:)")));
- (int32_t)selectOptions:(NSArray<XNetworkingOkioByteString *> *)options __attribute__((swift_name("select(options:)")));
- (id _Nullable)selectOptions_:(NSArray<id> *)options __attribute__((swift_name("select(options_:)")));
- (XNetworkingOkioByteString *)sha1 __attribute__((swift_name("sha1()")));
- (XNetworkingOkioByteString *)sha256 __attribute__((swift_name("sha256()")));
- (XNetworkingOkioByteString *)sha512 __attribute__((swift_name("sha512()")));
- (void)skipByteCount:(int64_t)byteCount __attribute__((swift_name("skip(byteCount:)")));
- (XNetworkingOkioByteString *)snapshot __attribute__((swift_name("snapshot()")));
- (XNetworkingOkioByteString *)snapshotByteCount:(int32_t)byteCount __attribute__((swift_name("snapshot(byteCount:)")));
- (XNetworkingOkioTimeout *)timeout __attribute__((swift_name("timeout()")));
- (NSString *)description __attribute__((swift_name("description()")));
- (XNetworkingOkioBuffer *)writeSource:(XNetworkingKotlinByteArray *)source __attribute__((swift_name("write(source:)")));
- (XNetworkingOkioBuffer *)writeByteString:(XNetworkingOkioByteString *)byteString __attribute__((swift_name("write(byteString:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)writeSource:(XNetworkingOkioBuffer *)source byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("write(source:byteCount_:)")));
- (XNetworkingOkioBuffer *)writeSource:(id<XNetworkingOkioSource>)source byteCount:(int64_t)byteCount __attribute__((swift_name("write(source:byteCount:)")));
- (XNetworkingOkioBuffer *)writeSource:(XNetworkingKotlinByteArray *)source offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(source:offset:byteCount:)")));
- (XNetworkingOkioBuffer *)writeByteString:(XNetworkingOkioByteString *)byteString offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(byteString:offset:byteCount:)")));
- (int64_t)writeAllSource:(id<XNetworkingOkioSource>)source __attribute__((swift_name("writeAll(source:)")));
- (XNetworkingOkioBuffer *)writeByteB:(int32_t)b __attribute__((swift_name("writeByte(b:)")));
- (XNetworkingOkioBuffer *)writeDecimalLongV:(int64_t)v __attribute__((swift_name("writeDecimalLong(v:)")));
- (XNetworkingOkioBuffer *)writeHexadecimalUnsignedLongV:(int64_t)v __attribute__((swift_name("writeHexadecimalUnsignedLong(v:)")));
- (XNetworkingOkioBuffer *)writeIntI:(int32_t)i __attribute__((swift_name("writeInt(i:)")));
- (XNetworkingOkioBuffer *)writeIntLeI:(int32_t)i __attribute__((swift_name("writeIntLe(i:)")));
- (XNetworkingOkioBuffer *)writeLongV:(int64_t)v __attribute__((swift_name("writeLong(v:)")));
- (XNetworkingOkioBuffer *)writeLongLeV:(int64_t)v __attribute__((swift_name("writeLongLe(v:)")));
- (XNetworkingOkioBuffer *)writeShortS:(int32_t)s __attribute__((swift_name("writeShort(s:)")));
- (XNetworkingOkioBuffer *)writeShortLeS:(int32_t)s __attribute__((swift_name("writeShortLe(s:)")));
- (XNetworkingOkioBuffer *)writeUtf8String:(NSString *)string __attribute__((swift_name("writeUtf8(string:)")));
- (XNetworkingOkioBuffer *)writeUtf8String:(NSString *)string beginIndex:(int32_t)beginIndex endIndex:(int32_t)endIndex __attribute__((swift_name("writeUtf8(string:beginIndex:endIndex:)")));
- (XNetworkingOkioBuffer *)writeUtf8CodePointCodePoint:(int32_t)codePoint __attribute__((swift_name("writeUtf8CodePoint(codePoint:)")));
@property (readonly) XNetworkingOkioBuffer *buffer __attribute__((swift_name("buffer")));
@property (readonly) int64_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("OkioTimeout")))
@interface XNetworkingOkioTimeout : XNetworkingBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) XNetworkingOkioTimeoutCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioByteString.Companion")))
@interface XNetworkingOkioByteStringCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingOkioByteStringCompanion *shared __attribute__((swift_name("shared")));
- (XNetworkingOkioByteString * _Nullable)decodeBase64:(NSString *)receiver __attribute__((swift_name("decodeBase64(_:)")));
- (XNetworkingOkioByteString *)decodeHex:(NSString *)receiver __attribute__((swift_name("decodeHex(_:)")));
- (XNetworkingOkioByteString *)encodeUtf8:(NSString *)receiver __attribute__((swift_name("encodeUtf8(_:)")));
- (XNetworkingOkioByteString *)ofData:(XNetworkingKotlinByteArray *)data __attribute__((swift_name("of(data:)")));
- (XNetworkingOkioByteString *)toByteString:(NSData *)receiver __attribute__((swift_name("toByteString(_:)")));
- (XNetworkingOkioByteString *)toByteString:(XNetworkingKotlinByteArray *)receiver offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("toByteString(_:offset:byteCount:)")));
@property (readonly) XNetworkingOkioByteString *EMPTY __attribute__((swift_name("EMPTY")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioBuffer.UnsafeCursor")))
@interface XNetworkingOkioBufferUnsafeCursor : XNetworkingBase <XNetworkingOkioCloseable>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));
- (int64_t)expandBufferMinByteCount:(int32_t)minByteCount __attribute__((swift_name("expandBuffer(minByteCount:)")));
- (int32_t)next __attribute__((swift_name("next()")));
- (int64_t)resizeBufferNewSize:(int64_t)newSize __attribute__((swift_name("resizeBuffer(newSize:)")));
- (int32_t)seekOffset:(int64_t)offset __attribute__((swift_name("seek(offset:)")));
@property XNetworkingOkioBuffer * _Nullable buffer __attribute__((swift_name("buffer")));
@property XNetworkingKotlinByteArray * _Nullable data __attribute__((swift_name("data")));
@property int32_t end __attribute__((swift_name("end")));
@property int64_t offset __attribute__((swift_name("offset")));
@property BOOL readWrite __attribute__((swift_name("readWrite")));
@property int32_t start __attribute__((swift_name("start")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioTimeout.Companion")))
@interface XNetworkingOkioTimeoutCompanion : XNetworkingBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) XNetworkingOkioTimeoutCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) XNetworkingOkioTimeout *NONE __attribute__((swift_name("NONE")));
@end

#pragma pop_macro("_Nullable_result")
#pragma clang diagnostic pop
NS_ASSUME_NONNULL_END
