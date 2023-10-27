local M = {}

M.toggle = function()
	local filename = vim.fn.expand("%:t:r")
	local extension = vim.fn.expand("%:e")
	if extension == "cpp" then
		vim.cmd("find " .. filename .. ".h")
	elseif extension == "h" then
		vim.cmd("find " .. filename .. ".cpp")
	end
end

return M
