#!/usr/bin/perl

# script terminology
for ($i = 0; $i < 63; $i++)
{
	print ("<key>byte$i</key>\n");
	print ("<dict>\n");
	print ("\t<key>Description</key>\n");
	print ("\t<string>Byte $i of the report data. If omitted, byte will be set to zero.</string>\n");
	print ("\t<key>Name</key>\n");
	print ("\t<string>byte$i</string>\n");
	print ("</dict>\n");			
}

print ("\n\n\n");

# script suite

for ($i = 0; $i < 63; $i++)
{
	print ("<key>byte$i</key>\n");
	print ("<dict>\n");
	print ("\t<key>AppleEventCode</key>\n");
	if ($i < 10)
	{
		print ("\t<string>byt$i</string>\n");
	}
	else
	{
		print ("\t<string>by$i</string>\n");
	}
	print ("\t<key>Optional</key>\n");
	print ("\t<string>YES</string>\n");
	print ("\t<key>Type</key>\n");
	print ("\t<string>NSNumber</string>\n");
	print ("</dict>\n");
}