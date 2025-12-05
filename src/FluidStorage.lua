local get_tank = require("utility.get_tank")

local UNKNOWN_TANK = 'Unable to find tank "%s", is it being tacked?'

---@class cctsl.FluidStorage
---@field loaded_tanks table<string, peripheral.FluidStorage>
---@field package _fluid_cache table<string, peripheral.FluidTankInfo[]>
local CLASS = {
	---@param self cctsl.FluidStorage
	---@param tank_name string
	load_tank = function(self, tank_name)
		self.loaded_tanks[tank_name] = get_tank(tank_name)
	end,
	---@param self cctsl.FluidStorage
	---@param tank_name string
	unload_tank = function(self, tank_name)
		self.loaded_tanks[tank_name] = nil
	end,

	---@param self cctsl.FluidStorage
	sync_tanks = function(self)
		for tank_name, tank in next, self.loaded_tanks do
			self._fluid_cache[tank_name] = tank.tanks()
		end
	end,
	---@param self cctsl.FluidStorage
	---@return string[]
	get_tanks = function(self)
		local tanks = {}

		for tank_name in next, self.loaded_tanks do
			table.insert(tanks, tank_name)
		end

		return tanks
	end,

	---comment
	---@param self cctsl.FluidStorage
	---@return table<string, integer>
	get_all_fluids = function(self)
		local output = {}

		for _, tank_fluids in next, self._fluid_cache do
			for _, fluid in next, tank_fluids do
				local name = fluid.name
				local amount = fluid.amount

				output[name] = (output[name] or 0) + amount
			end
		end

		return output
	end,

	---comment
	---@param self cctsl.FluidStorage
	---@param fluid_name string
	---@return fun(): string?, peripheral.FluidTankInfo?, integer?
	query_fluids = function(self, fluid_name)
		local cur_tank = nil
		local cur_fluid = nil

		return function()
			for tank_name, tank_fluids in next, self._fluid_cache, cur_tank do
				for index, fluid in next, tank_fluids, cur_fluid do
					cur_fluid = index

					if fluid.name == fluid_name then
						return tank_name, fluid, index
					end
				end

				cur_tank = tank_name
				cur_fluid = nil
			end

			return nil, nil, nil
		end
	end,

	---@param self cctsl.FluidStorage
	---@param tank_from string
	---@param tank_to string
	---@param limit? integer
	---@param fluid_name? string
	---@return integer transferred
	pull_fluids = function(self, tank_from, tank_to, limit, fluid_name)
		local to_tank = self.loaded_tanks[tank_to] ---@type peripheral.FluidStorage?

		if to_tank == nil then
			error(UNKNOWN_TANK:format(tank_to), 2)
		end

		return to_tank.pullFluid(tank_from, limit, fluid_name)
	end,
	---@param self cctsl.FluidStorage
	---@param tank_from string
	---@param tank_to string
	---@param limit? integer
	---@param fluid_name? string
	---@return integer transferred
	push_fluids = function(self, tank_from, tank_to, limit, fluid_name)
		local from_tank = self.loaded_tanks[tank_from] ---@type peripheral.FluidStorage?

		if from_tank == nil then
			error(UNKNOWN_TANK:format(from_tank), 2)
		end

		return from_tank.pushFluid(tank_to, limit, fluid_name)
	end,
}
local METATABLE = { __index = CLASS }

local function FluidStorage()
	local new_fluidstorage = setmetatable({
		loaded_tanks = {},
		_fluid_cache = {},
	}, METATABLE)

	return new_fluidstorage
end

return FluidStorage
