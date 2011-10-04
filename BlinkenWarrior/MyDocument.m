/*
	MyDocument.m
	Copyright (c) 2004 by CodeMercenaries GmbH, all rights reserved.
	Author: Ralf Menssen
 
 */

#import "MyDocument.h"
#include <mach/mach_port.h>
#include <unistd.h>
#include <sys/time.h>
#include "Util.h"

#define kBufSize 1024
#define kLEDLines	8

#define kLEDsPerLineIOWarrior56		64
#define KLEDsPerLineIOWarrrior24	32

#define kLEDsPerLine kLEDsPerLineIOWarrior56

typedef char LEDLine[kLEDsPerLine];

LEDLine gLedMatrix[kLEDLines];
int gCurLed, gCurLedLine;
bool gHasDocument;

int ParseFile (NSData *data, long *frameCount, long *totalDuration, long *leds, long *lines);
static void *NSGetLine (NSData *data, unsigned long *index, unsigned char *lineBuffer, unsigned long bufferSize);
void StartSequence ();
void CollectLight (char what);

int DisplayDataNow ();
int DisplayDataNowIOWarrior24or40 ();
int DisplayDataNowIOWarrior56 ();


int EnableLEDMode (bool on);
static void mysleep (long pause);
int IOWarriorWriteInterface1At24 (int inReportID, void *inData);

IOWarriorHIDDeviceInterface** FirstSupportedInterfaceWithType (int *outType);

#pragma mark --MyDocument--

@implementation MyDocument

//------------------------------------------------------------------
#pragma mark =initialize

- (void) initialize
{
	mWeHaveData = false;
	gHasDocument = false;
}

//------------------------------------------------------------------
#pragma mark =dealloc

- (void)dealloc
{
    [mDataFromFile release];
    mDataFromFile = nil;
    [super dealloc];
}


// ==========================================================
// Standard NSDocument methods
// ==========================================================

#pragma mark =windowNibName

- (NSString *)windowNibName
{
    return @"MyDocument";
}

//------------------------------------------------------------------
#pragma mark =windowControllerDidLoadNib

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Do the standard thing of loading in data we may have gotten if loadDataRepresentation: was used.
    if (mDataFromFile != nil)
	{
		[self loadTextViewWithInitialData: mDataFromFile];
	}
}

//------------------------------------------------------------------
#pragma mark =loadDataRepresentation

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    BOOL success = NO;
    
    if (!gIOWarriorIsInitialzed)
	{
        gIOWarriorIsInitialzed = true;
        if (IOWarriorInit ())
		{
            NSRunAlertPanel (@"Error", @"Could not initialize IOWarrior Lib", @"OK", NULL, NULL);
		}
        else
		{
            gHaveIOWarrior = (IOWarriorIsPresent () > 0);
		}
	}
    if (documentWindow != nil) 
	{
        [self loadTextViewWithInitialData: data];
	}
    else
	{
        long len;
        if ((len = ParseFile (data, &mFrameCount, &mDuration, &mLeds, &mLines)) < 0)
		{
            if (len == -4)
                NSRunAlertPanel ([self displayName], [[[NSString alloc] autorelease ] initWithFormat:
					@"This file is not a valid blinkenlights file. Syntax error."], @"OK", NULL, NULL);
            else
                NSRunAlertPanel ([self displayName], [[[NSString alloc] autorelease ] initWithFormat:
					@"Could not process this file. An error %ld occured.",len], @"OK", NULL, NULL);
            return NO;
		}
        mWeHaveData = true;
        mDataFromFile = [data retain];
	}
    gHasDocument = true;
    success = YES;
    return success;
}

//------------------------------------------------------------------
#pragma mark =loadTextViewWithInitialData

