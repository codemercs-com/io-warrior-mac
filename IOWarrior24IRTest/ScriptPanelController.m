//
//  ScriptPanelController.m
//  IOWarrior24IRTest
//
//  Created by ilja on Fri Oct 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "ScriptPanelController.h"
#import "NDAppleScriptObject.h"

@implementation ScriptPanelController

+ (BOOL) runScriptPanelSheetForWindow:(NSWindow*) inWindow script:(NSMutableDictionary*) inScript
                             delegate:(id) inDelegate;
/*" Displays a panel that lets user specify an AppleScript and a name for it. If inDictionary is not nil, 
    the dialog is initialized with values for keys @"name" and @"script". If user hits OK, returns a dictionary
    containing entered values under the keys @"name" and @"key". If inDelegate is not nil, it will be sent a 
    shouldAcceptScriptWithDescription: message where the only parameter is a dictionary of the same form as returned
    by this method. Only if the delegate responds with yes, the panel will close."*/

{
    ScriptPanelController* controller;
    int response;
    
    controller = [[ScriptPanelController alloc] initWithScript:inScript];
    
    [controller setDelegate:inDelegate]; 
    [NSApp beginSheet:[controller window]
       modalForWindow:inWindow
        modalDelegate:nil
       didEndSelector:nil
          contextInfo:nil];
    response = [NSApp runModalForWindow:[controller window]];
    [NSApp endSheet: [controller window]];
    [[controller window] orderOut: self];
    [controller autorelease];
    return (NSRunStoppedResponse == response);
}

- (id) initWithScript:(NSMutableDictionary*) inScript
{
    self = [self initWithWindowNibName:@"ScriptPanel"];
    if (self)
    {
        script = [inScript retain];
        backup = [script mutableCopy];
    }
    return self;
}

- (void) dealloc
{
    [script release];
    [backup release];
    [delegate release];
    
    [super dealloc];
}

- (void) awakeFromNib
{
    [scriptController setContent:script];
}

- (IBAction) doOK:(id) sender
{
    NSString* name;
    NSString* source;
    
    [[self window] makeFirstResponder:[self window]];
    
    name = [script objectForKey:@"name"];
    source = [script objectForKey:@"source"];
    if (nil == name || [name isEqualTo:@""])
    {
        NSRunAlertPanel (@"Missing Script Name.", @"You have to supply a unique name for this script.",
                         @"OK", nil, nil);
        return;
    }
    if (nil == source || [source isEqualTo:@""])
    {
        NSRunAlertPanel (@"Empty Script", @"You have to enter some script code.",
                         @"OK", nil, nil);
        return;
    }
    if ([delegate shouldAcceptScript:script])
    {
        [NSApp stopModal];
    }
}

- (IBAction) doCancel:(id) sender
{
    [script addEntriesFromDictionary:backup];
    [NSApp abortModal];
}

- (IBAction) doTestScript:(id) sender
{
    NDAppleScriptObject* theScript;
    
    if (nil == (theScript = [NDAppleScriptObject appleScriptObjectWithString:[script objectForKey:@"source"]]))
    {
        NSRunAlertPanel (@"Compile Error", @"You script contains an error. Please check.",
                         @"OK", nil, nil);
        return;
    }
    [theScript execute];
}

- (void) setDelegate:(id) inDelegate
{
    [delegate autorelease];
    delegate = [inDelegate retain];
}

@end