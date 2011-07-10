//
//  FacebookController.m
//  FBSync
//
//  Created by Eric Allen on 7/9/11.
//  Copyright 2011 2bkco, Inc. All rights reserved.
//

#import "FacebookController.h"


@implementation FacebookController

@synthesize fb;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)doFacebook:(id)source
{
    self.fb = [[PhFacebook alloc] initWithApplicationID:@"188204611236431" delegate:self];
    [fb getAccessTokenForPermissions: [NSArray arrayWithObjects: @"read_stream", @"publish_stream", nil] cached:YES];
}

- (void)userLoginSuccessful
{
    NSLog(@"Holy shit I'm in");
}

- (void) tokenResult: (NSDictionary*) result {

}
- (void) requestResult: (NSDictionary*) result {

}

@end
