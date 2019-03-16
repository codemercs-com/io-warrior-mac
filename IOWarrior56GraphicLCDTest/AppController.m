#import "AppController.h"
#import "IOWarriorLib.h"

/* This example work with an LC 7981 controller. */

#define kVerticalPitch	8
#define kHorizontalPitch 8
#define kDisplayWidth 80
#define kDisplayHeight 80

#define kBufferSize ((kDisplayWidth * kDisplayHeight) / 8)

@implementation AppController

AppController* gController = nil;


void IOWarriorCallback ()
/*" Called when IOWarrior is added or removed. "*/
{
    [gController updateStatusField];
}

- (void) awakeFromNib
{
	gController = self;
	
	IOWarriorInit ();
	
	IOWarriorSetDeviceCallback (IOWarriorCallback, nil);
	[self updateStatusField];

}

- (void) dealloc
{
    [self setSlideShowFiles: nil];
	[self setCurrentTimer: nil];

    [super dealloc];
}


- (IBAction)chooseFile:(id)sender
{
	// ask for an image file
	NSOpenPanel		*openPanel = [NSOpenPanel openPanel];
	NSMutableArray	*newFiles = [NSMutableArray array];
	
	[openPanel setAllowedFileTypes: [NSImage imageTypes]];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:YES];
	
	if (NO == [openPanel runModal])
	{
		[self setSlideShowFiles:[NSMutableArray array]];
		return;
	}

    for (NSURL *fileURL in openPanel.URLs)
    {
        NSString *theFile = fileURL.path;
        BOOL     isDir;

		if ([[NSFileManager defaultManager] fileExistsAtPath:theFile isDirectory:&isDir] && isDir)
		{
			// iterate over selected Dir contents
            NSArray			*dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:theFile error:nil];
			NSEnumerator	*dirEnum = [dirContents objectEnumerator];
			NSString		*fileFromDir;
			
			while (nil != (fileFromDir = [dirEnum nextObject]))
			{
				NSString *fileFromDirPath = [theFile stringByAppendingPathComponent:fileFromDir];
					
				if ([[NSFileManager defaultManager] fileExistsAtPath:fileFromDirPath isDirectory:&isDir] && !isDir)
				{
					if ([[NSImage imageTypes] containsObject:[fileFromDirPath pathExtension]])
					{
						[newFiles addObject:fileFromDirPath];
					}
				}
			}
		}
		else
		{
			[newFiles addObject:theFile];
		}
	}
	[self setSlideShowFiles:[NSMutableArray arrayWithArray:newFiles]];
}

- (void) advanceSlideShow:(NSTimer*) ignored
{
	if ([slideShowFiles count])
	{
		if (currentSlideShowIndex >= [slideShowFiles count])
		{
			currentSlideShowIndex = 0;
		}
		NSString *file = [slideShowFiles objectAtIndex:currentSlideShowIndex];
		[self downloadImageAtPath:file];
		currentSlideShowIndex++;
	}
	else
	{
		[currentTimer invalidate];
		[self setCurrentTimer:nil];
	}
}

