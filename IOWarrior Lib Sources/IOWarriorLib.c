/*
 *  IOWarriorLib.c
 *  IOWarriorHIDTest
 *
 *  Created by ilja on Sun Dec 29 2002.
 *  $Id: IOWarriorLib.c,v 1.7 2004/11/22 16:33:44 ilja Exp $
 *
 */

#include "IOWarriorLib.h"

#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDUsageTables.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <mach/mach.h>
#include <mach/mach_error.h>

// uncomment next line to see IOWarriorLib debug messages
#define IOWarriorDebug 1


//Global variables
static IONotificationPortRef    gNotifyPort;
static io_iterator_t            gIOWarriorAddedIter;
static io_iterator_t            gIOWarriorRemovedIter;

static IOWarriorListNode*	gIOWarriorList; // linked list of IOWarrior interfaces already discovered
static short			gIOWarriorListDirty; // is the IOWarrior interface list list up-to-date or dirty

IOWarriorDeviceCallbackFunctionPtr 	gIOWarriorCallBackPtr;
void*                                   gIOWarriorCallBackRefCon;

static CFArrayRef				gCustomDeviceIDs;

// Prototype declarations
void 			IOWarriorAdded(void *refCon, io_iterator_t iterator);
void 			IOWarriorRemoved(void *refCon, io_iterator_t iterator);
int  			IOWarriorWrite (int inWarriorIndex, int inInterfaceIndex, int inSize, void* inData);
int 			IOWarriorRead (int inWarriorIndex, int inInterfaceIndex, int inReportID, int inSize, void* outData);
io_iterator_t 		IOWarriorFindHIDDevices ();
void 			IOWarriorDiscoverInterfaces (void);
CFMutableDictionaryRef 	IOWarriorSetUpHIDMatchingDictionary ();
IOWarriorHIDDeviceInterface** 	IOWarriorCreateHIDDeviceInterface (io_object_t hidDevice);
void 			byteSwap (void* ioData, int inCount);
void 			IOWarriorAddInterfaceToList (IOWarriorHIDDeviceInterface** inInterface,
                                     int inInterfaceType, CFStringRef inDeviceSerialNumber);

void 			IOWarriorClearInterfaceList (void);
IOWarriorHIDDeviceInterface** 	IOWarriorGetInterface (int inWarriorIndex,int inInterfaceIndex);
IOWarriorListNode* 	IOWarriorGetInterfaceListNode (int inWarriorIndex,int inInterfaceIndex);

void 			IOWarriorRebuildInterfaceList (void);

// Debug utilities
void PrintNotificationMessage (char* msg);
void PrintErrMsg (char * msg);
void PrintErrMsgIfIOErr (long expr, char * msg);

int armNotificationsForDeviceWithID (int inDeviceID, int inVendorID, mach_port_t inMasterPort);


IONotificationPortRef GetNotificationPort ()
{
    return gNotifyPort;
}

void IOWarriorSetCustomDeviceIDs (CFArrayRef inCustomDeviceIDs)
{
	CFRetain (inCustomDeviceIDs);
	if (gCustomDeviceIDs)
	{
		CFRelease (gCustomDeviceIDs);
	}
	gCustomDeviceIDs = inCustomDeviceIDs;
	if (gCustomDeviceIDs)
	{
		CFRetain (gCustomDeviceIDs);
	}
	CFRelease (inCustomDeviceIDs);
}

CFMutableArrayRef IOWarriorCreateDeviceIDArray ()
{
	CFMutableArrayRef result;
	int knownIDs[] = {
		kIOWarrior40DeviceID, 
		kIOWarrior24DeviceID,
        kIOWarrior28DeviceID,
		kIOWarrior56DeviceID, 
		kIOWarrior24PVDeviceID, 
		kIOWarrior24CWDeviceID,
        kJoyWarrior24F8DeviceID,
        kMouseWarrior24F6DeviceID,
        kJoyWarrior24F14DeviceID};
	int	count = 8;
	int	i;
	
	result = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);

	for (i = 0; i < count;i++)
	{
		int			deviceID = knownIDs[i];
		CFNumberRef	numberRef;
				
		numberRef =  CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &deviceID);
		CFArrayAppendValue(result, numberRef);
		
		CFRelease (numberRef);
	}
	if (gCustomDeviceIDs)
	{
		CFRange theRange = {0, CFArrayGetCount(gCustomDeviceIDs)};
		CFArrayAppendArray(result, gCustomDeviceIDs, theRange);
	}
    return result;
}