- (void) loadTextViewWithInitialData: (NSData *) data
{
    long len;
    NSString *msg;
	
    if (!mWeHaveData)
        if ((len = ParseFile (data, &mFrameCount, &mDuration, &mLeds, &mLines)) >= 0)
		{
            mWeHaveData = true;
		}
			else
            {
				mWeHaveData = false;
				[self SetDataFileInformation: @"--- Error reading this file! ---"];
            }
			if (mDuration < 2000)
				msg = [NSString stringWithFormat:@"%ldx%ld, %ld Frames, duration = %ld millisecs", mLeds, mLines, mFrameCount, mDuration];
		else
			msg = [NSString stringWithFormat:@"%ldx%ld, %ld Frames, duration = %ld seconds", mLeds, mLines, mFrameCount, mDuration/1000];
    [self SetDataFileInformation: msg];
    gHaveIOWarrior = (IOWarriorIsPresent () > 0);
    if (gHaveIOWarrior)
        [self SetDownloadStatus: @"Press Play to start"];
    mDataFromFile = [data retain];
    gHasDocument = true;
}

- (IBAction)doPlay:(id)sender
{
	[self PlayFile: mDataFromFile doLoop: false];
}

- (IBAction)doLoopPlay:(id)sender
{
	[self PlayFile: mDataFromFile doLoop: true];
}

#pragma mark ¥NSFields¥
//------------------------------------------------------------------
- (void)SetDownloadStatus:(NSString *) statusStr
{
	[downloadStatus setStringValue: statusStr];
	[downloadStatus displayIfNeeded];
}

//------------------------------------------------------------------
- (void)SetDataFileInformation:(NSString *) statusStr
{
	[keyDataFileName setStringValue: statusStr];
}

//------------------------------------------------------------------

- (bool) PlayFile: (NSData *) data doLoop:(bool)doLoop
{
	char  buf[kBufSize];
	int   lc;
	int   len, i;
	int   duration;
	unsigned long index;
	long frameCount;
	NSString *msg;
	bool weHaveData;
	
	gHaveIOWarrior = (IOWarriorIsPresent () > 0);
	if (!gHaveIOWarrior)
    {
		[self SetDownloadStatus: @"No IOWarrior available"];
		return false;
    }
	if (EnableLEDMode (true) != 0)
    {
		NSRunAlertPanel (@"Error", @"Could not send data to IOWarrior", @"OK", NULL, NULL);
		goto errorPlaying;
    }
	do
    {
		lc = 1;
		index = 0;
		frameCount = 0;
		weHaveData = false;
		while (NSGetLine (data, &index, (unsigned char*) buf, kBufSize) && lc++)
        {
			len = strlen (buf);
			
			if (len == 0)
				continue;
			
			if (buf[0] == '#')
				continue;
			
			if (buf[0] == '@')
            {
				if (sscanf (buf+1, "%d", &duration) != 1 || duration < 0)
					duration = 0;
				if (weHaveData)
                {
					msg = [NSString stringWithFormat:@"Processing Frame %ld", frameCount];
					[self SetDownloadStatus: msg];
					if (DisplayDataNow () != 0)
                    {
						NSRunAlertPanel (@"Error", @"Could not send data to IOWarrior", @"OK", NULL, NULL);
						goto errorPlaying;
                    }
					mysleep (duration);
					if (BreakActionAvail ())
						goto stopPlaying;
                }
				weHaveData = true;
				
				if (sscanf (buf+1, "%d", &duration) != 1 || duration < 0)
					duration = 0;
				frameCount++;
            }
			else
            {
				/* skip empty lines */
				for (i = 0; i < len; i++)
					if (!isspace (buf[i]))
						break;
				if (i == len)
					continue;
				for (i = 0; i < len; i++)
					CollectLight (buf[i]); 
				
				CollectLight ('\n');
            }
        }
		if (weHaveData)
        {
			msg = [NSString stringWithFormat:@"Processing Frame %ld", frameCount];
			[self SetDownloadStatus: msg];
			DisplayDataNow ();
			mysleep (duration);
			if (BreakActionAvail ())
				goto stopPlaying;
        }
    }while (doLoop);
    
stopPlaying:
		[self SetDownloadStatus: @"Press Play to start"];
errorPlaying:
		EnableLEDMode (false);
	return true;
}


@end
#pragma mark ----------------------------------------

