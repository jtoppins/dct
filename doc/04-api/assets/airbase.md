# Airbase

Represents an airbase within DCT. Provides advanced functionality
beyond what DCS provides.

## Template Definition

Example template definition.

**file location:** `<theater-root>/Region 1/senaki.dct`

```lua
objtype = "airbase"
name = "Senaki-Kolkhi"	-- must be the name that can be used in
			-- Airbase.getByName(<name>)
coalition = 2
subordinates = {	-- all template names in this list must be defined
			-- in the same region, all templates in this list
			-- belonging to the same coalition (as defined
			-- above) will be spawned; in this example the
			-- "Blue" templates will be spawned.
	"Batumi Airbase Defense Blue",
	"Batumi Airbase Defense Red",
	"99thFS Blue",
	"43thFS Red",
}
recoverytype = "land"
takeofftype = "runway"
```

## Details

Describes details of how the asset operates within the context of
the DCT system.

### Player Slot Association

Player slots for the airbase belonging to the same side are associated
with the airbase automatically. If an airbase is not spawned the
associated player slots will not be enabled and players will not
be allowed to select those slots.

### Creation & Generation

When the asset is created the generate method is called. Any templates
listed in the subordinate list belonging to the same side will also
be created as new assets.

### Spawning

When the airbase is spawned this should trigger all subordinate
assets to be spawned if not already.

### Non Operational

In the event that the airbase determines it is non-operational
it sends an event to all airbase observers. Observers will need
to handle the various events the airbase emits.

### Destruction

The only way to destroy an airbase, that is not a ship, is to capture
it. Otherwise the airbase will be able to repair itself after a
predetermined period of time.

### Events

 * S_EVENT_TAKEOFF
 * S_EVENT_LAND
 * S_EVENT_HIT
 * S_EVENT_DEAD
 * DCT_EVENT_HIT
 * DCT_EVENT_DEAD
 * DCT_EVENT_OPERATIONAL

## States

 * **operational**: normal operation of the airbase is possible
 * **captured**: airbase is being captured by a side
 * **repairing**: airbase is repairing damage and is not able to
   sortie flights, player slots will be disabled and no new
   players will be allowed to join slots associated with the airbase
