//
//  InterfaceWriter.h
//  IOWarriorLEDText
//
//  Created by ilja on Fri Jun 18 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "IOWarriorLib.h"

@interface InterfaceWriter : NSObject {
	IOWarriorHIDDeviceInterface **interface;	/*" the iowarrior interface we are dealing with "*/
	NSFont						*font;			/*" the font we are using "*/
	NSString					*string;		/*" the string to be displayed "*/
	float						delay;			/*" how much time to let pass between writes "*/
	BOOL						running;		/*" are we still running "*/
	BOOL						bitmapDirty;	/*" do we need to re-generate the image rep "*/
	NSDate						*lastRun;		/*" the last time a write operation took place "*/
	int							startColumn;	/*" first column of image rep to be written to iowarrior "*/
	float						currentFontDescender;   /*"descender of the font used "*/
	int							interfaceType;
	
	NSBitmapImageRep			*currentImageRep;
}

- (id) initWithInterface:(IOWarriorHIDDeviceInterface**) inInterface
					font:(NSFont*) inFont
				  string:(NSString*) inString
				   delay:(float) inDelay
		   interfaceType:(int) inInterfaceType;

- (IOWarriorHIDDeviceInterface**) interface;

- (void) enableLEDMode;

- (NSFont *) font;
- (void) setFont: (NSFont *) inFont;

- (NSString *) string;
- (void) setString: (NSString *) inString;

- (float) delay;
- (void) setDelay: (float) inDelay;

- (BOOL) running;
- (void) setRunning: (BOOL) flag;

- (int) interfaceType;
- (void) setInterfaceType:(int) inInterfaceType;

- (NSBitmapImageRep*) bitmapForString:(NSString*) inString;

- (void) downloadImageRep:(NSBitmapImageRep*) inImageRep startColumn:(int) inStartColumn;
- (void) downloadImageRepToIOW56:(NSBitmapImageRep*) inImageRep startColumn:(int) inStartColumn;

- (BOOL) pixelIsSetInImageRep:(NSBitmapImageRep*)inImageRep atRow:(int) inRow column:(int) inColumn;


@end
