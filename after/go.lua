require('mason-lspconfig').setup({
    ensure_installed = {'gopls'},
    handlers = {
        gopls = function()
            require('lspconfig').gopls.setup({
                on_init = function(client)
                    client.server_capabilities.documetFormattingProvider = false
                end,
                settings = {
                    gopls = {
                        gofumpt = false,
                        analyses = {
                            unusedparams = true,
                            shadow = true,
                        }
                    }
                }
            })
        end,
    }
})
