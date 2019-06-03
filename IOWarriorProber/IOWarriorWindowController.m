#import "IOWarriorWindowController.h"
#import "IOWarriorLib.h"
#import "MacroNamePanelController.h"
#import "IOWarriorUtils.h"

void reportHandlerCallback (void *	 		target,
                            IOReturn                     result,
                            void * 			refcon,
                            void * 			sender,
                            UInt32		 	bufferSize);

@implementation IOWarriorWindowController

static NSString* kReportDirectionIn = @"R";
static NSString* kReportDirectionOut = @"W";

static NSString* kReportDirectionKey = @"R/W";
static NSString* kReportIDKey = @"Id";
static NSString* kReportDataKey = @"data";

static NSString* kMacroNameKey = @"name";
static NSString* kDefaultMacrosKey = @"default macros";

IOWarriorWindowController* gWindowController = nil;

void IOWarriorCallback ()
/*" Called when IOWarrior is added or removed. "*/
{
    [gWindowController populateInterfacePopup];
}

/*" Invoked when the nib file including the window has been loaded. "*/
- (void) awakeFromNib
{
    // set the global ptr to the main window controller to self, needed for iowarrior callbacks
    gWindowController = self;
    
    // init the IOWarrior library
    IOWarriorInit ();
    IOWarriorIsPresent (); // builds the list of available IOWarrior interface, speeds up library operations
    IOWarriorSetDeviceCallback (IOWarriorCallback, nil);
    isReading = false;
    ignoreDuplicates = YES;
    
    [self populateInterfacePopup];
    [self interfacePopupChanged:self];
    [self tableViewSelectionDidChange:nil];
    logEntries = [[NSMutableArray alloc] init];
    [logTable setTarget:self];
    [logTable setDoubleAction:@selector(logTableDoubleClicked)];
    // populate macropopup
    [self updateMacroPopup];
    [ignoreDuplicatesCheckBox setState:ignoreDuplicates];
}

- (void) dealloc
{
    [logEntries release];
    [lastValueRead release];
    [super dealloc];
}


- (void) populateInterfacePopup
/*" Inserts currently available IOWarrior interfaces into popup menu. "*/
{
    NSInteger i, interfaceCount;

    [interfacePopup removeAllItems];
    interfaceCount = IOWarriorCountInterfaces ();

    NSLog (@"populateInterfacePopup, interfaces counted: %ld", interfaceCount);

    [interfacePopup setEnabled:0 != interfaceCount];

    for (i = 0; i < interfaceCount; i++)
    {
        IOWarriorListNode*     listNode;
        NSString*              title;

        listNode = IOWarriorInterfaceListNodeAtIndex (i);
        title = [NSString stringWithFormat:@"%@ (SN %@)", [IOWarriorUtils nameForIOWarriorInterfaceType:listNode->interfaceType],
                 listNode->serialNumber];
        [interfacePopup addItemWithTitle:title];
    }
    [self interfacePopupChanged:self];
}

/*" Invoked when user hits 'Write"-Button. "*/
- (IBAction)doWrite:(id)sender
{
    unsigned char*                  buffer;
    int                             i;
    int                             result = 0;
    int                             reportID = -1;
    IOWarriorListNode*              listNode;
    int                             reportSize;

    if (NO == IOWarriorIsPresent ())
    {
        NSRunAlertPanel (@"IOWarrior not found", @"There is no IOWarrior device attached to you mac.", @"OK", nil, nil);
        return;
    }
    reportSize = [self reportSizeForInterfaceType:[self currentInterfaceType]];
    buffer = malloc (reportSize);
    for (i = 0 ; i < reportSize ; i++)
    {
        NSControl *theSubview;
        NSScanner *theScanner;
		int	  value;
        
        theSubview = (NSControl*) [[window contentView] viewWithTag:i + 100];

        theScanner = [NSScanner scannerWithString:[theSubview stringValue]];
        if ([theScanner scanHexInt:(unsigned int*) &value])
        {
            buffer[i] = (char) value;
        }
        else
        {
            NSRunAlertPanel (@"Invalid data format", @"Please only use hex values between 00 and FF.", @"OK", nil, nil);
            free (buffer);
            return;
        }
    }
    
    listNode = IOWarriorInterfaceListNodeAtIndex ([interfacePopup indexOfSelectedItem]);
    if (listNode)
    {
        if (![self reportIdRequiredForWritingToInterfaceOfType:listNode->interfaceType])
        {
            result = IOWarriorWriteToInterface (listNode->ioWarriorHIDInterface, reportSize, buffer);
        }
        else
        {
            if ([[NSScanner scannerWithString:[reportIDField stringValue]] scanHexInt:(unsigned int*) &reportID])
            {
                char tempBuffer[reportSize + 1];
    
                tempBuffer[0] = reportID;
    
                memcpy (&tempBuffer[1], buffer, reportSize);
                
                result = IOWarriorWriteToInterface (listNode->ioWarriorHIDInterface, reportSize + 1, tempBuffer);
            }
            else
            {
                NSRunAlertPanel (@"Invalid report id number format", @"Please only use hex values between 00 and FF.", @"OK", nil, nil);
            }
        }
        
        if (0 != result)
            NSRunAlertPanel (@"IOWarrior Error", @"An error occured while trying to write to the selected IOWarrior device.", @"OK", nil, nil);
        else
        {
            [self addLogEntryWithDirection:kReportDirectionOut
                                reportID:reportID
                                reportSize:reportSize
                                reportData:buffer];
        }
    }
    free (buffer);
}

