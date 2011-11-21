#import "AppController.h"
#import "IOWarriorLib.h"
#import "IOWarriorUtils.h"
#import "Report.h"

void interruptCallback (void * target, IOReturn result, void * refcon,  void * sender,  uint32_t bufferSize)
{
	AppController	*controller = refcon;
	unsigned char	*buffer = target;
    
    NSLog (@"interruptCallback called");

	if ([controller isScanningForDevices]) // no error reported
	{
        if (buffer[0] == 3 && buffer[1] == 1)
        {
            [controller saveCurrentScanAddress];
        }
	}
	else if (buffer[0] == 3) // response to read command
	{
		int i = 0;
		NSMutableArray *receivedData = [NSMutableArray array];
		
		for (i = 0; i < bufferSize; i++)
		{
			[receivedData addObject:[NSNumber numberWithUnsignedChar:buffer[i]]];
		}
		[controller handleReadResponse:receivedData];
	}
	[controller performSelector:@selector(checkNextAddressForDevice)
					 withObject:nil
					 afterDelay:0.01];
}

void IOWarriorCallback (void* inRefCon)
/*" Invoked when an IOWarriorDevice appears or disappears. "*/
{
    AppController*   controller = inRefCon;
	
	NSLog (@"IOWarriorCallback invoked");
	[controller performSelector:@selector (discoverInterfaces)
					 withObject:nil
					 afterDelay:0.01];
} 

@interface AppController (Private)
	- (IOWarriorHIDDeviceInterface**) selectedInterface;
@end

@implementation AppController

@synthesize isScanningForDevices;

- (void) awakeFromNib
{	
	[mainTreeController addObserver:self
						 forKeyPath:@"selection"
							options:(NSKeyValueObservingOptionNew)
							context:@"myContext"];
	
	
	IOWarriorInit ();
	IOWarriorSetDeviceCallback(IOWarriorCallback, self);	
}

- (void) applicationDidFinishLaunching:(NSNotification*) inNotification
{
	[mainWindow makeFirstResponder:writeDataField];
    
    [self performSelector:@selector(discoverInterfaces)
               withObject:nil
               afterDelay:0.1];
    
	//[self discoverInterfaces];
}

- (void) dealloc
{
	[self setCurrentScanInterface: nil];
	[super dealloc];
}

- (void) discoverInterfaces
/*" Inserts currently available IOWarrior interfaces into popup menu. "*/
{
    int i, interfaceCount;
    NSMutableArray	*existingDeviceSerials = [NSMutableArray array];
		
	interfaceCount = IOWarriorCountInterfaces ();
	for (i = 0; i < interfaceCount; i++)
    {
		if (i % 2 != 1)
			continue;
		
        IOWarriorListNode* 	listNode;
		
        listNode = IOWarriorInterfaceListNodeAtIndex (i);
		if (NULL == listNode)
			continue;
		
		NSEnumerator	*e = [[foundInterfacesController arrangedObjects] objectEnumerator];
		NSDictionary	*deviceDict;
		BOOL			deviceDictFound = NO;
		
		// check if we already know this device
		while (nil != (deviceDict = [ e nextObject]))
		{
			if ([[deviceDict objectForKey:@"serial"] isEqualToString:(NSString*) listNode->serialNumber])
			{
				deviceDictFound = YES;
				break;
			}
		}
		// if it's a new device, add it
		if (NO == deviceDictFound)
		{
			NSString	*interfaceName = [IOWarriorUtils chipNameForIOWarriorInterfaceType:listNode->interfaceType];
			NSString	*displayName = [NSString stringWithFormat:@"%@ (%@)", interfaceName, listNode->serialNumber];
			BOOL		canDisablePullUpResistors;
			BOOL		canUseSensibus;
			
			canDisablePullUpResistors = (listNode->interfaceType == kIOWarrior24Interface1) ||
                                        (listNode->interfaceType == kIOWarrior56Interface1);
			canUseSensibus = (listNode->interfaceType == kIOWarrior24Interface1) ||
							 (listNode->interfaceType == kIOWarrior40Interface1);
            
            NSLog (@"found interface at %lu", listNode->ioWarriorHIDInterface);

			[foundInterfacesController addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
												  displayName, @"displayName",
												  interfaceName, @"type", 
												  listNode->serialNumber, @"serial", 
												  [NSNumber numberWithUnsignedLong: (unsigned long) listNode->ioWarriorHIDInterface], @"interfaceAddress", 
												  [NSMutableArray array], @"devices", 
												  [NSMutableArray array], @"writeHistory",
												  [NSMutableArray array], @"readHistory",
												  [NSNumber numberWithBool:YES], @"needsDeviceScan", 
												  [NSNumber numberWithBool:canDisablePullUpResistors], @"canDisablePullUpResistors",
												  [NSNumber numberWithBool:canUseSensibus], @"canUseSensibus", 
												  nil]];
		
		}
		[existingDeviceSerials addObject:(NSString*) listNode->serialNumber];
    }
	// remove device dictionaries for device no longer present on usb
	NSMutableArray	*dictionariesToRemove = [NSMutableArray array];
	NSEnumerator	*e = [[foundInterfacesController arrangedObjects] objectEnumerator];
	NSDictionary	*deviceDict;

	while (nil != (deviceDict = [ e nextObject]))
	{
		if (![existingDeviceSerials containsObject:[deviceDict objectForKey:@"serial"]])
		{
			[dictionariesToRemove addObject:deviceDict];
		}
		if (deviceDict == [self currentScanInterface])
		{
			[self setCurrentScanInterface:nil];
			[self setIsScanningForDevices:NO];
		}	
	}
	[foundInterfacesController setSelectedObjects:[NSArray array]];
	
	[foundInterfacesController removeObjects:dictionariesToRemove];
		
	if ([[foundInterfacesController arrangedObjects] count])
	{
		[foundInterfacesController setSelectionIndex:0];
	}
	
	[self scanNewInterfacesForDevices];
}

