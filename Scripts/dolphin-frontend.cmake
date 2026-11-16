get_filename_component(EMUDEN_GC_BRIDGE "${CMAKE_CURRENT_LIST_DIR}/../Bridge" ABSOLUTE)
get_filename_component(EMUDEN_GC_PROBE "${CMAKE_CURRENT_LIST_DIR}/../Tests/GameCubeProbe" ABSOLUTE)
function(emuden_add_gamecube_frontend)
  string(TOLOWER "${CMAKE_OSX_SYSROOT}" EMUDEN_GC_SYSROOT)
  if(EMUDEN_GC_SYSROOT MATCHES "iphonesimulator")
    set(EMUDEN_GC_PLATFORM "iPhoneSimulator")
  else()
    set(EMUDEN_GC_PLATFORM "iPhoneOS")
  endif()
  configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/GameCubeFramework-Info.plist.in"
    "${CMAKE_CURRENT_BINARY_DIR}/EmuDenGameCube-Info.plist" @ONLY)
  find_package(Python3 REQUIRED COMPONENTS Interpreter)
  set(EMUDEN_AUDIO_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/EmuDenAudioCommon.cpp")
  execute_process(COMMAND "${Python3_EXECUTABLE}" "${EMUDEN_GC_BRIDGE}/../Scripts/prepare-dolphin-audio.py"
    --source "${CMAKE_SOURCE_DIR}/Source/Core/AudioCommon/AudioCommon.cpp" --output "${EMUDEN_AUDIO_SOURCE}"
    COMMAND_ERROR_IS_FATAL ANY)
  add_library(EmuDenGameCube SHARED "${EMUDEN_GC_BRIDGE}/GameCubeCore.cpp" "${EMUDEN_GC_BRIDGE}/GameCubeHost.cpp" "${EMUDEN_AUDIO_SOURCE}")
  target_compile_features(EmuDenGameCube PRIVATE cxx_std_23)
  target_link_libraries(EmuDenGameCube PRIVATE core uicommon)
  set_target_properties(EmuDenGameCube PROPERTIES
    FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER com.brandonaleman.EmuDen.GameCubeCore
    MACOSX_FRAMEWORK_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/EmuDenGameCube-Info.plist"
    PUBLIC_HEADER "${EMUDEN_GC_BRIDGE}/GameCubeCore.h"
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_NAME_DIR "@rpath")
  if(IOS)
    find_library(EMUDEN_UIKIT UIKit REQUIRED)
    find_library(EMUDEN_METAL Metal REQUIRED)
    find_library(EMUDEN_QUARTZCORE QuartzCore REQUIRED)
    find_library(EMUDEN_COREGRAPHICS CoreGraphics REQUIRED)
    find_library(EMUDEN_GAMECONTROLLER GameController REQUIRED)
    add_executable(EmuDenGameCubeProbe MACOSX_BUNDLE "${EMUDEN_GC_PROBE}/Main.mm")
    target_include_directories(EmuDenGameCubeProbe PRIVATE "${EMUDEN_GC_BRIDGE}")
    target_compile_features(EmuDenGameCubeProbe PRIVATE cxx_std_23)
    target_compile_options(EmuDenGameCubeProbe PRIVATE -fobjc-arc)
    target_link_libraries(EmuDenGameCubeProbe PRIVATE EmuDenGameCube ${FOUNDATION_LIBRARY} ${EMUDEN_UIKIT} ${EMUDEN_METAL} ${EMUDEN_QUARTZCORE} ${EMUDEN_COREGRAPHICS} ${EMUDEN_GAMECONTROLLER} objc)
    set_target_properties(EmuDenGameCubeProbe PROPERTIES
      MACOSX_BUNDLE_INFO_PLIST "${EMUDEN_GC_PROBE}/Info.plist"
      BUILD_WITH_INSTALL_RPATH TRUE
      INSTALL_RPATH "@executable_path/Frameworks")
    add_custom_command(TARGET EmuDenGameCubeProbe POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:EmuDenGameCubeProbe>/Frameworks"
      COMMAND ${CMAKE_COMMAND} -E copy_directory "$<TARGET_BUNDLE_DIR:EmuDenGameCube>" "$<TARGET_BUNDLE_DIR:EmuDenGameCubeProbe>/Frameworks/EmuDenGameCube.framework")
  endif()
endfunction()
cmake_language(DEFER CALL emuden_add_gamecube_frontend)
