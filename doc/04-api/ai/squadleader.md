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


CAP flight lead goals:
- investigate
   -
- intercept
   -
- attack
   - commit criteria
- persue
- disengage
- refuel
- rtb
- race-track on-station hold

actions setup per flight
- set reaction to threat
- use flare
- use ecm


flight lead actions:
- use radar
- set freq
- set ROE
- prohibit ab
- land
- takeoff


CAP flight lead actions:
- goto waypoint
- race-track hold (idle state until fuel low)
- refuel
- engageTargets
- missile attack range


flight lead attributes monitored:
- fuel state
- Friendly and Enemy SAM threat
- Friendly & enemy airbourne threats
- damage taken
- mission specific
  - cap station orbit size
  - ground targets


flight lead personalities:
- aggressiness
- emission awareness
- positioning (altitude & aspect)
- dcs skill level


squadron:
- skill range of pilot
- define airframe
- number of airframes available
- define airfield operating out of
- weapons loadouts; interceptor a/c vs. CAP a/c
- squadrons should be able to scramble a certian amount of jets
- allow designer to define the maintaince rate for given states of a/c returning


air defense commander:
- morphable border, determined by presence of ground assets in a given area
- select automatically CAP stations based on priority and threat
- assign sqdns to CAP stations based on distance
- be able to scramble alerts a/c
- critera for scrambling alert a/c
   * alerts are only used when all airborne CAP car committed
   * alert a/c RTB once a threat has been dewlt with
