#include "window_state.h"

#include <flutter_windows.h>

#include <cmath>
#include <limits>

namespace window_state {
namespace {

constexpr wchar_t kWindowStateRegistryKey[] = L"Software\\com.oneb\\anikin";
constexpr wchar_t kWindowWidthRegistryValue[] = L"WindowWidth";
constexpr wchar_t kWindowHeightRegistryValue[] = L"WindowHeight";

std::optional<DWORD> ReadDword(const wchar_t* name) {
  DWORD value = 0;
  DWORD value_size = sizeof(value);
  const LSTATUS result =
      RegGetValueW(HKEY_CURRENT_USER, kWindowStateRegistryKey, name,
                   RRF_RT_REG_DWORD, nullptr, &value, &value_size);
  if (result != ERROR_SUCCESS) {
    return std::nullopt;
  }
  return value;
}

}  // namespace

std::optional<Size> LoadSize() {
  const std::optional<DWORD> width = ReadDword(kWindowWidthRegistryValue);
  const std::optional<DWORD> height = ReadDword(kWindowHeightRegistryValue);
  if (!width || !height || *width == 0 || *height == 0 ||
      *width > static_cast<DWORD>(std::numeric_limits<int>::max()) ||
      *height > static_cast<DWORD>(std::numeric_limits<int>::max())) {
    return std::nullopt;
  }

  return Size{static_cast<int>(*width), static_cast<int>(*height)};
}

void SaveSize(HWND window, const WINDOWPLACEMENT* placement) {
  if (window == nullptr) {
    return;
  }

  WINDOWPLACEMENT current_placement = {sizeof(WINDOWPLACEMENT)};
  if (placement == nullptr) {
    if (!GetWindowPlacement(window, &current_placement)) {
      return;
    }
    placement = &current_placement;
  }

  const RECT& bounds = placement->rcNormalPosition;
  const int physical_width = bounds.right - bounds.left;
  const int physical_height = bounds.bottom - bounds.top;
  if (physical_width <= 0 || physical_height <= 0) {
    return;
  }

  const HMONITOR monitor =
      MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  const double scale_factor = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
  const DWORD logical_width =
      static_cast<DWORD>(std::lround(physical_width / scale_factor));
  const DWORD logical_height =
      static_cast<DWORD>(std::lround(physical_height / scale_factor));

  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kWindowStateRegistryKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  RegSetValueExW(key, kWindowWidthRegistryValue, 0, REG_DWORD,
                 reinterpret_cast<const BYTE*>(&logical_width),
                 sizeof(logical_width));
  RegSetValueExW(key, kWindowHeightRegistryValue, 0, REG_DWORD,
                 reinterpret_cast<const BYTE*>(&logical_height),
                 sizeof(logical_height));
  RegCloseKey(key);
}

}  // namespace window_state