/*" Invoked when user hits 'Read'-button. "*/
- (IBAction)doRead:(id)sender
{
    if (isReading)
    {
        [self stopReading];
    }
    else
    {
        [self startReading];
    }
}

- (void) stopReading
{
    [readButton setTitle:@"Read"];
    isReading = NO;
}

- (void) startReading
{
    IOWarriorListNode* 	listNode;
    
    listNode = IOWarriorInterfaceListNodeAtIndex ([interfacePopup indexOfSelectedItem]);
    if (nil == listNode) // if there is no interface, exit and don't invoke timer again
        return;
    
    if (listNode->interfaceType == kIOWarrior24Interface0 ||
        listNode->interfaceType == kIOWarrior40Interface0 ||
		listNode->interfaceType == kIOWarrior56Interface0 ||
		listNode->interfaceType == kIOWarrior24PVInterface0 ||
		listNode->interfaceType == kIOWarrior24CWInterface0 ||
        listNode->interfaceType == kJoyWarrior24F8Interface0 ||
        listNode->interfaceType == kMouseWarrior24F6Interface0 ||
        listNode->interfaceType == kJoyWarrior24F14Interface0 ||
         listNode->interfaceType == kJoyWarrior24F14Interface1)
    {
        // if user has selected some kind of interface0, read every 0.05 seconds using getReport request
        [self setLastValueRead:nil];
        [readButton setTitle:@"Stop Reading"];
        // read immediatly
		isReading = YES;
		[self timedRead:nil]; 
	}
    else
    {
        // we have somd kind of interface1, install interrupt handler
        char* buffer;
		int	 size = 8;
        
		if (listNode->interfaceType == kIOWarrior24Interface1 ||
			listNode->interfaceType == kIOWarrior40Interface1 ||
			listNode->interfaceType == kIOWarrior24PVInterface1 ||
			listNode->interfaceType == kIOWarrior24CWInterface1 ||
            listNode->interfaceType == kJoyWarrior24F8Interface1 ||
            listNode->interfaceType == kMouseWarrior24F6Interface1 ||
            listNode->interfaceType == kJoyWarrior24F14Interface1)
		{
			size = 8;
		}
		else if (listNode->interfaceType == kIOWarrior56Interface1)
		{
			size = 64;
        } else if (listNode->interfaceType == kIOWarrior28Interface0){
            size = 4;
        }
		buffer = malloc(size);
        IOWarriorSetInterruptCallback(listNode->ioWarriorHIDInterface, buffer, size, reportHandlerCallback, self);
    }
}

void reportHandlerCallback (void *	 		target,
                   IOReturn                     result,
                   void * 			refcon,
                   void * 			sender,
                   UInt32		 	bufferSize)
{    
    if (kIOReturnSuccess == result)
    {
        int                         reportID = -1;
        NSData*                     dataRead;
        char*                       buffer = (char*) target;
        IOWarriorWindowController*  controller = refcon;

        reportID = buffer[0];
        dataRead = [NSData dataWithBytes:buffer length:bufferSize];
      //  if (!ignoreDuplicates || (ignoreDuplicates && ![dataRead isEqualTo:lastValueRead]))
        //{
            [controller addLogEntryWithDirection:kReportDirectionIn
                                  reportID:reportID
                                reportSize:bufferSize
                                reportData:(unsigned char*) &buffer[0]];
            [controller setLastValueRead:dataRead];
       // }
    }
}


