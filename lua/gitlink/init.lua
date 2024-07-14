local M = {}

local GIT_ORIGIN_CMD = "git ls-remote --get-url origin"
local GIT_BRANCH_CMD = "git rev-parse --abbrev-ref HEAD"
local GIT_HEAD_CMD = "git rev-parse HEAD"
local GIT_FILE_COMMIT_CMD = "git rev-list -1 HEAD -- %s"
local GIT_ROOT_CMD = "git rev-parse --show-toplevel"
local URL_ENCODE_CMD = "curl -s --data-urlencode %s"

local DEFAULT_OPTIONS = {
  reference_format = {
    default_formatter = "default",
    formatters = {
      default = function(args)
        return string.format("[%s](%s)\n```%s\n%s\n```", args.filepath, args.link, args.filetype, args.selected_text)
      end,
    },
  },
}

M.config = DEFAULT_OPTIONS

local function cmd_run(cmd)
  return vim.fn.system(cmd):gsub("\n", "")
end

local function url_encode(str)
  local result = ""

  for i = 1, #str do
    local char = str:sub(i, i)
    local byte = string.byte(char)

    if
      (byte >= 65 and byte <= 90) -- A-Z
      or (byte >= 97 and byte <= 122) -- a-z
      or (byte >= 48 and byte <= 57) -- 0-9
      or byte == 45 -- - (hyphen)
      or byte == 46 -- . (dot)
      or byte == 95 -- _ (underscore)
      or byte == 126
    then -- ~ (tilde)
      result = result .. char
    else
      result = result .. string.format("%%%02X", byte)
    end
  end
  return result
end

local function find_least_indented_line(lines)
  local min_indent = math.huge

  for _, line in ipairs(lines) do
    local leading_spaces = line:match("^%s*")
    if leading_spaces then
      local indent_level = #leading_spaces
      if indent_level < min_indent then
        min_indent = indent_level
      end
    end
  end

  return min_indent
end

local function deindent(lines)
  local min_indent = find_least_indented_line(lines)
  local deindented_lines = {}

  for _, line in ipairs(lines) do
    table.insert(deindented_lines, line:sub(min_indent + 1))
  end

  return deindented_lines
end
local function url_encode_path_segments(path)
  local segments = vim.split(path, "/")
  local encoded_segments = vim.tbl_map(function(segment)
    return url_encode(segment)
  end, segments)
  return table.concat(encoded_segments, "/")
end

local function get_git_link(ref, startline, endline)
  local remote = cmd_run(GIT_ORIGIN_CMD)
  if not (remote:match("github") or remote:match("gitlab")) then
    vim.api.nvim_err_writeln("Unknown remote host")
    return
  end

  local repo
  if remote:match("^git") then
    repo = remote:gsub(":", "/"):gsub("^git@", "https://"):gsub("%.git$", "")
  elseif remote:match("^ssh") then
    repo = remote:gsub("/", "/"):gsub("^ssh://git@", "https://"):gsub("%.git$", "")
  elseif remote:match("^https") then
    repo = remote:gsub("%.git$", "")
  else
    vim.api.nvim_err_writeln("Remote doesn't match any known protocol")
    return
  end

  local root = cmd_run(GIT_ROOT_CMD)
  local filepath = string.sub(vim.fn.expand("%:p"), #root + 2)
  filepath = url_encode_path_segments(filepath)

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

function M.get_commit_link(lines)
  local ref = cmd_run(string.format(GIT_FILE_COMMIT_CMD, vim.fn.shellescape(vim.fn.expand("%"))))
  return get_git_link(ref, lines[1], lines[2])
end

function M.get_branch_link()
  local ref = cmd_run(GIT_BRANCH_CMD)
  return get_git_link(ref, vim.fn.line("v"), vim.fn.line("."))
end

function M.get_head_link()
  local ref = cmd_run(GIT_HEAD_CMD)
  return get_git_link(ref, vim.fn.line("v"), vim.fn.line("."))
end

function M.copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  vim.api.nvim_out_write("Copied " .. text .. "\n")
end

function M.yank_commit_permanent_link(lines)
  local link = M.get_commit_link(lines)
  M.copy_to_clipboard(link)
end

function M.yank_markdown_reference(lines)
  local link = M.get_commit_link(lines)

  local start_line = lines[1]
  local end_line = lines[2]
  local selected_text = vim.fn.getline(start_line, end_line)

  -- Ensure selected_text is a table for table.concat
  if type(selected_text) == "string" then
    selected_text = { selected_text }
  end

  local joined_text = table.concat(deindent(selected_text), "\n")

  local file_type = vim.bo.filetype
  local file_path = vim.fn.expand("%")

  local formatters = M.config.reference_format.formatters
  local default_formatter = M.config.reference_format.default_formatter

  if formatters[default_formatter] == nil then
    error("Formatter " .. default_formatter .. " not found")
  end

  local result = M.config.reference_format.formatters[default_formatter]({
    filepath = file_path,
    link = link,
    filetype = file_type,
    selected_text = joined_text,
  })

  -- local markdown = string.format("[%s](%s)\n```%s\n%s\n```", file_path, link, file_type, joined_text)

  M.copy_to_clipboard(result)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", DEFAULT_OPTIONS, opts or {})
end

return M