- (void) scanNewInterfacesForDevices
{	
	for (NSMutableDictionary *deviceDictionary in [foundInterfacesController arrangedObjects])
	{
		if ([[deviceDictionary objectForKey:@"needsDeviceScan"] boolValue] &&
			![[deviceDictionary objectForKey:@"sensibusEnabled"] boolValue])
		{
			[self selectInterfaceForDictionary:deviceDictionary];
			[self scanSelectedInterfaceForDevices];
			return;
		}
	}
}
			
- (void) selectInterfaceForDictionary:(NSDictionary*) interfaceDictionary
{
	int interfaceIndex = [[foundInterfacesController arrangedObjects] indexOfObject:interfaceDictionary];
	
	[mainTreeController setSelectionIndexPath:[NSIndexPath indexPathWithIndex:interfaceIndex]];

}
- (void) scanAllInterfacesForDevices
{
	NSEnumerator		*e = [[foundInterfacesController arrangedObjects] objectEnumerator];
	NSMutableDictionary *deviceDictionary;
	
	while (nil != (deviceDictionary = [ e nextObject ]))
	{
		if (![[deviceDictionary objectForKey:@"sensibusEnabled"] boolValue])
			[deviceDictionary setObject: [NSNumber numberWithBool:YES] forKey: @"needsDeviceScan"]; 
	}
	[self scanNewInterfacesForDevices];
}


- (void) scanSelectedInterfaceForDevices
{
	if (isScanningForDevices == YES)
		return;
	
	NSLog (@"starting address scan for device %@ ", [[self selectedInterfaceDictionary] objectForKey:@"serial"]);
	
	[self setCurrentScanInterface:[self selectedInterfaceDictionary]];
	
	while ([[foundDevicesController arrangedObjects] count])
		[foundDevicesController removeObjectAtArrangedObjectIndex:0];
	
	[foundDevicesController addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									   @"0x00", @"hexAddress",
									   [NSString stringWithFormat:@"%@ (%@)", @"0x00", @"Broadcast"], @"displayName",
									   [NSNumber numberWithUnsignedChar:0], @"address",
									   nil ]];
	
	NSMutableDictionary	*interfaceDict = [self selectedInterfaceDictionary];
	[interfaceDict setObject:[NSNumber numberWithBool:YES] 
					  forKey:@"canReadOrWrite"];
	
	
	// disable/ enable I2C
	char			buffer[64];
	int				result;
	
	bzero(buffer, sizeof(buffer));
	buffer[0] = 0x01;
	buffer[1] = 0x00;
	
	result = IOWarriorWriteToInterface ([self selectedInterface], sizeof(buffer), buffer);
	if (result != kIOReturnSuccess)
	{
		[self handleError:result];
        return;
	}
	
    sleep(1);
    
	bzero(buffer, sizeof(buffer));

	buffer[0] = 0x01;
	buffer[1] = 0x01;
	
	result = IOWarriorWriteToInterface ([self selectedInterface], sizeof(buffer), buffer);
	if (result != kIOReturnSuccess)
	{
		[self handleError:result];
        return;
	}
    sleep(1);

	currentScanAddress = 0;
    
    unsigned char				*interruptReportBuffer = malloc (64);
    
    result = IOWarriorSetInterruptCallback ([self selectedInterface], interruptReportBuffer, 64, 
                                   interruptCallback, (void*) self);
    if (result != kIOReturnSuccess)
	{
		[self handleError:result];
        return;
	}
    
	[self setIsScanningForDevices: YES];
	[self checkNextAddressForDevice];

}

