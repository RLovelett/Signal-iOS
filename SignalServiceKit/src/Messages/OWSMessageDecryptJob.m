//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageDecryptJob.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import "NSArray+OWS.h"
#import "NSNotificationCenter+OWS.h"
#import "NotificationsProtocol.h"
#import "OWSBackgroundTask.h"
#import "OWSQueues.h"
#import "OWSStorage.h"
#import "ProfileManagerProtocol.h"
#import "SSKEnvironment.h"
#import "TSAccountManager.h"
#import "TSErrorMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/Threading.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSNotificationName const kNSNotificationNameMessageDecryptionDidFlushQueue
    = @"kNSNotificationNameMessageDecryptionDidFlushQueue";

@implementation OWSMessageDecryptJob

+ (NSString *)collection
{
    return @"OWSMessageProcessingJob";
}

- (instancetype)initWithEnvelopeData:(NSData *)envelopeData serverDeliveryTimestamp:(uint64_t)serverDeliveryTimestamp
{
    OWSAssertDebug(envelopeData);

    self = [super init];
    if (!self) {
        return self;
    }

    _envelopeData = envelopeData;
    _serverDeliveryTimestamp = serverDeliveryTimestamp;
    _createdAt = [NSDate new];

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run
// `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
                       createdAt:(NSDate *)createdAt
                    envelopeData:(NSData *)envelopeData
         serverDeliveryTimestamp:(uint64_t)serverDeliveryTimestamp
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId];

    if (!self) {
        return self;
    }

    _createdAt = createdAt;
    _envelopeData = envelopeData;
    _serverDeliveryTimestamp = serverDeliveryTimestamp;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (nullable SSKProtoEnvelope *)envelopeProto
{
    NSError *error;
    SSKProtoEnvelope *_Nullable envelope = [[SSKProtoEnvelope alloc] initWithSerializedData:self.envelopeData
                                                                                      error:&error];
    if (error || envelope == nil) {
        OWSFailDebug(@"failed to parse envelope with error: %@", error);
        return nil;
    }

    return envelope;
}

@end

#pragma mark - Finder

NSString *const OWSMessageDecryptJobFinderExtensionName = @"OWSMessageProcessingJobFinderExtensionName2";
NSString *const OWSMessageDecryptJobFinderExtensionGroup = @"OWSMessageProcessingJobFinderExtensionGroup2";

@implementation OWSMessageDecryptJobFinder

#pragma mark - Dependencies

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

#pragma mark -

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [OWSMessageDecryptJobFinder registerLegacyClasses];

    return self;
}

- (NSString *)databaseExtensionName
{
    return OWSMessageDecryptJobFinderExtensionName;
}

- (NSString *)databaseExtensionGroup
{
    return OWSMessageDecryptJobFinderExtensionGroup;
}

- (OWSMessageDecryptJob *_Nullable)nextJob
{
    // POST GRDB TODO: Remove this queue & finder entirely.
    if (StorageCoordinator.dataStoreForUI != DataStoreYdb) {
        OWSLogWarn(@"Not processing queue; obsolete.");
        return nil;
    }

    __block OWSMessageDecryptJob *_Nullable job = nil;
    [self.databaseStorage
        readWithBlock:^(SDSAnyReadTransaction *transaction) { job = [self nextJobWithTransaction:transaction]; }];
    return job;
}

- (void)addJobForEnvelopeData:(NSData *)envelopeData serverDeliveryTimestamp:(uint64_t)serverDeliveryTimestamp
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self addJobForEnvelopeData:envelopeData
            serverDeliveryTimestamp:serverDeliveryTimestamp
                        transaction:transaction];
    });
}

- (void)addJobForEnvelopeData:(NSData *)envelopeData
      serverDeliveryTimestamp:(uint64_t)serverDeliveryTimestamp
                  transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSMessageDecryptJob *job = [[OWSMessageDecryptJob alloc] initWithEnvelopeData:envelopeData
                                                           serverDeliveryTimestamp:serverDeliveryTimestamp];
    [job anyInsertWithTransaction:transaction];
}

- (void)removeJobWithId:(NSString *)uniqueId
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        OWSMessageDecryptJob *_Nullable job = [OWSMessageDecryptJob anyFetchWithUniqueId:uniqueId
                                                                             transaction:transaction];
        if (job) {
            [job anyRemoveWithTransaction:transaction];
        }
    });
}

- (NSUInteger)queuedJobCount
{
    __block NSUInteger result;
    [self.databaseStorage readWithBlock:^(
        SDSAnyReadTransaction *transaction) { result = [self queuedJobCountWithTransaction:transaction]; }];
    return result;
}

- (NSUInteger)queuedJobCountWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWSMessageDecryptJob anyCountWithTransaction:transaction];
}

+ (YapDatabaseView *)databaseExtension
{
    YapDatabaseViewSorting *sorting =
        [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *transaction,
            NSString *group,
            NSString *collection1,
            NSString *key1,
            id object1,
            NSString *collection2,
            NSString *key2,
            id object2) {
            if (![object1 isKindOfClass:[OWSMessageDecryptJob class]]) {
                OWSFailDebug(@"Unexpected object: %@ in collection: %@", [object1 class], collection1);
                return NSOrderedSame;
            }
            OWSMessageDecryptJob *job1 = (OWSMessageDecryptJob *)object1;

            if (![object2 isKindOfClass:[OWSMessageDecryptJob class]]) {
                OWSFailDebug(@"Unexpected object: %@ in collection: %@", [object2 class], collection2);
                return NSOrderedSame;
            }
            OWSMessageDecryptJob *job2 = (OWSMessageDecryptJob *)object2;

            return [job1.createdAt compare:job2.createdAt];
        }];

    YapDatabaseViewGrouping *grouping =
        [YapDatabaseViewGrouping withObjectBlock:^NSString *_Nullable(YapDatabaseReadTransaction *_Nonnull transaction,
            NSString *_Nonnull collection,
            NSString *_Nonnull key,
            id _Nonnull object) {
            if (![object isKindOfClass:[OWSMessageDecryptJob class]]) {
                OWSFailDebug(@"Unexpected object: %@ in collection: %@", object, collection);
                return nil;
            }

            // Arbitrary string - all in the same group. We're only using the view for sorting.
            return OWSMessageDecryptJobFinderExtensionGroup;
        }];

    YapDatabaseViewOptions *options = [YapDatabaseViewOptions new];
    options.allowedCollections =
        [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[OWSMessageDecryptJob collection]]];

    return [[YapDatabaseAutoView alloc] initWithGrouping:grouping sorting:sorting versionTag:@"1" options:options];
}

+ (void)registerLegacyClasses
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // We've renamed OWSMessageProcessingJob to OWSMessageDecryptJob.
        [NSKeyedUnarchiver setClass:[OWSMessageDecryptJob class] forClassName:[OWSMessageDecryptJob collection]];
    });
}

+ (void)asyncRegisterDatabaseExtension:(OWSStorage *)storage
{
    [self registerLegacyClasses];

    YapDatabaseView *existingView = [storage registeredExtension:OWSMessageDecryptJobFinderExtensionName];
    if (existingView) {
        OWSFailDebug(@"%@ was already initialized.", OWSMessageDecryptJobFinderExtensionName);
        // already initialized
        return;
    }
    [storage asyncRegisterExtension:[self databaseExtension] withName:OWSMessageDecryptJobFinderExtensionName];
}

@end

NS_ASSUME_NONNULL_END