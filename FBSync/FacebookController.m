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
    self.fb = [MKFacebook facebookWithAPIKey:@"b7c1da5e946761369e313d9cb3e937f1" delegate:self];
    NSLog(@"OMG FACEBOOK");
}

@end