- (IBAction) scanForDevices:(id) sender
{
	NSDictionary *interfaceDict = [self selectedInterfaceDictionary];

	if (![[interfaceDict objectForKey:@"sensibusEnabled"] boolValue])
		[self scanSelectedInterfaceForDevices];
}

- (NSMutableDictionary*) selectedInterfaceDictionary
{
	if ([[foundInterfacesController selectedObjects] count])
	{
		return [[foundInterfacesController selectedObjects] objectAtIndex:0];
	}
	return nil;
}

- (IOWarriorHIDDeviceInterface**) selectedInterface
{
	IOWarriorHIDDeviceInterface** result;
	int								i;
	
	result = (IOWarriorHIDDeviceInterface**) [[[self selectedInterfaceDictionary] objectForKey:@"interfaceAddress"] unsignedLongValue] ;
	
	//IOWarriorRebuildInterfaceList(); // pretend we need to rescan the bus
	
	for (i = 0; i < IOWarriorCountInterfaces(); i++)
	{
		IOWarriorListNode *listNode = IOWarriorListNodeForInterface(result);
		
		if (listNode == NULL)
		{
			NSLog (@"selected interface no longer exists, returning NULL");
			return NULL;
		}
	}
	
	return result;
}

- (void) checkNextAddressForDevice
{
	char				buffer[64];
	int					result;

	// exit if there is no scanning done at the moment
	if (NO == isScanningForDevices)
		return;
	
	currentScanAddress++;
	
	if (currentScanAddress > 127)
	{
		// we scanned the whole address space already
		[self setIsScanningForDevices: NO];
		[self setCurrentScanInterface:nil];
		
		NSMutableDictionary		*deviceDictionary = [self selectedInterfaceDictionary];

		NSLog (@"ended address scan for device %@", [deviceDictionary objectForKey:@"serial"]);

		[deviceDictionary removeObjectForKey:@"needsDeviceScan"];
		
		if ([[foundDevicesController arrangedObjects] count])
		{
			[foundDevicesController setSelectionIndex:0];
			
			unsigned int	path[2];
			
			path[0] = [foundInterfacesController selectionIndex];
			path[1] = 0;
			
			[mainTreeController setSelectionIndexPath:[NSIndexPath indexPathWithIndexes:path length:2]];
		}
		[self scanNewInterfacesForDevices];
		return;
	}
	else
	{
		NSLog (@"probing address 0x%02x for device %@ at %lu", currentScanAddress, [[self selectedInterfaceDictionary] objectForKey:@"serial"], [self selectedInterface]);
		// probe next address
		bzero(buffer, sizeof(buffer));
		
		buffer[0] = 0x03;
		buffer[1] = 0x01;
		buffer[2] = currentScanAddress << 1;
        buffer[2] = buffer[2] | 1;
		
		result = IOWarriorWriteToInterface ([self selectedInterface], sizeof(buffer), buffer);
		if (result != kIOReturnSuccess)
		{
			[self setIsScanningForDevices:NO];
			[self setCurrentScanInterface:nil];
			[[self selectedInterfaceDictionary] removeObjectForKey:@"needsDeviceScan"];
			[self handleError:result];
			[self scanNewInterfacesForDevices];
		}
	}
}

- (void) saveCurrentScanAddress
{	
	if (!isScanningForDevices)
		return;
	
	NSLog (@"saving address 0x%02x for device %@", currentScanAddress, [[self selectedInterfaceDictionary] objectForKey:@"serial"]);
	
	NSMutableDictionary *deviceDescription;
	NSString			*hexAddress;
	
	hexAddress = [NSString stringWithFormat:@"0x%2X", currentScanAddress];
	deviceDescription = [NSMutableDictionary dictionaryWithObjectsAndKeys:
														   hexAddress, @"hexAddress",
															[NSString stringWithFormat:@"%@ (0x%2X)", hexAddress, currentScanAddress << 1], @"displayName",
														   [NSNumber numberWithUnsignedChar:currentScanAddress], @"address",
														   nil ];
	[foundDevicesController addObject:deviceDescription];
	
	NSMutableDictionary	*interfaceDict = [self selectedInterfaceDictionary];
	[interfaceDict setObject:[NSNumber numberWithBool:YES] 
					  forKey:@"canReadOrWrite"];
}

