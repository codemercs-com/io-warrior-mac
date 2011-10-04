#import "MainController.h"
#import "IOWarriorLib.h"
#import "ScriptPanelController.h"
#import "CommandPanelController.h"
#import "Command.h"
#import "NDAppleScriptObject.h"

/*" Preferences Keys "*/
#define kCommandsKey @"commandSets"
#define kScriptsKey @"scripts"
#define kDefaultSetKey @"defaultSet"

char            gCommandBuffer[8];
NSDictionary*   rc5codes = nil;

void IOWarriorInterruptCallback (void* target, IOReturn result,void* refcon, void* sender,UInt32 bufferSize){    
    if (kIOReturnSuccess == result)
        [(MainController*) refcon handleReceivedIRData:target];
}

void IOWarriorCallback (void* inRefCon)
        /*" Invoked when an IOWarriorDevice appears or disappears. Arms first device for receiving IR commands . "*/
{
    BOOL            deviceFound = NO;
    int             interfaceCount;
    int             i;
    MainController*   controller = inRefCon;
    
    interfaceCount = IOWarriorCountInterfaces ();
    for (i = 0; i < interfaceCount; i++)
    {
        IOWarriorListNode* theNode;
        
        theNode = IOWarriorInterfaceListNodeAtIndex(i); 
        if (kIOWarrior24Interface1 ==  theNode->interfaceType)
        {
            char params[8];
            
            bzero (params, 8);
            params[0] = 0x0C;
            params[1] = 0x01;
            
            IOWarriorSetInterruptCallback(theNode->ioWarriorHIDInterface, gCommandBuffer, 8, IOWarriorInterruptCallback, controller);
            IOWarriorWriteToInterface(theNode->ioWarriorHIDInterface,8,params);
            deviceFound = YES;
            break;
        }
    }
    [controller udpateIOWarriorState:deviceFound];
}   

@implementation MainController

+ (void) initialize
{
    NSDictionary *defaultsDict;
    
    defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" 
                                                                                              ofType:@"plist"]];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
}

- (void) awakeFromNib
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSEnumerator*   e;
    NSDictionary*   theDictionary;
    
    // init members
    dataRepetitionCount = 0;
    lastReceivedData = 0;
    defaultSetName = [[NSString alloc] init];
        
    // Init Library
    IOWarriorInit();
    IOWarriorSetDeviceCallback(IOWarriorCallback, self);
    IOWarriorCallback (self);
    
    // init sets
    sets = [[NSMutableDictionary alloc] init];
    
    // load saved command sets
    NSDictionary    *savedSets = [defaults objectForKey:kCommandsKey];
    NSString        *currentSet;
    
    e = [savedSets keyEnumerator];
    while (nil != (currentSet = [e nextObject]))
    {
        NSEnumerator*   savedCommandEnumerator = [[savedSets objectForKey:currentSet] objectEnumerator];
        NSMutableArray* commands;
        NSDictionary*   savedCommand;
        
        savedCommandEnumerator = [[savedSets objectForKey:currentSet] objectEnumerator];
        commands = [NSMutableArray array];
        while (nil != (savedCommand = [savedCommandEnumerator nextObject]))
        {
            [commands addObject:[[[Command alloc] initWithDescriptionDictionary:savedCommand] autorelease]];
        }
        [setsController addObject:currentSet];
        [sets setObject:commands forKey:currentSet];
    }
    // load name of default set
    [self setDefaultSetName:[defaults objectForKey:kDefaultSetKey]];
    
    // load saved scripts
    e = [[defaults objectForKey:kScriptsKey] objectEnumerator];
    while (nil != (theDictionary = [e nextObject]))
    {
        [scriptsController addObject:[NSMutableDictionary dictionaryWithDictionary:theDictionary]];
    }
    
    // Init GUI
    [lastCommandField setStringValue:@""];
    [commandTable setTarget:self];
    [commandTable setDoubleAction:@selector(commandTableDoubleClicked:)];
    [scriptTable setTarget:self];
    [scriptTable setDoubleAction:@selector(scriptTableDoubleClicked:)];
    [configureLastCommandButton setEnabled:NO];
    [makeDefaultSetButton setEnabled:[self currentSetCanBecomeDefaultSet]];
    [self commandSetPopupChanged:self];
}

- (void) dealloc
{
    [sets release];
    [lastReceivedCommand release];
    [defaultSetName release];
    [super dealloc];
}

- (void) udpateIOWarriorState:(BOOL) inState
{
    [stateField setStringValue: (inState ? @"IOWarrior24 present" : @"IOWarrior24 NOT present")];
}