int IOWarriorInit ()
{
    kern_return_t           result;
    mach_port_t             masterPort;
    CFRunLoopSourceRef      runLoopSource;
	CFMutableArrayRef		deviceIDs;
	long					i;
	long    				count;

    gIOWarriorList = NULL;
    gIOWarriorListDirty = 1;
    gIOWarriorCallBackPtr = NULL;
    
    //Create a master port for communication with the I/O Kit
    result = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (result || !masterPort)
    {
        return -1;
    }
    
    //To set up asynchronous notifications, create a notification port and
    //add its run loop event source to the programs run loop
    gNotifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
                       kCFRunLoopDefaultMode);
	
    deviceIDs = IOWarriorCreateDeviceIDArray ();
	count = CFArrayGetCount(deviceIDs);
	
	for (i = 0; i < count; i++)
	{
		CFNumberRef	deviceIDRef = CFArrayGetValueAtIndex(deviceIDs, i);
		int			deviceID; 
		
		CFNumberGetValue(deviceIDRef, kCFNumberSInt32Type, &deviceID);
		result = armNotificationsForDeviceWithID (deviceID, kIOWarriorVendorID, masterPort);
		if (result)
		{
			CFRelease (deviceIDs);
			mach_port_deallocate(mach_task_self(), masterPort);
			return -1;
		}
	}
	//Finished with master port
	CFRelease (deviceIDs);
    mach_port_deallocate(mach_task_self(), masterPort);

    return 0;
}

// Returns 1 if at least one IOWarrior is connected to this system. Returns 0 if no IOWarrior device could be discovered.
int IOWarriorIsPresent ()
{
    return (IOWarriorCountInterfaces () > 0);
}

// Returns the number of IOWarriors connected to this system
int IOWarriorCountInterfaces ()
{
    int 		result = 0;
    IOWarriorListNode* 	theNode;
    
    if (gIOWarriorListDirty)
    {
        IOWarriorRebuildInterfaceList ();
    }

    theNode = gIOWarriorList;
    
    while (NULL != theNode)
    {
        result++;
        theNode = theNode->nextNode;
    }
    
    return result;
}

// writes an 4 byte buffer to interface 0 of the first discovered IOWarrior40
int IOWarriorWriteInterface0 (void *inData)
{
    IOWarriorHIDDeviceInterface** interface = IOWarriorFirstInterfaceOfType (kIOWarrior40Interface0);
    
    if (interface)
    {
        return IOWarriorWriteToInterface (interface, 4, inData);
    }
    return -1;
}

// reads 4 byte from interface 0 of the first discovered IOWarrior40
int IOWarriorReadInterface0 (void *outData)
{
    IOWarriorHIDDeviceInterface** interface = IOWarriorFirstInterfaceOfType (kIOWarrior40Interface0);
    
    if (interface)
    {
        return IOWarriorReadFromInterface (interface, 0, 4, outData);
    }
    return -1;
}

// writes an 7 byte buffer to interface 1 of the first discovered IOWarrior40. Since passing simply 7 bytes and an reportID fails when doing the setReport call in IOWarriorWrite, reportID and data are merged into a single buffer which is passed to IOWarriorWrite using reportID 0
int IOWarriorWriteInterface1 (int inReportID, void *inData)
{
    IOWarriorHIDDeviceInterface** interface = IOWarriorFirstInterfaceOfType (kIOWarrior40Interface1);
    
    if (interface)
    {
        char buffer[8];
        
        buffer[0] = inReportID;
        memcpy (&buffer[1], inData, 7);
        
        return IOWarriorWriteToInterface (interface, 8, buffer);
    }
    return -1;
}

