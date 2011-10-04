//
//  IOWarriorPin.h
//  IOWarriorAppleScriptGateway
//
//  Created by ilja on Wed Feb 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface IOWarriorPin : NSObject {
    int	value;
    int	index;
}

- (id) initWithValue:(int) inValue index:(int) index;
- (void) setValue:(int) inValue;
- (void) setValueWithoutWriteBack:(int) inValue;
- (int) value;

@end
