/*
 
 File: AppControllerSyncing.m
 
 Abstract: Part of the People project demonstrating use of the
 SyncServices framework
 
 Version: 0.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Computer, Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Computer,
 Inc. may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright © 2005-2009 Apple Computer, Inc., All Rights Reserved.
 
 */ 

#import <SyncServices/SyncServices.h>

#import "FBSyncServices.h"
#import "AppControllerExtensions.h"
#import "Change.h"
#import "Constants.h"
#import "LastNameFilter.h"
#import "NSArrayExtras.h"

@implementation FBSyncServices (Syncing)

//
// ===========================================
// Syncing
//

- (void)performSync:(ISyncClient *)client :(ISyncSession *)session
{
    @try {
        if (session) {
            [self configureSession:session];
            [self pushDataForSession:session];
            [self pullDataForSession:session];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"caught exception: %@: %@", [exception name], [exception reason]);
    }
    @finally {
        [self syncCleanup];
    }
}

- (void)client:(ISyncClient *)client willSyncEntityNames:(NSArray *)entityNames
{
    [self sync:self];
}

- (ISyncClient *)registerClient 
{
    ISyncManager *manager = [ISyncManager sharedManager];
    ISyncClient *client;
    
    // Register the schema.
    [manager registerSchemaWithBundlePath:@"/System/Library/SyncServices/Schemas/Contacts.syncschema"];
    
	// Register the schema extensions.
    [manager registerSchemaWithBundlePath:
     [[NSBundle mainBundle] pathForResource:@"PeopleSchemaExtension" ofType:@"syncschema"]];
    
    // See if our client has already registered
    if (!(client = [manager clientWithIdentifier:ClientIdentifier])) {
        // and if it hasn't, register the client.
        client = [manager registerClientWithIdentifier:ClientIdentifier descriptionFilePath:
                  [[NSBundle mainBundle] pathForResource:@"ClientDescription" ofType:@"plist"]];
    }
    
    return client;
}

- (void)configureSession:(ISyncSession *)session 
{
    switch (m_syncMode) {
        case FastSync:
            // nothing to do here.
            break;
        case SlowSync:
            [session clientWantsToPushAllRecordsForEntityNames:m_entityNames];
            break;
        case RefreshSync:
            [session clientDidResetEntityNames:m_entityNames];
            break;
        case PullTheTruth:
            // not handled here. must be handled before session starts.
            break;
    }
}

- (void)pushDataForSession:(ISyncSession *)session
{
    if ([session shouldPushAllRecordsForEntityName:EntityContact]) {
        NSEnumerator *enumerator = [m_syncRecords objectEnumerator];
        NSDictionary *appRecord;
        while ((appRecord = [enumerator nextObject])) {
            NSDictionary *syncRecord = [self syncRecordForAppRecord:appRecord];
            NSString *identifier = [appRecord objectForKey:IdentifierKey];
            [session pushChangesFromRecord:syncRecord withIdentifier:identifier];
        }
    }
    else if ([session shouldPushChangesForEntityName:EntityContact]) {
        // push changes only
        NSEnumerator *enumerator = [m_syncChangesIn objectEnumerator];
        Change *change;
        while ((change = [enumerator nextObject])) {
            switch ([change type]) {
                case AddRecord:
                case ModifyRecord: {
                    NSDictionary *appRecord = [change record];
                    NSString *identifier = [appRecord objectForKey:IdentifierKey];
                    NSDictionary *syncRecord = [self syncRecordForAppRecord:appRecord];
                    [session pushChangesFromRecord:syncRecord withIdentifier:identifier];
                    break;
                }
                case DeleteRecord:
                    [session deleteRecordWithIdentifier:[[change oldRecord] objectForKey:IdentifierKey]];
                    break;
            }
        }
    }
}