// reads 7 bytes from interface 1 of the first discovered IOWarrior
int IOWarriorReadInterface1 (int inReportID, void *outData)
{
    IOWarriorHIDDeviceInterface** interface = IOWarriorFirstInterfaceOfType (kIOWarrior40Interface1);
    
    if (interface)
    {
        return IOWarriorReadFromInterface (interface, inReportID,  7, outData);
    }
    return -1;
}

// write inSize bytes at inData to interface inInterfaceIndex of device inWarriorIndex.
int IOWarriorWrite (int inWarriorIndex, int inInterfaceIndex, int inSize, void* inData)
{
    IOWarriorHIDDeviceInterface** interface;
    IOReturn ioReturnValue = kIOReturnSuccess;
    
    interface = IOWarriorGetInterface (inWarriorIndex, inInterfaceIndex);
    if (interface)
    {
        ioReturnValue = IOWarriorWriteToInterface (interface, inSize, inData);
    }
    else
        return -1;

    return ioReturnValue;
}

int IOWarriorWriteToInterface (IOWarriorHIDDeviceInterface** inInterface, int inSize, void* inData)
{
    IOReturn ioReturnValue = kIOReturnSuccess;
	
	if (NULL == inInterface)
		return kIOReturnError;
	
    // Open interface
   ioReturnValue = IOWarriorOpenInterfaceIfNecessary (inInterface);
    if (ioReturnValue != kIOReturnSuccess)
    {
        PrintErrMsgIfIOErr (ioReturnValue, "Could not open hid device interface.");
        (*inInterface)->Release (inInterface);
        return ioReturnValue;
    }
	ioReturnValue = (*inInterface)->setReport (inInterface, kIOHIDReportTypeOutput, 0, inData, inSize, 50, NULL, NULL, NULL);
    if (ioReturnValue != kIOReturnSuccess)
    {
        PrintErrMsgIfIOErr (ioReturnValue, "Could not write setReport on hid device interface");
        return ioReturnValue;
    }  

    return kIOReturnSuccess;
}

int IOWarriorSetInterruptCallback (IOWarriorHIDDeviceInterface** inInterface, void* inBuffer, UInt32 inBufferSize, 
                                  IOHIDReportCallbackFunction inCallbackPtr, void* inRefCon)
{
#ifdef kIOHIDDeviceInterfaceID122
    int                 ioReturnValue;
    CFRunLoopSourceRef  sourceRef;
    mach_port_t         port;
	CFRunLoopRef		rl;
    
    ioReturnValue = (*inInterface)->open (inInterface, 0);
	if (ioReturnValue)
		return ioReturnValue;
    ioReturnValue = (*inInterface)->createAsyncPort (inInterface, &port);
	if (ioReturnValue)
		return ioReturnValue;
    ioReturnValue = (*inInterface)->createAsyncEventSource (inInterface, &sourceRef);
	if (ioReturnValue)
		return ioReturnValue;
	
	rl = CFRunLoopGetCurrent ();
	CFRunLoopAddSource (rl, sourceRef,  kCFRunLoopDefaultMode);
    
    ioReturnValue = (*inInterface)->setInterruptReportHandlerCallback (inInterface, inBuffer, inBufferSize, inCallbackPtr, inBuffer, inRefCon);
    
    return ioReturnValue;
#else
    return -1;
#endif
}

int IOWarriorReadFromInterface (IOWarriorHIDDeviceInterface** inInterface, int inReportID, int inSize, void* outData)
{
    IOReturn 	ioReturnValue = kIOReturnSuccess;
    UInt32		dataSize = inSize;


    ioReturnValue = IOWarriorOpenInterfaceIfNecessary (inInterface);
    if (ioReturnValue != kIOReturnSuccess)
    {
        PrintErrMsgIfIOErr (ioReturnValue, "Could not open hid device interface");
        return ioReturnValue;
    }
    // read from interface
    ioReturnValue = (*inInterface)->getReport (inInterface, kIOHIDReportTypeInput,
                                             inReportID, outData, &dataSize, 100, NULL, NULL, NULL);
    if (ioReturnValue != kIOReturnSuccess)
    {
        PrintErrMsgIfIOErr (ioReturnValue, "Could not call getReport on hid device interface");
        return ioReturnValue;
    }
    return ioReturnValue;
}