- (void) timedRead:(NSTimer*) inTimer
{
	if (YES == [self readDataFromCurrentInterface])
	{
		if (isReading)
		{
			readTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(timedRead:) userInfo:nil repeats:NO];
		}
	}
	else
	{
		[self stopReading];
	}
}

- (BOOL)readDataFromCurrentInterface
{
    UInt8*		buffer;
    int	 		result = 0;
    int 		reportID = -1;
    NSData*		dataRead;
    IOWarriorListNode* 	listNode;
    int                 reportSize;

    listNode = IOWarriorInterfaceListNodeAtIndex ([interfacePopup indexOfSelectedItem]);
    if (nil == listNode) // if there is no interface, exit and don't invoke timer again
        return NO;
    
    reportSize = [self reportSizeForInterfaceType:listNode->interfaceType];
    if (listNode->interfaceType == kIOWarrior24Interface0 ||
        listNode->interfaceType == kIOWarrior28Interface0 ||
        listNode->interfaceType == kIOWarrior40Interface0 ||
		listNode->interfaceType == kIOWarrior56Interface0 ||
		listNode->interfaceType == kIOWarrior24PVInterface0 ||
        listNode->interfaceType == kJoyWarrior24F8Interface0 ||
        listNode->interfaceType == kMouseWarrior24F6Interface0 ||
        listNode->interfaceType == kJoyWarrior24F14Interface0 ||
        listNode->interfaceType == kJoyWarrior24F14Interface1)
    {
    
        buffer = malloc (reportSize);
        
        result = IOWarriorReadFromInterface (listNode->ioWarriorHIDInterface, 0, reportSize, buffer);

        if (result != 0)
        {
            NSRunAlertPanel (@"IOWarrior Error", @"An error occured while trying to read from the selected IOWarrior device.", @"OK", nil, nil);
            free (buffer);
            return NO;
        }
        dataRead = [NSData dataWithBytes:buffer length:reportSize];
        if (!ignoreDuplicates || (ignoreDuplicates && ![dataRead isEqualTo:lastValueRead]))
        {
            [self addLogEntryWithDirection:kReportDirectionIn
                                reportID:reportID
                                reportSize:reportSize
                                reportData:buffer];
            [self setLastValueRead:dataRead];
        }
        free (buffer);
    }
	return YES;
}

- (int) reportSizeForInterfaceType:(int) inType
/*" Returns the size of an output report written to an interface of type inType exluding size for report id. "*/
{
    int result = 0;
    
    switch (inType)
    {
        case kIOWarrior40Interface0:
        case kIOWarrior28Interface0:
			result = 4; 
		break;
		
        case kIOWarrior40Interface1:
			result = 7;
		break;
        
		case kIOWarrior24Interface0: 
		case kIOWarrior24PVInterface0:
		case kIOWarrior24CWInterface0:
			result = 2;
		break;
		
        case kIOWarrior24Interface1: 
		case kIOWarrior24PVInterface1:
		case kIOWarrior24CWInterface1:
			result = 7;
		break;
		
		case kIOWarrior56Interface0: 
			result = 7;
		break;
		
		case kIOWarrior56Interface1:
        case kIOWarrior28Interface1:
        case kIOWarrior28Interface2:
        case kIOWarrior28Interface3:
			result = 63;
		break;
            
        case kJoyWarrior24F8Interface1:
        case kMouseWarrior24F6Interface1:
        case kJoyWarrior24F14Interface1:
            result = 8;
        break;
            
        case kJoyWarrior24F8Interface0:
        case kMouseWarrior24F6Interface0:
        case kJoyWarrior24F14Interface0:
            result = 8;
        break;
    }
    return result;
}

