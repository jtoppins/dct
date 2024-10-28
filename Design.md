# DCT Redesign

## DCS Features / Support

* [Dynamic Spawning](https://forum.dcs.world/topic/352814-dynamic-spawn-guide/)
  - weapon restrictions can be done with aircraft templates
* [Cargo System](https://forum.dcs.world/topic/355649-cargo-system-guide/)

### Scripting Support

* Warehouse API for management of spawn inventory
* New AI task types
* Events have been modified
* Ability to spawn ground units with less than the max ammo, see mission editor
* AI Ground. Added the ability for SAM to evade ARM (enabled by default, but
  can be disabled in Set Options - Evasion of ARM). Units that detect the missile
  will turn off their radar(s) and displace. Units that cannot move quickly will
  simply turn off their radar(s). The higher the skill level, the higher the
  likelihood that the air defence unit will react to the incoming ARM
* AI. Performance-demanding logic of target detection and line of sight checks
  have been moved to a parallel thread. This gives more headroom for the
  performance, especially on AI-populated dedicated servers with large scale
  battles. This applies to ground, sea and airborne AI units.

## Design

### Mission and Strategic Map

The map that will be loaded as the mission file (miz) into the game. Will
specify dynamic spawn configuration using built-in game functionality. From a
DCT perspective this map will specify all initial aircraft bases participating in
the conflict.

Airbases should specify their initial weapons inventory as when they receive
supplies, each ammo and fuel unit delivered will map 1% of these initial values.

Summary of contents:
* dynamic spawn definitions

### Strategic Map

The strategic map drives a lot of how a future battle will play out. Allow a
designer to specify key terrain (regions), logistics routes, and objectives
that players and AI will attempt to capture/destroy. Also specifies spawn points
for off-map assets to spawn in.

Summary of contents:
* zones specifying regions
  - region borders if regions are irregular shapes
* navigation and flow maps
* zones specifying map objects that allow a supply line to be cut, like bridges

### Placed Object Templates

Templates defined like DCT v1.0 but using mission files. It should be easy to
transition a version 1 template to a version 2. Just import the STM into a mission
and then add a zone named "dct". This will hold all the key value pairs like
the .dct file did when using STMs.

#### ORBAT

Allow designers to define order of battle lists for each side. These lists
consist of;
 * Air groups (aka squadrons)
 * Ground groups (aka battalions)
 * Sea groups (aka Surface action group)

Each group will specify when they are available and where they are initially
based. The group will specify by name the spawn point or region where they will
initially be deployed. If there are multiple bases in the region that possible
a TBD base will be chosen to host the group. ORBAT groups are just a special case
of the object template.

Once a group is deployed, it will begin deploying its subordinate units into the
region per its assigned goals.

### Campaign Start

Using ORBAT and static templates an initial theater is generated much like
version 1. Region definitions will specify which side's templates will initially
be spawned, a region may specify no templates are initially spawned.

### Campaign Progression

An unowned region can be occupied by either side by deploying ground troops to
the region. However, the existence of troops is not enough the establishment of
a base object with a headquarters unit being assigned is needed before a region
is owned. Upon ownership change of a region the transition could cost the opposing
side X tickets.

_NOTE:_ currently spawned FARPs do not participate in dynamic slots.


## Coding

## Systems

### State Saving

Isolate state saving to one system.

The issue will be how to order reading in the save file and then
distributing all the save sections to various systems. Also treat
systems as invariant, the save system cannot create a new System
class simply because there is a state description for that system.
The reason is the mission or theater configuration could have changed
disabling a previously enabled system. So assume the following pesudo-code:

Theater:initialize()
    register remaining built-in systems
    run ordered initialization
        we need to guarentee the persistence system is the first to run

StateSave:initialize()
    read saved state
    unserialize data to each enabled system
        this will require the theater to provide a way to iterate through
        registered systems.

### Asset Manager

Central store for all assets tracked by DCT.

Responsibilities:
* track agents
* [think more] attach an Agent to newly spawned groups

### Region Manager

Central store for regions. What do regions do?

Responsibilities:
??

### Player Menu

A player menu is context sensitive and state dependant. This could be a way to
expose the player menu to external scripts in case they want to modify the menu.
Try to avoid hard-coding especially since things like weapon restrictions could
be optionally enabled so we don't want those menu options presented to players
if the system is disabled and there should be no required coding to do this.


