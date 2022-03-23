## DESCRIPTION

This is a demo theater for the Dynamic Campaign Tools (DCT) Framework.
It contains a handful of templates of various types in multiple regions to demonstrate use of DCT.


## INSTALLATION

1) Install the latest release of DCT, found at - https://github.com/jtoppins/dct/releases.

2) If this is your first install, move the contents of the "Config" Folder into your `Saved Games\DCS.openbeta\Config` folder.
The contained file, (dct.cfg), contains the default settings for the DCT install, such as theater path, state path, and debug logging.

3) Move the "DCT", "Mods" and "Missions" folders into your `Saved Games\DCS.openbeta` folder.

4) Run `dct-demo-mission.miz` in the game. At the 20 second mark, all templates should load in and slots will become unlocked.

NOTES: 

1) DCT is designed for MP Missions, and behaviour in SP is not representative of MP behaviour.
Testing should be done in MP Servers to get accurate results.

2) Prior to 20 seconds, all slots will be locked. 
After 20 seconds, slots correctly assigned to a squadron at a friendly airbase will unlock.
In SP, the dct_hooks file cannot enforce kicking, so slot blocking will not work!

