local M = {}

local function http_post(url, headers, body)
  local header_args = {}
  for k, v in pairs(headers) do
    table.insert(header_args, '-H')
    table.insert(header_args, string.format('%s: %s', k, v))
  end

  local command = vim.tbl_flatten({
    'curl', '-s', '-X', 'POST', url,
    header_args,
    '-d', body
  })

  return vim.fn.system(command)
end

local json = {
  decode = vim.json.decode,
  encode = vim.json.encode
}

function M.parse_conversation()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local messages = {}
    local current_message = {role = "user", content = {}}
    local in_code = true
    local code_lines = {}

    for _, line in ipairs(lines) do
        if in_code then
            if line:match("^@%?") then
                in_code = false
                local code_content = table.concat(code_lines, "\n")
                current_message.content = {"```\n" .. code_content .. "\n```"}
            else
                table.insert(code_lines, line)
            end
        elseif line:match("^@%?") then
            if #current_message.content > 0 then
                table.insert(messages, {role = current_message.role, content = table.concat(current_message.content, "\n")})
            end
            current_message = {role = "user", content = {}}
        elseif line:match("^%?@") then
            if #current_message.content > 0 then
                table.insert(messages, {role = current_message.role, content = table.concat(current_message.content, "\n")})
            end
            current_message = {role = "assistant", content = {}}
        else
            table.insert(current_message.content, line)
        end
    end

    if #current_message.content > 0 then
        table.insert(messages, {role = current_message.role, content = table.concat(current_message.content, "\n")})
    end

    return messages
end

function M.get_completion(messages)
  local api_key = vim.fn.readfile(vim.fn.expand('~/.config/anthropic.token'))[1]
  
  local system_prompt_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/system.txt"
  local system_prompt = nil
  if vim.fn.filereadable(system_prompt_path) == 1 then
    system_prompt = table.concat(vim.fn.readfile(system_prompt_path), "\n")
  end

  local data = {
    model = "claude-3-5-sonnet-20240620",
    max_tokens = 1024,
    messages = messages
  }

  if system_prompt then
    data.system = system_prompt
  end

  local response = http_post(
    'https://api.anthropic.com/v1/messages',
    {
      ["x-api-key"] = api_key,
      ["anthropic-version"] = "2023-06-01",
      ["content-type"] = "application/json"
    },
    json.encode(data)
  )

  local decoded_response = json.decode(response)
  
  if not decoded_response or not decoded_response.content then
    error("Unexpected API response format: " .. vim.inspect(decoded_response))
  end

  if type(decoded_response.content) ~= "table" or #decoded_response.content == 0 then
    error("API response does not contain expected content: " .. vim.inspect(decoded_response))
  end

  return decoded_response.content[1].text
end

function M.setup()
    vim.api.nvim_create_user_command('PromptStart', function()
        local current_buf = vim.api.nvim_get_current_buf()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)
        local initial_code = vim.api.nvim_buf_get_lines(current_buf, 0, cursor_pos[1], false)
        
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(buf, 'swapfile', false)
        vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
        
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_code)
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, {"@?", ""})
        
        vim.api.nvim_command('vsplit')
        vim.api.nvim_win_set_buf(0, buf)
        
        local last_line = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(0, {last_line, 0})
        
        vim.api.nvim_buf_create_user_command(buf, 'Prompt', function()
            local messages = M.parse_conversation()
            local completion = M.get_completion(messages)

            local lines = vim.split(completion, "\n")
            table.insert(lines, 1, "?@")
            table.insert(lines, "@?")
            table.insert(lines, "")
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
            
            local new_last_line = vim.api.nvim_buf_line_count(buf)
            vim.api.nvim_win_set_cursor(0, {new_last_line, 0})
        end, {})
    end, {})

    vim.keymap.set('n', '<leader>ps', ':PromptStart<CR>', {noremap = true, silent = true})
    vim.keymap.set('n', '<leader>p', ':Prompt<CR>', {noremap = true, silent = true})
end

return M
