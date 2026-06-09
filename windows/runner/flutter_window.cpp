#include "flutter_window.h"

#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterWindowChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "anikin/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "toggleFullscreen") {
          SetFullscreen(!fullscreen_);
          result->Success();
          return;
        }

        if (call.method_name() == "setFullscreen") {
          const auto* arguments = call.arguments();
          if (arguments == nullptr || !std::holds_alternative<bool>(*arguments)) {
            result->Error("bad_args", "setFullscreen expects a boolean.");
            return;
          }
          SetFullscreen(std::get<bool>(*arguments));
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

void FlutterWindow::SetFullscreen(bool fullscreen) {
  if (fullscreen_ == fullscreen) {
    return;
  }

  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  if (fullscreen) {
    fullscreen_style_ = GetWindowLong(hwnd, GWL_STYLE);
    fullscreen_placement_.length = sizeof(WINDOWPLACEMENT);
    GetWindowPlacement(hwnd, &fullscreen_placement_);

    MONITORINFO monitor_info = {};
    monitor_info.cbSize = sizeof(monitor_info);
    if (!GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                        &monitor_info)) {
      return;
    }

    SetWindowLong(hwnd, GWL_STYLE, fullscreen_style_ & ~WS_OVERLAPPEDWINDOW);
    SetWindowPos(
        hwnd, HWND_TOP, monitor_info.rcMonitor.left, monitor_info.rcMonitor.top,
        monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
        monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
        SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    fullscreen_ = true;
    return;
  }

  SetWindowLong(hwnd, GWL_STYLE, fullscreen_style_);
  SetWindowPlacement(hwnd, &fullscreen_placement_);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                   SWP_FRAMECHANGED);
  fullscreen_ = false;
}
