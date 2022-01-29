---
layout: default
title: Quick Start
nav_order: 2
permalink: /quick-start
---

# Quick Start Guide

1. **Download:** [latest release]({{ site.release_link }})
2. **Unzip** downloaded release
3. **Install** the `DCT` folder to your DCS mod folder `<dcs-saved-games>/Mods/tech`
   - _Note:_ If the path does not exist just create it. If installed properly DCT
     will be displayed as a module in the game's module manager.
4. **Install hooks** by moving `HOOKS/dct-hook.lua` to the hooks directory in your
   DCS Saved Games folder.
5. **Install Demo** by moving both the `DCT` and `Config` folders in the `DEMO`
   folder to your DCS saved games folder. Move the demo mission `dct-demo-mission.miz`
   to where you store your missions.
6. **Prepare DCS** by removing the following lines of
   your `DCS World\Scripts\MissionScripting.lua` file.
   - **WARNING:** unsanitizing your server's environment could leave it open to data
     loss or corruption of your system if you run a mission or scripts you do not
     understand.

```diff
  --Initialization script for the Mission lua Environment (SSE)

  dofile('Scripts/ScriptingSystem.lua')

  --Sanitize Mission Scripting environment
  --This makes unavailable some unsecure functions.
  --Mission downloaded from server to client may contain potentialy harmful lua code that may use these functions.
  --You can remove the code below and make availble these functions at your own risk.

  local function sanitizeModule(name)
    _G[name] = nil
    package.loaded[name] = nil
  end

  do
-   sanitizeModule('os')
-   sanitizeModule('io')
-   sanitizeModule('lfs')
-   _G['require'] = nil
-   _G['loadlib'] = nil
    _G['package'] = nil
  end
```
7. **Launch the game** and run the demo mission in a multiplayer session.
   - _Note:_ It will take at least 20 seconds for all the templates to spawn.
   During this time player slots will be locked.
