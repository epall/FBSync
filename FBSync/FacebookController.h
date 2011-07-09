//
//  FacebookController.h
//  FBSync
//
//  Created by Eric Allen on 7/9/11.
//  Copyright 2011 2bkco, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MkAbeFook/MkAbeFook.h"


@interface FacebookController : NSObject {
@private
    
}

@property (retain, nonatomic) MKFacebook* fb;
-(IBAction) doFacebook:(id)source;

@end