- (BOOL) reportIdRequiredForWritingToInterfaceOfType:(int) inType
/*" Returns YES if interfaces of type inType can take an report id different from 0 when writing output reports. "*/
{
    BOOL result = NO;
    
    switch (inType)
    {
        case kIOWarrior40Interface0:
        case kIOWarrior24Interface0:
		case kIOWarrior24PVInterface0:
		case kIOWarrior24CWInterface0:
		case kIOWarrior56Interface0:
        case kJoyWarrior24F8Interface0:
        case kMouseWarrior24F6Interface0:
        case kJoyWarrior24F14Interface0:
        case kJoyWarrior24F8Interface1:
        case kMouseWarrior24F6Interface1:
        case kJoyWarrior24F14Interface1:
        case kIOWarrior28Interface0:
            result = NO;
        break;
            
        case kIOWarrior40Interface1:
        case kIOWarrior24Interface1:
		case kIOWarrior24PVInterface1:
		case kIOWarrior24CWInterface1:
		case kIOWarrior56Interface1:
        case kIOWarrior28Interface1:
        case kIOWarrior28Interface2:
        case kIOWarrior28Interface3:
            result = YES;
        break;
    }
    return result;
}

- (int) currentInterfaceType
/*" Returns the type of the currently selected interface. "*/
{
    int selectedInterface = [interfacePopup indexOfSelectedItem];
    
    if (-1 != selectedInterface && (selectedInterface < IOWarriorCountInterfaces ()))
        return (IOWarriorInterfaceListNodeAtIndex (selectedInterface))->interfaceType;
    
    return -1;
}

- (IOWarriorHIDDeviceInterface**) currentInterface
/*" Returns the currently selected interfaces. "*/
{
    int selectedInterface = [interfacePopup indexOfSelectedItem];
    
    if (-1 != selectedInterface && (selectedInterface < IOWarriorCountInterfaces ()))
        return (IOWarriorInterfaceListNodeAtIndex (selectedInterface))->ioWarriorHIDInterface;
    
    return nil;
}

- (IBAction)interfacePopupChanged:(id)sender
{
    int currentType = [self currentInterfaceType];
    int newReportSize = [self reportSizeForInterfaceType:currentType];
    int	i;
        
    // disable or enable report data text field and captions
    for (i = 100; i <= 162; i++)
    {
        NSTextField* subview;
        BOOL        state;
        
        if (i < 100 + newReportSize)
            state = YES;
        else
            state = NO;
        
        subview = (NSTextField*)[[window contentView] viewWithTag:i];
        NSAssert (subview, @"could't get subview for tag");
        [subview setEnabled:state];
        if (state)
            [subview setStringValue:@"00"];
        else
            [subview setStringValue:@"--"];
        
		/*
        subview = (NSTextField*)[[window contentView] viewWithTag:i + 100];
        NSAssert (subview, @"could't get subview for tag");
        if (state)
            [subview setTextColor:[NSColor blackColor]];
        else
            [subview setTextColor:[NSColor grayColor]];
		*/
    }
    [reportIDField setEnabled: ([self reportIdRequiredForWritingToInterfaceOfType:currentType] ? YES : NO)];
}

- (void) addLogEntryWithDirection:(NSString*) inDirection reportID:(int) inReportID reportSize:(int) inSize reportData:(UInt8*) inData
{
    NSDictionary *entry;

    entry = [IOWarriorWindowController logEntryWithDirection:inDirection
                                                    reportID:inReportID
                                                  reportSize:inSize
                                                  reportData:inData
                                                        name:@""];
    [logEntries addObject:entry];
    [logTable reloadData];
    [logTable scrollRowToVisible:[logEntries count] - 1];
}

