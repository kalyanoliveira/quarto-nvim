local config = require("quarto.config").config
local quarto = require("quarto")

if config.lspFeatures.enabled then quarto.activate() end
