return {

  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    config = function ()
      require('config.treesitter')
    end,
    build = ':TSUpdate',
  },
}
