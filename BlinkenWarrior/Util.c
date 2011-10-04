/*
 *  Util.c
 *  BlinkenWarrior
 *
 *  Created by Ralf Menssen on Wed Feb 04 2004.
 *  Copyright (c) 2004 CodeMercenaries GmbH. All rights reserved.
 *
 */

#include "Util.h"
#include <Carbon/Carbon.h>

/*---------------------------------------------------------------------*/
#define chEscape 			27

int BreakActionAvail (void)
{
char ch;
short keycode;
EventRecord theEvent;

if (GetNextEvent (keyDownMask + autoKeyMask, &theEvent))
	{
	ch = (char)(theEvent.message & charCodeMask);
	keycode = (short)((theEvent.message >> keyCodeMask) & 8);
	if (((ch == '.') && (theEvent.modifiers & cmdKey)) || (ch == chEscape))
		{
		FlushEvents (keyDownMask + autoKeyMask + keyUpMask + mDownMask + mUpMask, 0);
		return true;
		}
	}
return false;
}

