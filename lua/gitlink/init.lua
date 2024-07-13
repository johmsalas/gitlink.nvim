local M = {}

local GIT_ORIGIN_CMD = "git ls-remote --get-url origin"
local GIT_BRANCH_CMD = "git rev-parse --abbrev-ref HEAD"
local GIT_HEAD_CMD = "git rev-parse HEAD"
local GIT_FILE_COMMIT_CMD = "git rev-list -1 HEAD -- %s"
local GIT_ROOT_CMD = "git rev-parse --show-toplevel"
local URL_ENCODE_CMD = "curl -s --data-urlencode %s"

local function cmd_run(cmd)
  return vim.fn.system(cmd):gsub("\n", "")
end

local function execute_with_ref(ref, startline, endline)
  local remote = cmd_run(GIT_ORIGIN_CMD)
  if not (remote:match("github") or remote:match("gitlab")) then
    vim.api.nvim_err_writeln("Unknown remote host")
    return
  end

  local repo
  if remote:match("^git") then
    repo = remote:gsub("^git@", "https://"):gsub(":", "/"):gsub("%.git$", "")
  elseif remote:match("^ssh") then
    repo = remote:gsub("^ssh://git@", "https://"):gsub("/", "/"):gsub("%.git$", "")
  elseif remote:match("^https") then
    repo = remote:gsub("%.git$", "")
  else
    vim.api.nvim_err_writeln("Remote doesn't match any known protocol")
    return
  end

  local root = cmd_run(GIT_ROOT_CMD)
  local filepath = vim.fn.expand("%:p"):gsub(root, "")
  filepath = cmd_run(string.format(URL_ENCODE_CMD, filepath))

  local link = string.format("%s/blob/%s/%s", repo, ref, filepath)

  if filepath:match("%.md$") and remote:match("github") then
    link = link .. "?plain=1"
  end

  if startline == endline then
    link = link .. "#L" .. startline
  else
    if remote:match("github") then
      link = link .. "#L" .. startline .. "-L" .. endline
    elseif remote:match("gitlab") then
      link = link .. "#L" .. startline .. "-" .. endline
    end
  end

  return link:gsub("[%s\n\t]", "")
end

function M.get_commit_link()
  local ref = cmd_run(string.format(GIT_FILE_COMMIT_CMD, vim.fn.shellescape(vim.fn.expand("%"))))
  return execute_with_ref(ref, vim.fn.line("v"), vim.fn.line("."))
end

function M.get_branch_link()
  local ref = cmd_run(GIT_BRANCH_CMD)
  return execute_with_ref(ref, vim.fn.line("v"), vim.fn.line("."))
end

function M.get_head_link()
  local ref = cmd_run(GIT_HEAD_CMD)
  return execute_with_ref(ref, vim.fn.line("v"), vim.fn.line("."))
end

function M.copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  vim.api.nvim_out_write("Copied " .. text .. "\n")
end

function M.yank_commit_permanent_link()
  local link = M.get_commit_link()
  M.copy_to_clipboard(link)
end
return M
