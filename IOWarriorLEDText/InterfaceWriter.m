//
//  InterfaceWriter.m
//  IOWarriorLEDText
//
//  Created by ilja on Fri Jun 18 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "InterfaceWriter.h"

@implementation InterfaceWriter

- (id) initWithInterface:(IOWarriorHIDDeviceInterface**) inInterface
					font:(NSFont*) inFont
				  string:(NSString*) inString
				   delay:(float) inDelay
		   interfaceType:(int) inInterfaceType

{
	self = [super init];
	if (self)
	{
		interface = inInterface;
		[self setFont:inFont];
		[self setString:inString];
		[self setDelay:inDelay];
		[self setInterfaceType:inInterfaceType];
		
		lastRun = [[NSDate date] retain];
		
		bitmapDirty = YES;
		
		[self enableLEDMode];
	}

	return self;
}


- (void) dealloc
{
    [self setFont: nil];
    [self setString: nil];
	
	[lastRun release];
	[currentImageRep release];
	
    [super dealloc];
}

- (IOWarriorHIDDeviceInterface**) interface
{
	return interface;
}

- (void) enableLEDMode
{
	unsigned char	buffer[64];
	int				reportSize;
	
	if ([self interfaceType] == kIOWarrior56Interface1)
	{
		reportSize = 64;
	}
	else
	{
		reportSize = 8;
	}
	
	bzero (buffer, reportSize);
	buffer[0] = 0x14; // led mode
	buffer[1] = 1;		// enable
	
	IOWarriorWriteToInterface (interface, reportSize, buffer);
}

- (NSFont *) font
{
    return font; 
}

- (void) setFont: (NSFont *) inFont
{
    if (font != inFont) {
        [font autorelease];
        font = [inFont retain];
		bitmapDirty = YES;
    }
}


- (NSString *) string
{
    return string; 
}

- (void) setString: (NSString *) inString
{
    if (string != inString) {
        [string autorelease];
        string = [inString retain];
		bitmapDirty = YES;

    }
}


- (float) delay
{
	
    return delay;
}

- (void) setDelay: (float) inDelay
{
	delay = inDelay;
}


- (int) interfaceType
{
	return interfaceType;
}

- (void) setInterfaceType:(int) inInterfaceType
{
	interfaceType = inInterfaceType;
}


- (BOOL) running
{
    return running;
}

- (void) setRunning: (BOOL) flag
{
	running = flag;
	[NSThread detachNewThreadSelector:@selector(updateLEDs:)
							 toTarget:self
						   withObject:nil];
}

- (void) updateLEDs:(id) ignored
{
	
	while (running)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (bitmapDirty)
		{
			[currentImageRep release];
			currentImageRep = [self bitmapForString:string];
			[currentImageRep retain];
		}
		if (startColumn > [currentImageRep pixelsWide])
			startColumn = 0;
		if ([self interfaceType] == kIOWarrior56Interface1)
		{
			[self downloadImageRepToIOW56:currentImageRep
							  startColumn:startColumn++];
		}
		else
		{
			[self downloadImageRep:currentImageRep
					   startColumn:startColumn++];
		}
			
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:delay]];	
		
		[pool release];
	}
}


- (NSBitmapImageRep*) bitmapForString:(NSString*) inString
{
	NSDictionary		*fontAttributes;
	NSSize				stringSize;
	NSImage				*image;
	NSData				*tiffData;
	NSBitmapImageRep	*result;
	
	currentFontDescender = [font descender];
	fontAttributes = [NSDictionary dictionaryWithObject:font
												 forKey:NSFontAttributeName];
	stringSize = [inString sizeWithAttributes:fontAttributes];
	image = [[NSImage alloc] initWithSize:stringSize];
	
	[image lockFocus];
	
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	[[NSColor whiteColor] set];
	NSRectFill(NSMakeRect (0,0, stringSize.width, stringSize.height));
	[inString drawAtPoint:NSZeroPoint
		   withAttributes:fontAttributes];
	
	[image unlockFocus];
	
	tiffData = [image TIFFRepresentation];
	[image release];
	
	result = [[NSBitmapImageRep alloc] initWithData:tiffData];
	
	return [result autorelease];
}

#define kLEDsPerLine 32
#define kLEDLines	8

- (void) downloadImageRep:(NSBitmapImageRep*) inImageRep startColumn:(int) inStartColumn
{
	int				row;
	int				column;
	unsigned char   buffer[8];
	
	for (row = 0; row < kLEDLines; row++) // iterate over all rows
	{
		bzero (buffer, 8); // clear buffer before re-use
		buffer[0] = 0x15; // report ID for LED Data
		buffer[1] = row; // first byte is line number
		
		for (column = 0; column < kLEDsPerLine; column++) // iterate over single LEDs in a row
		{
			if ([self pixelIsSetInImageRep:inImageRep atRow:row - currentFontDescender
									column:column + inStartColumn])
			{
				int index;
				unsigned char val;
				
				index = (column/8) + 2;
				val = (column % 8);
				val = 1 << val;
				buffer[index] |= val;				
			}
		}
		// send a report for each line
		IOWarriorWriteToInterface (interface, 8, buffer);
	}
}

- (void) downloadImageRepToIOW56:(NSBitmapImageRep*) inImageRep startColumn:(int) inStartColumn
{
	int				row;
	int				column;
	int				block;
	
	unsigned char   buffer[64];
	
	// compute block 0
	for (block = 0; block < 2; block++)
	{
		bzero (buffer, 64); // clear buffer before re-use
		buffer[0] = 0x15;	// report ID for LED Data
		buffer[1] = block; // first byte identifies block 

		for (row = 0; row <  4; row++)
		{
			for (column = 0; column < 64; column++)
			{
				if ([self pixelIsSetInImageRep:inImageRep atRow: (block * 4) + (row - currentFontDescender)
										column:column + inStartColumn])
				{
					int index;
					unsigned char val;
				
					index = 2 + (8 * row) + (column/8) ;
					val = (column % 8);
					val = 1 << val;
					buffer[index] |= val;				
				}
			}
		}
		// send a report for each block
		IOWarriorWriteToInterface (interface, 64, buffer);
	}
}

typedef struct _RGBPixel
{
	unsigned char redByte, greenByte, blueByte;	
} RGBPixel;


typedef struct _RGBAPixel
{
	unsigned char redByte, greenByte, blueByte, transperencyByte;
} RGBAPixel;


- (BOOL) pixelIsSetInImageRep:(NSBitmapImageRep*)inImageRep atRow:(int) inRow column:(int) inColumn
{
	RGBAPixel *pixels = (RGBAPixel *)[inImageRep bitmapData];
	int widthInPixels = [inImageRep pixelsWide];
	
	//NSAssert (3 == [inImageRep samplesPerPixel], @"inImageRep doesn't have RGB format");
	
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
	
	return NO;
}


@end
