local gitlink = require("gitlink")

local function sort_pair(t)
  if #t ~= 2 then
    error("Didn't receive line parameters correctly formatted")
  end

  if t[1] > t[2] then
    t[1], t[2] = t[2], t[1]
  end

  return t
end

vim.api.nvim_create_user_command("YankGitCommitPermanentLink", function(args)
  local line1 = args.line1
  local line2 = args.line2
  gitlink.yank_commit_permanent_link(sort_pair({ line1, line2 }))
end, { range = true })

vim.api.nvim_create_user_command("YankFormattedGitReference", function(args)
  local line1 = args.line1
  local line2 = args.line2
  local formatter = args.args
  gitlink.yank_markdown_reference(sort_pair({ line1, line2 }), formatter)
end, { range = true, nargs = "?", complete = "customlist,MyCustomCompleteFunc" })

-- vim.api.nvim_create_user_command("YankFormattedGitReference", function(args)
--   local line1 = args.line1
--   local line2 = args.line2
--   gitlink.yank_markdown_reference(sort_pair({ line1, line2 }))
-- end, { range = true })
