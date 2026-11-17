local cpp = vim.deepcopy(require("neogen.configurations.c"))
local nodes = require("neogen.utilities.nodes")
local default_locator = require("neogen.locators.default")
local i = require("neogen.types.template").item

-- Reuse C's function extractor
local c_function_extractor = cpp.data.func["function_declaration|function_definition|declaration|field_declaration"]["0"].extract

-- Get the first direct child matching any of the given node types.
local function child(node, types)
    return node and nodes:matching_child_nodes(node, types)[1]
end

-- Find the class or struct declared by a template, possibly wrapped in a declaration.
local function template_class(node)
    return child(node, "class_specifier|struct_specifier") or child(child(node, "declaration"), "class_specifier|struct_specifier")
end

-- Find the template_declaration directly enclosing a class or function.
local function enclosing_template(node)
    local parent = node:parent()
    if parent and parent:type() == "declaration" then
        parent = parent:parent()
    end

    return parent and parent:type() == "template_declaration" and parent or nil
end

-- Extract template parameter names, including nested template-template parameters.
local function template_params(params)
    local result = {}
    if not params then
        return result
    end

    for param in params:iter_children() do
        -- Process nested template parameters first to preserve source order.
        if param:type() == "template_template_parameter_declaration" then
            vim.list_extend(result, template_params(param:field("parameters")[1]))
            param = child(param, "type_parameter_declaration|optional_type_parameter_declaration|variadic_type_parameter_declaration") or param
        end

        -- Prefer named fields to avoid extracting types or default arguments.
        local name = param:field("name")[1]
        local declarator = param:field("declarator")[1]

        -- Non-type template parameters store their name in the declarator.
        if not name and declarator then
            name = declarator:type() == "identifier" and declarator or nodes:recursive_find(declarator, "identifier", { first = true })[1]
        end

        -- Non-defaulted type parameters (without = foo) lack an explicit "name" field.
        if not name and (param:type() == "type_parameter_declaration" or param:type() == "variadic_type_parameter_declaration") then
            name = child(param, "type_identifier")
        end

        if name then
            table.insert(result, vim.treesitter.get_node_text(name, 0))
        end
    end

    return result
end

-- Extract template parameters and delegate function-specific annotations to C.
local function template_extractor(node)
    local result = { [i.Tparam] = template_params(node:field("parameters")[1]) }

    -- Only delegate function templates to the C extractor.
    local decl = child(node, "declaration|function_definition")
    if not decl or template_class(node) then
        return result
    end

    -- Function declarators may be nested inside pointer/reference declarators.
    local declarator = decl:field("declarator")[1]
    if decl:type() == "function_definition" or (declarator and ( declarator:type() == "function_declarator"
            or #nodes:recursive_find(declarator, "function_declarator", { first = true }) > 0)) then
        local extracted = c_function_extractor(decl)
        local return_type = decl:field("type")[1]

        if not extracted[i.Return] and return_type
            and vim.treesitter.get_node_text(return_type, 0) ~= "void" then
            extracted[i.Return] = { true }
        end

        return vim.tbl_extend("force", extracted, result)
    end

    return result
end

-- Register template declarations for function-template extraction.
table.insert(cpp.parent.func, "template_declaration")
cpp.data.func["template_declaration"] = {
    ["0"] = { extract = template_extractor },
}

-- Register class and struct extraction, including template parameters when present.
cpp.parent.class = { "class_specifier", "struct_specifier" }
cpp.data.class = {
    ["class_specifier|struct_specifier"] = {
        ["0"] = {
            extract = function(node)
                local result = {}
                local name = node:field("name")[1]

                if name then
                    result[i.ClassName] = { vim.treesitter.get_node_text(name, 0) }
                end

                local template = enclosing_template(node)
                if template then
                    result[i.Tparam] = template_params(template:field("parameters")[1])
                end

                return result
            end,
        },
    },
}

-- Select the underlying class node for class templates so Neogen uses
-- the "class" annotation category, while keeping function templates as "func".
cpp.locator = function(info, types)
    local found = default_locator({ root = info.root, current = info.current }, types)

    -- Search upward from the cursor for an enclosing template declaration.
    local template = info.current
    while template and template:type() ~= "template_declaration" do
        template = template:parent()
    end

    if not template then
        return found
    end

    
    -- A cursor in template parameters must resolve to the class/struct node.
    local class = template_class(template)
    if class and (not found or found == template) then
        return vim.tbl_contains(types, class:type()) and class or nil
    end

    -- Promote wrapped function declarations to their enclosing template.
    if not class and found and enclosing_template(found)
        and vim.tbl_contains(types, "template_declaration") then
        return template
    end

    return found
end

-- Insert class-template documentation before "template", not before "class"/"struct".
cpp.template.position = function(node, type)
    local template = type == "class" and enclosing_template(node)
    if template then
        return template:start()
    end
end

return cpp
