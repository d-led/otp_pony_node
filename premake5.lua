function exec(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end

function find_ei()
    -- installed via Homebrew
    if os.target() == "macosx" then
        -- return "/usr/local/Cellar/erlang/21.2.4/lib/erlang/lib/erl_interface-3.10.4/"
        return exec("ls -td -- /usr/local/Cellar/erlang/21.2.4/lib/erlang/lib/erl_interface-*/ | head -n 1")
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

-------------------
workspace "otp_pony_node"
    configurations { "Debug", "Release" }

    -- build files location
    location("build" .. "/" .. os.target() .. "/" .. (_ACTION or ''))

    -- output file locations
    objdir ("obj/%{cfg.system}/%{prj.name}")
    targetdir (".")

    filter "configurations:Debug"
        architecture "x86_64"
        symbols "On"

    filter "configurations:Release"
        architecture "x86_64"
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
