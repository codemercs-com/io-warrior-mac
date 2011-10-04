//
//  I2CHumidityTemperatureAppDelegate.h
//  I2CHumidityTemperature
//
//  Created by ilja on 06.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IOWarriorLib.h"

@interface I2CHumidityTemperatureAppDelegate : NSObject {
    NSWindow *window;
	
	unsigned char					*interruptReportBuffer;
	IOWarriorHIDDeviceInterface**	interface;
	int								stage;
	
	UInt16							rawTemp;
	UInt16							rawHum;
	
	IBOutlet NSTextField			*tempField;
	IBOutlet NSTextField			*humField;
	IBOutlet NSTextField			*dewPointField;
	
	IBOutlet NSTextField			*stateField;
	

}

- (void) handleError:(OSStatus) inErr;
- (void) processReadBytes:(unsigned char*) inBytes;
- (void) updateInterface;
- (void) discoverInterfaces;
@end
