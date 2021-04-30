DESCRIPTION

This is a demo theater for the Dynamic Campaign Tools (DCT) Framework.
It contains a handful of templates of various types in multiple regions to demonstrate use of DCT.


INSTALLATION

1) Install the latest release of DCT, found at - https://github.com/jtoppins/dct/releases.

2) Move the contents of the "CONFIG" Folder into your SavedGames\DCS.openbeta\Config file.
The contained file, (dct.cfg), contains the settings for the DCT install, such as theater path, state path, and debugging.

3) Move the "THEATER" folder to the location you have defined in dct.cfg.
As standard, we have simply left the theater folder in the root DCS.openbeta folder.

4) Take the example mission from the "MISSIONS" folder and run it as normal.
At the 20 second mark, all templates should load in and slots will become unlocked.

NOTES: 

1) DCT is designed for MP Missions, and behaviour in SP is not representative of MP behaviour.
Testing should be done in MP Servers to get accurate results.

2) Prior to 20 seconds, all slots will be locked. 
After 20 seconds, slots correctly assigned to a squadron at a friendly airbase will unlock.
In SP, the dct_hooks file cannot enforce kicking, so slot blocking will not work!

