local UNKNOWN_INVENTORY = 'Unable to find inventory "%s", is it being tracked?'
local UNKNOWN_PERIPHERAL = 'Unable to find peripheral "%s"'
local INVALID_INVENTORY = 'Peripheral "%s" is not a valid inventory!'

---@type cc.peripheral.Inventory
local TURTLE_COMPAT = {
	---@return table<integer, cc.types.items.BasicItemStackDetails?>
	list = function()
		local items = {}

		for slot = 1, 16 do
			items[slot] = turtle.getItemDetail(slot)
		end

		return items
	end,
	---@return integer
	size = function()
		return 16
	end,
	---@param slot integer
	---@return integer
	getItemLimit = function(slot)
		return turtle.getItemSpace(slot) + turtle.getItemCount(slot)
	end,
	getItemDetail = turtle.getItemDetail,
}

local _THIS_COMPUTER = assert(peripheral.find("modem"), "No modem connected to computer!").getNameLocal()

---@alias cctsl.types.ItemFilter fun(item: cc.types.items.BasicItemStackDetails, inv_name: string, slot: number): boolean

---@class cctsl.types.Inventory
---@field name string
---@field remote cc.peripheral.Inventory
---@field items cc.types.items.BasicItemStackDetails[]
---@field slot_count integer

---@param inv_name string
---@return cc.peripheral.Inventory
local function get_inventory(inv_name)
	-- if we're trying to get ourselves and we're a turtle, then return the inventory-like interface for the turtle
	if turtle ~= nil and inv_name == _THIS_COMPUTER then
		return TURTLE_COMPAT
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

---@param a cc.types.items.BasicItemStackDetails
---@param b cc.types.items.BasicItemStackDetails
---@return boolean
local function default_item_sort(a, b)
	return a.count > b.count
end