IOReturn IOWarriorOpenInterfaceIfNecessary (IOWarriorHIDDeviceInterface** inInterface)
{
	IOWarriorListNode	*listNode;
    IOReturn			ioReturnValue = kIOReturnSuccess;

	listNode = IOWarriorListNodeForInterface (inInterface);
	if (NULL == listNode)
		return kIOReturnError;
	
	if (false == listNode->interfaceOpen)
	{
		ioReturnValue = (*inInterface)->open (inInterface, 0);
		if (ioReturnValue != kIOReturnSuccess)
			return ioReturnValue;
		
		listNode->interfaceOpen = true;
	}
	return ioReturnValue;
}

IOReturn IOWarriorCloseInterfaceIfNecessary(IOWarriorHIDDeviceInterface** inInterface)
{
	IOWarriorListNode	*listNode;
    IOReturn			ioReturnValue = kIOReturnSuccess;

	listNode = IOWarriorListNodeForInterface (inInterface);
	
	if (true == listNode->interfaceOpen)
	{
		ioReturnValue = (*inInterface)->close (inInterface);
		if (kIOReturnSuccess == ioReturnValue)
		{
			listNode->interfaceOpen = false;
		}
	}
	return ioReturnValue;
}

IOWarriorListNode* IOWarriorListNodeForInterface (IOWarriorHIDDeviceInterface** inInterface)
{
	IOWarriorListNode *currentNode = gIOWarriorList;
    
	while (currentNode)
	{
		if (currentNode->ioWarriorHIDInterface == inInterface )
		{
			return currentNode;
		}
		currentNode = currentNode->nextNode;
	}
	return nil;
}

// read inSize bytes from interface inInterfaceIndex of device inWarriorIndex to outData.
int IOWarriorRead (int inWarriorIndex, int inInterfaceIndex, int inReportID, int inSize, void* outData)
{
    IOWarriorHIDDeviceInterface** 	interface;
    IOReturn 			ioReturnValue = kIOReturnSuccess;
    
    interface = IOWarriorGetInterface (inWarriorIndex, inInterfaceIndex);
    if (interface)
    {
        ioReturnValue = IOWarriorReadFromInterface (interface, inReportID, inSize, outData);
    }
    else
        return -1;
    
    return ioReturnValue;
}

/* Returns a pointer to interface inInterfaceIndex of device inWarriorIndex, returns NULL if interface could not be found. */
IOWarriorListNode* IOWarriorGetInterfaceListNode (int inWarriorIndex,int inInterfaceIndex)
{
    if (gIOWarriorListDirty)
    {
        IOWarriorRebuildInterfaceList ();
    }
    return IOWarriorInterfaceListNodeAtIndex ((2 * inWarriorIndex) + inInterfaceIndex);
}

/* Clears the list of interface nodes and rebuilds it. */
void IOWarriorRebuildInterfaceList ()
{
    IOWarriorClearInterfaceList ();
    IOWarriorDiscoverInterfaces ();
    gIOWarriorListDirty = false;
}

/* Returns a pointer to interface inInterfaceIndex of device inWarriorIndex, returns NULL if interface could not be found. */
IOWarriorHIDDeviceInterface** IOWarriorGetInterface (int inWarriorIndex,int inInterfaceIndex)
{
    IOWarriorListNode* node;

    node = IOWarriorGetInterfaceListNode (inWarriorIndex, inInterfaceIndex);
    if (node)
        return node->ioWarriorHIDInterface;

    return NULL;
}

