local specs = require("tests.utils.specs")

describe("C++ templates", function()
    it("extract class names from class templates", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            struct a {
                int foo();
            };
            ]], "cpp")

        assert.matches("brief", result, 1, true)
        assert.matches("@class a", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.is_nil(result:find("@return", 1, true))
    end)

    it("preserve returns for function templates", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            T identity(T value) {
                return value;
            }
            ]], "cpp")

        assert.matches("brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.matches("@param value", result, 1, true)
        assert.matches("@return", result, 1, true)
    end)

    it("extract multiple template parameters", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T, typename U, int N>
            struct container {
                T values[N];
            };
            ]], "cpp")

        assert.matches("@class container", result, 1, true)
        assert.matches("@brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.matches("@tparam U", result, 1, true)
        assert.matches("@tparam N", result, 1, true)
        assert.is_nil(result:find("@return", 1, true))
    end)

    it("extract non-type template parameters", function()
        local result = specs.make_docstring([[
            template <int X, int Y>
            struct |cursor|foo {};
            ]], "cpp")

        assert.matches("@class foo", result, 1, true)
        assert.matches("@brief", result, 1, true)
        assert.matches("@tparam X", result, 1, true)
        assert.matches("@tparam Y", result, 1, true)
    end)

    it("extract template template parameters", function()
        local result = specs.make_docstring([[
            template <template <typename> typename |cursor|Container>
            struct a {};
            ]], "cpp")
        assert.matches("@class a", result, 1, true)
        assert.matches("@brief", result, 1, true)
        assert.matches("@tparam Container", result, 1, true)
    end)

    it("ignore default template argument names", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T = SomeType, int N = someValue>
            struct foo {};
            ]], "cpp")

        assert.matches("@class foo", result, 1, true)
        assert.matches("@brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.matches("@tparam N", result, 1, true)
        assert.is_nil(result:find("@tparam SomeType", 1, true))
        assert.is_nil(result:find("@tparam someValue", 1, true))
    end)

    it("ignore unnamed template parameter defaults", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T, typename = SomeType>
            struct foo {};
            ]], "cpp")

        assert.matches("@class foo", result, 1, true)
        assert.matches("@brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.is_nil(result:find("@tparam SomeType", 1, true))
    end)

    it("accept variadic template arguments", function()
        local result = specs.make_docstring([[
            template <typename |cursor|... Args>
            int foo(Args&& ...args);
            ]], "cpp")

        assert.matches("brief", result, 1, true)
        assert.matches("@tparam Args", result, 1, true)
        assert.matches("@param args", result, 1, true)
        assert.matches("@return", result, 1, true)
    end)

    it("handle function templates returning pointers", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            T* create();
            ]], "cpp")

        assert.matches("brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.matches("@return", result, 1, true)
    end)

    it("handle template variables", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            T foo = 0;
            ]], "cpp")

        assert.matches("brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.is_nil(result:find("@return", 1, true))
    end)

    it("handle template aliases", function()
        local result = specs.make_docstring([[
            template <typename T>
            struct X;

            template <typename T>
            using|cursor| Y = X<T>;
            ]], "cpp")

        assert.matches("brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.is_nil(result:find("@return", 1, true))
    end)

    it("handle concepts", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            concept Y = sizeof(T) > 0;
        ]], "cpp")

        assert.matches("@brief", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.is_nil(result:find("@return", 1, true))
    end)

    
    it("handle forward-declared class templates", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            class Foo;
        ]], "cpp")

        assert.matches("@class Foo", result, 1, true)
        assert.matches("@tparam T", result, 1, true)
        assert.matches("%*/%s*template%s*<", result)
    end)

    
    it("do not generate returns for void function templates", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            void consume(T value);
        ]], "cpp")

        assert.matches("@tparam T", result, 1, true)
        assert.matches("@param value", result, 1, true)
        assert.is_nil(result:find("@return", 1, true))
        assert.is_nil(result:find("@class", 1, true))
    end)

    it("handle function template declarations", function()
        local result = specs.make_docstring([[
            template <typename |cursor|T>
            T identity(T value);
        ]], "cpp")

        assert.matches("@tparam T", result, 1, true)
        assert.matches("@param value", result, 1, true)
        assert.matches("@return", result, 1, true)
    end)

    
    it("handle nested template-template parameters", function()
        local result = specs.make_docstring([[
            template <template <typename X> typename |cursor|Container>
            struct Foo {};
        ]], "cpp")

        assert.matches("@class Foo", result, 1, true)
        assert.matches("@tparam X", result, 1, true)
        assert.matches("@tparam Container", result, 1, true)
    end)

    
    it("do not mistake member functions for the class template", function()
        local result = specs.make_docstring([[
            template <typename T>
            struct Foo {
                int |cursor|bar();
            };
        ]], "cpp")

        assert.matches("@return", result, 1, true)
        assert.is_nil(result:find("@class Foo", 1, true))
        assert.is_nil(result:find("@tparam T", 1, true))
    end)

    
    it("handle ordinary structs without templates", function()
        local result = specs.make_docstring([[
            struct |cursor|Foo {};
        ]], "cpp")

        assert.matches("@class Foo", result, 1, true)
        assert.is_nil(result:find("@tparam", 1, true))
    end)

    it("handle function templates returning qualified reference types", function()
        local result = specs.make_docstring([[
            template <class |cursor|CharT, class Traits>
            std::basic_ostream<CharT, Traits>& operator<<(
                std::basic_ostream<CharT, Traits>& os,
                CharT str
            );
        ]], "cpp")

        assert.matches("@tparam CharT", result, 1, true)
        assert.matches("@tparam Traits", result, 1, true)
        assert.matches("@param os", result, 1, true)
        assert.matches("@param str", result, 1, true)
        assert.matches("@return", result, 1, true)
    end)
end)
