---@type cctsl.types.ItemFilter
---An item filter that accepts any item stack.
local function any(item, inv_name, slot)
	return true
end

---Creates an item filter that only accepts item stacks with the specified name.
---@param target_name string
---@return cctsl.types.ItemFilter
local function with_name(target_name)
	return function(item, inv_name, slot)
		return item.name == target_name
	end
end

---Creates an item filter that only accepts item stacks from the specified mod.
---@param mod_id string
---@return cctsl.types.ItemFilter
local function from_mod(mod_id)
	return function(item, inv_name, slot)
		return string.match(item.name, "([^:]+):") == mod_id
	end
end

return {
	any = any,
	with_name = with_name,
	from_mod = from_mod,
}