- (void) downloadImageAtPath:(NSString*) inImagePath
{
	NSImage							*theImage = [[NSImage alloc] initWithSize:NSMakeSize (kDisplayWidth, kDisplayHeight)];
	char							buffer[kBufferSize];
	int								row, column;
	IOWarriorHIDDeviceInterface**	interface = IOWarriorFirstInterfaceOfType(kIOWarrior56Interface1);
	char							commandBuffer[64];
	
	NSLog (@"downloading file %@", inImagePath); 	// fill the image
	[theImage lockFocus];
	
	
	NSImage *otherImage = [[NSImage alloc] initWithContentsOfFile:inImagePath];
	
	[otherImage setSize:NSMakeSize (kDisplayWidth, kDisplayHeight)];
	
	[otherImage drawInRect:NSMakeRect (0,0, kDisplayWidth, kDisplayHeight)
				  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
				  fraction:1.0];
	
	[theImage unlockFocus];
	
	
	NSBitmapImageRep *theImageRep = [[NSBitmapImageRep alloc] initWithData:[theImage TIFFRepresentation]];
	
	bzero (buffer, kBufferSize);
	for (row = 0; row < kDisplayHeight; row++)
	{
		for (column = 0; column < kDisplayWidth; column++)
		{
			int bitIndex = (row * kDisplayWidth) + column;
			int	byte = bitIndex / 8;
			int	bit = bitIndex % 8;
			
			if ([self pixelIsSetInImageRep:theImageRep
									 atRow:row
									column:column])
			{
				buffer[byte] = buffer[byte] | (1 << bit);
			}
		}
	}
	
	[theImageRep release];
	[theImage release];
	
	// enable LCD mode
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x04;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = 0x16;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);	
	
	// set character pitch
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x01;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = ((kVerticalPitch -1 ) * 16) + (kHorizontalPitch -1 ); 
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);	
	
	// set number of characters
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x02;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = (kDisplayWidth / kHorizontalPitch) - 1; 
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);
	
	// set time division number
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x03;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = kDisplayHeight - 1;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer), commandBuffer);
	
	// enable graphic mode
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = 0x32;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);	
	
	// set display address
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x08;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = 0x00;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x09;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = 0x00;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);
	
	// set read/write address
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x0A;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = 0x00;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x0B;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);	
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x01;
	commandBuffer[2] = 0x00;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);
	
	// write data
	bzero(commandBuffer,sizeof (commandBuffer));
	commandBuffer[0] = 0x05;
	commandBuffer[1] = 0x81;
	commandBuffer[2] = 0x0C;
	IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);
	
	int bytesLeft = kBufferSize;
	int	bytesSent = 0;
	
	while (bytesLeft)
	{
		int reportDataSize;
		
		if (bytesLeft < 62)
		{
			reportDataSize = bytesLeft;
		}
		else
		{
			reportDataSize = 62;
		}
		bytesLeft -= reportDataSize;
		
		bzero(commandBuffer,sizeof (commandBuffer));
		commandBuffer[0] = 0x05;
		commandBuffer[1] = reportDataSize;
		
		memcpy(&commandBuffer[2] , &buffer[bytesSent], reportDataSize);
		
		IOWarriorWriteToInterface(interface,sizeof (commandBuffer),commandBuffer);
		
		bytesSent += reportDataSize;
	}	
}



- (void) updateStatusField
{
	if (IOWarriorFirstInterfaceOfType(kIOWarrior56Interface1))
	{
		[statusField setStringValue:@"IOWarrior56 found"];
	}
	else
	{
		[statusField setStringValue:@"No IOWarrior56 found"];
	}
}

typedef struct _RGBPixel
{
	unsigned char redByte, greenByte, blueByte;	
} RGBPixel;

typedef struct _RGBAPixel
{
	unsigned char redByte, greenByte, blueByte, alphaByte;	
} RGBAPixel;

- (BOOL) pixelIsSetInImageRep:(NSBitmapImageRep*)inImageRep atRow:(int) inRow column:(int) inColumn
{
	NSInteger widthInPixels = [inImageRep pixelsWide];
		
	if (3 == [inImageRep samplesPerPixel])
	{
		RGBPixel	*pixels = (RGBPixel *)[inImageRep bitmapData];

		if (inRow < [inImageRep pixelsHigh] &&
			inColumn < [inImageRep pixelsWide])
		{
			RGBPixel *thisPixel = (RGBPixel *) &(pixels[((widthInPixels * inRow) + inColumn)]);
			
			if (thisPixel->redByte < 128 	&&
				thisPixel->greenByte < 128  &&
				thisPixel->blueByte < 128)
			{
				return YES;
			}
		}
	}
	if (4 == [inImageRep samplesPerPixel])
	{
		RGBAPixel	*pixels = (RGBAPixel *)[inImageRep bitmapData];
		
		if (inRow < [inImageRep pixelsHigh] &&
			inColumn < [inImageRep pixelsWide])
		{
			RGBAPixel *thisPixel = (RGBAPixel *) &(pixels[((widthInPixels * inRow) + inColumn)]);
			
			if (thisPixel->redByte < 128 	&&
				thisPixel->greenByte < 128  &&
				thisPixel->blueByte < 128)
			{
				return YES;
			}
		}
	}
	
	
	return NO;
}

- (NSMutableArray *) slideShowFiles
{
    return slideShowFiles; 
}

- (void) setSlideShowFiles: (NSMutableArray *) inSlideShowFiles
{
    if (slideShowFiles != inSlideShowFiles) {
        [slideShowFiles autorelease];
        slideShowFiles = [inSlideShowFiles retain];
    }
	currentSlideShowIndex = 0;
	[self advanceSlideShow:nil];
	[self setCurrentTimer:[NSTimer scheduledTimerWithTimeInterval:2.0
												  target:self
												selector:@selector(advanceSlideShow:)
														 userInfo:nil
												 repeats:YES]];
}


- (NSTimer *) currentTimer
{
    return currentTimer; 
}

- (void) setCurrentTimer: (NSTimer *) inCurrentTimer
{
    if (currentTimer != inCurrentTimer) {
        [currentTimer autorelease];
        currentTimer = [inCurrentTimer retain];
    }
}


@end
