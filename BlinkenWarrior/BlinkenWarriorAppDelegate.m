#import "BlinkenWarriorAppDelegate.h"
#import "MyDocument.h"

bool gHaveIOWarrior = false;
bool gIOWarriorIsInitialzed = false;

@implementation BlinkenWarriorAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *) notification
{
if (!gIOWarriorIsInitialzed)
    {
    gIOWarriorIsInitialzed = true;
    if (IOWarriorInit ())
        {
        NSRunAlertPanel (@"Error", @"Could not initialize IOWarrior Lib", @"OK", NULL, NULL);
        }
    else
        {
//        NSRunAlertPanel (@"Okay", @"initialize IOWarrior Lib", @"OK", NULL, NULL);
        gHaveIOWarrior = (IOWarriorIsPresent () > 0);
        }
    }
if (!gHasDocument)
    [[NSDocumentController sharedDocumentController] openDocument:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification;
{

}


@end
