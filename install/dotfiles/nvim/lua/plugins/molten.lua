return {
  "benlubas/molten-nvim",
  version = "^1.0.0",
  build = ":UpdateRemotePlugins",
  lazy = false,
  init = function()
    vim.g.molten_image_provider = "none"
    vim.g.molten_output_win_max_height = 20
    vim.g.molten_auto_open_output = true
  end,
  config = function()
    -- auto-import existing cell outputs when opening a notebook
    local import_outputs = function(e)
      vim.schedule(function()
        local ok, metadata = pcall(function()
          return vim.json.decode(io.open(e.file, "r"):read("a"))["metadata"]
        end)
        local kernel_name = ok and metadata.kernelspec and metadata.kernelspec.name or "python3"
        if not vim.tbl_contains(vim.fn.MoltenAvailableKernels(), kernel_name) then
          return
        end
        vim.cmd(("MoltenInit %s"):format(kernel_name))
        vim.cmd("MoltenImportOutput")
      end)
    end
    vim.api.nvim_create_autocmd("BufAdd", { pattern = "*.ipynb", callback = import_outputs })
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*.ipynb",
      callback = function(e)
        if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
          import_outputs(e)
        end
      end,
    })

    -- auto-export outputs back into the .ipynb on save
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*.ipynb",
      callback = function()
        if require("molten.status").initialized() == "Molten" then
          vim.cmd("MoltenExportOutput!")
        end
      end,
    })
  end,
  keys = {
    { "<localleader>mi", "<cmd>MoltenInit<cr>", desc = "Molten: init kernel" },
    { "<localleader>e", "<cmd>MoltenEvaluateOperator<cr>", desc = "Molten: evaluate operator" },
    { "<localleader>rl", "<cmd>MoltenEvaluateLine<cr>", desc = "Molten: evaluate line" },
    { "<localleader>rr", "<cmd>MoltenReevaluateCell<cr>", desc = "Molten: re-evaluate cell" },
    { "<localleader>rv", ":<C-u>MoltenEvaluateVisual<cr>gv", mode = "v", desc = "Molten: evaluate visual" },
    { "<localleader>os", "<cmd>MoltenShowOutput<cr>", desc = "Molten: show output" },
    { "<localleader>oh", "<cmd>MoltenHideOutput<cr>", desc = "Molten: hide output" },
  },
}
