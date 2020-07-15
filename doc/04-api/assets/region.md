# Regions

## Usage

Defines a logical grouping of game assets within the world.

## Storage

Region configuration data is stored in a `region.def` file. All templates
defined in the same directory or lower as a `region.def` will belong to
this region. Only the first `region.def` file found will define the region,
regions cannot be nested.

## Attributes - General

### `name`

 * _required:_ yes
 * _value:_ string

The name of the region. This name can be used to lookup the region from
the Theater object.

### `priority`

 * _required:_ yes
 * _value:_ number

The initial priority of the region. The higer the priority (lower number is
higher) the earlier assets/targets in that region will be scheduled.

### `limits`

 * _required:_ no
 * _value:_ table
 * _default:_ empty table

If not defined all templates will be spawned. If the limits table is defined
it consists of keys that are the names of asset types\[[1][1]\] with the
value being a table describing the min and max number of templates of that
type that will be spawned.

	["limits"] = {
		["ammodump"] = {
			["min"] = 2,
			["max"] = 4,
		},
	}

The spawning algorithm, from the sample above, will select at random a number
between 2 and 4 inclusive as the maximum number(X) of ammodumps to spawn. The
algorithm will then select X ammodumps defined in the region to spawn at
random. If there are not X ammodumps to spawn then all possible ammodumps
will be spawned.

### `airspace`

 * _required:_ no
 * _value:_ boolean
 * _default:_ true

Set to false if an airspace object should not be created over this region.
Airspace objects are used as navigation points and analysis points for
airspace combat. The default radius of an automatically generated airspace
is 50 nautical miles.

[1]: ../../../src/dct/enum.lua
