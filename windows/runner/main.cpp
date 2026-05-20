#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

//constexpr int kWindowWidth = 300;
//constexpr int kWindowHeight = 400;
constexpr int kWindowWidth = 1152;
constexpr int kWindowHeight = 300;

void CenterWindow(HWND window) {
  RECT window_rect;
  if (!::GetWindowRect(window, &window_rect)) {
    return;
  }

  HMONITOR monitor = ::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!::GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const int window_width = window_rect.right - window_rect.left;
  const int window_height = window_rect.bottom - window_rect.top;
  const int work_area_width = monitor_info.rcWork.right - monitor_info.rcWork.left;
  const int work_area_height = monitor_info.rcWork.bottom - monitor_info.rcWork.top;
  const int centered_left =
      monitor_info.rcWork.left + (work_area_width - window_width) / 2;
  const int centered_top =
      monitor_info.rcWork.top + (work_area_height - window_height) / 2;

  ::SetWindowPos(window, nullptr, centered_left, centered_top, 0, 0,
                 SWP_NOZORDER | SWP_NOSIZE | SWP_NOACTIVATE);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(kWindowWidth, kWindowHeight);
  if (!window.Create(L"anikin", origin, size)) {
    return EXIT_FAILURE;
  }
  CenterWindow(window.GetHandle());
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
