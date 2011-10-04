#import <Cocoa/Cocoa.h>


@interface AppController :NSObject {
	
	IBOutlet NSArrayController	*foundInterfacesController;
	IBOutlet NSArrayController	*foundDevicesController;
	IBOutlet NSTreeController	*writeHistoryController;
	
	IBOutlet NSTreeController	*mainTreeController;
	
	IBOutlet NSArrayController	*readDataDisplayStringsController;
	
	IBOutlet NSWindow			*mainWindow;
	
	IBOutlet NSTextField		*writeDataField;
	IBOutlet NSTextField		*sensibusCommandField;
	
	unsigned char				currentScanAddress;
	
	IBOutlet NSTextField		*readByteCountField;
	
	IBOutlet NSOutlineView		*writeHistoryOutlineView;
	IBOutlet NSTableView		*readHistoryTableView;
	
	BOOL	isScanningForDevices;
	
	IBOutlet NSButton			*writeActionButton;
	IBOutlet NSButton			*readActionButton;
	
	NSDictionary	*currentScanInterface;
}

- (void) discoverInterfaces;

- (void) scanNewInterfacesForDevices;
- (void) scanAllInterfacesForDevices;

- (void) scanSelectedInterfaceForDevices;

- (void) checkNextAddressForDevice;
- (void) saveCurrentScanAddress;

- (void) selectInterfaceForDictionary:(NSDictionary*) interfaceDictionary;

- (IBAction) scanForDevices:(id) sender;
- (IBAction) write:(id) sender;
- (IBAction) read:(id) sender;
- (IBAction) interfaceOptionsChanged:(id) sender;

- (unsigned char) selectedDeviceAddress;
- (NSMutableDictionary*) selectedInterfaceDictionary;

- (void) handleReadResponse:(NSArray*) inReadData;

- (BOOL) useHex;
- (void) setUseHex: (BOOL) flag;

- (unsigned char) sensibusCommand;

- (void) handleError:(OSStatus) inErr;

- (NSDictionary *) currentScanInterface;
- (void) setCurrentScanInterface: (NSDictionary *) inCurrentScanInterface;


@end
