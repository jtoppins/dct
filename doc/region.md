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

### `airspace`

 * _required:_ no
 * _value:_ boolean
 * _default:_ true

Specified if an airspace object is created over this region. Airspace
objects are used as navigation points and CAP stations in mission assignment.
