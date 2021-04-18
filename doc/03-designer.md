# Campaign Designer

## Overview

The campaign designer is the individual(s) that prepares the templates
and campaign configuration that will be utilized by DCT to create the
dynamic persistent campaign. To develop a campaign for DCT one mainly
spends time in the mission editor using various features to create
parts that will be stitched together by DCT to make a complete campaign.
First we need to discuss the DCT "theater".

## Theater

A DCT theater is a directory hierarchy that contains various configuration
files. The theater is broken up this way so that the same template can
be utilized in other campaigns without recreating the set of groups over
again when building a new mission.

The directory hierarchy is:

	+ <Theater Directory>
	  - theater.goals
	  + settings
	    - restrictedweapons.cfg
	    - payloadlimits.cfg
	    - codenamedb.cfg
	    - ui.cfg
	  + <Region 1>
	    - region.def
	    + <arbitrary-named-directory>
	      - template1.dct
	      - template1.stm
	      + <another-directory>
	        - template2.dct
	        - template2.stm
	    + <another-directory2>
	      - template3.dct
	      - template3.stm
	  + <Region 2>
	    - region.def
	    + <arbitrary-named-directory>
	      - template4.dct
	      - template4.stm
	  + <Region N>
	    - region.def
	    + <arbitrary-named-directory>
	      - template5.dct
	      - template5.stm

### Theater Level Configuration

Theater level configuration consist of various files that manipulate a
specific aspect of DCT on a theater wide level. The various theater
wide settings are described in the subsections below.

### Theater Goals

Theater goals define the way in which DCT will evaluate the completion
of the campaign. It is a simple ticket system much like what is present
in many AAA FPS titles.

#### Example

**file location:** `<theater-root>/theater.goals`

	time = 43200  -- 12 hours in seconds
	blue = {
		flag            = 45,
		tickets         = 100,
		player_cost     = 1,
		modifier_reward = 0.5,
		modifier_loss   = 0.2,
	}

	neutral = {
		flag    = 20,
		tickets = 0,
	}

	red = {
		flag       = 60,
		tickets    = 200,
		difficulty = "easy",
	}

#### Configuration Options

##### `time`

The total time, in seconds, the campaign will run before a winner is
determined and a new state is generated. Set to zero to disable the
timer.

##### `red`, `blue` and `neutral`

Each faction definition is required and can have the following
possible entries;

###### `flag`

 * required

Defines the flag number used in the associated .miz which will trigger
an end of the mission.

DCT relies on the associated mission to provide 3 triggers (one per
faction), with each trigger being conditional on the specified flag
number being true. With the action of the trigger being the mission-end
action with the values of the mission end action representing a winning
condition. This means that the flag for the red faction, if set to true,
will result in a mission end event stating the red team has won.

###### `tickets`

 * required

Number of tickets the side's ticket pool starts with. The Neutral
faction can start with zero tickets all others must have above zero.

Ticket loss and reward:

Tickets are lost by the owning side each time an asset dies. A side may
gain tickets for completing missions. The calculations are as follows:

	tickets-lost = asset.cost * owner.modifier_loss

	tickets-gained = tgtasset.cost * mission.owner.modifier_reward

An example; suppose a flight of two players (blue) attacked and destroyed
a factory (red) which was part of their mission. During the mission one
of the players is shot down.

Point values and modifiers:

 * factory worth 10 tickets
 * player cost worth 2 tickets
 * red modifiers; ticket = 50, modifier_reward = .5, modifier_loss = .5
 * blue modifiers; tickets = 30, modifier_reward = 1, modifier_loss = 1

Red Tickets:

	red tickets = 50 - (factory.cost * red.modifier_loss)
	            = 50 - (10 * .5)
	            = 45

Blue Tickets:

	blue tickets = 30 - (player.cost * blue.modifier_loss) + mission success
	             = 30 - (2 * 1) + mission success
	             = 28 + (factory.cost * blue.modifier_reward)
	             = 28 + (10 * 1)
	             = 38