- (IBAction)addCommandAction:(id)sender
{
    Command* newCommand = [Command command];
            
    if ([CommandPanelController runCommandPanelForWindow:mainWindow
                                                          command:newCommand
                                                          scripts:[self scriptNames]
                                                         delegate:self])
    {
        [[self currentSet]  addObject:newCommand];
        [commandsController addObject:newCommand];
    }
}

- (IBAction) removeCommmandAction:(id) sender
{
    [[self currentSet] removeObject: [[commandsController selectedObjects] objectAtIndex:0]];
    [commandsController remove:self];
}

- (void) handleReceivedIRData:(char*) inData
{
    UInt8 address, IRCommand, toggleBit;
    Command* theCommand;
    
    if (inData[0] != 0x0C)
        return;
    IRCommand = inData[1];
    if (!(inData[2] & 0x40)) 
        IRCommand |= 0x40;
    address = inData[2] & 0x1F;
    toggleBit = (inData[2] & 0x20) >> 5; // bit 5 is toggle bit
    
    if (lastReceivedData == (*(UInt32*) inData))
        dataRepetitionCount++;
    else {
        dataRepetitionCount = 0;
        lastReceivedData = (*(UInt32*) inData);
    }
    
    if (nil != (theCommand = [self findCommandForDevice:address IRCommand:IRCommand]))
        [self executeCommand:theCommand repetition:dataRepetitionCount];
    
    [self setLastReceivedCommand:[Command commandWithDevice:address
                                                  IRCommand:IRCommand
                                                     script:nil
                                                    repeats:NO
                                        repetitionThreshold:3]];
    
    [lastCommandField setStringValue:[NSString stringWithFormat:@"Device: %@ (%d), Command: %@ (%d)",
        [MainController deviceNameForAddress:address],
        address,
        [MainController nameForCommand:IRCommand],
        IRCommand]];
    
    
    [configureLastCommandButton setEnabled:YES];
}

- (void) setLastReceivedCommand:(Command*) inCommand
{
    [lastReceivedCommand autorelease];
    lastReceivedCommand = [inCommand retain];
}

- (IBAction) doConfigureCommand:(id) sender
{
    Command* theCommand;
    
    if (!lastReceivedCommand) // nothing received so far, nothing to configure
        return;
    
    if (nil != (theCommand = [self findCommandForDevice:[lastReceivedCommand device]
                                         IRCommand:[lastReceivedCommand IRCommand]]))
    {
        editedCommand = theCommand;
        [CommandPanelController runCommandPanelForWindow:mainWindow
                                                 command:theCommand
                                                 scripts:[self scriptNames]
                                                delegate:self];
        theCommand = nil;
    }
    else
    {
        theCommand = [Command commandWithDevice:[lastReceivedCommand device]
                                      IRCommand:[lastReceivedCommand IRCommand]
                                         script:[lastReceivedCommand script]
                                        repeats:[lastReceivedCommand repeats]
                            repetitionThreshold:[lastReceivedCommand repetitionThreshold]];
        if ([CommandPanelController runCommandPanelForWindow:mainWindow
                                                 command:theCommand
                                                 scripts:[self scriptNames]
                                                delegate:self])
        {
            [commandsController addObject:theCommand];
            [[self currentSet]  addObject:theCommand];
        }
    }
}

- (Command*) findCommandForDevice:(int) inDevice IRCommand:(int)inIRCommand
{
    Command*    result;
    NSString*   currentApplication;
    
    currentApplication = [[[NSWorkspace sharedWorkspace] activeApplication] objectForKey:@"NSApplicationName"];
    if (nil != (result = [self findCommandForDevice:inDevice IRCommand:inIRCommand inCommandSet:[sets objectForKey:currentApplication]]))
        return result;
    return [self findCommandForDevice:inDevice IRCommand:inIRCommand inCommandSet:[sets objectForKey:defaultSetName]];
}

- (Command*) findCommandForDevice:(int) inDevice IRCommand:(int)inIRCommand inCommandSet:(NSArray*) inSet
{
    NSEnumerator*   e = [inSet objectEnumerator];
    Command*        theCommand;
    
    while (nil != (theCommand = [e nextObject]))
    {
        if ([theCommand device] == inDevice &&
            [theCommand IRCommand] == inIRCommand)
        {
            return theCommand;
        }
    }
    return nil;
}

