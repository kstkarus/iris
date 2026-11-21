#include "window_placement_store.h"

#include <shlobj.h>

#include <algorithm>
#include <array>
#include <charconv>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <locale>
#include <sstream>
#include <string_view>

namespace window_placement {
namespace {

constexpr std::array<std::string_view, 8> kKeys{
    "normal_left", "normal_top", "normal_right", "normal_bottom", "maximized",
    "pip_left", "pip_top", "pip_width"};

RECT PlaceInWorkArea(LONG left, LONG top, SIZE size, const RECT& work_area) {
  left = std::clamp(left, work_area.left, work_area.right - size.cx);
  top = std::clamp(top, work_area.top, work_area.bottom - size.cy);
  return {left, top, left + size.cx, top + size.cy};
}

LONG FitDimension(LONG start, LONG end, LONG minimum, LONG available) {
  return static_cast<LONG>(std::clamp<int64_t>(
      static_cast<int64_t>(end) - start, std::min(minimum, available),
      available));
}

}  // namespace

std::filesystem::path StatePath() {
  PWSTR roaming_app_data = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, KF_FLAG_DEFAULT,
                                 nullptr, &roaming_app_data)) ||
      roaming_app_data == nullptr) {
    return {};
  }
  const std::filesystem::path directory(roaming_app_data);
  CoTaskMemFree(roaming_app_data);
  return directory / L"com.kstkarus" / L"iris" / L"window_state.ini";
}

WindowState Load(const std::filesystem::path& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) return {};
  char bytes[512];
  file.read(bytes, sizeof(bytes));
  if (!file.eof() || file.bad()) return {};
  std::istringstream lines(std::string(bytes, file.gcount()));
  std::array<std::optional<LONG>, kKeys.size()> values{};
  for (std::string line; std::getline(lines, line);) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    const auto delimiter = line.find('=');
    if (delimiter == std::string::npos) return {};
    const auto key = std::string_view(line).substr(0, delimiter);
    const auto field = std::find(kKeys.begin(), kKeys.end(), key);
    if (field == kKeys.end()) return {};
    auto& value = values[field - kKeys.begin()];
    if (value) return {};
    LONG number = 0;
    const char* end = line.data() + line.size();
    const auto parsed = std::from_chars(line.data() + delimiter + 1, end, number);
    if (parsed.ec != std::errc{} || parsed.ptr != end) return {};
    value = number;
  }

  const auto& [left, top, right, bottom, maximized, pip_left, pip_top,
               pip_width] = values;
  WindowState state;
  if (left && top && right && bottom && maximized && *left < *right &&
      *top < *bottom && (*maximized == 0 || *maximized == 1)) {
    state.main = MainWindowPlacement{{*left, *top, *right, *bottom},
                                     *maximized == 1};
  }
  if (pip_left && pip_top && pip_width && *pip_width > 0) {
    state.pip = PictureInPicturePlacement{*pip_left, *pip_top, *pip_width};
  }
  return state;
}

bool Save(const std::filesystem::path& path, const WindowState& state) {
  if (path.empty()) return false;
  const auto directory = path.parent_path();
  std::error_code error;
  std::filesystem::create_directories(directory, error);
  if (error) return false;
  wchar_t temp_path[MAX_PATH];
  if (GetTempFileNameW(directory.c_str(), L"irp", 0, temp_path) == 0) return false;

  std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
  file.imbue(std::locale::classic());
  if (state.main) {
    const auto& bounds = state.main->normal_bounds;
    file << "normal_left=" << bounds.left << '\n'
         << "normal_top=" << bounds.top << '\n'
         << "normal_right=" << bounds.right << '\n'
         << "normal_bottom=" << bounds.bottom << '\n'
         << "maximized=" << static_cast<int>(state.main->maximized) << '\n';
  }
  if (state.pip) {
    file << "pip_left=" << state.pip->left << '\n'
         << "pip_top=" << state.pip->top << '\n'
         << "pip_width=" << state.pip->width << '\n';
  }
  file.close();
  if (file && MoveFileExW(temp_path, path.c_str(),
                          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    return true;
  }
  DeleteFileW(temp_path);
  return false;
}

MainWindowPlacement MainFromWindowPlacement(const WINDOWPLACEMENT& placement,
                                            const MONITORINFO& monitor) {
  RECT bounds = placement.rcNormalPosition;
  // GetWindowPlacement reports workspace coordinates for our overlapped window.
  OffsetRect(&bounds, monitor.rcWork.left - monitor.rcMonitor.left,
             monitor.rcWork.top - monitor.rcMonitor.top);
  const bool maximized = placement.showCmd == SW_SHOWMAXIMIZED ||
                         (placement.showCmd == SW_SHOWMINIMIZED &&
                          (placement.flags & WPF_RESTORETOMAXIMIZED) != 0);
  return {bounds, maximized};
}

RECT ClampWindowBounds(const RECT& bounds, const RECT& work_area, SIZE minimum) {
  const SIZE size{
      FitDimension(bounds.left, bounds.right, minimum.cx,
                   work_area.right - work_area.left),
      FitDimension(bounds.top, bounds.bottom, minimum.cy,
                   work_area.bottom - work_area.top)};
  return PlaceInWorkArea(bounds.left, bounds.top, size, work_area);
}

PictureInPictureSize FitPictureInPictureClientSize(int desired_width,
                                                   double aspect,
                                                   int maximum_width,
                                                   int maximum_height) {
  int width = std::min({desired_width, maximum_width,
                        static_cast<int>(std::floor(maximum_height * aspect))});
  width = std::max(1, width);
  int height = std::max(1, static_cast<int>(std::lround(width / aspect)));
  if (height > maximum_height) {
    height = maximum_height;
    width = std::max(1, static_cast<int>(std::floor(height * aspect)));
  }
  return {width, height};
}

RECT RestorePictureInPictureBounds(const PictureInPicturePlacement& saved,
                                   const RECT& work_area,
                                   double aspect,
                                   int minimum_width) {
  const auto size = FitPictureInPictureClientSize(
      std::max(static_cast<int>(saved.width), minimum_width), aspect,
      work_area.right - work_area.left, work_area.bottom - work_area.top);
  return PlaceInWorkArea(saved.left, saved.top, {size.width, size.height},
                         work_area);
}

}  // namespace window_placement