/* Populates the linked list of known IOWarrior Interfaces. It makes the assumption that the hidObjectIterator object returns all interface 0 just before interface 1 for each connected IOWarrior. Caller is responsible for releasing interface by calling (*interface)->Release (interface). */
void IOWarriorDiscoverInterfaces ()
{
    io_iterator_t		            hidObjectIterator = 0;
    IOWarriorHIDDeviceInterface**	result = nil;

    PrintNotificationMessage ("IOWarriorDiscoverInterfaces() called");

    hidObjectIterator = IOWarriorFindHIDDevices ();
    if (hidObjectIterator == 0) {
        PrintErrMsg("IOWarriorDiscoverInterfaces(): IOWarriorFindHIDDevices returned nil iterator");
        return;
    }
    io_object_t 	    hidDevice = 0;
    int 		        iteratorIndex= 0;
    CFMutableArrayRef   deviceIDs = IOWarriorCreateDeviceIDArray();

    while ((hidDevice = IOIteratorNext (hidObjectIterator))) {
        kern_return_t           err;
        CFMutableDictionaryRef  properties = NULL;

        err = IORegistryEntryCreateCFProperties (hidDevice, &properties, kCFAllocatorDefault, kNilOptions);

        if (err != KERN_SUCCESS) {
            PrintErrMsgIfIOErr (err, "IORegistryEntryCreateCFProperties returned error.");
            continue;
        }

        CFTypeRef vendorIDRef;
        CFTypeRef deviceIDRef;
        CFTypeRef serialNumberRef;

        vendorIDRef = CFDictionaryGetValue (properties, CFSTR(kIOHIDVendorIDKey));
        deviceIDRef = CFDictionaryGetValue (properties, CFSTR(kIOHIDProductIDKey));
        serialNumberRef = CFDictionaryGetValue (properties, CFSTR(kIOHIDSerialNumberKey));
        if (vendorIDRef && deviceIDRef) {
            SInt16		vendorID = 0;
            SInt16		deviceID = 0;
            CFRange		range = {0, CFArrayGetCount(deviceIDs)};

            CFNumberGetValue (vendorIDRef, kCFNumberSInt16Type, &vendorID);
            CFNumberGetValue (deviceIDRef, kCFNumberSInt16Type, &deviceID);

            // if the HID Device is an IOWarrior supported by this version of the library
            if (vendorID == kIOWarriorVendorID &&
                CFArrayContainsValue(deviceIDs, range, deviceIDRef))
            {
                PrintNotificationMessage ("found IOWarrior HID device\n");
                result = IOWarriorCreateHIDDeviceInterface (hidDevice);
                if (NULL != result)
                {
                    int			interfaceType;
                    CFStringRef mySerialNumberRef;

                    if (kIOWarrior28DeviceID == deviceID) {
                        interfaceType = iteratorIndex % 4; // 4 interfaces for IOWarrior28
                    } else {
                        interfaceType = iteratorIndex % 2; // all other IOWarriors have 2 interfaces
                    }

                    if (kIOWarrior24DeviceID == deviceID) {
                        interfaceType += 2; // gives an IOWarrior24 interface
                    } else if (kIOWarrior56DeviceID == deviceID) {
                        interfaceType += 4;
                    } else if (kIOWarrior24PVDeviceID == deviceID) {
                        interfaceType += 6;
                    } else if (kIOWarrior24CWDeviceID == deviceID) {
                        interfaceType += 8;
                    } else if (kJoyWarrior24F8DeviceID == deviceID) {
                        interfaceType += 10;
                    } else if (kMouseWarrior24F6DeviceID == deviceID) {
                        interfaceType += 12;
                    } else if (kJoyWarrior24F14DeviceID == deviceID) {
                        interfaceType += 14;
                    } else if (kIOWarrior28DeviceID == deviceID) {
                        interfaceType += kIOWarrior28Interface0;
                    } else {// it's a custom device id
                        interfaceType += kIOWarriorCustomTypeInterface0;
                    }

                    mySerialNumberRef = NULL;
                    if (NULL == serialNumberRef)
                    {
                        // if device didn't supply us with a serial number, lets create our own
                        mySerialNumberRef = CFStringCreateWithCString (NULL, "0",  kCFStringEncodingMacRoman);
                    }
                    else
                    {
                        mySerialNumberRef = CFStringCreateCopy (NULL, serialNumberRef);
                    }

                    IOWarriorAddInterfaceToList (result, interfaceType, serialNumberRef);
                    CFRelease (mySerialNumberRef);
                    iteratorIndex++;
                }
            } else {
                 PrintNotificationMessage ("HID device found, not IOWarrior\n");
            }
        } // if (vendorIDRef && deviceIDRef)
        CFRelease (properties);
        IOObjectRelease (hidDevice);
    } // end while
    CFRelease (deviceIDs);
    IOObjectRelease (hidObjectIterator);
    //mach_port_deallocate (mach_task_self (), masterPort);
	gIOWarriorListDirty = false; // mark interface list as up-to-data
}

