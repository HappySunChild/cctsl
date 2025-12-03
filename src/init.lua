local lib_path = select(2, ...)
local lib_dir = fs.getDir(lib_path)

local path_format = "~;/~/?.lua;/~/?/init.lua;"
local original_path = package.path

package.path = path_format:gsub("~", lib_dir) .. original_path

local storage_lib = {
	AutoCrafter = require("AutoCrafter"),
	ItemStorage = require("ItemStorage"),
}

package.path = original_path

return storage_lib
