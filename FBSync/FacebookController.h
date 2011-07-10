//
//  FacebookController.h
//  FBSync
//
//  Created by Eric Allen on 7/9/11.
//  Copyright 2011 2bkco, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PhFacebook/PhFacebook.h>


@interface FacebookController : NSObject <PhFacebookDelegate> {
@private
    
}

@property (retain, nonatomic) PhFacebook* fb;
-(IBAction) doFacebook:(id)source;
- (void) tokenResult: (NSDictionary*) result;
- (void) requestResult: (NSDictionary*) result;
@end
