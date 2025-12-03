local get_tank = require("utility.get_tank")

---@class cctsl.FluidStorage
---@field tanks table<string, peripheral.FluidStorage>
local CLASS = {
	---@param self cctsl.FluidStorage
	---@param tank_name string
	load_tank = function(self, tank_name)
		self.tanks[tank_name] = get_tank(tank_name).tanks()
	end,
	---@param self cctsl.FluidStorage
	---@param tank_name string
	unload_tank = function(self, tank_name)
		self.tanks[tank_name] = nil
	end,

	---@param self cctsl.FluidStorage
	sync_tanks = function(self) end,
	---@param self cctsl.FluidStorage
	get_tanks = function(self) end,

	---@param self cctsl.FluidStorage
	push_fluids = function(self) end,
	---@param self cctsl.FluidStorage
	pull_fluids = function(self) end,
}
local METATABLE = { __index = CLASS }

local function FluidStorage()
	local new_fluidstorage = setmetatable({
		tanks = {},
	}, METATABLE)

	return new_fluidstorage
end

return FluidStorage