/* Returns an iterator object, which can be used to iterate through all hid devices available on the machine. You have to release the iterator after usage be calling IOObjectRelease (hidObjectIterator).*/
io_iterator_t IOWarriorFindHIDDevices ()
{
    CFMutableDictionaryRef hidMatchDictionary = IOWarriorSetUpHIDMatchingDictionary ();;

    // Set up matching dictionary to search the I/O Registry for HID devices we are interested in. Dictionary reference is NULL if error.
    if (NULL == hidMatchDictionary) {
        PrintErrMsg ("Couldn't create a matching dictionary.");
        return 0;
    }

    io_iterator_t hidObjectIterator;

    // Now search I/O Registry for matching devices.
    IOReturn ioReturnValue = IOServiceGetMatchingServices (kIOMasterPortDefault, hidMatchDictionary, &hidObjectIterator);
    if (ioReturnValue != kIOReturnSuccess) {
        PrintErrMsgIfIOErr(ioReturnValue, "IOServiceGetMatchingServices returned error");
        return 0;
    }
    if (hidObjectIterator == 0) {
        PrintErrMsg("IOServiceGetMatchingServices returned nil hidObjectIterator");
        return 0;
    }
	
    return hidObjectIterator;
}


// Called by IOKit when an IOWarrior was attached to the system
void IOWarriorAdded(void *refCon, io_iterator_t iterator)
{
    io_service_t            usbDevice;

    while ((usbDevice = IOIteratorNext(iterator)) != 0)
    {
        PrintNotificationMessage ("Discovered IOWarrior device\n");
        IOObjectRelease(usbDevice);
    }

    gIOWarriorListDirty = 1;
    if (NULL != gIOWarriorCallBackPtr) {
        (*gIOWarriorCallBackPtr )(gIOWarriorCallBackRefCon);
    }
}

// Called by IOKit when an IOWarrior was removed from the system
void IOWarriorRemoved(void *refCon, io_iterator_t iterator)
{
    io_service_t    usbDevice;

    while ((usbDevice = IOIteratorNext(iterator)) != 0)
    {
        PrintNotificationMessage ("IOWarrior device removed\n");
        IOObjectRelease(usbDevice);
    }
    gIOWarriorListDirty = 1;
    if (NULL != gIOWarriorCallBackPtr) {
        (*gIOWarriorCallBackPtr )(gIOWarriorCallBackRefCon);
    }
}

CFMutableDictionaryRef IOWarriorSetUpHIDMatchingDictionary ()
{
    // Set up a matching dictionary to search I/O Registry by class name for all IOWarrior devices.
	CFMutableDictionaryRef 	refHIDMatchDictionary = IOServiceMatching (kIOHIDDeviceKey);

    if (refHIDMatchDictionary == NULL) {
        PrintErrMsg ("Failed to get HID CFMutableDictionaryRef via IOServiceMatching.");
        return NULL;
    }
    int                        vendorID = kIOWarriorVendorID;
    CFNumberRef                vendorIDRef = CFNumberCreate (kCFAllocatorDefault, kCFNumberIntType, &vendorID);;

    CFDictionarySetValue (refHIDMatchDictionary, CFSTR (kIOHIDVendorIDKey), vendorIDRef);
    CFRelease (vendorIDRef);

    return refHIDMatchDictionary;
}

