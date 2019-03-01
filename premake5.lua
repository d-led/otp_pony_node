-------------------
workspace "otp_pony_node"
    configurations { "Debug", "Release" }

    -- build files location
    location("build" .. "/" .. os.target() .. "/" .. _ACTION)

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

    filter "system:macosx"
        -- todo detect/configure
        ei_dir = "/usr/local/Cellar/erlang/21.2.4/lib/erlang/lib/erl_interface-3.10.4/"
        includedirs {
            ei_dir .. "/include",
        }
        libdirs {
            ei_dir .. "/lib",
        }
        targetextension ".so"
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
