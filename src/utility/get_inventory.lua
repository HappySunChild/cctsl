local turtle_compat = require("utility.turtle_compat")

local UNKNOWN_PERIPHERAL = 'Unable to find peripheral "%s"'
local INVALID_INVENTORY = 'Peripheral "%s" is not a valid inventory!'

local modem = peripheral.find("modem") ---@type peripheral.Modem
local this_computer = modem.getNameLocal()

---@param inv_name string
---@return peripheral.Inventory
local function get_inventory(inv_name)
	-- if we're trying to get ourselves and we're a turtle, then return the inventory-like interface for the turtle
	if turtle ~= nil and inv_name == this_computer then
		return turtle_compat
	end

	local inventory = peripheral.wrap(inv_name)

	if inventory == nil then
		error(UNKNOWN_PERIPHERAL:format(inv_name), 2)
	end

	if inventory.list == nil then
		error(INVALID_INVENTORY:format(inv_name), 2)
	end

	return inventory
end

return get_inventory
