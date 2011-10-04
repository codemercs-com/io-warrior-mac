#include <CoreFoundation/CoreFoundation.h>
#include "IOWarriorLib.h"

/* This example application is intented for use with a two row LCD display, each being 16 characters wide.

The LCD supports the following commands. Transcription given in IOWarrior comands, first byte is report id:

initializing display:
0x05 0x03 0x38 0x01 0x0F 0x00 0x00 0x00

setting the current cursor position / current memory address send:
third byte with highest bit enabled is the new memory address.
$05 $01 $80 $00 $00 $00 $00 $00 <-- jumps to beginning of first line, initial state
$05 $01 $A8 $00 $00 $00 $00 $00 <-- jumps to beginning of second line

erasing display contents:
$05 $01 $00 $00 $00 $00 $00 $00

writing to the display at current position:
$05 $8x $aa $bb $cc $dd $ee $ff 
x is the number characters to be send
the following bytes are the ascii values of the characters to be send
*/

// enough room for IOWarrior56
#define kMaxReportSize 64

IOWarriorHIDDeviceInterface** gMyInterface; // the interface we are using for writing

int							 gReportSize; // the size of the reports being sent, depends on IOWarriorType

void enableLCDMode ();
void initDisplay ();
void writeToDisplay (const char *inString);
void writeLineToDisplay (const char* inString);
void moveToLine2 ();
int myDiscoverInterfaces ();
int myWriteInterface1 (int inReportID, void* inData);

int main (int argc, const char * argv[])
{
    if (argc != 2)
    {
        printf ("usage: IOWarriorCLITest <message>\n");
        return -1;
    }
    // initalize IOWarrior Lib
    IOWarriorInit ();

    if (-1 == myDiscoverInterfaces ())
    {
        printf ("IOWarrior could not be discovered\n");
        return -1;
    }

    // enable LCD mode
    enableLCDMode ();

    // initialize the display module
    initDisplay ();

    // write the command line argument to the display
    writeToDisplay (argv[1]);
    
    return 0;
}

void enableLCDMode ()
{
    char buffer[7];

    bzero (buffer, 7);
    buffer[0] = 1; // set enable bit
    myWriteInterface1 (4, buffer);
}

void initDisplay ()
{
    char buffer[7];

    bzero (buffer, 7);
    buffer[0] = 0x03;
    buffer[1] = 0x38;
    buffer[2] = 0x01;
    buffer[3] = 0x0F;
    myWriteInterface1(5, buffer);
}

// writes a string to the current line
void writeLineToDisplay (const char* inString)
{
    int 	length = strlen (inString);
    char 	buffer[7];
    int		i;
    const char*	currentChar = inString;

    
    // we truncate after the first 6 letters
     while (strlen (currentChar))
     {
         bzero (buffer, 7);
         length = strlen (currentChar);
         if (length > 6)
             length = 6;
         buffer[0] = 0x80 | length;
         for (i = 1; i <= length; i++)
         {
             buffer[i] = *currentChar;
             currentChar++;
         }
         myWriteInterface1 (5, buffer);
     }
}


// write inString to do Display
void writeToDisplay (const char* inString)
{
    // display lines have 16 characters, allow for one string terminationmarker
    char firstLineContents[17];
    char secondLineContents[17];

    bzero (firstLineContents, 17);
    bzero (secondLineContents, 17);
    strncpy (firstLineContents, inString, 16);
    writeLineToDisplay (firstLineContents);
    if (strlen (inString) > 16)
    {
        strncpy (secondLineContents,  &inString[16], strlen (inString) - 16);
        moveToLine2 ();
        writeLineToDisplay (secondLineContents);
    }
}

// advances to LCD cursor to the second row
void moveToLine2 ()
{
    char buffer[7];

    bzero (buffer, 7);
    buffer[0] = 0x01;
    buffer[1] = 0xA8;
    myWriteInterface1 (5, buffer);
}

int myDiscoverInterfaces ()
{
	gMyInterface = IOWarriorFirstInterfaceOfType (kIOWarrior40Interface1);
	if (gMyInterface)
	{
		gReportSize = 8;
		return 0;
	}
	gMyInterface = IOWarriorFirstInterfaceOfType (kIOWarrior24Interface1);
	if (gMyInterface)
	{
		gReportSize = 8;
		return 0;
	}
	
	gMyInterface = IOWarriorFirstInterfaceOfType (kIOWarrior56Interface1);
	if (gMyInterface)
	{
		gReportSize = 64;
		return 0;
	}
	
	return -1;
}

int myWriteInterface1 (int inReportID, void* inData)
{
	if (gMyInterface)
	{
		char buffer[kMaxReportSize];

		buffer[0] = inReportID;
		memcpy (&buffer[1], inData, 7);

		return IOWarriorWriteToInterface (gMyInterface, gReportSize, buffer);
	}
	return -1;	
}