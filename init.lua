-- copied from lazy.nvim site
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.keymap.set('n', 'ch', '<C-w>h')
vim.keymap.set('n', 'cj', '<C-w>j')
vim.keymap.set('n', 'ck', '<C-w>k')
vim.keymap.set('n', 'cl', '<C-w>l')
vim.keymap.set('n', 'c+', '<C-w>+')
vim.keymap.set('n', 'c-', '<C-w>-')
vim.keymap.set('n', 'c>', '<C-w>>')
vim.keymap.set('n', 'c<', '<C-w><')
vim.keymap.set('n', 'c=', '<C-w>=')

vim.cmd('syntax on')

vim.opt.colorcolumn = '120'
vim.opt.number = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.expandtab = true
vim.opt.clipboard:append('unnamedplus')

vim.cmd('highlight ColorColumn ctermbg=238')

require("lazy").setup({
  'itchyny/lightline.vim',
  'ellisonleao/gruvbox.nvim',
  {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'},
  'nvim-lua/plenary.nvim',
  {'nvim-telescope/telescope.nvim', tag = '0.1.8'},
})

vim.g.lightline = { colorscheme = 'solarized' }

vim.opt.background = 'light'
vim.cmd('colorscheme gruvbox')

require'nvim-treesitter.configs'.setup {
    ensure_installed = { "lua", "python", "query", "markdown", "markdown_inline", "c", "vimdoc" },
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
    }
}

-- inline Claude completion
require('claude').setup()