- (void)pullDataForSession:(ISyncSession *)session
{
    BOOL shouldPull = [session shouldPullChangesForEntityName:EntityContact];
    if (!shouldPull) {
        [self syncCleanup];
    }
    
    if ([session shouldReplaceAllRecordsOnClientForEntityName:EntityContact]) {
        m_syncReplaceAllRecords = YES;
    }
    
	if (![session prepareToPullChangesForEntityNames:m_entityNames beforeDate:[NSDate distantFuture]]) {
        [self syncFailed:session error:nil];
        return;
    }	
    
    if (m_syncReplaceAllRecords)
        [m_syncRecords removeAllObjects];
    
    NSEnumerator *changeEnumerator = [session changeEnumeratorForEntityNames:m_entityNames];
    ISyncChange *change;
    while ((change = [changeEnumerator nextObject])) {
        NSString *identifier = [change recordIdentifier];
        [m_pulledIdentifiers addObject:identifier];
        switch ([change type]) {
            case ISyncChangeTypeDelete: {
                NSUInteger idx = [m_syncRecords indexOfSyncRecordWithIdentifier:identifier];
                if ([m_syncRecords count] > idx)
                    [m_syncRecords removeObjectAtIndex:idx];
                break;
            }
            case ISyncChangeTypeAdd: {
                NSDictionary *syncRecord = [change record];
                NSDictionary *appRecord = [self appRecordForSyncRecord:syncRecord withIdentifier:identifier];
                [m_syncRecords addObject:appRecord];
                break;
            }
            case ISyncChangeTypeModify: {
                NSDictionary *syncRecord = [change record];
                NSDictionary *appRecord = [self appRecordForSyncRecord:syncRecord withIdentifier:identifier];
                NSUInteger idx = [m_syncRecords indexOfSyncRecordWithIdentifier:identifier];
                if ([m_syncRecords count] > idx) {
                    [m_syncRecords replaceObjectAtIndex:idx withObject:appRecord];
                }
                break;
            }
        }
    }
    
    NSString *identifier;
    NSEnumerator *enumerator = [m_pulledIdentifiers objectEnumerator];
    while ((identifier = [enumerator nextObject])) {
        [session clientAcceptedChangesForRecordWithIdentifier:identifier 
                                              formattedRecord:[m_formattedRecords objectForKey:identifier]
                                          newRecordIdentifier:nil];
    }
    
    [session clientCommittedAcceptedChanges];
	[session finishSyncing];
    
    [m_records removeAllObjects];
    [m_records addObjectsFromArray:m_syncRecords];
}

- (void)syncFailed:(ISyncSession *)session error:(NSError *)error
{
    [session cancelSyncing];
    NSLog(@"sync failed: %@", [error localizedFailureReason]);
    [self syncCleanup];
}

- (void)syncCleanup
{
    [m_syncProgress stopAnimation:self];
    [m_syncProgress setHidden:YES];
    [m_syncButton setEnabled:YES];
    [m_syncModeButton setEnabled:YES];
    
    [m_syncRecords release]; m_syncRecords = nil;
    [m_syncChangesIn release]; m_syncChangesIn = nil;
    [m_pulledIdentifiers release]; m_pulledIdentifiers = nil;
    [m_formattedRecords release]; m_formattedRecords = nil;
    
    [self sortNamesAndDisplay];
    [self update];
    [self writeDataFile];
}

//
// ===========================================
// Record conversion
//

- (NSDictionary *)syncRecordForAppRecord:(NSDictionary *)record
{
    NSString *firstName = [record objectForKey:FirstNameKey];
    NSString *middleName = [record objectForKey:MiddleNameKey];
    NSString *lastName = [record objectForKey:LastNameKey];
    NSString *company = [record objectForKey:CompanyNameKey];
    NSString *location = [record objectForKey:LocationNameKey];
    NSData *officialPhoto = [record objectForKey:ImageKey];
    NSData *candidPhoto = [record objectForKey:CandidPhotoKey];
    NSData *extremePhoto = [record objectForKey:ExtremePhotoKey];
    
    NSMutableDictionary *syncRecord = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       EntityContact, ISyncRecordEntityNameKey,
                                       nil];
    
    if (firstName && ([firstName isEqualToString:@""] == NO)) {
        [syncRecord setObject:firstName forKey:FirstNameKey];
    }
    if (middleName && ([middleName isEqualToString:@""] == NO)) {
        [syncRecord setObject:middleName forKey:MiddleNameKey];
    }
    if (lastName && ([lastName isEqualToString:@""] == NO)) {
        [syncRecord setObject:lastName forKey:LastNameKey];
    }
    if (company && ([company isEqualToString:@""] == NO)) {
        [syncRecord setObject:company forKey:CompanyNameKey];
    }
    if (location && ([location isEqualToString:@""] == NO)) {
        [syncRecord setObject:location forKey:LocationNameKey];
    }
    if (officialPhoto) {
        [syncRecord setObject:officialPhoto forKey:ImageKey];
    }
    if (candidPhoto) {
        [syncRecord setObject:candidPhoto forKey:CandidPhotoKey];
    }
    if (extremePhoto) {
        [syncRecord setObject:extremePhoto forKey:ExtremePhotoKey];
    }
    return syncRecord;
}

