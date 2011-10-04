/* MyController */

#import <Cocoa/Cocoa.h>
#import "IOWarriorLib.h"

@class InterfaceWriter;

@interface MyController : NSObject
{
    IBOutlet NSTextField	*theField;
	IBOutlet NSSlider		*speedSlider;
	IBOutlet NSPopUpButton  *fontPopup;
	IBOutlet NSPopUpButton  *interfacePopup;
	IBOutlet NSButton		*startStopButton;
	
	NSMutableArray  *writers;

}
- (IBAction) startOrStop:(id)sender;
- (IBAction) speedSliderChanged:(id)sender;
- (void) fontPopupChanged:(id) sender;
- (IBAction) interfacePopupChanged:(id) sender;

- (void) populateInterfacePopup;
- (NSFont*) selectedFont;
- (NSString*) nameForIOWarriorInterfaceType:(int) inType;

- (InterfaceWriter*) selectedWriter;
- (InterfaceWriter*) writerForInterface:(IOWarriorHIDDeviceInterface**) inInterface;
- (IOWarriorHIDDeviceInterface**) selectedInterface;

@end
