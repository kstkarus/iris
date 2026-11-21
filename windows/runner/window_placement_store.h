#ifndef RUNNER_WINDOW_PLACEMENT_STORE_H_
#define RUNNER_WINDOW_PLACEMENT_STORE_H_

#include <windows.h>

#include <filesystem>
#include <optional>

namespace window_placement {

struct MainWindowPlacement {
  RECT normal_bounds;
  bool maximized;
};

struct PictureInPicturePlacement {
  LONG left;
  LONG top;
  LONG width;
};

struct WindowState {
  std::optional<MainWindowPlacement> main;
  std::optional<PictureInPicturePlacement> pip;
};

std::filesystem::path StatePath();
WindowState Load(const std::filesystem::path& path);
bool Save(const std::filesystem::path& path, const WindowState& state);

MainWindowPlacement MainFromWindowPlacement(const WINDOWPLACEMENT& placement,
                                            const MONITORINFO& monitor);
RECT ClampWindowBounds(const RECT& bounds, const RECT& work_area, SIZE minimum);

struct PictureInPictureSize {
  int width;
  int height;
};

PictureInPictureSize FitPictureInPictureClientSize(int desired_width,
                                                   double aspect,
                                                   int maximum_width,
                                                   int maximum_height);
PictureInPicturePlacement PictureInPictureFromWindowBounds(
    const RECT& bounds, const std::optional<PictureInPicturePlacement>& saved,
    bool resized);
RECT RestorePictureInPictureBounds(const PictureInPicturePlacement& saved,
                                   const RECT& work_area,
                                   double aspect,
                                   int minimum_width);

}  // namespace window_placement

#endif  // RUNNER_WINDOW_PLACEMENT_STORE_H_
