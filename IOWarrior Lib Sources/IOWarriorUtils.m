//
//  IOWarriorUtils.m
//  IOWarriorSimpleI2C
//
//  Created by ilja on 15.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "IOWarriorUtils.h"
#import "IOWarriorLib.h"


@implementation IOWarriorUtils

+ (NSString*) nameForIOWarriorInterfaceType:(int) inType
/*" Returns a human readable name for a given IOWarrior interface type. "*/
{
    switch (inType)
    {
        case kIOWarrior40Interface0:
            return @"IOWarrior40 Interface 0";
            break;
			
        case kIOWarrior40Interface1:
            return @"IOWarrior40 Interface 1";
            break;
			
        case kIOWarrior24Interface0:
            return @"IOWarrior24 Interface 0";
            break;
			
        case kIOWarrior24Interface1:
            return @"IOWarrior24 Interface 1";
            break;
			
		case kIOWarrior56Interface0:
            return @"IOWarrior56 Interface 0";
            break;
			
        case kIOWarrior56Interface1:
            return @"IOWarrior56 Interface 1";
            break;
			
		case kIOWarrior24PVInterface0:
            return @"IOWarrior24 PV Interface 0";
            break;
			
        case kIOWarrior24PVInterface1:
            return @"IOWarrior24 PV Interface 1";
            break;
			
		case kIOWarrior24CWInterface0:
            return @"IOWarrior24 CW Interface 0";
            break;
			
        case kIOWarrior24CWInterface1:
            return @"IOWarrior24 CW Interface 1";
            break;
        
        case kJoyWarrior24F8Interface0:
            return @"JoyWarrior24F8 Interface 0";
            break;
            
        case kJoyWarrior24F8Interface1:
            return @"JoyWarrior24F8 Interface 1";
            break;
        
        case kMouseWarrior24F6Interface0:
            return @"MouseWarrior24F6 Interface 0";
            break;
            
        case kMouseWarrior24F6Interface1:
            return @"MouseWarrior24F6 Interface 1";
            break;
        
        case kJoyWarrior24F14Interface0:
            return @"JoyWarrior24F14 Interface 0";
            break;
            
        case kJoyWarrior24F14Interface1:
            return @"JoyWarrior24F14 Interface 1";
            break;
			
    }
    return @"Unknown interface type";
}

+ (NSString*) chipNameForIOWarriorInterfaceType:(int) inType
/*" Returns a human readable chip name for a given IOWarrior interface type. "*/
{
    switch (inType)
    {
        case kIOWarrior40Interface0:
		case kIOWarrior40Interface1:
			return @"IOWarrior40";
		break;

        case kIOWarrior24Interface0:
		case kIOWarrior24Interface1:
            return @"IOWarrior24";
            break;
			
		case kIOWarrior56Interface0:
		case kIOWarrior56Interface1:
            return @"IOWarrior56";
            break;
			
		case kIOWarrior24PVInterface0:
		case kIOWarrior24PVInterface1:
            return @"IOWarrior24 PV";
            break;
			
		case kIOWarrior24CWInterface0:
		case kIOWarrior24CWInterface1:
            return @"IOWarrior24 CW";
            break;
        
        case kJoyWarrior24F8Interface0:
		case kMouseWarrior24F6Interface0:
        case kJoyWarrior24F14Interface0:
        case kJoyWarrior24F8Interface1:
		case kMouseWarrior24F6Interface1:
        case kJoyWarrior24F14Interface1:
            return @"JoyWarror/MouseWarrior 24";
            break;
    }
    return @"Unknown interface type";
}


@end
