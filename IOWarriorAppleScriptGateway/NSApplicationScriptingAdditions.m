//
//  NSApplicationScriptingAdditions.m
//  IOWarriorAppleScriptGateway
//
//  Created by ilja on Fri Jan 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "NSApplicationScriptingAdditions.h"
#import "IOWarriorLib.h"
#import "IOWarriorPin.h"

// Protptypes
UInt32				swaplong (UInt32 number);

IOWarriorListNode*	myDiscoverInterface0 (void);
IOWarriorListNode*	myDiscoverInterface1 (void);
//int					MyWriteInterface1 (int reportID, void* inData);

int					reportSizeForInterface(IOWarriorListNode* inNode);


#define kMaxPinCount 56

#define kMaxReportSize 64


@implementation NSApplication (ScriptingAdditions)

NSArray*		gPins = nil;	// pins values used for communication with apple script
int				gLastReadTime = 0; // the last time interface 0 pin values have been read
int				gUserChangedPinValues = NO;
NSMutableArray* gInterface0Buffer = nil;
NSTimer*		gBufferedReadTimer = nil;


-(id) handleIsIOWarriorPresentCommand:(NSScriptCommand *) command
{
    return [NSNumber numberWithBool:IOWarriorIsPresent ()];
}

-(id) handleWriteInterface0Command:(NSScriptCommand *) command
{
    int					result = 1;
	IOWarriorListNode   *theInterface;
	
	if (nil != (theInterface = myDiscoverInterface0 ()))
	{
		int				i;
		int				bufferSize;
		unsigned char 	*buffer;
		
		bufferSize = reportSizeForInterface (theInterface) ;
		buffer = malloc (bufferSize);
		bzero (buffer, bufferSize);
		for (i = 0; i < bufferSize; i++)
		{
			NSNumber* tempRef;

			tempRef = [[command arguments] objectForKey:[NSString stringWithFormat:@"port%d", i]];
			if (tempRef)
				buffer[i] = [tempRef intValue];
		}
		result = IOWarriorWriteToInterface (theInterface->ioWarriorHIDInterface, bufferSize, buffer);
		free (buffer);
	}
	return [NSNumber numberWithInt:result];
}

-(id) handleWriteInterface1Command:(NSScriptCommand *) command
{
    int					reportID = [[[command arguments] objectForKey:@"reportId"] intValue];
	IOWarriorListNode   *theInterface;
	int					bufferSize;
    char				*buffer;
    int					i;
	id					result = nil;

	theInterface = myDiscoverInterface1();
	
	if (nil != theInterface)
	{
		bufferSize = reportSizeForInterface(theInterface);
		buffer = malloc (bufferSize);
		bzero (buffer, bufferSize);
		buffer[0] = reportID;
		for (i = 0; i < bufferSize - 1; i++)
		{
			NSNumber* tempRef;

			tempRef = [[command arguments] objectForKey:[NSString stringWithFormat:@"byte%d", i]];
			if (tempRef)
			{
				buffer[i + 1] = [tempRef intValue]; // first byte is reserved for report id
			}
		}
		result = [NSNumber numberWithInt:IOWarriorWriteToInterface(theInterface->ioWarriorHIDInterface,
																   bufferSize,
																   buffer)];
		free (buffer);
	}
	return result;
}

-(id) handleReadInterface0Command:(NSScriptCommand *) command
{
    NSNumber			*swapBytes;
    NSMutableArray		*result = [NSMutableArray array];
    int					i;
	IOWarriorListNode*  listNode;
	int					reportSize = 0;
	char				*buffer;
    
    swapBytes = [[command arguments] objectForKey:@"swap bytes"];
	
	listNode = myDiscoverInterface0 ();
	
	if (listNode == NULL)
		return nil;
	
	reportSize = reportSizeForInterface(listNode);
	buffer = malloc (reportSize);
	
    if (nil != gInterface0Buffer)
    {
        // we are in buffered mode, return earliest read value, if existant
        if ([gInterface0Buffer count])
        {
            NSData* data = [gInterface0Buffer objectAtIndex:0];
            
            memcpy(buffer,[data bytes],reportSize);
				[gInterface0Buffer removeObjectAtIndex:0];
        }
        else
		{
			free (buffer);
            return nil;
		}
    }
    else
    {
		if (IOWarriorReadFromInterface(listNode->ioWarriorHIDInterface,0,reportSize,buffer) != noErr)
		{
			free (buffer);
            return nil;
		}
			    
	}
	/*
    if (swapBytes != nil)
    {
        data = swaplong (data);
    }
	 */
    for (i = 0; i < reportSize; i++)
    {
		int value = buffer[i];
		
        [result addObject:[NSNumber numberWithInt:value]];
    }
	free (buffer);
    return result;
}

