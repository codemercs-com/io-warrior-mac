//
//  I2CHumidityTemperatureAppDelegate.m
//  I2CHumidityTemperature
//
//  Created by ilja on 06.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "I2CHumidityTemperatureAppDelegate.h"

#define kNoStage 0
#define kStageTemp 1
#define kStageHum 2

void CalcTRH(float *humidity, float *temperature);
float calc_dewpoint(float h,float t);


void IOWarriorCallback (void* inRefCon)
/*" Invoked when an IOWarriorDevice appears or disappears. "*/
{
    I2CHumidityTemperatureAppDelegate*   controller = inRefCon;
	
	[controller performSelector:@selector (discoverInterfaces)
					 withObject:nil
					 afterDelay:0.01];
} 

void interruptCallback (void * target, IOReturn result, void * refcon,  void * sender,  uint32_t bufferSize)
{
	I2CHumidityTemperatureAppDelegate	*controller = refcon;
	
	[controller processReadBytes:target];
	
}

@implementation I2CHumidityTemperatureAppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	
	IOWarriorInit ();
	IOWarriorSetDeviceCallback(IOWarriorCallback, self);
	
	[self discoverInterfaces];
	
	[NSTimer scheduledTimerWithTimeInterval:1.0
									 target:self
								   selector:@selector (updateTimer:)
								   userInfo:nil
									repeats:YES];
}

- (void) discoverInterfaces
{
	interface = IOWarriorFirstInterfaceOfType(kIOWarrior24Interface1);
	
	if (interface)
	{
		char			buffer[8];
		OSStatus		result;
		
		// set callback for data
		interruptReportBuffer = malloc (8);
		
		IOWarriorSetInterruptCallback (interface, interruptReportBuffer, 8, 
									   interruptCallback, (void*) self);

		bzero(buffer, sizeof(buffer));
		
		// disable I2C
		buffer[0] = 0x01;
		buffer[1] = 0x00;
		
		result = IOWarriorWriteToInterface (interface, sizeof(buffer), buffer);
		if (result != kIOReturnSuccess)
		{
			[self handleError:result];
			return;
		}
		
		// enable I2C with current options
		bzero(buffer, sizeof(buffer));
		buffer[0] = 0x01;
		buffer[1] = 0x01;
		buffer[2] |= (1 << 6);
		
		result = IOWarriorWriteToInterface (interface, sizeof(buffer), buffer);
		if (result != kIOReturnSuccess)
		{
			[self handleError:result];
			return;
		}
		
	}
	else
	{
		if (interruptReportBuffer)
		{
			free (interruptReportBuffer);
			interruptReportBuffer = NULL;
		}
		stage = kNoStage;
		interface = NULL;
	
		[self updateInterface];
	}
}

- (void) requestTemperature
{
	char			buffer[8];
	OSStatus		result;
	
	stage = kStageTemp;
	
	bzero (buffer, 8);
	buffer[0] = 3;
	buffer[1] = 3;
	buffer[2] = 3;
	
	result = IOWarriorWriteToInterface(interface, 8, buffer);
	if (kIOReturnSuccess != result)
	{
		[self handleError:result];
		return;
	}
}

- (void) updateTimer:(NSTimer*) inTimer
{
	if (interface)
	{
		[self requestTemperature];
	}
}

- (void) handleError:(OSStatus) inErr
{
	NSRunCriticalAlertPanel(@"Write Error", @"An error occured while writing to the selected IOWarrior interface. Error code: %d", @"OK", nil, nil, inErr); 
	return;
}

- (void) processReadBytes:(unsigned char*) inBytes
{
	if (stage == kStageTemp)
	{
		OSStatus result;
		
		rawTemp = (inBytes[2] << 8)| inBytes[3];
		
		//rawTemp = NSSwapLittleShortToHost(rawTemp);
		
		stage = kStageHum;
		unsigned char buffer[8];
		
		bzero (buffer, 8);
		buffer[0] = 3;
		buffer[1] = 3;
		buffer[2] = 5;
		
		result = IOWarriorWriteToInterface(interface, 8, buffer);
		if (kIOReturnSuccess != result)
		{
			[self handleError:result];
			return;
		}		
		
	}
	else if (stage == kStageHum)
	{
		rawHum = (inBytes[2] << 8)| inBytes[3];
		//rawHum = NSSwapLittleShortToHost(rawHum);

		[self updateInterface];
	}
}

- (void) updateInterface
{
	
	
	if (interface)
	{
		float							temp = rawTemp;
		float							hum = rawHum;
		float							dewPoint;
		
		CalcTRH (&hum, &temp);
		dewPoint = calc_dewpoint(hum, temp);
		
		[tempField setStringValue:[NSString stringWithFormat:@"%.2f°C", temp]];
		[humField setStringValue:[NSString stringWithFormat:@"%.2f %%", hum]];
		[dewPointField setStringValue:[NSString stringWithFormat:@"%.2f°C", dewPoint]];

		[stateField setStringValue:@"IOWarrior found"];
	}
	else
	{
		[tempField setStringValue:@"--"];
		[humField setStringValue:@"--"];
		[dewPointField setStringValue:@"--"];

		[stateField setStringValue:@"IOWarrior not found"];
	}
}



@end

void CalcTRH(float *humidity, float *temperature)
{
	const float C1 = -4.0;              // for 12 Bit
	const float C2 = +0.0405;           // for 12 Bit
	const float C3 = -0.0000028;        // for 12 Bit
	const float T1 = +0.01;             // for 14 Bit @ 5V
	const float T2 = +0.00008;           // for 14 Bit @ 5V	
	
	float rh = *humidity;					// rh:      Humidity [Ticks] 12 Bit 
	float t = *temperature;				// t:       Temperature [Ticks] 14 Bit
	float rh_lin;							// rh_lin:  Humidity linear
	float rh_true;						// rh_true: Temperature compensated humidity
	float t_C;							// t_C   :  Temperature [∞C]
	
	t_C = t*0.01 - 40;						//calc. temperature from ticks to [∞C]
	rh_lin = C3*rh*rh + C2*rh + C1;			//calc. humidity from ticks to [%RH]
	rh_true = (t_C-25)*(T1+T2*rh)+rh_lin;		//calc. temperature compensated humidity [%RH]
	
	if(rh_true>100) rh_true = 100;		//cut if the value is outside of
	if(rh_true<0.1) rh_true = 0.1;		//the physical possible range
	
	
	*temperature = t_C;		//return temperature [∞C]
	*humidity = rh_true;		//return humidity[%RH]
}

float calc_dewpoint(float h,float t)
{ 
	float logEx,dew_point;
	logEx = 0.66077 + 7.5 * t / (237.3+t) + (log10(h) - 2);
	dew_point = (logEx - 0.66077) * 237.3 / (0.66077+7.5-logEx);
	
	return dew_point;
}
