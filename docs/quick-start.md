---
layout: default
title: Quick Start
nav_order: 2
permalink: /quick-start
---

# Quick Start Guide

1. **Download:** [latest release]({{ site.release_link }})
2. **Unzip** downloaded release into your `Saved Games\DCS` folder
    - **NOTE:** if updating DCT, do not replace the Config folder!
3. **Prepare DCS** by deleting the marked lines in your
  `Program Files\DCS World\Scripts\MissionScripting.lua` file to allow DCT to read settings
  and save the state file.
    - **WARNING:** this will allow any mission or server you play on to access the internet
    and modify your files, allowing a malicious mission to download and install viruses.
    **Restore the file or repair the game before running any untrusted missions!**

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
-   _G['package'] = nil
  end
```

4. **Launch the game** and run the demo mission in a multiplayer session.
   - _Note:_ It will take at least 20 seconds for all the templates to spawn.
   During this time player slots will be locked.