- (IBAction) write:(id) sender
{
	NSScanner		*scanner = [NSScanner scannerWithString:[writeDataField stringValue]];
	unsigned		value = 0;
	int				signedValue = 0;
	NSMutableArray	*dataToWrite = [NSMutableArray array];
	NSMutableArray	*reportStrings = [NSMutableArray array]; // display representation of the sent data
	NSDictionary	*interfaceDict = [self selectedInterfaceDictionary];

	while (([self useHex] && [scanner scanHexInt:&value]) || [scanner scanInt:&signedValue])
	{
		if ([self useHex])
			[dataToWrite addObject:[NSNumber numberWithUnsignedInt:value]];
		else
			[dataToWrite addObject:[NSNumber numberWithInt:signedValue]];
	}
	if (0 == [dataToWrite count])
		return;
	
	
	// insert address of selected device for writing
	if ([[interfaceDict objectForKey:@"sensibusEnabled"] boolValue])
	{
		[dataToWrite insertObject:[NSNumber numberWithUnsignedChar:[self sensibusCommand]]
						  atIndex:0];
	}
	else
	{
		unsigned char device = [self selectedDeviceAddress];
		device = device << 1;
		[dataToWrite insertObject:[NSNumber numberWithUnsignedInt:device] atIndex:0];
	}
	
	// chop data into reports
	while ([dataToWrite count])
	{
		unsigned char reportData[8];
		
		bzero (reportData, 8);
		reportData[0] = 2;
		
		if (0 == [reportStrings count]) // we are constructing the first report, set start bit
			reportData[1] |= 0x80;
		if ([dataToWrite count] <= 6) // this is the last report in this block, set stop bit
		{
			reportData[1] |= 0x40;
		}
		if ([dataToWrite count] > 6) // set size bits
		{
			reportData[1] |= 6;
		}
		else
		{
			reportData[1] |= [dataToWrite count];
		}
		
		// fill in remaining six report bytes, if available
		
		int i = 2;
		
		while (i < 8 && [dataToWrite count])
		{
			reportData[i] = [[dataToWrite objectAtIndex:0] unsignedCharValue];
			[dataToWrite removeObjectAtIndex:0];
			i++;
		}
		
		// sent data to device
		int result;
		
		result = IOWarriorWriteToInterface([self selectedInterface], 8, reportData);
		if (kIOReturnSuccess != result)
		{
			[self handleError:result];
			return;
		}
		
		// construct display reprensentation of report data
		//NSString		*reportString = @"";
		NSMutableArray	*reportDataArray = [NSMutableArray array];
		
		for (i = 0; i < 8; i++)
		{
			[reportDataArray addObject:[NSNumber numberWithUnsignedChar:reportData[i]]];
			//reportString = [reportString stringByAppendingFormat:@"0x%02x ", reportData[i]];
		}
		
		Report *theReport = [[[Report alloc] init] autorelease];
		[theReport setReportData:reportDataArray];
		
		[reportStrings addObject:theReport];
	}
	
	// add report strings to write history
	
	[writeHistoryController addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									   [writeDataField stringValue], @"displayString",
									   reportStrings, @"reportStrings",
									   nil]];
}

- (unsigned char) selectedDeviceAddress
{
	if ([[foundDevicesController selectedObjects] count])
	{
		return [[[[foundDevicesController selectedObjects] objectAtIndex:0] objectForKey:@"address"] unsignedCharValue];
	}
	return 0;
}

- (IBAction) read:(id) sender
{
	unsigned char	reportData[8];
	NSDictionary	*interfaceDict = [self selectedInterfaceDictionary];
	int				result;

	bzero (reportData, 8);
	reportData[0] = 3;
	if (![self useHex])
	{
		reportData[1] = [readByteCountField intValue];
	}
	else
	{
		unsigned value;
		NSScanner *scanner = [NSScanner scannerWithString:[readByteCountField stringValue]];
		
		if (![scanner scanHexInt:&value])
			return;
		
		reportData[1] = value;
	}
	// insert address of selected device for writing
	if ([[interfaceDict objectForKey:@"sensibusEnabled"] boolValue])
	{
		reportData[2] = [self sensibusCommand];
	}
	else
	{
		reportData[2] = ([self selectedDeviceAddress] << 1) | 1;
	}
		
	result = IOWarriorWriteToInterface([self selectedInterface], 8, reportData);
	if (kIOReturnSuccess != result)
	{
		[self handleError:result];
		return;
	}
}

