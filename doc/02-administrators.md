# Administrators

Administration is relatively straight forward. This section will walk
you through installation and configuration.

## Installation

DCT is distributed as a standard DCS module. You can download the
[latest release](https://github.com/jtoppins/dct/releases/latest)
and download the zip file.

Once downloaded copy the `DCT` folder contained in the zip file to your
DCS saved games directory and place in;

	<dcs-saved-games>/Mods/tech

If the path does not exist just create it. If installed properly DCT
will be displayed as a module in the game's module manager.

## Configuration

TODO - this section

store server related configuration in:

	_G.dct.settings.server.<config-item>

### Options

configuration related to the server:
- debug - globally enable debug logging and debug checks
- logger settings - defines logging level for each logging subsystem
- profile - enable profiling
- statepath - defines where the statefile for the theater will be stored
- theaterpath - defines where the "theater" exists
- schedfreq - defines how often the command scheduler runs
- tgtfps - defines what the server's target FPS is, is used to calculate
     quanta for the command schedular
- percentTimeAllowed - 
