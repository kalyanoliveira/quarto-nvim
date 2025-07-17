local M = {}
local api = vim.api
local cfg = require 'quarto.config'

-- from https://github.com/neovim/nvim-lspconfig/blob/f98fa715acc975c2dd5fb5ba7ceddeb1cc725ad2/lua/lspconfig/util.lua#L23
function M.bufname_valid(bufname)
  if bufname:match '^/' or bufname:match '^[a-zA-Z]:' or bufname:match '^zipfile://' or bufname:match '^tarfile:' then
    return true
  end
  return false
end

M.activate = function()
  local bufname = vim.api.nvim_buf_get_name(0)
  -- do not activate in special buffers, for example 'fugitive://...'
  if not M.bufname_valid(bufname) then
    return
  end
  local tsquery = nil
  if cfg.config.lspFeatures.chunks == 'curly' then
    tsquery = [[
      (fenced_code_block
      (info_string
        (language) @_lang
      ) @info
        (#match? @info "{")
      (code_fence_content) @content (#offset! @content)
      )
      ((html_block) @html @combined)

      ((minus_metadata) @yaml (#offset! @yaml 1 0 -1 0))
      ((plus_metadata) @toml (#offset! @toml 1 0 -1 0))

      ]]
  end
  require('otter').activate(cfg.config.lspFeatures.languages, cfg.config.lspFeatures.completion.enabled, cfg.config.lspFeatures.diagnostics.enabled, tsquery)
end

-- setup
M.setup = function(opt)
  cfg.config = vim.tbl_deep_extend('force', cfg.defaultConfig, opt or {})

  if cfg.config.codeRunner.enabled then
    -- setup top level run functions
    local runner = require 'quarto.runner'
    M.quartoSend = runner.run_cell
    M.quartoSendAbove = runner.run_above
    M.quartoSendBelow = runner.run_below
    M.quartoSendAll = runner.run_all
    M.quartoSendRange = runner.run_range
    M.quartoSendLine = runner.run_line

    -- setup run user commands
    api.nvim_create_user_command('QuartoSend', function(_)
      runner.run_cell()
    end, {})
    api.nvim_create_user_command('QuartoSendAbove', function(_)
      runner.run_above()
    end, {})
    api.nvim_create_user_command('QuartoSendBelow', function(_)
      runner.run_below()
    end, {})
    api.nvim_create_user_command('QuartoSendAll', function(_)
      runner.run_all()
    end, {})
    api.nvim_create_user_command('QuartoSendRange', function(_)
      runner.run_range()
    end, { range = 2 })
    api.nvim_create_user_command('QuartoSendLine', function(_)
      runner.run_line()
    end, {})
  end
end

return M
