local UNKNOWN_TANK = 'Unable to find tank "%s", is it being tacked?'
local UNKNOWN_PERIPHERAL = 'Unable to find peripheral "%s"'
local INVALID_TANK = 'Peripheral "%s" is not a valid tank!'

---@alias cctsl.types.FluidFilter fun(fluid: cc.types.peripheral.FluidTankDetails, tank_name: string)

---@class cctsl.types.FluidTank
---@field name string
---@field remote cc.peripheral.FluidStorage
---@field fluids cc.types.peripheral.FluidTankDetails[]

---@param tank_name string
---@return cc.peripheral.FluidStorage
local function internal_get_tank(tank_name)
	local tank = peripheral.wrap(tank_name)

	if tank == nil then
		error(UNKNOWN_PERIPHERAL:format(tank_name), 2)
	end

	if tank.tanks == nil then
		error(INVALID_TANK:format(tank_name), 2)
	end

	return tank
end

---@class cctsl.FluidNetwork
---@field tracked_tanks table<string, cctsl.types.FluidTank>
local CLASS = {
	---Adds a tank into the network.
	---@param self cctsl.FluidNetwork
	---@param tank_name string
	add_tank = function(self, tank_name)
		self.tracked_tanks[tank_name] = {
			name = tank_name,
			remote = internal_get_tank(tank_name),
			fluids = {},
		}
	end,
	---Adds multiple tanks to the network at once.
	---@param self cctsl.FluidNetwork
	---@param tank_names string[]
	add_tanks = function(self, tank_names)
		for _, tank_name in next, tank_names do
			self.tracked_tanks[tank_name] = {
				name = tank_name,
				remote = internal_get_tank(tank_name),
				fluids = {},
			}
		end
	end,
	---Removes a tank from the network.
	---@param self cctsl.FluidNetwork
	---@param tank_name string
	remove_tank = function(self, tank_name)
		self.tracked_tanks[tank_name] = nil
	end,
	---Removes multiple tanks from the network at once.
	---@param self cctsl.FluidNetwork
	---@param tank_names string[]
	remove_tanks = function(self, tank_names)
		for _, tank_name in next, tank_names do
			self.tracked_tanks[tank_name] = nil
		end
	end,
	---Returns an array of all tanks currently being tracked by the network.
	---@param self cctsl.FluidNetwork
	---@return cctsl.types.FluidTank[] tanks
	get_tanks = function(self)
		local tanks = {}

		for _, tank in next, self.tracked_tanks do
			table.insert(tanks, tank)
		end

		return tanks
	end,

	---Syncs the tanks connected to the network.
	---@param self cctsl.FluidNetwork
	sync = function(self)
		for _, tank in next, self.tracked_tanks do
			tank.fluids = tank.remote.tanks()
		end
	end,

	---Returns a table of every fluid in the network and it's network amount.
	---@param self cctsl.FluidNetwork
	---@return table<string, integer> network_fluids
	get_network_fluids = function(self)
		local output = {}

		for _, tank in next, self.tracked_tanks do
			for _, fluid in next, tank.fluids do
				local name = fluid.name
				local amount = fluid.amount

				output[name] = (output[name] or 0) + amount
			end
		end

		return output
	end,

	---Returns an iterator for each occurnace of a fluid in the network.
	---@param self cctsl.FluidNetwork
	---@param filter cctsl.types.FluidFilter
	---@return fun(): string?, cc.types.peripheral.FluidTankDetails?, integer?
	iter_fluids = function(self, filter)
		local cur_tank = nil
		local cur_fluid = nil

		return function()
			for tank_name, tank in next, self.tracked_tanks, cur_tank do
				for index, fluid in next, tank.fluids, cur_fluid do
					cur_fluid = index

					if filter(fluid, tank_name) then
						return tank_name, fluid, index
					end
				end

				cur_tank = tank_name
				cur_fluid = nil
			end

			return nil, nil, nil
		end
	end,

	---Pulls fluids from one tank into another.
	---@param self cctsl.FluidNetwork
	---@param tank_from string
	---@param tank_to string
	---@param limit? integer
	---@param fluid_name? string
	---@return integer transferred
	pull_fluids = function(self, tank_from, tank_to, limit, fluid_name)
		local to_tank = self.tracked_tanks[tank_to] ---@type cctsl.types.FluidTank?

		if to_tank == nil then
			error(UNKNOWN_TANK:format(tank_to), 2)
		end

		return to_tank.remote.pullFluid(tank_from, limit, fluid_name)
	end,
	---Pushs fluids from one tank into another.
	---@param self cctsl.FluidNetwork
	---@param tank_from string
	---@param tank_to string
	---@param limit? integer
	---@param fluid_name? string
	---@return integer transferred
	push_fluids = function(self, tank_from, tank_to, limit, fluid_name)
		local from_tank = self.tracked_tanks[tank_from] ---@type cctsl.types.FluidTank?

		if from_tank == nil then
			error(UNKNOWN_TANK:format(from_tank), 2)
		end

		return from_tank.remote.pushFluid(tank_to, limit, fluid_name)
	end,
}
local METATABLE = { __index = CLASS }

local function FluidNetwork()
	local new_fluidnetwork = setmetatable({
		tracked_tanks = {},
	}, METATABLE)

	return new_fluidnetwork
end

return FluidNetwork
