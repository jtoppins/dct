Events to subordinates:

 * runway status {disabled, enabled}
 * airbase captured; prev-owner, new-owner

airbase requirements:
 * an airbase object needs to be created for every airbase that has a
   unit stationed

Airbase
 - registerSubordiante(sub, eventhandler)
 - notifyAirbaseEvent()
 - requestResources(spectbl)

When an airbase changes ownership, for the previously owning side the
airbase is effectively "dead". So all current subordinates should be
told that their airbase has died. This notification can happen with a
simple higher/lower relationship model, meaning:

An airbase keeps a list of all subordinate assets
  - my defense units
  - squadron 1
  - player squadron 2
  ...

notification:
	foreach asset in subordinatelist do
		asset:onHigherEvent(event)
	end

This can be made generic with the Observer pattern and making all assets
able to handle this relationship. The calls being:
	asset:notifySubordinates(event) -- sends the event to all subs
	asset:onHigherEvent(event) -- the function each sub implements