IOWarriorHIDDeviceInterface ** IOWarriorCreateHIDDeviceInterface (io_object_t hidDevice)
{
    io_name_t						className;
    IOCFPlugInInterface**			plugInInterface = NULL;
    HRESULT							plugInResult = S_OK;
    SInt32							score = 0;
    IOReturn						ioReturnValue = kIOReturnSuccess;
    IOWarriorHIDDeviceInterface**	pphidDeviceInterface = NULL;

	//NSLog (@"enterting IOWarriorCreateHIDDeviceInterface");
    ioReturnValue = IOObjectGetClass (hidDevice, className);
    PrintErrMsgIfIOErr (ioReturnValue, "Failed to get class name.");
    PrintNotificationMessage ("Creating interface for device\n");
	//NSLog (@" before IOCreatePlugInInterfaceForService" );
    ioReturnValue = IOCreatePlugInInterfaceForService (hidDevice, 
													   kIOHIDDeviceUserClientTypeID,
                                                       kIOCFPlugInInterfaceID, 
													   &plugInInterface, 
													   &score);
	//NSLog (@" after IOCreatePlugInInterfaceForService" );
    if (ioReturnValue == kIOReturnSuccess)
    {
        // Call a method of the intermediate plug-in to create the device interface
		//NSLog (@" before QueryInterface" );
        plugInResult = (*plugInInterface)->QueryInterface (plugInInterface,
                                                           CFUUIDGetUUIDBytes (kIOWarriorHIDDeviceInterfaceID),
														   (void *) &pphidDeviceInterface);
		//NSLog (@" after QueryInterface" );
        if (plugInResult != S_OK)
            PrintErrMsg ("Couldn't query HID class device interface from plugInInterface");
        (*plugInInterface)->Release (plugInInterface);
    }
    else
        PrintErrMsg ("Failed to create **plugInInterface via IOCreatePlugInInterfaceForService.");
	//NSLog (@"leaving IOWarriorCreateHIDDeviceInterface");
    return pphidDeviceInterface;
}


void PrintNotificationMessage (char* msg)
{
#ifdef IOWarriorDebug
    printf (msg);
#endif
}
void PrintErrMsg (char * msg)
{
    fprintf (stderr, "%s\n", msg);
    fflush (stderr);
}

void PrintErrMsgIfIOErr (long expr, char * msg)
{
    IOReturn err = (IOReturn) expr;
    if (err != kIOReturnSuccess)
    {
        fprintf (stderr, "%s - %s(%x,%d)\n",
                 msg, mach_error_string (err), err, err & 0xffffff);
        fflush(stderr);
    }
}

// Reverses the byte order of ioData, so that byte 0 becomes byte (inCount - 1).
void byteSwap (void* ioData, int inCount)
{
    char* temp;
    char* source = (char*) ioData;
    int	  i;

    temp = malloc (inCount);
    memcpy (temp, source, inCount);

    for (i = 0; i < inCount; i++)
    {
        source[i] = temp[inCount -1 - i];
    }
    free (temp);
}

// appends a newly discovered IOWarrior interface to the linked list of known IOWarrior devices
void IOWarriorAddInterfaceToList (IOWarriorHIDDeviceInterface** inInterface, int inInterfaceType, CFStringRef inDeviceSerialNumber)
{
    IOWarriorListNode *newNode;
    IOWarriorListNode *currentNode;

#ifdef IOWarriorDebug
    printf ("adding IOWarrior interface with interface type %d and serialNumber %d\n", inInterfaceType, inDeviceSerialNumber);
#endif
    
    // first construct a new node
    newNode = malloc (sizeof (IOWarriorListNode));
    newNode->ioWarriorHIDInterface = inInterface;
    newNode->interfaceType = inInterfaceType;
	 newNode->interfaceOpen = false;
	if (NULL != inDeviceSerialNumber)
		CFRetain (inDeviceSerialNumber);
    newNode->serialNumber = inDeviceSerialNumber;
    newNode->nextNode = NULL;

    // if the list is currently empty, the new node will become the head node
    if (NULL == gIOWarriorList)
    {
        gIOWarriorList = newNode;
    }
    else
    {
        // insert the new node at the end of the linked list
        currentNode = gIOWarriorList;
        while (NULL != currentNode->nextNode)
        {
            currentNode = currentNode->nextNode;
        }
        currentNode->nextNode = newNode;
    }
}

