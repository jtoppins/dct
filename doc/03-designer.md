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

Theater level configuration consist of various files that manipulate a
specific aspect of DCT on a theater wide level.

### Theater Level Configuration

See [theater configuration](04-api/assets/theater.md) details to
understand how to setup these configuration files.


## Regions

Regions are a logical grouping of templates. This grouping is arbitrary
and it is up to the designer to develop criteria for defining a region,
the most common being geographical. Any directory at the same level as
the 'theater.goals' file is assumed to be a region and the mandatory
'region.def' file must be defined within the directory or an error will
be generated. The [region.def](04-api/assets/region.md) details can
be found in the API documentation.

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

Templates are stored in a combination of `.dct` (known as ‘DCT files’) and
`.stm` (known as ‘STM files’) files with the same named file, but with
different post-fix comprise the entire template definition. DCT files are
the only files needed to fully define a template. STM files come from the
DCS mission editor’s static template feature\[[1][1]\], which allows a
mission designer to compose groups of DCS objects in a semi-visual way
without having to redo the work over-and-over in new mission files.

Creation of a template is pretty straight forward. Once the designer
creates a static template, stored by default at
`<dcs-saved-games>/StaticTemplate/`, this template needs to be copied
to your theater directory. You then need to create the associated `dct`
file. The details of what needs to be defined in a dct file can
be found in the [template](04-api/assets/template.md) API documentation.


[1]: https://www.youtube.com/watch?v=oi6VioycdQw "Creating Static Template"
