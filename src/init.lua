assert(
	peripheral.find("modem"),
	"No modem connected to computer! cctsl requires a wired modem to connect to external inventories!"
)

local LIB_PATH = select(2, ...)
local LIB_DIR = fs.getDir(LIB_PATH)

local PATH_FORMAT = "~;/~/?.lua;/~/?/init.lua;"
local ORIGINAL_PATH = package.path

package.path = string.gsub(PATH_FORMAT, "~", LIB_DIR) .. ORIGINAL_PATH

local cctsl = {
	AutoCrafter = require("AutoCrafter"),
	ItemNetwork = require("ItemNetwork"),
	FluidNetwork = require("FluidNetwork"),
}

package.path = ORIGINAL_PATH

return cctsl
