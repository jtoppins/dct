# Intel System

He who knows, knows where to shoot.

## Goal

Provide a way for players to participate in the gathering of intel and
refinement of coordinates that result in more detailed and accurate
briefings in follow-on missions.

## Execution

Provide ways of improving situational awareness of a given coalition;

 1. allow players fly reconnaissance flights
    * These recon flights will automatically "reveal" various assets with the
      level on intel gained proportional to the level of risk (distance) the
      recon flight must get to an asset
    * recon flights as part of their mission criteria must return to base
      before the intel they have gathered is revealed to the rest of the
      team
 2. allow players to provide 'pireps' via use placed F10 marks to identify
    location and type of enemy assets
    * use a syntax to identify the type of asset and what kind of type
      - `Example: "PIREP SAM SA2"`


## Region & Theater Threat Reports

 * SEA
 * AIR
 * ELINT
 * SAM
 * SHORAD

Measure these items based on a threat point system. The threat reported
is only for the assets detected, this can mean threats not detected
will not be reported or the threat be under reported.

For example the threat calculation for SAMs would be:

    threat = sum(SAM.threat, 0, i)

For calculation of air threat the calculation would be:

    threat = sum(AIR.enemy.threat,0,i) - sum(AIR.friendly.threat,0,x)

This means we do not need to know how many assets were originally
spawned. Making it easier to dynamically figure out threats without
having to keep individual counts of everything all the time.

The region threat for each item can be periodically calculated along
with the commander's theater view.

Note: the threat for each asset will need to be a 3 tuple to cover
air, land, and sea threat capability of the asset.

## Logistics & Resourcing

Each region will have a base set of resources plus an additional amount
which will be dictated by how many from TBD.

## Questions

 * how/can the player generated intel feed into the AI system? This being
   mission assignment and target list generation
 * What kind of intel needs to be reported?
   - The fact someone was "mud spiked" or launched on?
   - that a player sees a factory/ammo dump previously not known?
     * how does the player communicate the efficacy of the location and
       the self reported accuracy of the report?
 * does this intel influence how missions are assigned?
 * does this intel, specifically recon missions, inform BDA instead of the
   perfect information system that is currently in effect for reporting
   when a strike mission is complete?
 * how can players 'cheeze' the system?
   - for the PIREPS they could be abused by exposing or hiding information,
     some examples; Assume the following abuse prevention critera are in place
     1. Marks must be within 5NM radius of the asset type claimed or the pirep
        is considered invalid
     2. Marks identifying the same type of asset cannot be within 10NM
        of another pirep, otherwise it replaces the previous report
   - Example of Abuse/Exploit
     * Example 1: information leakage
       - An abusive player can place marks on the map until until the ones
         that fall within 5NM are accepted thus exposing locations without
         having done any real work
     * Example 2: information loss
       - A trolling player could intentionally degrade the accuracy of a
         previous mark by placing a mark next to it, thereby loosing
         coordinate accuracy
   - Mitigations?
     * if the player is not in the air and within X miles of the report
       it is considered not valid?
     * instead of overriding a previous report incorporate with the previous
       intel and take the centroid thereby increasing the accuracy over time
       To provide a confidence level to the intel track how many times
       different units reported the similar location for the same type of
       asset. This also implies using the scratchpad so it moderates how
       quickly a player can enter data to influence the reporting.
