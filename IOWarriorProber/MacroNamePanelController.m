//
//  MacroNamePanelController.m
//  IOWarriorCocoaGUITest
//
//  Created by ilja on Wed Mar 26 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "MacroNamePanelController.h"


@implementation MacroNamePanelController

+ (NSString*) chooseMacroName
{
    MacroNamePanelController* 	theController;
    NSString* 			result = nil;
    int				returnCode;

    theController = [[MacroNamePanelController alloc] init];
    [theController showWindow:nil];
    returnCode = [NSApp runModalForWindow:[theController window]];
    if (returnCode == NSRunStoppedResponse)
    {
        result = [theController macroName];
    }
    [theController close];
    [theController autorelease];
    return result;
}

- (id) init
{
    self = [self initWithWindowNibName:@"MacroName"];
    return self;
}

- (IBAction)doCancel:(id)sender
{
    [NSApp abortModal];
}

- (IBAction)doOK:(id)sender
{
    [NSApp stopModal];
}

- (NSString*) macroName
{
    return [nameField stringValue];
}
@end
