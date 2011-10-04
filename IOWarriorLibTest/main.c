#include <CoreFoundation/CoreFoundation.h>
#include "IOWarriorLib.h"

void myCallback (void *	buffer, UInt32 bufferSize, void *refcon);

int main (int argc, const char * argv[])
{
    int 	result;
    UInt32 	buffer;
    //char	longBuffer[7];

    // Initializing IOWarrior Library
    printf ("Calling IOWarriorInit\n");
    result = IOWarriorInit ();
    if (result)
    {
        printf ("IOWarriorInit returned %d\n", result);
        return -1;
    };

    // checking for presence
    if (IOWarriorIsPresent ())
        printf ("IOWarrior is present\n");
    else
        printf ("IOWarrior is not present\n");

    // writing 32 bits
    buffer = (1) << 3;
    result = IOWarriorWriteInterface0 (&buffer);
    if (result)
        printf ("IOWarriorWriteInterface0 returned %d\n", result);

    // reading 32 bits
    bzero (&buffer, 4);
    result = IOWarriorReadInterface0 (&buffer);
    if (result)
            printf ("IOWarriorReadInterface0 returned %d\n", result);
    printf ("IOWarriorReadInterface0 read %08lx\n", buffer);

     /*
    // setting up 7 byte buffer - enabling LCD mode
    bzero (longBuffer, 7);
    longBuffer[0] = 1;
    result = IOWarriorWriteInterface1 (4, longBuffer);
    if (result)
        printf ("IOWarriorWriteInterface1 returned %d\n", result);
    */

    
    //printf ("Entering CFRunLoopRun - press Control-C to exit\n");
    //CFRunLoopRun();

    return 0;
}

void myCallback (void *	buffer, UInt32 bufferSize, void *refcon)
{
    printf ("myCallback invoked\n");
}
