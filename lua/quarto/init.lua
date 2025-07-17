local M = {}
local api = vim.api
local cfg = require 'quarto.config'
local tools = require 'quarto.tools'
local util = require 'quarto.util'


function M.quartoUpdatePreview()
  local quartoOutputBuf = api.nvim_buf_get_var(0, 'quartoOutputBuf')
  local query_start = 'Browse at http'
  local lines = vim.api.nvim_buf_get_lines(quartoOutputBuf, 0, -1, false)
  local url = nil
  for _, line in ipairs(lines) do
    if line:find(query_start) then
      url = 'http' .. line:sub(#query_start + 1)
      break
    end
  end
  if not url then
    vim.notify('Could not find the preview url in the terminal buffer. Maybe it is still warming up. Check the buffer and try again.', vim.log.levels.WARN)
    return
  end
  api.nvim_buf_set_var(0, 'quartoUrl', url)
  local request_url = url .. 'quarto-render/'
  local get_request = 'curl -s ' .. request_url
  local response = vim.fn.system(get_request)
  if response ~= 'rendered' then
    vim.notify_once('Failed to update preview with command: ' .. get_request, vim.log.levels.ERROR)
  end
end

function M.quartoClosePreview()
  local success, quartoOutputBuf = pcall(api.nvim_buf_get_var, 0, 'quartoOutputBuf')
  if not success then
    return
  end
  if api.nvim_buf_is_loaded(quartoOutputBuf) then
    api.nvim_buf_delete(quartoOutputBuf, { force = true })
  end
end

M.searchHelp = function(cmd_input)
  local topic = cmd_input.args
  local url = 'https://quarto.org/?q=' .. topic .. '&show-results=1'
  local sysname = vim.loop.os_uname().sysname
  local cmd
  if sysname == 'Linux' then
    cmd = 'xdg-open "' .. url .. '"'
  elseif sysname == 'Darwin' then
    cmd = 'open "' .. url .. '"'
  else
    print 'sorry, I do not know how to make Windows open a url with the default browser. This feature currently only works on linux and mac.'
    return
  end
  vim.fn.jobstart(cmd)
end

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
