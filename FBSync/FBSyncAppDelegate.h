//
//  FBSyncAppDelegate.h
//  FBSync
//
//  Created by Eric Allen on 7/9/11.
//  Copyright 2011 2bkco, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FBSyncAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
