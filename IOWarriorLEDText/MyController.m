#import "MyController.h"
#import "InterfaceWriter.h"

@implementation MyController

MyController* gController = nil;

void IOWarriorCallback ()
/*" Called when IOWarrior is added or removed. "*/
{
    [gController populateInterfacePopup];
}

- (void) awakeFromNib
{
	gController = self;
	
	IOWarriorInit ();
	
	NSArray *fonts = [[NSFontManager sharedFontManager] availableFontFamilies];
	[fontPopup removeAllItems];
	[fontPopup addItemsWithTitles:[fonts sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	[fontPopup selectItemWithTitle:@"Monaco"];
	
	[theField setDelegate:self];
	[self speedSliderChanged:self];
	
	[self populateInterfacePopup];

	writers = [[NSMutableArray alloc] init];
	
	IOWarriorSetDeviceCallback (IOWarriorCallback, nil);
}

- (IBAction) startOrStop:(id)sender
{
	InterfaceWriter *theWriter = [self selectedWriter];
	if ([theWriter running])
	{
		[theWriter setRunning:NO];
		[writers removeObject:theWriter];
		[sender setTitle:@"Start"];
	}
	else if (nil == theWriter)
	{
		IOWarriorHIDDeviceInterface **interface =  [self selectedInterface];
		IOWarriorListNode *node = IOWarriorListNodeForInterface(interface);
		
		theWriter = [[InterfaceWriter alloc] initWithInterface:interface
														  font:[self selectedFont]
														string:[theField stringValue]
														 delay:[speedSlider floatValue] / 10.0
												 interfaceType:node->interfaceType];
		[writers addObject:theWriter];
		[theWriter release];
		[theWriter setRunning:YES];
		[sender setTitle:@"Stop"];		
	}
}

- (IBAction) speedSliderChanged:(id) sender
{
	[[self selectedWriter] setDelay:[speedSlider floatValue] / 10.0];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[[self selectedWriter] setString:[theField stringValue]];
}

- (void) fontPopupChanged:(id) sender
{
	[[self selectedWriter] setFont:[self selectedFont]];
}

- (NSFont*) selectedFont
{
	return [[NSFontManager sharedFontManager] fontWithFamily:[fontPopup titleOfSelectedItem]
													  traits:0
													  weight:5
														size:9];
}

- (IOWarriorHIDDeviceInterface**) selectedInterface
{
	int count = IOWarriorCountInterfaces();
	int selectedIndex = [interfacePopup indexOfSelectedItem];
	int interfaces = 0;
	int i;
	
	if (selectedIndex >= 0)
	{
		for (i = 0; i< count ; i++)
		{
			IOWarriorListNode* 	listNode;
			
			listNode = IOWarriorInterfaceListNodeAtIndex (i);
			if (listNode->interfaceType == kIOWarrior24Interface1 ||
				listNode->interfaceType == kIOWarrior40Interface1 ||
				listNode->interfaceType == kIOWarrior56Interface1)
			{
				if (interfaces == selectedIndex)
				{
					return listNode->ioWarriorHIDInterface;
				}
				interfaces++;
			}
		}
	}

return NULL;
}

- (InterfaceWriter*) selectedWriter
/*" Returns the writer for the currently selected interface, if one has already been created. "*/ 
{
	return [self writerForInterface:[self selectedInterface]];	
}
	
- (InterfaceWriter*) writerForInterface:(IOWarriorHIDDeviceInterface**) inInterface
{
	NSEnumerator	*e = [writers objectEnumerator];
	InterfaceWriter *theWriter;
	
	while (nil != (theWriter = [e nextObject]))
	{
		if ([theWriter interface] == inInterface)
		{
			return theWriter;
		}
	}
	return nil;
}

- (void) populateInterfacePopup
	/*" Inserts currently available IOWarrior interfaces into popup menu. "*/
{
    int i, interfaceCount;
    
    [interfacePopup removeAllItems];
    interfaceCount = IOWarriorCountInterfaces ();
	for (i = 0; i < interfaceCount; i++)
    {
        IOWarriorListNode* 	listNode;
        NSString*		title;
		
        listNode = IOWarriorInterfaceListNodeAtIndex (i);
		if (listNode->interfaceType == kIOWarrior24Interface1 ||
			listNode->interfaceType == kIOWarrior24PVInterface1 ||
			listNode->interfaceType == kIOWarrior40Interface1 ||
			listNode->interfaceType == kIOWarrior56Interface1)
		{
			title = [NSString stringWithFormat:@"%@ (SN %@)", [self nameForIOWarriorInterfaceType:listNode->interfaceType],
				listNode->serialNumber];
			[interfacePopup addItemWithTitle:title];
		}
    }
	[interfacePopup setEnabled:[[interfacePopup itemArray] count] > 0];
	[startStopButton setEnabled:[[interfacePopup itemArray] count] > 0];
    [self interfacePopupChanged:self];
}

- (IBAction) interfacePopupChanged:(id) sender
{
	InterfaceWriter *theWriter = [self selectedWriter];
	
	if ([theWriter running])
		[startStopButton setTitle:@"Stop"];
	else
		[startStopButton setTitle:@"Start"];
	
	if (theWriter)
	{
		[theField setStringValue:[theWriter string]];
	}
}

- (NSString*) nameForIOWarriorInterfaceType:(int) inType
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
			
		case kIOWarrior24PVInterface0:
            return @"IOWarrior24PV Interface 0";
            break;
			
        case kIOWarrior24PVInterface1:
            return @"IOWarrior24PV Interface 1";
            break;
			
		case kIOWarrior56Interface0:
            return @"IOWarrior56 Interface 0";
            break;
			
        case kIOWarrior56Interface1:
            return @"IOWarrior56 Interface 1";
            break;
    }
    return @"Unknown interface type";
}

@end
