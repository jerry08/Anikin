#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <string>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

namespace {

//constexpr int kWindowWidth = 300;
//constexpr int kWindowHeight = 400;
constexpr int kWindowWidth = 1152;
constexpr int kWindowHeight = 700;

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

bool SendAppLinkToInstance(const std::wstring& title) {
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", title.c_str());
  if (hwnd == nullptr) {
    return false;
  }

  SendAppLink(hwnd);

  WINDOWPLACEMENT placement = {sizeof(WINDOWPLACEMENT)};
  GetWindowPlacement(hwnd, &placement);
  if (placement.showCmd == SW_SHOWMINIMIZED) {
    ShowWindow(hwnd, SW_RESTORE);
  } else {
    ShowWindow(hwnd, SW_NORMAL);
  }
  SetForegroundWindow(hwnd);
  return true;
}

void RegisterProtocol(const wchar_t* scheme) {
  wchar_t executable[MAX_PATH];
  if (GetModuleFileNameW(nullptr, executable, MAX_PATH) == 0) {
    return;
  }

  std::wstring key = L"Software\\Classes\\";
  key += scheme;
  std::wstring description = L"URL:";
  description += scheme;
  std::wstring command = L"\"";
  command += executable;
  command += L"\" \"%1\"";

  RegSetKeyValueW(HKEY_CURRENT_USER, key.c_str(), nullptr, REG_SZ,
                  description.c_str(),
                  static_cast<DWORD>((description.size() + 1) * sizeof(wchar_t)));
  RegSetKeyValueW(HKEY_CURRENT_USER, key.c_str(), L"URL Protocol", REG_SZ,
                  L"", sizeof(wchar_t));

  key += L"\\shell\\open\\command";
  RegSetKeyValueW(HKEY_CURRENT_USER, key.c_str(), nullptr, REG_SZ,
                  command.c_str(),
                  static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (SendAppLinkToInstance(L"anikin")) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  RegisterProtocol(L"anistream");
  RegisterProtocol(L"anikin");
  RegisterProtocol(L"tachiyomi");
  RegisterProtocol(L"anizen");

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
