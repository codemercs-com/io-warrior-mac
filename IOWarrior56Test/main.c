#include <stdio.h>
#include "IOWarriorLib.h"

int main (int argc, const char * argv[]) {
    // insert code here...
	
	IOWarriorHIDDeviceInterface** interface; 
	unsigned char	buffer[7] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
	int				result;
	
   result = IOWarriorInit ();
    if (result)
    {
        printf ("IOWarriorInit returned %d\n", result);
        return -1;
    };
	interface = IOWarriorFirstInterfaceOfType (kIOWarrior56Interface0);
	if (nil == interface)
	{
		printf ("No kIOWarrior56Interface0 found.\n", result);
        return -1;
	}
	
	result = IOWarriorWriteToInterface (interface,sizeof (buffer), buffer);
	if (result)
	{
		     printf ("IOWarriorWriteToInterface returned %d\n", result);
			return -1;
	}
	
    return 0;
}