- (NSArray*) scriptNames
{
    NSEnumerator*   scriptEnumerator = [[scriptsController arrangedObjects] objectEnumerator];
    NSMutableArray* result = [NSMutableArray array];
    NSDictionary*         theScript;

    while (nil != (theScript = [scriptEnumerator nextObject]))
    {
        [result addObject:[theScript objectForKey:@"name"]];
    }
    
    return [result sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSMutableDictionary*) scriptWithName:(NSString*) inName
{
    NSEnumerator*           scriptEnumerator = [[scriptsController arrangedObjects] objectEnumerator];
    NSMutableDictionary*    theScript;
    
    while (nil != (theScript = [scriptEnumerator nextObject]))
    {   
        if ([[theScript objectForKey:@"name"] isEqualToString:inName])
            return theScript;
    }
    return nil;
}

- (void) executeCommand:(Command*) inCommand repetition:(int) inRepetition {    
    if ((0 == inRepetition) || ([inCommand repeats] && inRepetition >= [inCommand repetitionThreshold])) {
        NSString* source =[[self scriptWithName:[inCommand script]] objectForKey:@"source"];
        [[NDAppleScriptObject appleScriptObjectWithString:source] execute];
    }
}

+ (NSString*) nameForCommand:(int) inCommand
{
    NSArray* commandNames;
    
    if (nil == rc5codes)
    {
        rc5codes = [[NSDictionary alloc] initWithContentsOfFile:
            [[NSBundle mainBundle] pathForResource:@"rc5codes" ofType:@"plist"]];
    }
    
    commandNames = [rc5codes objectForKey:@"commands"];
    if (inCommand < [commandNames count])
        return [commandNames objectAtIndex:inCommand];
    
    return @"";
}

+ (NSString*) deviceNameForAddress:(int) inAddress
{
    NSArray* devices;
    
    if (nil == rc5codes)
    {
        rc5codes = [[NSDictionary alloc] initWithContentsOfFile:
            [[NSBundle mainBundle] pathForResource:@"rc5codes" ofType:@"plist"]];
    }
    
    devices = [rc5codes objectForKey:@"devices"];
    
    if (inAddress < [devices count])
        return [devices objectAtIndex:inAddress];
    
    return @"";
}

- (BOOL) shouldAcceptScript:(NSDictionary*) inScript
{
    NSString*       scriptName = [inScript objectForKey:@"name"];
    NSMutableDictionary*   existingScript;
    
    existingScript = [self scriptWithName:scriptName];
    
     if (existingScript &&
         (existingScript != inScript))
    {
        
        NSRunAlertPanel(@"Script Name Already used" ,@"Cannot add script, because a script by that name already exists.",
                            @"OK", nil, nil);
        return NO;
    }
    return YES;
}
- (void) scriptTableDoubleClicked:(id) sender
{
    if ([[scriptsController selectedObjects] count])
    {
        NSMutableDictionary* selectedScript = [[scriptsController selectedObjects] objectAtIndex:0];
        
        [scriptsController removeObject:selectedScript];
        [ScriptPanelController runScriptPanelSheetForWindow:mainWindow
                                                     script:selectedScript
                                                    delegate:self];
        [scriptsController addObject:selectedScript];
    }
}

- (void) commandTableDoubleClicked:(id) sender
{
    if ([[commandsController selectedObjects] count])
    {
        Command* selectedCommand = [[commandsController selectedObjects] objectAtIndex:0];
        
        editedCommand = selectedCommand;
        [CommandPanelController runCommandPanelForWindow:mainWindow
                                                command:selectedCommand
                                                scripts:[self scriptNames]
                                                delegate:self];
        editedCommand = nil;  
    }
}

- (IBAction) addScriptAction:(id) sender
{
    NSMutableDictionary* newScript;
    
    newScript = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Neues Script", @"name", 
        @"", @"source", nil];
    
    if ([ScriptPanelController runScriptPanelSheetForWindow:mainWindow
                                                 script:newScript
                                               delegate:self])
    {
        [scriptsController addObject:newScript];
    }
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    NSUserDefaults*         defaults = [NSUserDefaults standardUserDefaults];
    NSEnumerator*           e;
    Command*                theCommand;
    NSMutableArray*         theArray;
    NSDictionary*           theScript;
    NSMutableDictionary*    theDictionary = [NSMutableDictionary dictionary];
    NSString*               theCommandSet;
    
    // save commands to default database
    e = [sets keyEnumerator];
    while (nil != (theCommandSet = [e nextObject]))
    {
        NSEnumerator *commandIterator = [[sets objectForKey:theCommandSet] objectEnumerator]; 
        theArray = [NSMutableArray array];
        
        while (nil != (theCommand = [commandIterator nextObject])){
            [theArray addObject:[theCommand descriptionDictionary]];
        }
        [theDictionary setObject:theArray forKey:theCommandSet];
    }
    [defaults setObject:theDictionary forKey:kCommandsKey];
    
    // save default set name
    [defaults setObject:defaultSetName forKey:kDefaultSetKey];
    
    // save scripts
    e = [[scriptsController arrangedObjects] objectEnumerator] ;
    theArray = [NSMutableArray array];
    {
        while (nil != (theScript = [e nextObject])){
            [theArray addObject:theScript];
        }
        
    }
    [defaults setObject:theArray forKey:kScriptsKey];
    [defaults synchronize];
}


