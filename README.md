# Dynamic Campaign Tools (DCT)

Mission scripting framework for persistent Digital Combat Simulator (DCS)
missions.

Provide a set of tools to allow mission designers to easily create scenarios
for persistent dynamic campaigns within the DCS game world.

**D**ynamic **C**ampaign **T**ools relies on content that can be built
directly in the mission editor, these individuals need little to no
programming skills to provide content to a DCT enabled mission.

Scenarios are created through a theater definition consisting of templates
created in the Mission Editor. There is an initial learning curve but it is
no more difficult than initially learning the DCS Mission Editor.

## Getting Started

See our documentation [here](https://jtoppins.github.io/dct/quick-start).

## Features

* **Mission Creation**
  - uses static templates for reusable asset creation
  - no large .miz to manage just place player slots
  - theater and region organization to control spawning
    and placement
  - settings to customize how you want your campaign to
    play

* **Game Play**
  - Focus on more goal based gameplay vs. "air quake"
  - mission system used by AI and players
  - ticket system to track win/loss critera
  - Integrated Air Defense per faction
  - Weapon point buy system for players to limit kinds and
    types of payloads
  - Bomb blast effects enhancement and weapon impact system

* **Technical**
  - Built for large scale scenarios
  - **Persistent campaign progress across server restarts**

## Contribution Guide

See our [documentation](https://jtoppins.github.io/dct/), in short contributions
can be made with a github pull request but features and/or changes need to be
discussed first. Code is licensed under LGPLv3 and contributions must be
licensed under the same. For any issues or feature requests please use the
issue tracker and file a new issue. Make sure to provide as much detail
about the problem or feature as possible. New development is done in feature
branches which are eventually merged into `master`, base your features and
fixes off `master`.

### Development Environment Setup

All development is done on [Debian Stable](https://www.debian.org/) using
[DCS Dedicated Server](https://www.digitalcombatsimulator.com/en/downloads/world/server/).
You can setup your own development environment by running the setup script.
The script will ask you if it should installed DCS Dedicated Server for you.
The DCS server installer is interactive only so you must attend the setup.
If you choose to not install DCS server (we assume you have already installed)
the setup is unattended.

Run the following on your system:
```
git clone
sudo ./scripts/devel-setup
```

## Contact Us

* [DCT discord](https://discord.gg/kG38MDqDrN)
