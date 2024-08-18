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

    for _, line in ipairs(lines) do
        if line:match("^@%?") then
            if #current_message.content > 0 then
                table.insert(messages, {role = current_message.role, content = table.concat(current_message.content, "\n")})
            end
            current_message = {role = "assistant", content = {}}
        elseif line:match("^%?@") then
            if #current_message.content > 0 then
                table.insert(messages, {role = current_message.role, content = table.concat(current_message.content, "\n")})
            end
            current_message = {role = "user", content = {}}
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
    local token_path = vim.fn.expand('~/.config/anthropic.token')
  
    if vim.fn.filereadable(token_path) ~= 1 then
        error("Anthropic API token not found. Please create a file at " .. token_path .. " containing your API key.")
    end

    local api_key = vim.fn.readfile(token_path)[1]

    local system_prompt_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/system.txt"
    local system_prompt = nil
    if vim.fn.filereadable(system_prompt_path) == 1 then
        system_prompt = table.concat(vim.fn.readfile(system_prompt_path), "\n")
    end

    local data = {
        model = "claude-3-5-sonnet-20240620",
        max_tokens = 4096,
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
  
    if decoded_response.error then
        error("API error: " .. decoded_response.error.message)
    end

    if not decoded_response or not decoded_response.content then
        error("Unexpected API response format: " .. vim.inspect(decoded_response))
    end

    if type(decoded_response.content) ~= "table" or #decoded_response.content == 0 then
        error("API response does not contain expected content: " .. vim.inspect(decoded_response))
    end

    return decoded_response.content[1].text
end

function M.prompt()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local lines = vim.api.nvim_buf_get_lines(0, 0, cursor_pos[1], false)
    local last_line = lines[#lines]
    lines[#lines] = last_line:sub(1, cursor_pos[2])

    local content = table.concat(lines, "\n"):gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
    
    -- if content is empty, use a default message
    if content == "" then
        content = "Hello, I'd like to start a conversation."
    end
    
    local messages = {{role = "user", content = content}}

    -- insert delimiter
    vim.api.nvim_buf_set_lines(0, cursor_pos[1], cursor_pos[1], false, {"@?"})
    vim.api.nvim_win_set_cursor(0, {cursor_pos[1] + 1, 0})

    -- call API
    local completion = M.get_completion(messages)

    local response_lines = vim.split(completion, "\n")
    table.insert(response_lines, "?@")
    table.insert(response_lines, "")

    vim.api.nvim_buf_set_lines(0, cursor_pos[1] + 1, cursor_pos[1] + 1, false, response_lines)
    local new_cursor_pos = cursor_pos[1] + #response_lines + 1
    vim.api.nvim_win_set_cursor(0, {new_cursor_pos, 0})
end

function M.setup()
    vim.keymap.set('n', '<leader>p', M.prompt, {noremap = true, silent = true})
end

return M
