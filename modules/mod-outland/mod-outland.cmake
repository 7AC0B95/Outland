# Extra configuration for mod-outland executed after target 'modules' exists

# Locate this module's root directory (not the src subdir)
# GetPathToModuleSource returns the "src" folder, which is not what we want here.
# Use the modules base path and append the module name to get the module root.
GetModulesBasePath(MOD_OUTLAND_MODULES_BASE)
set(MOD_OUTLAND_MODULE_ROOT "${MOD_OUTLAND_MODULES_BASE}/${SOURCE_MODULE}")

set(MOD_OUTLAND_LUA_DIR "${MOD_OUTLAND_MODULE_ROOT}/data/lua_scripts")

if(EXISTS "${MOD_OUTLAND_LUA_DIR}")
  file(GLOB MOD_OUTLAND_LUA_SCRIPTS "${MOD_OUTLAND_LUA_DIR}/*.lua")

  if(MOD_OUTLAND_LUA_SCRIPTS)
    if(WIN32)
      if(MSVC)
        set(MSVC_CONFIGURATION_NAME $(ConfigurationName)/)
      endif()

      # Ensure destination directory exists (MSVC uses config subfolder)
      add_custom_command(TARGET modules POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/bin/${MSVC_CONFIGURATION_NAME}lua_scripts/")

      foreach(MOD_OUTLAND_LUA_SCRIPT ${MOD_OUTLAND_LUA_SCRIPTS})
        get_filename_component(MOD_OUTLAND_LUA_SCRIPT_NAME "${MOD_OUTLAND_LUA_SCRIPT}" NAME)
        add_custom_command(TARGET modules POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy_if_different "${MOD_OUTLAND_LUA_SCRIPT}"
                  "${CMAKE_BINARY_DIR}/bin/${MSVC_CONFIGURATION_NAME}lua_scripts/${MOD_OUTLAND_LUA_SCRIPT_NAME}")
      endforeach()
    else()
      # Non-Windows layout
      add_custom_command(TARGET modules POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/bin/lua_scripts/")

      foreach(MOD_OUTLAND_LUA_SCRIPT ${MOD_OUTLAND_LUA_SCRIPTS})
        get_filename_component(MOD_OUTLAND_LUA_SCRIPT_NAME "${MOD_OUTLAND_LUA_SCRIPT}" NAME)
        add_custom_command(TARGET modules POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy_if_different "${MOD_OUTLAND_LUA_SCRIPT}"
                  "${CMAKE_BINARY_DIR}/bin/lua_scripts/${MOD_OUTLAND_LUA_SCRIPT_NAME}")
      endforeach()
    endif()

    # Install lua scripts alongside binaries
    install(DIRECTORY "${MOD_OUTLAND_LUA_DIR}/" DESTINATION "${CMAKE_INSTALL_PREFIX}/bin/lua_scripts/")
  endif()
endif()


