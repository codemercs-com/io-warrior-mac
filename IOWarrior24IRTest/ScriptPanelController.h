//
//  ScriptPanelController.h
//  IOWarrior24IRTest
//
//  Created by ilja on Fri Oct 10 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@class Script;

@interface ScriptPanelController : NSWindowController 
{
    IBOutlet NSObjectController*    scriptController;
    id                              delegate;
    NSMutableDictionary*            script;
    NSMutableDictionary*            backup;
}

+ (BOOL) runScriptPanelSheetForWindow:(NSWindow*) inWindow script:(NSMutableDictionary*) inScript
                                     delegate:(id) inDelegate;

- (id) initWithScript:(NSMutableDictionary*) inScript;

- (IBAction) doTestScript:(id) sender;
- (IBAction) doOK:(id) sender;
- (IBAction) doCancel:(id) sender;

- (void) setDelegate:(id) inDelegate;

@end

@interface NSObject (ScriptPanelControllerDelegate)
- (BOOL) shouldAcceptScript:(NSMutableDictionary*) inScriptDescription;
@end
