/* AppController */

#import <Cocoa/Cocoa.h>
#import "IOWarriorLib.h"

@interface AppController : NSObject
{
    IBOutlet NSTextField *statusField;
    IBOutlet NSTextField *temperatureField;
	
	IOWarriorHIDDeviceInterface **interface;
}

- (void) udpateIOWarriorStateField;
- (void) updateTemperatureField:(float) inTemperature;

- (void) setInterface:(IOWarriorHIDDeviceInterface **) inInterface;
-(IOWarriorHIDDeviceInterface **) interface;

@end
