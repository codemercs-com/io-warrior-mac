/* IOWarriorWindowController */

#import <Cocoa/Cocoa.h>
#import "IOWarriorLib.h"

@interface IOWarriorWindowController : NSObject
{
    BOOL		isReading;
    NSTimer*		readTimer;

    BOOL		ignoreDuplicates;
    
    NSMutableArray*	logEntries;
    
    IBOutlet	NSTableView*	logTable;
    IBOutlet	NSWindow*	window;
    IBOutlet	NSPopUpButton*	interfacePopup;
    IBOutlet	NSPopUpButton*	macroPopup;
    IBOutlet	NSTextField*	reportIDField;	    /*" id for reports sent "*/
    IBOutlet	NSButton*	ignoreDuplicatesCheckBox; 
    IBOutlet    NSButton*       readButton;
    IBOutlet    NSButton*       addMacroButton;

    NSData*	lastValueRead; /*" The last value read"*/
}

/*" Actions methods"*/
- (IBAction)doRead:(id)sender;
- (IBAction)doWrite:(id)sender;
- (IBAction)interfacePopupChanged:(id)sender;
- (IBAction)clearLogEntries:(id)sender;
- (IBAction)macroPopupChanged:(id)sender;
- (IBAction)addMacro:(id)sender;
- (IBAction)deleteMacro:(id)sender;
- (IBAction)resetReportValues:(id)sender;
- (IBAction)duplicateCheckboxClicked:(id)sender;
- (IBAction) closeInterface:(id) sender;

/*" Timer  "*/
- (BOOL)readDataFromCurrentInterface;

/*" Interface validation "*/
- (void) populateInterfacePopup;
- (void) updateMacroPopup;

/*" Logging "*/
- (void) addLogEntryWithDirection:(NSString*) inDirection reportID:(int)inReportID
                       reportSize:(int) inSize reportData:(UInt8*) inData;
+ (NSDictionary*) logEntryWithDirection:(NSString*) inDirection reportID:(int) inReportID
                             reportSize:(int) inSize reportData:(UInt8*) inData name:(NSString*) inName;
- (void) updateInterfaceFromLogEntry:(NSDictionary*) inLogEntry;

/*" Reading "*/

- (void) startReading;
- (void) stopReading;
- (void) timedRead:(NSTimer*) inTimer;

- (void) setLastValueRead:(NSData*) inData;

/*" Misc stuff "*/

- (BOOL) reportIdRequiredForWritingToInterfaceOfType:(int) inType;
- (IOWarriorHIDDeviceInterface**) currentInterface;
- (int) currentInterfaceType;
- (int) reportSizeForInterfaceType:(int) inType;

@end