+ (NSDictionary*) logEntryWithDirection:(NSString*) inDirection reportID:(int) inReportID reportSize:(int) inSize reportData:(UInt8*) inData
                                   name:(NSString*) inName;
{
    NSMutableDictionary *entry;

    entry = [NSMutableDictionary dictionary];
    [entry setObject:inDirection forKey:kReportDirectionKey];
    [entry setObject:[NSNumber numberWithInt:inReportID] forKey:kReportIDKey];
    [entry setObject:[NSData dataWithBytes:inData length:inSize] forKey:kReportDataKey];
    [entry setObject:inName forKey:kMacroNameKey];

    return [NSDictionary dictionaryWithDictionary:entry];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [logEntries count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    NSDictionary* entry = [logEntries objectAtIndex:rowIndex];
    id 		result;
    int		reportID = [[entry objectForKey:kReportIDKey] intValue];
    id		rowIdentifier = [aTableColumn identifier];

    if (nil != (result = [entry objectForKey:rowIdentifier]))
    {
        if ([rowIdentifier isEqualTo:kReportIDKey] && reportID == -1)
            return @"";
        else if ([rowIdentifier isEqualTo:kReportIDKey])
            return [NSString stringWithFormat:@"0x%02x", reportID];
        else
            return result;
    }
    else //
    {
        NSData* data = [entry objectForKey:kReportDataKey];
        char*	buffer = (char*) [data bytes];
		
		if ([data length])
		{
			NSMutableString *string = [NSMutableString string];
			int				i;
			
			for (i = 0; i < [data length]; i++)
			{
				[string appendString:[NSString stringWithFormat:@"%02x ", (UInt8) buffer[i]]];
			}
			return [NSString stringWithString:string];
		}
        else
            return @"";
    }
}

- (void)logTableDoubleClicked
{
    int index = [logTable selectedRow];

    if (-1 != index)
    {
        NSDictionary* logEntry = [logEntries objectAtIndex:index];

        [self updateInterfaceFromLogEntry:logEntry];
    }
}

- (void) updateInterfaceFromLogEntry:(NSDictionary*) inLogEntry
{
    if ([[inLogEntry objectForKey:kReportDirectionKey] isEqualTo:kReportDirectionOut])
    {
        int 	reportID = [[inLogEntry objectForKey:kReportIDKey] intValue];
        NSData* reportData = [inLogEntry objectForKey:kReportDataKey];
        int	i;
        UInt8* 	bytes = (UInt8*) [reportData bytes];
        
        if (reportID != -1)
        {
            [reportIDField setStringValue:[NSString stringWithFormat:@"%02x",reportID]];
        }
        for (i = 0; i < ((reportID == -1)?4:7); i++)
        {
            NSControl* theSubview;
            
            theSubview = (NSControl*) [[window contentView] viewWithTag:i + 100];
            [theSubview setStringValue:[NSString stringWithFormat:@"%02x",bytes[i]]];
        }
    }
}

- (void) setLastValueRead:(NSData*) inData
{
    [inData retain];
    [lastValueRead release];
    lastValueRead = inData;
}

- (IBAction)clearLogEntries:(id)sender
{
    [logEntries removeAllObjects];
    [logTable reloadData];
}

/*" Invoked by the runtime system before a message is sent to any object of the class. Initializes default preferences. "*/
+ (void) initialize
{
    NSMutableDictionary* 	defaultValues;
    NSMutableArray*		defaultMacros;
    NSDictionary*		entry;
    UInt8			buffer[7];
    
    
    defaultValues = [NSMutableDictionary dictionary];
    defaultMacros = [NSMutableArray array];

    // Enable LCD mode macro
    bzero (buffer, 7);
    buffer[0] = 1;
    entry = [IOWarriorWindowController logEntryWithDirection:kReportDirectionOut
                       reportID:4
                     reportSize:7
                     reportData:buffer
                           name:@"Enable LCD Mode"];
    [defaultMacros addObject:entry];

    // Init display macro
    bzero (buffer, 7);
    buffer[0] = 0x03;
    buffer[1] = 0x38;
    buffer[2] = 0x01;
    buffer[3] = 0x0F;
    entry = [IOWarriorWindowController logEntryWithDirection:kReportDirectionOut
                               reportID:5
                             reportSize:7
                             reportData:buffer
                                   name:@"Init display"];
    [defaultMacros addObject:entry];

    // Write to display macro
    bzero (buffer, 7);
    buffer[0] = 0x84;
    buffer[1] = 'T';
    buffer[2] = 'e';
    buffer[3] = 's';
    buffer[4] = 't';
    entry = [IOWarriorWindowController logEntryWithDirection:kReportDirectionOut
                               reportID:5
                             reportSize:7
                             reportData:buffer
                                   name:@"Write to display"];
    [defaultMacros addObject:entry];
    
    // Move to display start macro
    bzero (buffer, 7);
    buffer[0] = 0x01;
    buffer[1] = 0x80;
    entry = [IOWarriorWindowController logEntryWithDirection:kReportDirectionOut
                                                    reportID:5
                                                  reportSize:7
                                                  reportData:buffer
                                                        name:@"Move to first LCD pos."];
    [defaultMacros addObject:entry];

    // Read from 4 bytes from display macro
    bzero (buffer, 7);
    buffer[0] = 0x84;
    entry = [IOWarriorWindowController logEntryWithDirection:kReportDirectionOut
                                                    reportID:6
                                                  reportSize:7
                                                  reportData:buffer
                                                        name:@"Read 4 bytes from LCD"];
    [defaultMacros addObject:entry];
    // Enable Infra red reception (IOWarrior 24)
    bzero (buffer, 7);
    buffer[0] = 0x01;
    entry = [IOWarriorWindowController logEntryWithDirection:kReportDirectionOut
                                                    reportID:0x0C
                                                  reportSize:7
                                                  reportData:buffer
                                                        name:@"Enable Infra red reception (IOWarrior 24)"];
    
    [defaultMacros addObject:entry];
    
    
    [defaultValues setObject:[NSArray arrayWithArray:defaultMacros] forKey:kDefaultMacrosKey];

    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultValues];
}