---An object that tracks inventories and handles item logistics.
---@class cctsl.ItemNetwork
---@field tracked_inventories table<string, cctsl.types.Inventory>
local CLASS = {
	---Adds an inventory into the network.
	---@param self cctsl.ItemNetwork
	---@param inv_name string The name of the peripheral to track
	add_inventory = function(self, inv_name)
		self.tracked_inventories[inv_name] = {
			name = inv_name,
			remote = get_inventory(inv_name),
			items = {},
			slot_count = -1,
		}
	end,
	---Adds multiple inventories to the network at once.
	---@param self cctsl.ItemNetwork
	---@param inv_names string[] The names of peripherals to track
	---@see cctsl.ItemNetwork.add_inventory
	add_inventories = function(self, inv_names)
		for _, inv_name in next, inv_names do
			self.tracked_inventories[inv_name] = {
				name = inv_name,
				remote = get_inventory(inv_name),
				items = {},
				slot_count = -1,
			}
		end
	end,
	---Removes an inventory from the network.
	---@param self cctsl.ItemNetwork
	---@param inv_name string The name of the peripheral to stop tracking
	remove_inventory = function(self, inv_name)
		self.tracked_inventories[inv_name] = nil
	end,
	---Removes multiple inventories from the network at once.
	---@param self cctsl.ItemNetwork
	---@param inv_names string[]
	remove_inventories = function(self, inv_names)
		for _, inv_name in next, inv_names do
			self.tracked_inventories[inv_name] = nil
		end
	end,
	---Returns an array of all the inventories currently being tracked by the network.
	---@param self cctsl.ItemNetwork
	---@return cctsl.types.Inventory[] inventories
	get_inventories = function(self)
		local inventories = {}

		for _, inv in next, self.tracked_inventories do
			table.insert(inventories, inv)
		end

		return inventories
	end,

	---Syncs the inventories connected to the network (updating items and inventory sizes).
	---
	---This function should only be called when it's absolutely necessary, as it's rather slow to gather all of the items from every
	---inventory in the network (especially large ones).
	---@param self cctsl.ItemNetwork
	sync = function(self)
		for _, inventory in next, self.tracked_inventories do
			local remote = inventory.remote

			inventory.items = remote.list()
			inventory.slot_count = remote.size()
		end
	end,

	---Returns the total size (slots) of the network.
	---@param self cctsl.ItemNetwork
	---@return integer total_size
	get_network_size = function(self)
		local size = 0

		for _, inventory in next, self.tracked_inventories do
			size = size + inventory.slot_count
		end

		return size
	end,
	---Returns a table of every item in the network and it's network count.
	---@param self cctsl.ItemNetwork
	---@return table<string, integer> network_items
	get_network_items = function(self)
		local output = {}

		for _, inventory in next, self.tracked_inventories do
			for _, item in next, inventory.items do
				local name = item.name
				local count = item.count

				output[name] = (output[name] or 0) + count
			end
		end

		return output
	end,
	---Returns a _sorted_ array of all the items in the network.
	---
	---You can specify your own sorter callback.
	---@param self cctsl.ItemNetwork
	---@param sorter? fun(a: cc.types.items.BasicItemStackDetails, b: cc.types.items.BasicItemStackDetails): boolean
	---@return cc.types.items.BasicItemStackDetails[]
	get_network_items_sorted = function(self, sorter)
		local sorted_output = {}

		for name, count in next, self:get_network_items() do
			table.insert(sorted_output, {
				name = name,
				count = count,
			})
		end

		table.sort(sorted_output, sorter or default_item_sort)

		return sorted_output
	end,

	---Returns an iterator for each occurance of an item in the network.
	---
	---Example usage:
	---```lua
	---for inv, slot, item in network:iter_items(function(item) return item.name == "minecraft:torch" end) do
	---	print(inv, slot, item.count)
	---end
	---```
	---@param self cctsl.ItemNetwork
	---@param filter cctsl.types.ItemFilter
	---@return fun(): string?, integer?, cc.types.items.BasicItemStackDetails?
	iter_items = function(self, filter)
		local cur_inv = nil
		local cur_slot = nil

		return function()
			for inv_name, inv in next, self.tracked_inventories, cur_inv do
				for slot, item in next, inv.items, cur_slot do
					cur_slot = slot

					if filter(item, inv_name, slot) then
						return inv_name, slot, item
					end
				end

				-- advancing to next inventory
				cur_inv = inv_name
				cur_slot = nil -- reset slot
			end

			return nil, nil, nil
		end
	end,

	---Pulls items from one inventory into another.
	---@param self cctsl.ItemNetwork
	---@param inv_from string
	---@param slot_from integer
	---@param inv_to string
	---@param slot_to? integer
	---@param count? integer
	---@return integer transferred
	pull_items = function(self, inv_from, slot_from, inv_to, slot_to, count)
		local to_inventory = self.tracked_inventories[inv_to] ---@type cctsl.types.Inventory?

		if to_inventory == nil then
			error(UNKNOWN_INVENTORY:format(inv_to), 2)
		end

		return to_inventory.remote.pullItems(inv_from, slot_from, count, slot_to)
	end,
	---Pushs items from one inventory into another.
	---@param self cctsl.ItemNetwork
	---@param inv_from string
	---@param slot_from integer
	---@param inv_to string
	---@param slot_to? integer
	---@param count? integer
	---@return integer transferred
	push_items = function(self, inv_from, slot_from, inv_to, slot_to, count)
		local from_inventory = self.tracked_inventories[inv_from] ---@type cctsl.types.Inventory?

		if from_inventory == nil then
			error(UNKNOWN_INVENTORY:format(inv_from), 2)
		end

		return from_inventory.remote.pushItems(inv_to, slot_from, count, slot_to)
	end,

	---Imports an item stack into the network from an external inventory, at the specified slot.
	---@param self cctsl.ItemNetwork
	---@param inv_from string Name of external inventory to pull from
	---@param slot_from integer Slot index of item stack to pull
	---@param count? integer Number of items to pull from the item stack
	---@return integer total_transferred
	import_from_slot = function(self, inv_from, slot_from, count)
		local current_inv = next(self.tracked_inventories)

		-- this would mean that our network had zero inventories in it, i guess it's technically correct
		-- though i feel like this should throw an error
		if current_inv == nil then
			return 0
		end

		local total_transferred = 0

		while true do
			local remaining = count ~= nil and count - total_transferred or nil
			local transferred = self:pull_items(inv_from, slot_from, current_inv, nil, remaining)

			total_transferred = total_transferred + transferred

			if count ~= nil and total_transferred >= count then
				break
			end

			if transferred == 0 then -- cycle to next inventory, current inventory might be full
				current_inv = next(self.tracked_inventories, current_inv)

				-- ran out of inventories in the network, abort import
				if current_inv == nil then
					break
				end
			elseif count == nil then
				break
			end
		end

		return total_transferred
	end,

	---Imports all items into the network from an external inventory that pass the specified filter.
	---@param self cctsl.ItemNetwork
	---@param inv_from string Name of external inventory to import from
	---@param filter cctsl.types.ItemFilter Function that determines what items are imported
	---@param count number? Number of items to pull from the inventory
	---@return integer total_transferred
	import_items = function(self, inv_from, filter, count)
		local total_transferred = 0

		local inventory = get_inventory(inv_from)

		for slot, item in next, inventory.list() do
			if filter(item, inv_from, slot) then
				local remaining = count ~= nil and count - total_transferred or item.count
				local transferred = self:import_from_slot(inv_from, slot, math.min(remaining, item.count))

				total_transferred = total_transferred + transferred
			end
		end

		return total_transferred
	end,

	---Exports the specified item from the system into an external inventory.
	---@param self cctsl.ItemNetwork
	---@param inv_to string Name of external inventory to export to
	---@param filter cctsl.types.ItemFilter Function that determines what items are exported
	---@param slot_to? integer
	---@param count? integer
	---@return integer total_transferred
	export_items = function(self, inv_to, filter, slot_to, count)
		local total_transferred = 0

		for inv, slot in self:iter_items(filter) do
			local remaining = count ~= nil and count - total_transferred or nil
			local transferred = self:push_items(inv, slot, inv_to, slot_to, remaining)

			total_transferred = total_transferred + transferred

			if count == nil or total_transferred >= count then
				break
			end
		end

		return total_transferred
	end,

	---Returns whether every single slot in every inventory connected to the network has an item stack.
	---@param self cctsl.ItemNetwork
	is_full = function(self)
		return self:get_network_size()
	end,
}
local METATABLE = { __index = CLASS }

---@param initial_inventories? string[]
---@return cctsl.ItemNetwork
local function ItemNetwork(initial_inventories)
	local new_storagesystem = setmetatable({
		tracked_inventories = {},
	}, METATABLE)

	if initial_inventories ~= nil then
		new_storagesystem:add_inventories(initial_inventories)
	end

	return new_storagesystem
end

return ItemNetwork
