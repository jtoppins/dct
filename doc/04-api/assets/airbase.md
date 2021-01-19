# Airbase

Represents an airbase asset.

## Life-cycle

things associated with an airbase;

 * player slots
 * squadrons
 * base defense units

### Creation & Generation

When the asset is created the generate method is called. Any
generated assets should be stored in a subordinate list.

option 1:
 Player slots are not immediately associated with an airbase on
 creation.

option 2:
 Player slots for the airfield belonging to the same side are
 created when generating the asset.

### Unmarshalling

The list of defense and squadron assets associated with the airbase
need to be stored in a list so that we can restore when we unmarshal.

option 1:
 The subordinates list is untouched when unmarshalled, players are
 not in this list.

option 2:
 The subordinates list is processed to remove player slots during
 marshalling. During unmarshalling in the \_unmarshalpost function
 player slots are discovered and associated with the airbase. This
 is to allow the .miz to be changed without requiring a state reset.

### Spawn

When the airbase is spawned this should trigger all subordinate
assets to be spawned if not already.

option 1:
 In addition, the airbase should lookup all player slots that are
 associated with the airbase, add these player assets as observers
 of the airbase so that slots can receive airbase events.

option 2:
 No special handling needed in spawn, beyond spawning subordinates.

### Non Operational

In the event that the airbase determines it is non-operational
it sends an event to all airbase observers. Observers will need
to handle the various events the airbase emits.

### Destruction

It seems the only way to really destroy an airbase is to capture it.
This means any destruction done to an airbase will be restored after
a set period of time.

### Implications

Since an airbase is required to manage player slots, if an airbase
is not generated the associated player slots will always be disabled.
Airbases are required to be created, if they are not listed in the
theater they will not be used. This means that player bases must have
an airbase template or those slots will not be enabled.

Squadrons will also need to adopt the approach of the airbase, in
associating player slots on spawn instead of at object creation time.

## Events

### Subordinate Events

 * DCT dead
 * takeoff
 * land

### Airbase Events

 * hit; both DCS and DCT events

### DCT Events Generated

 * dead
 * operational, true/false
 * resource request; spec of resources needed

## Requirements

 * an airbase object needs to be created for every airbase that has a
   unit stationed
 * for player stationed units, queue with assetmanager airbase names
   so that default airbase assets can be generated for airbases
   not defined in the theater -- humm, this may not work... thinking

## States

 * operational - a side owns the airbase
   - transition
 * empty - no one owns the airbase
 * capturing - the airbase is being captured by a side
 * destroyed - the airbase is so damaged that it would take too
   long to repair

An airbase is either operational or not governed by the equation:

	Operational = !C
	    where C is the set of conditions that can affect the airbase



When an airbase changes ownership, form the previously owning side the
airbase is effectively "dead". So all current subordinates should be
told that their airbase has died. This notification can happen with a
simple higher/lower relationship model, meaning:





States Preventing Operation

 * (R) runway out
 * (S) suppressed - enemy air is overhead or bombs are landing too close
 * (E) enemy ground forces - a too close, can lead to capture
 * (Su) out of supply
 * (!Sp) not Spawned

	Operational = !(R + S + E)

Some of these states do not make sense to clear in a concurrent way.
Implies we need to keep a stack of states and checking for the operational
status is simply a matter of.

	Operational = stack:empty()

## Player Slots

Player slots on the field. Well we need to consider a few things:

 * need to know which player slots are on the field, all slots
   are subordinates
 * player parking positions need to be tracked

What about airbase objects that are not defined as part of the theater?
 A: These will need to be dynamically created.

What about carriers?
 They have their own issues like not being able to determine which
 parking spots are taken. A player's parking id is unreliable when
 on a carrier.


Airbase Assets managed:
 * flights - departures/arrivals
 * subordinates - is an asset that makes up the base structure
   - generation of additional assets that support the base, things
     like base defense and squadrons
   - since we cannot guarentee subordinate assets exist in an unmarshal
     situation, registering subordinates during the base's spawn function
	 seems to be the way to solve this; spawning of an airbase requires
	 that all assets be generated before spawning so this would seem to
	 work. How do we store the list of subordinates?
	 This still will not work unless we change when assets are spawned,
	 spawning needs to be delayed until all assets are created and/or
	 unmarshaled.
   - subordinates

events:
 * spawn; value: t/f
 * operational; value: t/f

departures:
  * spawns the next flight

states:
  * operational



# Problems

## Asset creation order

With assets being able to generate their own assets, generally as
"subordinates" we have created an ordering problem when it comes to
unmarshalling
