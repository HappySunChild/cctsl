return {
	---@return table<integer, peripheral.InventoryItem?>
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
} ---@type peripheral.Inventory
