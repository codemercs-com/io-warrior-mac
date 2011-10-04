/* IRController */

#import <Cocoa/Cocoa.h>

#define kMaxDeviceCount 32
#define kMaxCommandCount 128

@class Command;

@interface MainController : NSObject
{
    IBOutlet NSTableView    *commandTable;
    IBOutlet NSTableView    *scriptTable;
    IBOutlet NSTextField    *lastCommandField;
    IBOutlet NSTextField    *stateField;
    IBOutlet NSWindow       *mainWindow;
    IBOutlet NSButton       *configureLastCommandButton;
    IBOutlet NSButton       *makeDefaultSetButton;
    
    IBOutlet NSArrayController  *scriptsController;
    IBOutlet NSArrayController  *commandsController;
    IBOutlet NSArrayController  *setsController;    
    
    UInt32                  lastReceivedData;               /*" last received ir data "*/
    int                     dataRepetitionCount;            /*" how often have received the same ir data in a row "*/
    Command                 *editedCommand;                 /*" pointer to the command currently being edited in command panel "*/
    Command                 *lastReceivedCommand;           /*" the last Received command "*/
    NSMutableDictionary     *sets;
    NSString                *defaultSetName;
}

/*" IBActions "*/

- (IBAction) addScriptAction:(id) sender;
- (IBAction) addCommandAction:(id) sender;
- (IBAction) removeCommmandAction:(id) sender;
- (IBAction) addSetAction:(id) sender;
- (IBAction) removeSetAction:(id) sender;
- (IBAction) commandSetPopupChanged:(id) sender;
- (IBAction) makeDefaultSetAction:(id) sender;
- (IBAction) doConfigureCommand:(id) sender;

/*" Set Management "*/
- (NSMutableArray*) currentSet;
- (void) makeCurrentSet:(NSString*) inSet;
- (void) setDefaultSetName:(NSString*) inSetName;

/*" Command Management "*/
- (Command*) findCommandForDevice:(int) inDevice IRCommand:(int)inIRCommand;
- (Command*) findCommandForDevice:(int) inDevice IRCommand:(int)inIRCommand inCommandSet:(NSArray*) inSet;
- (void) executeCommand:(Command*) inCommand repetition:(int) inRepetition;
- (void) setLastReceivedCommand:(Command*) inCommand;

+ (NSString*) nameForCommand:(int) inCommand;
+ (NSString*) deviceNameForAddress:(int) inCommand;

/*" Script Management "*/

- (NSMutableDictionary*) scriptWithName:(NSString*) inName;
- (NSArray*) scriptNames;

- (void) udpateIOWarriorState:(BOOL) inState;
- (void) handleReceivedIRData:(char*) inData;

- (BOOL) currentSetCanBecomeDefaultSet;
@end