Therefore even though blue lost a plane they were able to net 8 tickets.
While red lost a net of 5 tickets. It is up to the campaign designer to
assign costs to each asset, via their .dct file.

###### `difficulty`

 * _default:_ `custom`
 * _value:_ limit set of strings (`easy`, `normal`, `hard`, `realistic`,
  `custom`)

Defines some predefined settings for player_cost, modifier_reward, and
modifier_loss. If this is set to anything other than `custom` any
explicitly defined values for player_cost, etc will be overwritten.

`easy`:

 * player_cost: 1
 * modifier_reward: .5
 * modifier_loss: 1.5

`normal`:

 * player_cost: 1
 * modifier_reward: 1
 * modifier_loss: 1

`hard`:

 * player_cost: 1
 * modifier_reward: 1.5
 * modifier_loss: .5

`realistic`:

 * player_cost: 1
 * modifier_reward: 1
 * modifier_loss: 0

###### `player_cost`

Defines the cost of each player slot.

###### `modifier_reward`

Defines the multiplicative modifier that is applied to all rewards the
given faction receives.

###### `modifier_loss`

Defines the multiplicative modifier that is applied to all losses the
given faction takes.

### Defined Weapon Categories

These categories are used in the payload limits and restricted weapons
definitions.

 * `AG` - air-to-ground weapons category
 * `AA` - air-to-air weapons category

These identifiers are case insensitive.

### Payload Limits

The payload limits configuration allows a campaign designer to define a
default limit for each weapon category. This default, if defined, will
be applied for all player aircraft regardless of side.

A hardcoded default table is built into DCT which allows a limit of
4999 per category. There is an infinite weapons cost hardcoded to
5000, setting any weapon cost to this value will deny the use of that
weapon in the mission.

#### Example

**file location:** `<theater-root>/settings/payloadlimits.cfg`

	ag = 20
	aa = 20

#### Internal API

**table access:** `_G.dct.settings.payloadslimits`

 - the location where the default payload limits table can be accessed

### Restricted Weapons

The restricted weapons configuration allows a campaign designer to limit
or remove the use of a given weapon type without the need to modify the
.miz. This allows for a consistent enforcement of restricted weapons
without having to update their mission each time the game adds a new
weapon.

The enforcement policy is one of removing the player from their slot
if they takeoff with a restricted loadout.

#### Example

**file location:** `<theater-root>/settings/restrictedweapons.cfg`

	restrictedweapons = {
		["AIM-120C"] = {
			cost = 3,
			category = "aa",
		},
		["GBU-12"] = {
			cost = 15,
			category = "ag",
		},
	}

#### Details

The algorithm is simple, weapons in the restricted list will apply their
defined cost value for each instance of the weapon loaded on the unit to
the category specified. This total value per category is then compared
to the defined limit per category, if the total is greater than the limit
the enforcement policy action is taken.

#### Internal API

**table access:** `_G.dct.settings.restrictedweapons`

 - stores the weapons restriction table that defines the cost of each
   weapon

### Code Name Overriding

DCT assigns 'code names' to assets that are later used when players
request missions. This allows a campaign designer to override DCT's
default naming tables.

The codenamedb is a lua table with keys equal to the asset type value
and values equal to a name list.

#### Example

**file location:** `<theater-root>/settings/codenamedb.cfg`

	facility = {"FORD", "DODGE", "CHEVY",}
	sam = {"alpha", "bravo", "charlie",}

The above example will override the name list of "C2" assets with the
list of possible names above.

#### Internal API

**table access:** `_G.dct.settings.codenamedb`

 - stores the codename database

### User Interface(UI)

Allows the mission designer to modify various defaults about the
DCT UI.

`gridfmt`:

DCT formats user facing coordinates based on the type of aircraft
they are flying. This table allows the mission designer to modify
the coordinate format which the player will see. The default format
is degrees minutes seconds(DMS), this means if the aircraft should
see a coordinate in DMS then it does not need to be in the table.
Also, DCT provides generally reasonable defaults for most flyable
aircraft. This grid format setting applies to the aircraft specified
regardless of side.

