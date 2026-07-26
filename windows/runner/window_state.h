#ifndef RUNNER_WINDOW_STATE_H_
#define RUNNER_WINDOW_STATE_H_

#include <windows.h>

#include <optional>

namespace window_state {

struct Size {
  int width;
  int height;
};

// Loads the last non-fullscreen window size, expressed in logical pixels.
std::optional<Size> LoadSize();

// Saves the normal (restored) size of |window| in logical pixels. When
// |placement| is supplied, its normal bounds are used instead of querying the
// current window. This keeps fullscreen bounds from replacing the saved size.
void SaveSize(HWND window, const WINDOWPLACEMENT* placement = nullptr);

}  // namespace window_state

#endif  // RUNNER_WINDOW_STATE_H_