- (id) handleReadInterface1Command:(NSScriptCommand *) command
{
    int					reportID;
    NSNumber			*reportIDRef = [[command arguments] objectForKey:@"reportId"];
    char				buffer[7];
    NSMutableArray* 	result = [NSMutableArray array];

    if (nil != (reportIDRef =[[command arguments] objectForKey:@"reportId"]))
    {
        int i;
        
        reportID = [reportIDRef intValue];
        if (0 != IOWarriorReadInterface1 (reportID, buffer))
            return result;

        for (i = 0; i < 7; i++)
        {
            [result addObject:[NSNumber numberWithInt:buffer[i]]];
        }
    }
    return result;
}


- (NSArray*) pins
{    
   if (NULL == gPins)
   {
       gPins = [self buildPinArray];
       [gPins retain];
   }

   if (NO == gUserChangedPinValues)
       [self readPinArrayValues];
    
    return gPins;
}

/*" Returns an array of 32 IOWarrior pin objects. "*/
- (NSArray*) buildPinArray
{
    NSMutableArray *pins = [NSMutableArray array];
    int i;

    for (i = 0; i< kMaxPinCount; i++)
    {
        IOWarriorPin* pin = [[IOWarriorPin alloc] initWithValue:0 index:i];
        [pins addObject:pin];
		[pin release];
    }

    return [NSArray arrayWithArray:pins];
}


- (void) readPinArrayValues
/*" Updates the global pin array with values read from the IOWarrior. "*/
{
	IOWarriorListNode*  listNode;
	
	if (nil != (listNode = myDiscoverInterface0()))
	{
		int		reportSize;
		int		i;
		char	*buffer;

		
		reportSize = reportSizeForInterface(listNode);
		buffer = malloc (reportSize);
		if (noErr == IOWarriorReadFromInterface (listNode->ioWarriorHIDInterface, 0, reportSize, buffer))
		{
			for (i = 0; i < reportSize * 8; i++)
			{
				IOWarriorPin* pin = [gPins objectAtIndex:i];
				int	port = [self portForPinIndex:i reportSize:reportSize];
				int portPin = [self portPinForPinIndex:i];
				
				if (buffer[port] & (1 << portPin))
				{
					[pin setValueWithoutWriteBack:1];
				}
				else
				{
					[pin setValueWithoutWriteBack:0];
				}
			}
		}
		free (buffer);
	}
}

/*" Timed selector. Scheduled when user changes a pin value. Writes current pin values back to the IOWarrior."*/

- (void) writeBack:(NSTimer*) inTimer
{
	IOWarriorListNode *listNode = myDiscoverInterface0();

    if (NULL != gPins && NULL != listNode)
    {
		int		i;
		char*	buffer;
		int		reportSize = reportSizeForInterface(listNode);
		
		buffer = malloc (reportSize);
		bzero (buffer, reportSize);

		for (i = 0; i < reportSize * 8; i++)
		{
			IOWarriorPin* pin = [gPins objectAtIndex:i];
	
			if ([pin value])
			{
				int	port = [self portForPinIndex:i reportSize:reportSize];
				int portPin = [self portPinForPinIndex:i];
				
				buffer[port] = buffer[port] | (1 << portPin);
			}
		}
		IOWarriorWriteToInterface (listNode->ioWarriorHIDInterface, reportSize, buffer);
    }
    gUserChangedPinValues = false;
}

- (int) portForPinIndex:(int) pinIndex reportSize:(int) reportSize
{
	return (reportSize - 1) - (pinIndex / 8);
}

- (int) portPinForPinIndex:(int) pinIndex
{
	return (pinIndex % 8);
}