- (NSDictionary *)appRecordForSyncRecord:(NSDictionary *)record withIdentifier:(NSString *)identifier
{
    NSString *firstName = [record objectForKey:FirstNameKey];
    NSString *middleName = [record objectForKey:MiddleNameKey];
    NSString *lastName = [record objectForKey:LastNameKey];
    NSString *company = [record objectForKey:CompanyNameKey];
    NSString *location = [record objectForKey:LocationNameKey];
    NSData *officialPhoto = [record objectForKey:ImageKey];
    NSData *candidPhoto = [record objectForKey:CandidPhotoKey];
    NSData *extremePhoto = [record objectForKey:ExtremePhotoKey];
    if (m_syncsUsingRecordFormatting) {
        firstName = [firstName length] > FormatLimit ? [firstName substringToIndex:FormatLimit] : firstName;
        middleName = [middleName length] > FormatLimit ? [middleName substringToIndex:FormatLimit] : middleName;
        lastName = [lastName length] > FormatLimit ? [lastName substringToIndex:FormatLimit] : lastName;
        company = [company length] > FormatLimit ? [company substringToIndex:FormatLimit] : company;
        location = [location length] > FormatLimit ? [location substringToIndex:FormatLimit] : location;
    }
    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                            identifier, IdentifierKey,
                            firstName ? firstName : @"", FirstNameKey,
                            middleName ? middleName : @"", MiddleNameKey,
                            lastName ? lastName : @"", LastNameKey,
                            company ? company : @"", CompanyNameKey,
                            location ? location : @"", LocationNameKey,
                            officialPhoto ? officialPhoto : [[NSImage imageNamed: DefaultPhoto] TIFFRepresentation], ImageKey,
                            candidPhoto ? candidPhoto : [[NSImage imageNamed: DefaultPhoto] TIFFRepresentation], CandidPhotoKey,
                            extremePhoto ? extremePhoto : [[NSImage imageNamed: DefaultPhoto] TIFFRepresentation], ExtremePhotoKey,
                            nil];
    if (m_syncsUsingRecordFormatting) {
        [m_formattedRecords setObject:[self syncRecordForAppRecord:result] forKey:identifier];
    }
    return result;
}

//
// ===========================================
// IBActions
//

- (IBAction)syncOptionsChanged:(id)sender
{
    NSInteger value = [sender tag];
    switch (value) {
        case UsesRecordFiltering:
            m_syncsUsingRecordFiltering = !m_syncsUsingRecordFiltering;
            break;
        case UsesRecordFormatting:
            m_syncsUsingRecordFormatting = !m_syncsUsingRecordFormatting;
            break;
        case UsesSyncAlertHandler:
            m_syncsUsingSyncAlertHandler = !m_syncsUsingSyncAlertHandler;
            BOOL flag = m_syncsUsingSyncAlertHandler;
            ISyncClient *client = [self registerClient];
            [client setShouldSynchronize:flag withClientsOfType:ISyncClientTypeApplication];
            [client setShouldSynchronize:flag withClientsOfType:ISyncClientTypeDevice];
            [client setShouldSynchronize:flag withClientsOfType:ISyncClientTypeServer];
            [client setShouldSynchronize:flag withClientsOfType:ISyncClientTypePeer];
            [client setSyncAlertHandler:self selector:@selector(client:willSyncEntityNames:)];
            break;
        case SyncsOnAppDeactivate:
            m_syncsOnAppDeactivate = !m_syncsOnAppDeactivate;
            NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
            if (m_syncsOnAppDeactivate) {
                [defaultCenter addObserver:self 
                                  selector:@selector(sync:) 
                                      name:NSApplicationWillResignActiveNotification 
                                    object:nil];
            }
            else {
                [defaultCenter removeObserver:self 
                                         name:NSApplicationWillResignActiveNotification 
                                       object:nil];
            }
            break;
    }
}

- (IBAction)sync:(id)sender
{
    @try {
        [m_syncButton setEnabled:NO];
        [m_syncModeButton setEnabled:NO];
        [m_syncProgress setHidden:NO];
        [m_syncProgress startAnimation:self];
        [[m_window undoManager] removeAllActions];
        
        m_syncRecords = [m_records mutableCopy];
        m_syncChangesIn = [m_changes coalescedCopy];
        [m_changes removeAllObjects];
        m_pulledIdentifiers = [[NSMutableArray alloc] init];
        m_formattedRecords = [[NSMutableDictionary alloc] init];
        m_syncReplaceAllRecords = NO;
        NSInteger suggestedMode = [m_syncModeButton indexOfSelectedItem];
        if (suggestedMode > m_syncMode) m_syncMode = suggestedMode;
        
        ISyncClient *client = [self registerClient];
        if (!client) {
            NSLog(@"cannot create sync client.");
            return;
        }
        
        if (m_syncsUsingRecordFiltering) {
            id filter = [LastNameFilter filter];
            [client setFilters:[NSArray arrayWithObject:filter]]; 
        }
        else {
            [client setFilters:[NSArray array]]; 
        }
        
        if (m_syncMode == PullTheTruth) {
            [client setShouldReplaceClientRecords:YES forEntityNames:m_entityNames];
        }
        
        [ISyncSession beginSessionInBackgroundWithClient:client entityNames:m_entityNames 
                                                  target:self selector:@selector(performSync::)];
    }
    @catch (NSException *exception) {
        NSLog(@"caught exception: %@: %@", [exception name], [exception reason]);
        [self syncCleanup];
    }
}

@end
