function exec(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end

-- This function assumes, the latest Erlang has been the last to have been installed.
--  If this is not so, make sure, the desired one has the latest modified date.
--  If a custom ei location is supplied (--ei=<path>), it is returned
function find_ei()
    if _OPTIONS["ei"] then
        return _OPTIONS["ei"]
    end

    -- installed via Homebrew
    if os.target() == "macosx" then
        -- return "/usr/local/Cellar/erlang/21.2.4/lib/erlang/lib/erl_interface-3.10.4/"
        local ei_path = exec("ls -td -- /opt/homebrew/Cellar/erlang/*/lib/erlang/lib/erl_interface-*/ | head -n 1")
        if ei_path ~= nil and ei_path ~= "" then
            return ei_path
        end
        return exec("ls -td -- /usr/local/Cellar/erlang/*/lib/erlang/lib/erl_interface-*/ | head -n 1")
    end

    -- installed via official instructions
    if os.target() == "linux" then
        -- return "/usr/lib/erlang/lib/erl_interface-3.10.4/"
        return exec("ls -td -- /usr/lib/erlang/lib/erl_interface-*/ | head -n 1")
    end

    -- installed via official instructions / chocolatey
    if os.target() == "windows" then
        -- return "C:\Program Files\erl10.1\lib\erl_interface-3.10.4\"
        return exec("src\\find_latest_erl_interface\\find_latest_erl_interface")
    end
end

newoption {
   trigger     = "ei",
   description = "Supply a custom path to the erl_interface directory (must include include, lib)"
}

-------------------
workspace "otp_pony_node"
    configurations { "Debug", "Release" }

    -- build files location
    location("build" .. "/" .. os.target() .. "/" .. (_ACTION or ''))

    -- output file locations
    objdir ("obj/%{cfg.system}/%{prj.name}")
    targetdir (".")

    filter "configurations:Debug"
        symbols "On"

    filter "configurations:Release"
        symbols "On"
        optimize "On"

    filter "action:gmake"
        linkoptions  { "-std=c++11" }
        buildoptions { "-std=c++11" } --, "-stdlib=libc++"
    
    filter {}

    ei_dir = find_ei():gsub("^%s*(.-)%s*$", "%1")

    print("ei_dir: "..ei_dir)

    filter "system:macosx or system:linux"
        -- todo detect/configure
        includedirs {
            ei_dir .. "/include",
        }
        libdirs {
            ei_dir .. "/lib",
        }
        defines {
            "_REENTRANT"
        }
        targetextension ".so"

    filter "system:windows"
        -- todo detect/configure
        includedirs {
            ei_dir .. "\\include",
        }
        libdirs {
            ei_dir .. "\\lib",
        }
        links {
            "ws2_32.lib"
        }
        buildoptions {
            "/NODEFAULTLIB",
            "/MT",
        }
        linkoptions {
            "/WHOLEARCHIVE"
        }
        defines {
            "__WIN32__"
        }
    filter {}

    -------------
    project "otp_pony_node_c"
        kind "SharedLib"
        language "C++"
        defines {
            "BUILDING_OPN_API"
        }

        files {
            "src/otp_pony_node_c/*.cpp",
            "src/otp_pony_node_c/*.h",
        }

        links "ei"