- (id) startBufferedReading:(NSScriptCommand *) command
{
    if (nil == gInterface0Buffer)
    {
        gInterface0Buffer = [[NSMutableArray alloc] init];
        gBufferedReadTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                         target:self
                                       selector:@selector(bufferedReadInterface0)
                                       userInfo:nil
                                        repeats:YES];
    }

    return [NSNumber numberWithInt:0];
}

- (id) stopBufferedReading:(NSScriptCommand *) command
{
    [gBufferedReadTimer invalidate];
	[gInterface0Buffer release];
    gInterface0Buffer = nil;

    return [NSNumber numberWithInt:0];
}

- (id) handleReadBufferSize:(NSScriptCommand*) command
{
    NSUInteger result = 0;
    
    if (gInterface0Buffer != nil)
    {
        result = [gInterface0Buffer count];
    }

    return @(result);
}

- (void) bufferedReadInterface0
/*" Selector invoked by timer when buffered reading is enabled. "*/
{
    int					status;
    char				*buffer;
	IOWarriorListNode   *node;
	int					reportSize;

    NSAssert (gInterface0Buffer, @"read buffer array cannot be nil here");
	if (nil == (node = myDiscoverInterface0 ()))
		return;
	
	reportSize = reportSizeForInterface (node);
	buffer = malloc (reportSize);
    status = IOWarriorReadFromInterface (node->ioWarriorHIDInterface, 0, reportSize, buffer);
    if (status == noErr)
    {
		NSData *data = [NSData dataWithBytes:buffer
									  length:reportSize];
		if (!([gInterface0Buffer count] &&
			  [[gInterface0Buffer lastObject] isEqualTo:data]))
		{
			[gInterface0Buffer addObject:data];
		}
	}
	free (buffer);
}

@end

/*" Swaps the byte order of a 4 byte integer "*/
UInt32 swaplong (UInt32 number)
{
    UInt32	  	result = 0;
    char*		ptrToSrc = (char*) &number;
    char*		ptrToDest = (char*) &result;
    int			i;

    for (i= 0; i < 4; i++)
    {
        ptrToDest[i] = ptrToSrc[3 - i];
    }

    return result;
}
	
IOWarriorListNode* myDiscoverInterface1 ()
{
	int i;
	
	for (i = 0; i < IOWarriorCountInterfaces (); i++)
	{
		IOWarriorListNode   *listNode;
		
		listNode = IOWarriorInterfaceListNodeAtIndex (i);
		if ((listNode->interfaceType == kIOWarrior40Interface1) ||
			(listNode->interfaceType == kIOWarrior24Interface1) ||
			(listNode->interfaceType == kIOWarrior24PVInterface1) ||
			(listNode->interfaceType == kIOWarrior56Interface1))
		{
			return listNode;
		}
	}
	
	return NULL;
}

IOWarriorListNode* myDiscoverInterface0 ()
{
	int i;
	
	for (i = 0; i < IOWarriorCountInterfaces (); i++)
	{
		IOWarriorListNode   *listNode;
		
		listNode = IOWarriorInterfaceListNodeAtIndex (i);
		if ((listNode->interfaceType == kIOWarrior40Interface0) ||
			(listNode->interfaceType == kIOWarrior24Interface0 ||
			listNode->interfaceType == kIOWarrior24PVInterface0 ||
			listNode->interfaceType == kIOWarrior56Interface0))
		{
			return listNode;
		}
	}
	return NULL;
}

int reportSizeForInterface(IOWarriorListNode* inNode)
	/*" Returns the size of a report written to an interface of type inType. For interfaces of type 1 the report byte is included in the result "*/
{
    int result = 0;
    
    switch (inNode->interfaceType)
    {
        case kIOWarrior40Interface0: result = 4; break;
        case kIOWarrior40Interface1: result = 8; break;
			
        case kIOWarrior24Interface0: result = 2; break;
        case kIOWarrior24Interface1: result = 8; break;
			
		case kIOWarrior24PVInterface0: result = 2; break;
        case kIOWarrior24PVInterface1: result = 8; break;
			
		case kIOWarrior56Interface0: result = 7; break;
        case kIOWarrior56Interface1: result = 64; break;
    }
    return result;
}
