<img src="./gh-assets/logo-dark.png#gh-dark-mode-only" alt="cctsl">
<img src="./gh-assets/logo-light.png#gh-light-mode-only" alt="cctsl">

`cctsl` (CC:Tweaked Storage Library) is a library for [CC:Tweaked](https://tweaked.cc/) that simplifies managing inventories and autocrafting.

This library was originally for my [okstorage](https://github.com/HappySunChild/okstorage) program, but I've decided to rip out the actual library part and make it it's own project (though development will still be pretty interlinked).

> [!NOTE]
> All inventory peripherals must be connected via `Wired Modems` and `Networking Cables`, using `Ender Modems` does not work!
> 
> Also note that adjacent peripherals (peripherals connected to a `Computer` without a modem) are _**incompatible**_ with modem peripherals, your networks **must** be entirely adjacent or modem peripherals.

## Example Usage

Here's a small example of using the `ItemNetwork` object to iterate over every instance of `"minecraft:charcoal"` in some chests.
```lua
local cctsl = require("cctsl")
local filters = cctsl.filters

local network = cctsl.ItemNetwork({ "minecraft:chest_11", "minecraft:chest_12", "minecraft:chest_13" })
network:sync()

for inv, slot, item in network:iter_items(filters.with_name("minecraft:charcoal")) do
	print(inv, slot, item.count)
end

```