static void mysleep (long pause)
{
	static struct timeval last = { 0, 0 };
	struct timeval now;
	long           expired;
	
	pause *= 1000;
	
	gettimeofday (&now, NULL);
	if (last.tv_sec != 0)
		expired = ((now.tv_sec - last.tv_sec) * 1000000 + 
				   (now.tv_usec - last.tv_usec));
	else
		expired = 0;
	
	if (pause - expired > 0)
		usleep (pause - expired);
	
	gettimeofday (&last, NULL);
}

//------------------------------------------------------------------

static void *NSGetLine (NSData *data, unsigned long *index, unsigned char *lineBuffer, unsigned long bufferSize)
{
	unsigned char *p, c;
	unsigned long lineBufferIndex = 0;
	unsigned long len = [data length];
	
	if (*index >= len)
		return NULL;
	
	p = (unsigned char *) [data bytes];
	while ((*index < len) && (lineBufferIndex < bufferSize - 1))
	{
        c = p[(*index)++];
		if ((c == '\n') || (c == '\r'))
			break;
		lineBuffer[lineBufferIndex++] = c;
	}
	lineBuffer[lineBufferIndex++] = '\0';
	if ((p[*index] == '\n') || (p[*index] == '\r'))	// Check for Windows format (CR+LF, or LF+CR)
		(*index)++;
	return lineBuffer;
}

//------------------------------------------------------------------

int ParseFile (NSData *data, long *frameCount, long *totalDuration, long *leds, long *lines)
{
	char  buf[kBufSize];
	int   lc;
	int   len, i;
	int   duration;
	unsigned long index = 0;
	bool ledsCounted, linesCounted, expectFirstLine;
	
	*frameCount = 0;
	*totalDuration = 0;
	*leds = 0;
	*lines = 0;
	ledsCounted = false;
	linesCounted = false;
	expectFirstLine = false;
	
	lc = 1;
	if (NSGetLine (data, &index, (unsigned char*) buf, kBufSize) == NULL)
		goto blerror;
	
	if (buf[0] != '#')
		goto blerror;
	
	i = 1;
	while (isspace (buf[i]))
		i++;
	
	if ((strncasecmp (buf + i, "BlinkenLights Movie", 19) != 0))
		goto blerror;
	
	while (NSGetLine (data, &index, (unsigned char*) buf, kBufSize) && lc++)
    {
		len = strlen (buf);
		if (!ledsCounted && expectFirstLine)
        {
			*leds = len;
			ledsCounted = true;
        }
		
		if (len == 0)
			continue;
		
		if (buf[0] == '#')
			continue;
		
		if (buf[0] == '@')
        {
			if (sscanf (buf+1, "%d", &duration) != 1 || duration < 0)
				duration = 0;
			*frameCount += 1;
			*totalDuration += duration;
			if (*lines != 0)
				linesCounted = true;
			expectFirstLine = true;
        }
		else
        {
			/* skip empty lines */
			for (i = 0; i < len; i++)
				if (!isspace (buf[i]))
					break;
			if (i == len)
				continue;
			if (!linesCounted)
            {
				*lines += 1;
            }
        }
    }
	return 0;
	
blerror:
		NSRunAlertPanel (@"Error", [[[NSString alloc] autorelease ] initWithFormat:
												   @" parsing BlinkenLights movie : (line %d)", lc], @"OK", NULL, NULL);
	return -1;  
}

//------------------------------------------------------------------
void StartSequence ()
{
	int i, l;
	gCurLed = 0;
	gCurLedLine = 0;
	for (l = 0; l < kLEDLines; l++)
		for (i = 0; i < kLEDsPerLine; i++)
        {
			gLedMatrix[l][i] = '0';	// Initalize all black
        }
}

//------------------------------------------------------------------
void CollectLight (char what)
{
	switch (what)
    {
		case '0':
		case '1':
			if ((gCurLed < kLEDsPerLine) && (gCurLedLine < kLEDLines))
				gLedMatrix [gCurLedLine][gCurLed++] = what;
			break;
		case '\n':
			gCurLedLine++;
			gCurLed = 0;
			break;
    }
}