// clears the list of known devices
void IOWarriorClearInterfaceList ()
{
    IOWarriorListNode 		*currentNode;
    IOWarriorListNode 		*nextNode;
    IOWarriorHIDDeviceInterface** 	interface;
    
    currentNode = gIOWarriorList;
    while (currentNode)
    {
        
        nextNode = currentNode->nextNode;
        interface = currentNode->ioWarriorHIDInterface;
        (*interface)->Release (interface);
		if (currentNode->serialNumber)
			CFRelease (currentNode->serialNumber);
        free (currentNode);
        currentNode = nextNode;
    }
    gIOWarriorList = NULL;
}

// returns the list node element at index inIndex, returns NULL if inIndex out ouf bounds
IOWarriorListNode* IOWarriorInterfaceListNodeAtIndex (int inIndex)
{
    IOWarriorListNode *currentNode;
    int			i;
    
	if (gIOWarriorListDirty)
    {
        IOWarriorRebuildInterfaceList ();
    }
    currentNode = gIOWarriorList;
    for (i = 0; i < inIndex && currentNode;i++)
    {
        currentNode = currentNode->nextNode;
    }
    return currentNode;
}

void IOWarriorSetDeviceCallback (IOWarriorDeviceCallbackFunctionPtr inCallbackPtr, void* inRefCon)
{
    gIOWarriorCallBackPtr = inCallbackPtr;
    gIOWarriorCallBackRefCon = inRefCon;
}

IOWarriorHIDDeviceInterface** IOWarriorFirstInterfaceOfType (int inInterfaceType)
{
    IOWarriorListNode *currentNode;
    
	if (gIOWarriorListDirty)
	{
		IOWarriorRebuildInterfaceList ();
	}
    currentNode = gIOWarriorList;
    while (currentNode)
    {
        if (currentNode->interfaceType == inInterfaceType)
        {
            return currentNode->ioWarriorHIDInterface;
        }
        currentNode = currentNode->nextNode;
    }
    return NULL;
}
                                                    
int armNotificationsForDeviceWithID (int inDeviceID, int inVendorID, mach_port_t inMasterPort)
{
	CFMutableDictionaryRef	matchingDict;
	CFNumberRef				vendorID;
	CFNumberRef				deviceID;
	kern_return_t			result;
	
	//Set up matching dictionary for class IOUSBDevice and its subclasses
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict)
    {
        return -1;
    }
	
	vendorID = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &inVendorID);
	deviceID = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &inDeviceID);

	
    //Add the vendor and product IDs to the matching dictionary
    //This is the second key of the first table in the USB Common Class
    //Specification
    CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorName),vendorID);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBProductName), deviceID);
	
	CFRelease(vendorID);
	CFRelease(deviceID);
	
    //Now set up two notifications: one to be called when a raw device
    //is first matched by the I/O Kit and another to be called when the
    //device is terminated
    //Notification of first match
	CFRetain(matchingDict);
    result = IOServiceAddMatchingNotification(gNotifyPort,
                                              kIOFirstMatchNotification, matchingDict,
                                              IOWarriorAdded, NULL, &gIOWarriorAddedIter);
	if (result)
	{
		CFRelease (matchingDict);
		return result;
	}
    //Iterate over set of matching devices to access already-present devices
    //and to arm the notification
    IOWarriorAdded(NULL, gIOWarriorAddedIter);
	
    //Notification of termination
    CFRetain(matchingDict);
    result = IOServiceAddMatchingNotification(gNotifyPort,
                                              kIOTerminatedNotification, matchingDict,
                                              IOWarriorRemoved, NULL, &gIOWarriorRemovedIter);
	if (result)
	{
		CFRelease (matchingDict);
		return result;
	}
    //Iterate over set of matching devices to release each one and to
    //arm the notification
    IOWarriorRemoved(NULL, gIOWarriorRemovedIter);
    CFRelease(matchingDict);
	
	return 0;
}
