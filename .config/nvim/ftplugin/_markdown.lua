-- If we are in a float we want to hide the fenced code-block whitespace
vim.wo.conceallevel = vim.bo.readonly or vim.bo.buftype == 'nofile' and 2 or 0
