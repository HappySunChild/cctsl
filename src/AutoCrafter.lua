local UNKNOWN_PERIPHERAL = 'Unable to find peripheral "%s"'
local UNKNOWN_PROCESSOR = 'Unable to find processor "%s", did you add it?'
local PATTERN_NOT_SUPPORTED = 'Processor "%s" does not support this pattern!'
local PROCESSOR_BUSY = 'Processor "%s" is busy!'
local NOT_ENOUGH_INGREDIENTS = "Not enough ingredients!"

---@class cctsl.AutoCrafter.PatternInfo
---@field results table<string, integer>
---@field input_slots { [1]: integer, [2]: string }[] Slots to input items into.
---@field output_slots number[] Slots to constantly pull into the system.
---@field poll_rate number How frequently the processor checks the output per second.
---@field label string

---Find the index of a value in the passed table.
---@generic K
---@param haystack table<K, any>
---@param needle? any
---@return K?
local function find(haystack, needle)
	for key, value in next, haystack do
		if value == needle then
			return key
		end
	end

	return nil
end

---@generic K, V
---@param in_tbl table<K, V>
---@param count integer
---@return fun(tbl: table<K, V>, index: K?): K?, V?, integer?
---@return K, nil
local function distribute(in_tbl, count)
	local count_per_item = math.floor(count / #in_tbl)
	local extra_items = count % #in_tbl

	---@generic K, V
	---@param tbl table<K, V>
	---@param index K?
	return function(tbl, index)
		local current_index = next(in_tbl, index)

		if current_index == nil then
			return nil
		end

		local iterations = count_per_item + (extra_items > 0 and 1 or 0)

		extra_items = extra_items - 1

		if iterations == 0 then
			return nil
		end

		return current_index, tbl[current_index], iterations
	end,
		in_tbl,
		nil
end

---@class cctsl.AutoCrafter.Processor
---@field patterns string[]
---@field in_use boolean
---@field reserved boolean

---Returns a dictionary of ingredients needed to produce a pattern.
---@param pattern cctsl.AutoCrafter.PatternInfo
---@param iterations integer
---@return table<string, integer>
local function get_pattern_ingredients(pattern, iterations)
	local requirements = {}

	for _, ingredient in next, pattern.input_slots do
		local ingr_count, ingr_name = ingredient[1], ingredient[2]

		requirements[ingr_name] = (requirements[ingr_name] or 0) + (ingr_count * iterations)
	end

	return requirements
end

---@param pattern cctsl.AutoCrafter.PatternInfo
---@return integer count
local function get_pattern_output_count(pattern)
	local total_count = 0

	for _, count in next, pattern.results do
		total_count = total_count + count
	end

	return total_count
end

---An object that handles basic item autocrafting.
---@class cctsl.AutoCrafter
---@field processors table<string, cctsl.AutoCrafter.Processor>
---@field patterns table<string, cctsl.AutoCrafter.PatternInfo>
---@field request_network cctsl.ItemNetwork
local CLASS = {
	---Registers a pattern.
	---@param self cctsl.AutoCrafter
	---@param pattern string
	---@param info cctsl.AutoCrafter.PatternInfo
	load_pattern = function(self, pattern, info)
		self.patterns[pattern] = info
	end,
	---Deregisters a pattern.
	---@param self cctsl.AutoCrafter
	---@param pattern string
	unload_pattern = function(self, pattern)
		self.patterns[pattern] = nil
	end,
	---Returns an array of all registers patterns.
	---@param self cctsl.AutoCrafter
	---@return string[]
	get_loaded_patterns = function(self)
		local list = {}

		for name in next, self.patterns do
			table.insert(list, name)
		end

		return list
	end,

	---Adds a processor to the AutoProcessing manager.
	---@param self cctsl.AutoCrafter
	---@param proc_name string The name of the inventory the processor uses.
	---@param patterns string[] All of the patterns this processor supports.
	load_processor = function(self, proc_name, patterns)
		if not peripheral.isPresent(proc_name) then
			error(UNKNOWN_PERIPHERAL:format(proc_name), 2)
		end

		self.processors[proc_name] = {
			patterns = patterns,
			in_use = false,
			reserved = false,
		}
	end,
	---Removes a processor from the AutoProcessing manager
	---@param self cctsl.AutoCrafter
	---@param proc_name string The name of the inventory the processor uses.
	unload_processor = function(self, proc_name)
		self.processors[proc_name] = nil
	end,
	---Returns an array of all the processors in the AutoProcessing manager.
	---@param self cctsl.AutoCrafter
	---@return string[]
	get_processors = function(self)
		local processors = {}

		for proc_name in next, self.processors do
			table.insert(processors, proc_name)
		end

		table.sort(processors)

		return processors
	end,

	---Adds a pattern to a processor.
	---@param self cctsl.AutoCrafter
	---@param proc_name string
	---@param pattern string
	add_pattern_to_processor = function(self, proc_name, pattern)
		local processor = self.processors[proc_name]

		if processor == nil then
			error(UNKNOWN_PROCESSOR:format(proc_name), 2)
		end

		if find(processor.patterns, pattern) then
			return
		end

		table.insert(processor.patterns, pattern)
	end,
	---Removes a pattern from a processor.
	---@param self cctsl.AutoCrafter
	---@param proc_name string
	---@param pattern string
	remove_pattern_from_processor = function(self, proc_name, pattern)
		local processor = self.processors[proc_name]

		if processor == nil then
			error(UNKNOWN_PROCESSOR:format(proc_name), 2)
		end

		local index = find(processor.patterns, pattern)

		if index then
			table.remove(processor.patterns, index)
		end
	end,

	---Returns whether the specified processor is available.
	---@param self cctsl.AutoCrafter
	---@param proc_name string The name of the inventory the processor uses.
	---@return boolean available Where the processor is available.
	is_processor_available = function(self, proc_name)
		local processor = self.processors[proc_name]

		if processor == nil then
			error(UNKNOWN_PROCESSOR:format(proc_name))
		end

		return not processor.in_use and not processor.reserved
	end,
	---Returns an array of all available processors that are able to produce the specified item.
	---@param self cctsl.AutoCrafter
	---@param pattern string The name of the item to search with.
	---@return string[] processors A list of names for available processors.
	get_available_processors = function(self, pattern)
		local processors = {}

		for proc_name, processor in next, self.processors do
			if self:is_processor_available(proc_name) and find(processor.patterns, pattern) then
				table.insert(processors, proc_name)
			end
		end

		table.sort(processors)

		return processors
	end,
	---Returns an array of all registered patterns that result in the specified item.
	---@param self cctsl.AutoCrafter
	---@param item string
	---@return string[] patterns
	get_patterns_with_result = function(self, item)
		local patterns = {}

		for name, info in next, self.patterns do
			if info.results[item] ~= nil then
				table.insert(patterns, name)
			end
		end

		return patterns
	end,
	---Returns whether the autocrafter is able to craft the specified item.
	---@param self cctsl.AutoCrafter
	---@param item string
	---@param item_count integer
	---@return boolean
	can_craft = function(self, item, item_count)
		local patterns = self:get_patterns_with_result(item)

		for _, pattern in ipairs(patterns) do
			if #self:get_available_processors(pattern) > 0 then
				local info = self.patterns[pattern]
				local count = math.ceil(item_count / info.results[item])

				local missing = self:get_missing_ingredients(pattern, count)
				local ok = true

				for name, missing_count in next, missing do
					if name == item or not self:can_craft(name, missing_count) then
						ok = false

						break
					end
				end

				if ok then
					return true
				end
			end
		end

		return false
	end,

	---Returns a dictionary of all the missing ingredients for the specified pattern.
	---@param self cctsl.AutoCrafter
	---@param pattern string The pattern to check the ingredients of.
	---@param count integer The number of times the pattern is crafted (ie. crafting a pattern multiple times).
	---@return table<string, integer>
	get_missing_ingredients = function(self, pattern, count)
		local network_items = self.request_network:get_network_items()

		local missing = {}
		local ingredients = get_pattern_ingredients(self.patterns[pattern], count)

		for ingr_name, ingr_count in next, ingredients do
			local network_count = network_items[ingr_name] or 0

			if network_count < ingr_count then
				missing[ingr_name] = ingr_count - network_count
			end
		end

		return missing
	end,

	---@param self cctsl.AutoCrafter
	---@param proc_name string The name of the processor to use.
	---@param pattern string The pattern to use with the processor.
	---@param count integer The number of times to process this pattern on this processor.
	---@return boolean
	start_process_async = function(self, proc_name, pattern, count)
		local processor = self.processors[proc_name]

		if processor == nil then
			error(UNKNOWN_PROCESSOR:format(proc_name), 2)
		end

		if processor.in_use then
			error(PROCESSOR_BUSY:format(proc_name), 2)
		end

		if find(processor.patterns, pattern) == nil then
			error(PATTERN_NOT_SUPPORTED:format(proc_name), 2)
		end

		processor.reserved = false

		local pattern_info = self.patterns[pattern]

		local request_network = self.request_network

		local poll_duration = 1 / pattern_info.poll_rate
		local output_per_pattern = get_pattern_output_count(pattern_info)

		local input_slots = pattern_info.input_slots
		local output_slots = pattern_info.output_slots

		processor.in_use = true

		for _ = 1, count do
			-- input ingredients into slots
			for input_slot, ingredient in next, input_slots do
				local ingr_count, ingr_name = ingredient[1], ingredient[2]

				request_network:export_items(proc_name, function(item, inv_name, slot)
					return item.name == ingr_name
				end, input_slot, ingr_count)
			end

			request_network:sync()

			-- wait for result items back
			-- should this instead check for items being added into the system?
			local remaining = output_per_pattern

			while remaining > 0 do
				sleep(poll_duration)

				for _, output_slot in next, output_slots do
					local transferred = request_network:import_from_slot(proc_name, output_slot)

					remaining = remaining - transferred
				end
			end
		end

		processor.in_use = false

		return true
	end,
	---@param self cctsl.AutoCrafter
	---@param processors string[]
	---@param pattern string
	---@param total_count integer
	start_batch_process_async = function(self, processors, pattern, total_count)
		local missing = self:get_missing_ingredients(pattern, total_count)

		for ingr, item_count in next, missing do
			if not self:can_craft(ingr, item_count) then
				error(NOT_ENOUGH_INGREDIENTS, 2)
			end

			local sub_pattern = self:get_patterns_with_result(ingr)[1]
			local sub_pattern_info = self.patterns[sub_pattern]

			local sub_processors = self:get_available_processors(sub_pattern)

			local iterations = math.ceil(item_count / sub_pattern_info.results[ingr])

			self:start_batch_process_async(sub_processors, sub_pattern, iterations)
		end

		local tasks = {}

		for _, proc_name, count in distribute(processors, total_count) do
			local run_tasks = function()
				self:start_process_async(proc_name, pattern, count)
			end

			table.insert(tasks, run_tasks)
		end

		parallel.waitForAll(table.unpack(tasks))
	end,
}
local METATABLE = { __index = CLASS }

---@param item_network cctsl.ItemNetwork
---@param initial_processors? table<string, string[]>
---@return cctsl.AutoCrafter
local function AutoCrafter(item_network, initial_processors)
	local new_autocrafter = setmetatable({
		request_network = item_network,

		patterns = {},
		processors = {},
	}, METATABLE)

	if initial_processors ~= nil then
		for inv_name, patterns in next, initial_processors do
			pcall(new_autocrafter.load_processor, new_autocrafter, inv_name, patterns)
		end
	end

	return new_autocrafter
end

return AutoCrafter
