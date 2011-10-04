//
//  MacroNamePanelController.h
//  IOWarriorCocoaGUITest
//
//  Created by ilja on Wed Mar 26 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface MacroNamePanelController : NSWindowController {
    IBOutlet NSTextField* nameField;
}

+ (NSString*) chooseMacroName;

- (id) init;
- (IBAction)doCancel:(id)sender;
- (IBAction)doOK:(id)sender;

- (NSString*) macroName;

@end
