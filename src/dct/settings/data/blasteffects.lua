--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Name lists for various asset types
--]]

local tntrel = {
	["TNT"]      = 1,
	["Tritonal"] = 1.05,
	["PBXN109"]  = 1.17,
	["Torpex"]   = 1.30,
	["CompB"]    = 1.33,
	["H6"]       = 1.356,
}

-- exmass - mass of explosive compound in kilograms
local function tnt_equiv_mass(exmass, tntfactor)
	tntfactor = tntfactor or tntrel.TNT
	return exmass * tntfactor
end

local wpnmass = {
	["M_117"]        = tnt_equiv_mass(201),

-- source: for mk80 series
-- http://www.ordtech-industries.com/2products/Bomb_General/Bomb_General.html
	["Mk_81"]        = tnt_equiv_mass( 45, tntrel.H6),
	["Mk_82"]        = tnt_equiv_mass( 87, tntrel.H6),
	["Mk_83"]        = tnt_equiv_mass(202, tntrel.H6),
	["Mk_84"]        = tnt_equiv_mass(443, tntrel.H6),
	["BLU_109"]      = tnt_equiv_mass(242, tntrel.PBXN109),

	["FAB_100"]      = tnt_equiv_mass( 39),
	["FAB_250"]      = tnt_equiv_mass(104),
	["FAB_500"]      = tnt_equiv_mass(213),
	["FAB_1500"]     = tnt_equiv_mass(675),
	["BetAB_500"]    = tnt_equiv_mass( 98),
	["BetAB_500ShP"] = tnt_equiv_mass(107),

	["KH-66_Grom"]   = tnt_equiv_mass(108),
	["AN_M64"]       = tnt_equiv_mass(121),
	["X_23"]         = tnt_equiv_mass(111),
	["X_23L"]        = tnt_equiv_mass(111),
	["X_28"]         = tnt_equiv_mass(160),
	["X_25ML"]       = tnt_equiv_mass( 89),
	["X_25MP"]       = tnt_equiv_mass( 89),
	["X_25MR"]       = tnt_equiv_mass(140),
	["X_58"]         = tnt_equiv_mass(140),
	["X_29L"]        = tnt_equiv_mass(320),
	["X_29T"]        = tnt_equiv_mass(320),
	["X_29TE"]       = tnt_equiv_mass(320),
	["AGM_62"]       = tnt_equiv_mass(400),
	["AGM_84E"]      = tnt_equiv_mass(488),
	["AGM_88C"]      = tnt_equiv_mass( 89),
	["AGM_119"]      = tnt_equiv_mass(176),
	["AGM_122"]      = tnt_equiv_mass( 15),
	["AGM_123"]      = tnt_equiv_mass(274),
	["AGM_130"]      = tnt_equiv_mass(582),
	["AGM_154C"]     = tnt_equiv_mass(305),
	["S-24A"]        = tnt_equiv_mass( 24),
	--["S-24B"]      = tnt_equiv_mass(123),
	["S-25OF"]       = tnt_equiv_mass(194),
	["S-25OFM"]      = tnt_equiv_mass(150),
	["S-25O"]        = tnt_equiv_mass(150),
	["S_25L"]        = tnt_equiv_mass(190),
	["S-5M"]         = tnt_equiv_mass(  1),
	["C_8"]          = tnt_equiv_mass(  4),
	["C_8OFP2"]      = tnt_equiv_mass(  3),
	["C_13"]         = tnt_equiv_mass( 21),
	["C_24"]         = tnt_equiv_mass(123),
	["C_25"]         = tnt_equiv_mass(151),
	["HYDRA_70M15"]  = tnt_equiv_mass(  2),
	["Zuni_127"]     = tnt_equiv_mass(  5),
	["ARAKM70BHE"]   = tnt_equiv_mass(  4),
	["BR_500"]       = tnt_equiv_mass(118),
	["Rb 05A"]       = tnt_equiv_mass(217),
	["HEBOMB"]       = tnt_equiv_mass( 40),
	["HEBOMBD"]      = tnt_equiv_mass( 40),
	["MK-81SE"]      = tnt_equiv_mass( 60),
	["AN-M57"]       = tnt_equiv_mass( 56),
	["AN-M64"]       = tnt_equiv_mass(180),
	["AN-M65"]       = tnt_equiv_mass(295),
	["AN-M66A2"]     = tnt_equiv_mass(536),
}

-- weapons that use the same warheads
wpnmass["MK_82AIR"]     = wpnmass["Mk_82"]
wpnmass["MK_82SNAKEYE"] = wpnmass["Mk_82"]
wpnmass["GBU_12"]       = wpnmass["Mk_82"]
wpnmass["GBU_38"]       = wpnmass["Mk_82"]
wpnmass["GBU_16"]       = wpnmass["Mk_83"]
wpnmass["GBU_10"]       = wpnmass["Mk_84"]
wpnmass["GBU_24"]       = wpnmass["Mk_84"]
wpnmass["GBU_31"]       = wpnmass["Mk_84"]
wpnmass["GBU_31_V_2B"]  = wpnmass["BLU_109"]
wpnmass["GBU_31_V_3B"]  = wpnmass["BLU_109"]
wpnmass["GBU_31_V_4B"]  = wpnmass["BLU_109"]
--wpnmass["GBU_32_V_2B"]  = wpnmass["BLU_109"]
wpnmass["FAB_250M54TU"] = wpnmass["FAB_250"]
wpnmass["KAB_500"]      = wpnmass["FAB_500"]
wpnmass["KAB_500Kr"]    = wpnmass["FAB_500"]
wpnmass["KAB_1500Kr"]   = wpnmass["FAB_1500"]

return wpnmass
