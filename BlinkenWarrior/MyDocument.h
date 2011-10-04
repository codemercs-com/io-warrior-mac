/*
	MyDocument.h
	Copyright (c) 2004 by CodeMercenaries GmbH, all rights reserved.
	Author: Ralf Menssen

*/

#import <Cocoa/Cocoa.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "IOWarriorLib.h"

@interface MyDocument : NSDocument {
@private

    NSData							*mDataFromFile;
    bool							mWeHaveData;
    long							mFrameCount;
    long							mLeds;
    long							mLines;
    long							mDuration;
    IBOutlet NSWindow				*documentWindow;
    IBOutlet NSTextField			*keyDataFileName;
    IBOutlet NSTextField			*downloadStatus;

}

- (void)initialize;
- (void)dealloc;

- (void)loadTextViewWithInitialData:(NSData *)data;

- (void)SetDownloadStatus:(NSString *) statusStr;
- (void)SetDataFileInformation:(NSString *) statusStr;
- (bool)PlayFile: (NSData *) data doLoop:(bool)doLoop;
- (IBAction)doPlay:(id)sender;
- (IBAction)doLoopPlay:(id)sender;


@end

extern bool gHaveIOWarrior;
extern bool gHasDocument;
extern bool gIOWarriorIsInitialzed;