- (void) handleReadResponse:(NSArray*) inReadData
{
	Report		*theReport = [[[Report alloc] init] autorelease];
	
	[theReport setReportData:inReadData];
	[readDataDisplayStringsController addObject:theReport];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == mainTreeController)
	{
		if (0 == [[mainTreeController selectedObjects] count])
		{
			[foundInterfacesController setSelectedObjects:[NSArray array]];
		}
		else
		{
			NSDictionary *selectedObject = [[mainTreeController selectedObjects] objectAtIndex:0];
			
			if (nil != [selectedObject objectForKey:@"serial"])
			{
				// an interface was selected
				[foundInterfacesController setSelectedObjects:[NSArray arrayWithObject:selectedObject]];
			}
			else
			{
				// a device address was selected, select parent interface first
				NSIndexPath *path = [mainTreeController selectionIndexPath];
				
				[foundInterfacesController setSelectionIndex:[path indexAtPosition:0]];
				[foundDevicesController setSelectionIndex:[path indexAtPosition:1]];
			}
		}
	}
}

- (BOOL) useHex
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"useHex"];
}

- (void) setUseHex: (BOOL) flag
{
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"useHex"];
	
	[writeHistoryOutlineView reloadData];
	[readHistoryTableView reloadData];
}

- (IBAction) interfaceOptionsChanged:(id) sender
{
	char			buffer[8];
	NSMutableDictionary	*interfaceDict = [self selectedInterfaceDictionary];
	int					result;

	if (nil == interfaceDict)
		return;
	
	bzero(buffer, sizeof(buffer));
	
	// disable I2C
	buffer[0] = 0x01;
	buffer[1] = 0x00;
	
	result = IOWarriorWriteToInterface ([self selectedInterface], sizeof(buffer), buffer);
	if (result != kIOReturnSuccess)
	{
		[self handleError:result];
		return;
	}
	
	// enable I2C with current options
	bzero(buffer, sizeof(buffer));
	buffer[0] = 0x01;
	buffer[1] = 0x01;
	
	if ([[interfaceDict objectForKey:@"pullUpResistorsDisabled"] boolValue])
	{
		buffer[2] |= (1 << 7);
	}
	if ([[interfaceDict objectForKey:@"sensibusEnabled"] boolValue])
	{
		buffer[2] |= (1 << 6);
	}
	if ([[interfaceDict objectForKey:@"timeOut"] length])
	{
		buffer[3] = [[interfaceDict objectForKey:@"timeOut"] intValue];
	}
	result = IOWarriorWriteToInterface ([self selectedInterface], sizeof(buffer), buffer);
	if (result != kIOReturnSuccess)
	{
		[self handleError:result];
		return;
	}

	[interfaceDict setObject:[interfaceDict objectForKey:@"sensibusEnabled"] forKey:@"canReadOrWrite"];
}

- (unsigned char) sensibusCommand
{
	NSString *string = [sensibusCommandField stringValue];
	
	if ([self useHex])
	{
		NSScanner *scanner = [NSScanner scannerWithString:string];
		unsigned value = 0;
		
		[scanner scanHexInt:&value];
		
		return value;
	}
	return [string intValue];
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
	if (control == writeDataField)
	{
		[writeActionButton setKeyEquivalent:@"\r"];
		[readActionButton setKeyEquivalent:@""];
	}
	else if (control == readByteCountField)
	{
		[writeActionButton setKeyEquivalent:@""];
		[readActionButton setKeyEquivalent:@"\r"];

	}
	return YES;
}

- (void) handleError:(OSStatus) inErr
{
	NSLog (@"displaying panel for error %d", inErr);
	NSRunCriticalAlertPanel(@"Write Error", @"An error occured while writing to the selected IOWarrior interface. Error code: %d", @"OK", nil, nil, inErr); 
	return;
}

- (NSDictionary *) currentScanInterface
{
    return currentScanInterface; 
}

- (void) setCurrentScanInterface: (NSDictionary *) inCurrentScanInterface
{
    if (currentScanInterface != inCurrentScanInterface) {
        [currentScanInterface autorelease];
        currentScanInterface = [inCurrentScanInterface retain];
    }
}

@end
