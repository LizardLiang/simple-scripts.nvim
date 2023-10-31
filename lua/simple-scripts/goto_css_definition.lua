local function read_tsconfig()
	local f = io.open("tsconfig.json", "r")
	if f then
		local content = f:read("*all")
		f:close()
		return vim.fn.json_decode(content)
	else
		return nil, "Could not read tsconfig.json"
	end
end

local function find_import_of_object(object_name)
	local filetype = vim.bo.filetype
	if filetype == "typescriptreact" then
		filetype = "typescript"
	end
	local parser = vim.treesitter.get_parser(0, filetype)
	local tree = parser:parse()[1]
	local root = tree:root()

	local import_path = nil

	root:descendant_for_range(0, 0, root:end_position()):iter_children(function(node)
		local node_type = node:type()

		if node_type == "import_declaration" then
			for child in node:iter_children() do
				if child:type() == "import_specifier" then
					local content = vim.treesitter.get_node_text(child, 0)
					if content == object_name then
						for import_child in node:iter_children() do
							if import_child:type() == "string" then
								import_path = vim.treesitter.get_node_text(import_child, 0):gsub('"', "")
								return false -- Stop the iteration
							end
						end
					end
				end
			end
		end
	end)

	local tsconfig = read_tsconfig()
	if tsconfig and tsconfig.compilerOptions and tsconfig.compilerOptions.paths then
		local alias = tsconfig.compilerOptions.paths[object_name]
		if alias and alias[1] then
			import_path = alias[1]:gsub("/*$", "") -- Remove trailing "/*" if present
		end
	end

	return import_path
end

local find_class_definition = function()
	local parser = vim.treesitter.get_parser(0, vim.bo.filetype)
	local tree = parser:parse()[1]
	local root = tree:root()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1

	local object_name, class_name

	local node = root:descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col + 1)
	if node then
		local content = vim.treesitter.get_node_text(node, 0)
		object_name, class_name = content:match("([%w_]+)%s*%.%s*([%w_]+)")
	end

	if object_name and class_name then
		local import_path = find_import_of_object(object_name)

		if import_path then
			-- Open the CSS file and search for the class definition
			vim.cmd("edit " .. import_path)
			vim.cmd("normal! /\\." .. class_name .. "\\C\\<CR>")
		else
			print("Import not found")
		end
	else
		print("Could not identify object and class name")
	end
end

return find_class_definition
