//
//  IOWarriorUtils.h
//  IOWarriorSimpleI2C
//
//  Created by ilja on 15.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IOWarriorUtils : NSObject {

}

+ (NSString*) nameForIOWarriorInterfaceType:(int) inType;
+ (NSString*) chipNameForIOWarriorInterfaceType:(int) inType;

@end
