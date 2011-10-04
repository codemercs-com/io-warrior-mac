#!/usr/bin/perl

# prints the name of the track currently being played by iTunes on the LCD display of a connected IOWarrior

while (1)
{
	$song = qx (osascript -e \'tell application \"iTunes\" to get the name of the current track\');
	$artist = qx (osascript -e \'tell application \"iTunes\" to get the artist of the current track\');
	$string = join " ", $song, "by", $artist;
	if ($string ne $lastString)
	{
		system ("./IOWarriorCLITest \"$string\"");
		$string = $lastString;
	}
	sleep (5);
}