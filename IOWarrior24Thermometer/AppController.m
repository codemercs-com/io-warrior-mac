#import "AppController.h"

char            gDataBuffer[8];


void IOWarriorInterruptCallback (void* target, IOReturn result,void* refcon, void* sender,UInt32 bufferSize)
/*" Invoked when data is received from IOWarrior */
{    
	AppController*   controller = refcon;

    if (kIOReturnSuccess == result)
	{
		UInt16 temp = 0;
		
		memcpy(&temp,&gDataBuffer[2],2); // get the two temperature bytes from received data
		temp = NSSwapBigShortToHost(temp);
		temp = temp >> 3; // shift 3 bytes to the right to remove status flags
		[controller updateTemperatureField:(float) temp / 4.0]; // dived by four to get whole degrees
	}
}

void IOWarriorCallback (void* inRefCon)
/*" Invoked when an IOWarriorDevice appears or disappears. "*/
{
	IOWarriorHIDDeviceInterface **interface = IOWarriorFirstInterfaceOfType(kIOWarrior24Interface1);
    AppController*   controller = inRefCon;
    
	if ([controller interface] != interface)
	{
		char SPIModeCommand[] = {0x08, 0x01, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00};
		
		[controller setInterface:interface];
		[controller udpateIOWarriorStateField];
		
		// init SPI mode
		IOWarriorWriteToInterface(interface, 8 , SPIModeCommand);
		
		IOWarriorSetInterruptCallback(interface, gDataBuffer, 8, IOWarriorInterruptCallback, controller);
	}
} 

@implementation AppController

- (void) awakeFromNib
{
	// Init IOWarrior Library
	IOWarriorInit();
	
	[self udpateIOWarriorStateField];
	[temperatureField setStringValue:@"?"];
	
	// register call IOWarrior call backs
	IOWarriorSetDeviceCallback(IOWarriorCallback, self);
    IOWarriorCallback (self);
	
	// 
	[NSTimer scheduledTimerWithTimeInterval:2
									 target:self
								   selector:@selector(readTemperature:)
								   userInfo:nil
									repeats:YES];
}

- (void) udpateIOWarriorStateField
{
	if (nil != interface)
	{
		[statusField setStringValue:@"IOWarrior24 present"];
	}
	else
	{
		[statusField setStringValue:@"IOWarrior24 not found"];
		[temperatureField setStringValue:@"?"];

	}
}

- (void) updateTemperatureField:(float) inTemperature
{
	[temperatureField setStringValue:[NSString stringWithFormat:@"%.2f\ue28483 C", inTemperature]];
}

- (void) readTemperature:(NSTimer*) inTimer
{
	if (interface)
	{
		char tempCommand[] = {0x09, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
		
		IOWarriorWriteToInterface(interface, 8 , tempCommand);
	}
}


-(void) setInterface:(IOWarriorHIDDeviceInterface **) inInterface
{
	interface = inInterface;
}

-(IOWarriorHIDDeviceInterface **) interface
{
	return interface;
}


@end