/*" Invoked when macro popup changes. Fills in macro data into current gui. "*/
- (IBAction)macroPopupChanged:(id)sender
{
    int 		index = [macroPopup indexOfSelectedItem];
    NSUserDefaults* 	defaults = [NSUserDefaults standardUserDefaults];
    NSArray*		macros = [defaults objectForKey:kDefaultMacrosKey];

    [self updateInterfaceFromLogEntry:[macros objectAtIndex:index]];
}

- (IBAction)addMacro:(id)sender
{
    int index;

    index = [logTable selectedRow];
    if (-1 != index)
    {
        NSDictionary* 	logEntry = [logEntries objectAtIndex:index];
        

        if ([[logEntry objectForKey:kReportDirectionKey] isEqualTo:kReportDirectionOut])
        {
            NSString*	macroName = [MacroNamePanelController chooseMacroName];
            if (nil != macroName)
            {
                NSUserDefaults* 	defaults = [NSUserDefaults standardUserDefaults];
                NSMutableArray*		macros = [NSMutableArray arrayWithArray:[defaults objectForKey:kDefaultMacrosKey]];
                NSMutableDictionary*	newMacro = [NSMutableDictionary dictionaryWithDictionary:logEntry];
    
                [newMacro setObject:macroName forKey:kMacroNameKey];
                [macros addObject:[NSDictionary dictionaryWithDictionary:newMacro]];
                [defaults removeObjectForKey:kDefaultMacrosKey];
                [defaults setObject:[NSArray arrayWithArray:macros] forKey:kDefaultMacrosKey];
                [self updateMacroPopup];
            }
        }
    }
}

- (IBAction)deleteMacro:(id)sender
{
    int	index;

    index = [macroPopup indexOfSelectedItem];
    if (index > 0)
    {
        NSUserDefaults* 	defaults = [NSUserDefaults standardUserDefaults];
        NSMutableArray*		macros = [NSMutableArray arrayWithArray:[defaults objectForKey:kDefaultMacrosKey]];

        [macros removeObjectAtIndex:index];
        [defaults removeObjectForKey:kDefaultMacrosKey];
        [defaults setObject:[NSArray arrayWithArray:macros] forKey:kDefaultMacrosKey];
        [self updateMacroPopup];
    }
}

- (void) updateMacroPopup
{
    NSUserDefaults*	defaults = [NSUserDefaults standardUserDefaults];
    NSArray*		macros = [defaults objectForKey:kDefaultMacrosKey];
    int			i;

    [macroPopup removeAllItems];
    for (i = 0; i < [macros count]; i++)
    {
        NSDictionary *macro = [macros objectAtIndex:i];

        [macroPopup addItemWithTitle:[macro objectForKey:kMacroNameKey]];
    }    
}

- (IBAction)resetReportValues:(id)sender
{
    int i;
    
    for (i = 0 ; i < 7 ; i++)
    {
        NSControl *theSubview;

        theSubview = (NSControl*) [[window contentView] viewWithTag:i + 100];
        [theSubview setStringValue:@"00"];
    }
}

- (IBAction)duplicateCheckboxClicked:(id)sender
{
    ignoreDuplicates = [ignoreDuplicatesCheckBox state];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if (-1 == [logTable selectedRow]) // nothing selected
    {
        [addMacroButton setEnabled:NO];
    }
    else // log entry selected
    {
        [addMacroButton setEnabled:YES];
    }
}

- (IBAction) closeInterface:(id) sender
{
	IOWarriorListNode *listNode = IOWarriorInterfaceListNodeAtIndex ([interfacePopup indexOfSelectedItem]);
	
	IOWarriorCloseInterfaceIfNecessary(listNode->ioWarriorHIDInterface);
}

@end