int DisplayDataNow ()
{
	int	type;
	
	if (FirstSupportedInterfaceWithType (&type))
	{
		if ((type == kIOWarrior24Interface1) ||
			(type == kIOWarrior40Interface1))
		{
			return DisplayDataNowIOWarrior24or40 ();
		}
		else if (type == kIOWarrior56Interface1)
		{
			return DisplayDataNowIOWarrior56 ();
		}
	}
	return -1;
}

//------------------------------------------------------------------
int DisplayDataNowIOWarrior24or40 ()
{
	unsigned char buffer[7];
	int i, line, leds;
	int result;
	int index;
	unsigned char val;
	
	for (line = 0; line < kLEDLines; line++)
    {
		buffer[0] = line;
		for (i = 1; i < 7; i++)
			buffer[i] = 0;
		for (leds = 0; leds < KLEDsPerLineIOWarrrior24; leds++)
        {
			if (gLedMatrix[line][leds] == '1')
            {
				index = (leds/8) + 1;
				val = (leds % 8);
				val = 1 << val;
				buffer[index] |= val;
				//            buffer[(leds/8) + 1] |= 1 << (leds % 8);
            }
        }
		result = IOWarriorWriteInterface1 (0x15, buffer);
		if (result != 0)
        {
			result = IOWarriorWriteInterface1At24 (0x15, buffer);
			if (result != 0)
				return result;
        }
    }
	StartSequence ();
	return 0;
}

int DisplayDataNowIOWarrior56 ()
{
	
	int				row;
	int				column;
	int				block;
	OSStatus		err;
	IOWarriorHIDDeviceInterface** interface;

	unsigned char   buffer[64];
	
	interface = IOWarriorFirstInterfaceOfType (kIOWarrior56Interface1);

	// compute block 0
	for (block = 0; block < 2; block++)
	{
		bzero (buffer, 64); // clear buffer before re-use
		buffer[0] = 0x15;	// report ID for LED Data
		buffer[1] = block; // first byte identifies block 
		
		for (row = 0; row <  4; row++)
		{
			for (column = 0; column < kLEDsPerLineIOWarrior56; column++)
			{
				if (gLedMatrix[(block * 4) + row][column] == '1')
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
		err = IOWarriorWriteToInterface (interface, 64, buffer);
		if (err)
			return err;
	}
	StartSequence ();
	return 0;
}

IOWarriorHIDDeviceInterface** FirstSupportedInterfaceWithType (int *outType)
{
	IOWarriorHIDDeviceInterface** interface;
	
	interface = IOWarriorFirstInterfaceOfType (kIOWarrior24Interface1);
	if (interface)
	{
		*outType = kIOWarrior24Interface1;
		return interface;
	}
	
	interface = IOWarriorFirstInterfaceOfType (kIOWarrior40Interface1);
	if (interface)
	{
		*outType = kIOWarrior40Interface1;
		return interface;
	}
	
	interface = IOWarriorFirstInterfaceOfType (kIOWarrior56Interface1);
	if (interface)
	{
		*outType = kIOWarrior56Interface1;
		return interface;
	}

	return nil;
}

//------------------------------------------------------------------

int EnableLEDMode (bool on)
{
	unsigned char					buffer[64];
	int								reportSize;
	IOWarriorHIDDeviceInterface**	interface;
	int								interfaceType;
	
	interface = FirstSupportedInterfaceWithType(&interfaceType);
	
	if (interface)
	{
		if (interfaceType == kIOWarrior56Interface1)
		{
			reportSize = 64;
		}
		else
		{
			reportSize = 8;
		}
		
		bzero (buffer, reportSize);
		buffer[0] = 0x14; // led mode
		buffer[1] = (on ? 1 : 0); // set enable bit
		
		return IOWarriorWriteToInterface (interface, reportSize, buffer);
	}
	return -1;
}

//------------------------------------------------------------------
int IOWarriorWriteInterface1At24 (int inReportID, void *inData)
{
    IOWarriorHIDDeviceInterface** interface = IOWarriorFirstInterfaceOfType (kIOWarrior24Interface1);
    
    if (interface)
    {
        char buffer[8];
        
        buffer[0] = inReportID;
        memcpy (&buffer[1], inData, 7);
        
        return IOWarriorWriteToInterface (interface, 8, buffer);
    }
    return -1;
}

//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