- (BOOL) shouldAcceptCommand:(Command*) inCommand
{
    Command* existingCommand;
    
    existingCommand = [self findCommandForDevice:[inCommand device]
                                       IRCommand:[inCommand IRCommand]
                                    inCommandSet:[self currentSet]];
    if (nil == existingCommand) // we dont have a configuration for this ir command
        return YES;
    
    if ([inCommand device] == [editedCommand device] &&
        [inCommand IRCommand] == [editedCommand IRCommand]) // we are editing the existing command
        return YES;
    
    NSRunAlertPanel(@"Command Configuration Already existing",
                    @"There is already another configuration for the IR command you are trying to add.",
                    @"OK",nil,nil);
    return NO;
}

- (IBAction) addSetAction:(id) sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    
    [op setAllowsMultipleSelection:YES];
    [op beginSheetForDirectory:@"/Applications"
                          file:nil
                         types:[NSArray arrayWithObjects:@"app",nil]
                modalForWindow:mainWindow
                 modalDelegate:self
                didEndSelector:@selector(addSetPanelDidEnd:returnCode:contextInfo:)
                   contextInfo:nil];
}

- (IBAction) removeSetAction:(id) sender
{
    if ([[setsController arrangedObjects] count] > 1) // prevent removal of the last set
    {
        [sets removeObjectForKey:[[setsController selectedObjects] objectAtIndex:0]];
        [setsController remove:self];
        [self makeCurrentSet:[[setsController arrangedObjects] objectAtIndex:0]]; // select first remaining set
    }
}

- (void)addSetPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (NSOKButton == returnCode)
    {
        NSEnumerator* e = [[sheet filenames] objectEnumerator];
        NSString*	theFile;
        
        while (nil != (theFile = [e nextObject]))
        {
            NSString* appName = [[NSFileManager defaultManager] displayNameAtPath:theFile];
            
            if (![[sets allKeys] containsObject:appName])
            {
                [sets setObject:[NSMutableArray array] forKey:appName];
                [setsController addObject:appName];
                [self makeCurrentSet:appName];
            }
        }
    }
}

- (void) makeCurrentSet:(NSString*) inSet
{
    // switches popup menu
    [setsController setSelectedObjects:[NSArray arrayWithObject:inSet]];
    
    // remove existing objects from commands controller
    [commandsController removeObjects:[commandsController arrangedObjects]];
    
    // install commands for other application
    [commandsController addObjects:[sets objectForKey:inSet]];
    
    // update state of currentSetCanBecomeDefaultSet
    [makeDefaultSetButton setEnabled:[self currentSetCanBecomeDefaultSet]];
}

- (NSMutableArray*) currentSet
{
    NSString* selectedSet;
    
    if (nil != (selectedSet = [[setsController selectedObjects] objectAtIndex:0]))
    {
        return [sets objectForKey:selectedSet];
    }
    return nil;
}

- (IBAction) commandSetPopupChanged:(id) sender
{
    if ([[setsController selectedObjects] count])
    {
        [self makeCurrentSet:[[setsController selectedObjects] objectAtIndex:0]];
    }
}

- (IBAction) makeDefaultSetAction:(id) sender;
{
    [self setDefaultSetName:[[setsController selectedObjects] objectAtIndex:0]];
    [makeDefaultSetButton setEnabled:[self currentSetCanBecomeDefaultSet]];
}

- (void) setDefaultSetName:(NSString*) inSetName
{
    [defaultSetName autorelease];
    defaultSetName = [inSetName retain];
}

- (BOOL) currentSetCanBecomeDefaultSet
{
    if ([[setsController selectedObjects] count])
    {
        return ![defaultSetName isEqualToString:[[setsController selectedObjects] objectAtIndex:0]];
    }
    return NO;
}

@end
