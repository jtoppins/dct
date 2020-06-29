	-- kinds of states
	--   * tactical states
	--      - losses taken
	--      - target dead
	--      - joker
	--      - bingo
	--      - winchester
	--      - goto location
	--
	--   * mission states
	--      - target dead
	--      - station time > #
	--      - mission active for > X time
	--      - assigned dead
	--
	--   * theater states
	--      - tickets <= 0
	--      - primary targets destroyed > %
	--      - secondary targets destroyed > %

defend
escort
attack
intercept
moveto



states:
- at location
- inair
- target = bool (true is alive)
- in-range; this is really just a variation of "at location"
- has-weapon; this could be a bit field specifying a set of weapons that would
    satify the test


goals:  goals describe desired states
* goal; move to
  - at location

* goal; hold area, defend area
  - at location
  - !target

* goal; stealth hold area
  - at location
  - ROE == weapons hold
  - !detected

* goal; attack target
  - in-range
  - has weapon
  - target == dead

* goal; CAP, hold area, defend area
  - at location
  - !target
  - inair


For various ancillary settings like; formation, ROE setting, alarm state, AB usage, etc
 use utility to determine their settings.
