//
//  IOWarriorPin.m
//  IOWarriorAppleScriptGateway
//
//  Created by ilja on Wed Feb 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "IOWarriorPin.h"

@implementation IOWarriorPin

extern int gUserChangedPinValues;

- (id) initWithValue:(int) inValue index:(int) inIndex
{
    self = [super init];
    if (self)
    {
        index = inIndex;
        [self setValueWithoutWriteBack:inValue];
        
    }

    return self;
}

/*" Changes the value of a pin. Sets up a timer that will write the changes back to the iowarrior after 0.2 seconds, so not every value change of a pin will cause a usb transaction. "*/
- (void) setValue:(int) inValue;
{
    //NSLog (@"setValue of pin %d to %d", index, inValue);

    /* test code - reads current pins values before changing them
    [NSApp readPinArrayValues];

     value = inValue;
    
    [NSApp writeBack:NULL];

    */

    value = inValue;

    if (false == gUserChangedPinValues)
    {
        gUserChangedPinValues = true;
        [NSTimer scheduledTimerWithTimeInterval:0.2
                                         target:NSApp
                                       selector:@selector (writeBack:)
                                       userInfo:NULL
                                        repeats:NO];
    }
}

/*" Changes the value of a pin. Used to set the value after having read the original value from the IOWarrior. Does not schedule a timer. "*/
- (void) setValueWithoutWriteBack:(int) inValue
{
    //NSLog (@"setValueWithoutWriteBack of pin %d to %d", index, inValue);
    value = inValue;
}

- (int) value
{
    //NSLog (@"value of pin %d is %d", index, value);
    
    return value;
}


@end
