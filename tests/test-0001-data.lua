#!/usr/bin/lua

require("os")
json = require("libs.json")

rc = pcall(dofile, "./data/test.stm")
assert(rc, "parsing of test.stm failed")
rc = pcall(dofile, "./data/test.dct")
assert(rc, "parsing of test.dct failed")

assert(staticTemplate ~= nil)
assert(metadata ~= nil)
--print(json:encode_pretty(staticTemplate))
--print(json:encode_pretty(metadata))

--[[
<template-root>
	generic
		<category:facility|ground|air|ship>
			<name>.stm
		facility
			<name>.stm
	<mission-name>
		<category:facility|ground|air|ship>
			<name>.{stm|dct}
		facility
			<name>.{stm|dct}

Template Categories:
* facility
		- assets that generally do not move; play a role in the overall
		  strategic success in the theater and change the flow of the
		  situation slowly.

types (taken from the NATO Joint Military Symbology list):
	base
	ewr
	artillery
	missile
	sam
	ammo dump
	fuel dump
	depots
	c2
	gcv (ground convoy vehicle)
	factory
	bai
--]]