Valid Grid Formats (case insensitive):

 * `dms` - degrees minutes seconds decimal (45° 32' 30.04")
 * `mgrs` - military grid reference system (NY 1234567890)
 * `dd` - degrees decimal (45.534°)
 * `ddm` - degrees decimal minutes (45° 32.501')

`ato`:

By default DCT allows all possible mission types to be requested
by the player. If the mission designer chooses to limit the types
of missions a specific airframe can fly this is where they do it.
The designer must specify *all* mission types a given airframe is
allowed to request. This per-airframe setting applies to all
airframes of the type regardless of side.

List of Valid Mission Types (case insensitive):

 * `cap` - combat air patrol
 * `cas` - close air support
 * `strike` - strike mission
 * `sead` - suppression of enemy air defense
 * `bai` - battlefield air interdiction (currently not implemented)
 * `oca` - offensive counter air
 * `armedrecon` - armed reconnaissance

#### Example

**file location:** `<theater-root>/settings/ui.cfg`

	gridfmt = {
		["UH-1H"] = "ddm",
	}
	ato = {
		["UH-1H"] = {"armedrecon", },
	}

#### Internal API

**table access:** `_G.dct.settings.ui`


## Regions

Regions are a logical grouping of templates. This grouping is arbitrary
and it is up to the designer to develop criteria for defining a region,
the most common being geographical. Any directory at the same level as
the 'theater.goals' file is assumed to be a region and the mandatory
'region.def' file must be defined within the directory or an error will
be generated.

### Storage

Region configuration data is stored in a `region.def` file. All templates
defined in the same directory or lower as a `region.def` will belong to
this region. Only the first `region.def` file found will define the region,
regions cannot be nested.

### Example

**file location:** `<theater-root>/Region 1/region.def`

	name = "Test region"
	priority = 10
	limits = {
		["ammodump"] = {
			["min"] = 1,
			["max"] = 2,
		},
	}

### Attributes

#### `name`

 * _required:_ yes
 * _value:_ string

The name of the region. This name can be used to lookup the region from
the Theater object.

#### `priority`

 * _required:_ yes
 * _value:_ number

The initial priority of the region. The higer the priority (lower number
is higher) the earlier assets/targets in that region will be scheduled.

#### `limits`

 * _required:_ no
 * _value:_ table
 * _default:_ empty table

If not defined all templates will be spawned. If the limits table is defined
it consists of keys that are the names of `assetType`\[[1][1]\] with the
value being a table describing the min and max number of templates of that
type that will be spawned.

	...
	limits = {
		["ammodump"] = {
			["min"] = 2,
			["max"] = 4,
		},
	}
	...

The spawning algorithm, from the sample above, will select at random a
number between 2 and 4 inclusive as the maximum number(X) of ammodumps
to spawn. The algorithm will then select X ammodumps defined in the
region to spawn at random. If there are not X ammodumps to spawn then
all possible ammodumps will be spawned.

#### `altitude_floor`

 * _required:_ no
 * _value:_ number
 * _default:_ 914.4 meters

Specifies the minimum safe altitue for a given region.

## Templates

Templates are core to DCT and will be where the designer spends most of
their time. A template basically represents a grouping of, usually, DCS
objects (statics and/or units) that represent a particular general
category, such as a SAM site. This template is then used by DCT to
create a DCT Asset object which will spawn and track the DCS objects
associated with the template. There is no limitation imposed by DCT
on what kind of DCS object can be contained in any given type of
template. This allows enormous flexibility in the construction and
aesthetic.

_Note: Currently there is no way to reuse a template with the only
difference being where the template is located on the map. This was
considered to be not a high priority feature._

### Template Creation

A template represents a non-unique DCT game object. These objects can be
copied to represent unique game objects within the DCT/DCS game world. The
primary usage for Template objects is to validate user/mission-creator
provided game data in a consistent and common way. This removes the
responsibility of Asset objects from having to perform this validation each
time.

Templates are stored in a combination of `.dct` (known as ‘DCT files’) and
`.stm` (known as ‘STM files’) files with the same named file, but with
different post-fix comprise the entire template definition. DCT files are
the only files needed to fully define a template. STM files come from the
DCS mission editor’s static template feature\[[2][2]\], which allows a
mission designer to compose groups of DCS objects in a semi-visual way
without having to redo the work over-and-over in new mission files.

Creation of a template is pretty straight forward. Once the designer
creates a static template, stored by default at
`<dcs-saved-games>/StaticTemplate/`, this template needs to be copied
to your theater directory. You then need to create the associated `dct`
file.

### .dct Example

**file location:** `<theater-root>/Region 1/template.dct`

	objtype = "ammodump"
	intel = 2
	cost = 20

_Note:_ This example assumes an associated STM file that will define the
DCS game objects that make up an "ammo dump".

### Attributes - General

_NOTE:_ Things noted as required mean the DCT file associated with the
template must define the attribute.

### `objtype`

 * _required:_ yes
 * _value:_ string

Defines the type of game object (Asset) that will be created from the
template. Allowed values can be found in `assetType`\[[1][1]\] table.

### `name`

 * _required:_ depends
 * _value:_ string

The name of the template. This name can be used to lookup the template from
the Region object. If the template uses an STM file then the name field of
the STM template will be used. This name field is editable in the mission
editor. If the template is an airbase type the name must reference an
airbase object in the game world or define a tpldata to spawn a new airbase.
This airbase validation is not done at template definition time and is
instead done at asset creation time, thus it is a non-fatal error
generating a warning in the log file. The asset will not be created if the
name or tpldata is incorrect or does not exist.

### `regionname`

 * _required:_ depends
 * _value:_ string

The region name the template belongs to. If a template is created outside
the theater definition directory this region will need to be defined.

### `coalition`

 * _required:_ depends
 * _value:_ "red", "blue", "neutral" (case doen't matter)
 * _default:_ the coalition the DCS groups/statics belong too or this field
   is **required**

A template can only belong to a single coalition (side) and any DCS
groups/statics not belonging to the same side as the first group will
cause a fatal error. This can be confusing sometimes when a template is
attempted to be used across different campaigns. Your campaign designer
should come up with a standard country set for each coalition.

### `desc`

 * _required:_ no
 * _value:_ string

This is a text string field used to provide the 'target briefing' text when
a mission is assigned to a player. This text can use string replacement to
make certain parts of the message variable, the replacement fields are:

 * `LOCATIONMETHOD` - provides a randomly selected description of how the
   target was discovered.
 * `TOT` - replaces with the expected time-on-target

### `tpldata`

 * _required:_ depends
 * _value:_ table
 * _default:_ autogenerated if STM is provided otherwise required if DCS
   in-game objects need to be associated with the template

For templates that are not associated with an STM file the format of
`tpldata` follows:

	tpldata = {
	    # = {
	      category = Unit.Category,
	      countryid = id,
	      data      = {
	        # group def members
	        dct_deathgoal = goalspec
	      },
	}}

`tpldata` is a LUA list where each list entry is as shown above; `category`,
`countryid`, and `data`.

 * `category` - is a value from the `Unit.Category`[\[3\]][3] table
 * `countryid` - is the numerical id of the country[\[4\]][4] the
   static/group belongs to
 * `data` - is the actual static/group definition in a format that is
   expected by `coalition.addGroup()`[\[5\]][5] and
   `coalition.addStatic()`[\[6\]][6]

#### Death Goal Specification (goalspec)

A template can consist of an arbitrary number of statics and groups
that make up the "asset", however some of these groups/statics may
be there to provide atmosphere to the overall objective and or a
supporting role such as local AAA coverage. With goal specification
the designer has direct control over specifying which specific statics
and/or groups need to be damaged or destroyed to determine when the
overall Asset is dead according to DCT.

Lets take for example our ammo dump [_TODO: add link to stm_] template. It
consists of a few ammo bunker statics and some supporting AAA units
for local security. But we as the designer do not care if all the AAA
units are hit we only care if the bunkers are hit or destroyed. In the
mission editor we can modify the bunker name to include the
following key words, this will cause DCT to create a "death goal" for the
template instead of using the default death goal which is 90% of all
objects must be destroyed.

Keywords:

 * `PRIMARY` - statics/groups that contain this text in their name will
   be tracked and contribute to the Assets overall death goal
 * `UNDAMAGED` - static/group must have less than 10% damage or the object
    is considered dead
 * `DAMAGED` - static/group must have less than 45% damage or the object
    is considered dead
 * `INCAPACITATED` - static/group must have less than 75% damage or the
    object is considered dead
 * `DESTROYED` - static/group must have less than 90% damage or the object
    is considered dead

Using the keywords above in our ammo dump example we would name the
ammo bunker static object in the static template the following;
  `PRIMARY DESTROYED bunker 1`

This would require a player or AI to do 90% damage to "bunker 1", and no
other objects before DCT would consider the overall ammo dump dead. This
means a player could hammer all the AAA and progress toward killing the
overall ammo dump would be zero percent. This gives the template designer
a lot of flexibility and ability to create "decoy" portions of a template.

### `buildings`

 * _required:_ no
 * _value:_ table
 * _default:_ nil

Allows the campaign designer to specify scenery objects as part of the
template. The definition is a list of scenery objects that should
be included as part of the template, an example from the Persian Gulf
map;

	...
	buildings = {
		{
			["name"] = "building 1",
			["goal"] = "primary destroyed",
			["id"]   = 109937143,
		},
	}
	...

Where `name` is the name of the scenery object (is arbitrary and only
referenced in DCT for error reporting), `goal` conforms to the textual
[goalspec](#death-goal-specification-goalspec), and `id` is the map
specific object id which can be obtained from the mission editor.

### `uniquenames`

 * _required:_ no
 * _value:_ boolean
 * _default:_ false

When a template can represent more than one instance of an Asset this
attribute should be set to `true` so when a new Asset is created the names
of the DCS objects are made unique. This way when the DCS objects are
dynamically spawned DCS will not despawn previously spawned objects because
they have the same name.

### `priority`

 * _required:_ no
 * _value:_ number, lower means higher priority
 * _default:_ depending on `objtype` an appropriate value will be selected

This field defines the relative priority to other templates/assets within
the region. A lower non-negative number means higher priority.

### `intel`

 * _required:_ no
 * _value:_ `0` to `5`
 * _default:_ `0`

Defines the initial amount of 'intel' the opposing side knows about any
assets generated from the template. The intel value is a direct
representation to how many decimal places the location of the asset will
be truncated to[\[7\]][7].

### `spawnalways`

 * _required:_ no
 * _value:_ `true` or `false`
 * _default:_ `false`

Used to identify templates that should always be spawned, the value should
always be 'true' or removed from the template definition.

### `exclusion`

 * _required:_ no
 * _value:_ string

Used to mark templates that should not be spawned together. If the templates
have the same string value the templates will be grouped together and only
one template from the exclusion group will be selected. All other members
of the group will be ignored.

### `airbase`

 * _required:_ no
 * _value:_ string
 * _default:_ nil

Specifies which airbase the asset is associated with. Normally not needed
to be specified by the campaign designer. The value must be a string
that when passed to `Airbase.getByName(<name>)` returns a DCS Airbase
object.

### `ignore`

 * _required:_ no
 * _value:_ boolean
 * _default:_ false

Assets generated from templates with this attribute set to true will be
ignored by the DCT AI. This includes scheduling the asset to be assigned
as a target to a player. [TODO] This will also make any units spawned
by the asset to be ignored by the DCS AI.

### `regenerate`

 * _required:_ no
 * _value:_ boolean
 * _default:_ false

Forces an asset on state reload to reset its `tpldata` to the original
state when the asset was created.

### `cost`

 * _required:_ no
 * _value:_ number
 * _default:_ 0

The amount of tickets an asset generated from this template is worth.
With the ticket system each side has a given amount of tickets they can
lose. An asset with a cost value will deduct against this per-side ticket
pool. See the [tickets](#tickets) section for more information.

### `codename`

 * _required:_ no
 * _value:_ string
 * _default:_ random codename assigned to asset

A static codename can be assigned to a template overriding the normally
random codename. Codenames are displayed in mission briefings and other
player UI elements.

### `location`

 * _required:_ no, only required for airspace templates
 * _value:_ table, with members `x` and `y`

Is the center of the airspace. The location is defined as `x` is the
east-west DCS location value while `y` is the north-south DCS value.
_Note: These values cannot be lat-long or degrees decimal corrdinates,
they much be DCS internal map coordinates._

### Attributes - Type Specific

#### Airspace

##### `radius`

 * _required:_ yes
 * _value:_ number in meters
 * _default:_ 55560

Is the radius of the circle defining the airspace region.

#### Airbase

##### `subordinates`

 * _required:_ no
 * _value:_ table
 * _default:_ none

A list of template names that will be converted into DCT assets. These
templates are usually base defenses or squadrons but there is nothing
preventing the designer from spawning additional assets with this list.

##### `contest_dist`

 * _required:_ no
 * _value:_ number
 * _default:_ 10 nautical miles for land bases, disabled for ships

The distance opposing troops are allowed to come within before the
airbase is considered contested and the ability to launch aircraft
will be disabled.

##### `takeofftype`

 * _required:_ no
 * _value:_ string
 * _default:_ `inair`

This allows the mission designer to specify how AI aircraft will
depart the field. The possible options are:

 * `inair` - aircraft will depart the field already in the air above the
   field at 1500ft
 * `runway` - aircraft will depart from the runway
 * `parking` - aircraft will depart the airfield from parking cold

##### `recoverytype`

 * _required:_ no
 * _value:_ string
 * _default:_ `terminal`

This allows the mission designer to specify how AI aircraft will
recover at the field. The possible options are:

 * `terminal` - aircraft will get within 10nm of the airbase before
   despawning
 * `land` - when the aircraft land event fires the plane will be
   despawned
 * `taxi` - the aircraft will be despawned after 5 minutes of the
   land event firing

#### Squadron

##### `ato`

 * _required:_ no
 * _value:_ list of strings
 * _default:_ all mission types allowed

The allowed mission types the squadron can fly.  See the
[User Interface](#user-interfaceui) section for details on how this
attribute is defined.

**Player Squadron:**

##### `payloadlimits`

 * _required:_ no
 * _value:_ table
 * _default:_ no limit

A table listing the cost limit for different ordinance groups, by default
there is no limit. The format of the table is as follows:

			["payloadlimits"]  = {
				["ag"] = 20,
				["aa"] = 10,
			}

See [Payload Limits](#payload-limits) section for further details.

### Asset Types

_TODO: describe what each asset type means in the context of DCT and how
losing an asset of a given type would manipulate the overall battlespace.
This could be combined with the specific asset examples below._

### Template and Asset Examples

 * [Airbase](04-api/assets/airbase.md)
 * [Squadron](04-api/assets/squadron.md)
 * [StaticAsset](04-api/assets/staticasset.md)


[1]: ../src/dct/enum.lua
[2]: https://www.youtube.com/watch?v=oi6VioycdQw "Creating Static Template"
[3]: https://wiki.hoggitworld.com/view/DCS_Class_Unit
[4]: https://wiki.hoggitworld.com/view/DCS_enum_country
[5]: https://wiki.hoggitworld.com/view/DCS_func_addGroup
[6]: https://wiki.hoggitworld.com/view/DCS_func_addStaticObject
[7]: https://en.wikipedia.org/wiki/Decimal_degrees "Decimal degrees"
[8]: https://wiki.hoggitworld.com/view/DCS_func_searchObjects "DCS Volume Spec"
[9]: https://wiki.hoggitworld.com/view/DCS_enum_coalition "Hoggit Wiki - Coalition Table"
