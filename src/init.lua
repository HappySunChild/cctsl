local lib_path = select(2, ...)
local lib_dir = fs.getDir(lib_path)

local path_format = "~;/~/?.lua;/~/?/init.lua;"
local original_path = package.path

package.path = path_format:gsub("~", lib_dir) .. original_path

local cctsl = {
	AutoCrafter = require("AutoCrafter"),
	ItemStorage = require("ItemStorage"),
	FluidStorage = require("FluidStorage"),
}

package.path = original_path

return cctsl
