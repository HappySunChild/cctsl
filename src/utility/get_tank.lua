local UNKNOWN_PERIPHERAL = 'Unable to find peripheral "%s"'
local INVALID_TANK = 'Peripheral "%s" is not a valid tank!'

---@param tank_name string
---@return peripheral.FluidStorage
local function get_tank(tank_name)
	local tank = peripheral.wrap(tank_name)

	if tank == nil then
		error(UNKNOWN_PERIPHERAL:format(tank_name), 2)
	end

	if tank.tanks == nil then
		error(INVALID_TANK:format(tank_name), 2)
	end

	return tank
end

return get_tank
