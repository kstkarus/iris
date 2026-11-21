#include "window_placement_store.h"

#include <cassert>
#include <fstream>
#include <iostream>
#include <limits>

namespace {

using namespace window_placement;

void TestRoundTrip() {
  const auto temp_directory = std::filesystem::temp_directory_path();
  wchar_t unique_path[MAX_PATH];
  assert(GetTempFileNameW(temp_directory.c_str(), L"irt", 0, unique_path) != 0);
  assert(DeleteFileW(unique_path));
  const std::filesystem::path directory(unique_path);
  const auto file = directory / L"iris" / L"window_state.ini";

  const auto missing = Load(file);
  assert(!missing.main && !missing.pip);

  const MainWindowPlacement main{{-1790, 20, -590, 720}, true};
  assert(Save(file, {main, std::nullopt}));
  const auto main_only = Load(file);
  assert(main_only.main && !main_only.pip);
  assert(main_only.main->maximized);
  assert(EqualRect(&main_only.main->normal_bounds, &main.normal_bounds));

  const PictureInPicturePlacement pip{-800, 400, 460};
  assert(Save(file, {main, pip}));
  const auto both = Load(file);
  assert(both.main && both.main->maximized && both.pip);
  assert(both.pip->left == -800 && both.pip->top == 400 && both.pip->width == 460);
  assert(std::distance(std::filesystem::directory_iterator(file.parent_path()),
                       std::filesystem::directory_iterator{}) == 1);

  for (const char* corrupt : {"not an ini file", "normal_left=99999999999999",
                              "pip_width=400px", "pip_width=400\npip_width=300",
                              "normal_left=1\nnormal_top=2\nmaximized=1"}) {
    std::ofstream(file) << corrupt;
    const auto rejected = Load(file);
    assert(!rejected.main && !rejected.pip);
  }

  std::ofstream(file, std::ios::binary)
      << "normal_left=10\r\nnormal_top=20\r\nnormal_right=810\r\n"
         "normal_bottom=620\r\nmaximized=0\r\npip_left=0\r\n"
         "pip_top=0\r\npip_width=-1\r\n";
  const auto recovered = Load(file);
  assert(recovered.main && !recovered.main->maximized && !recovered.pip);

  std::filesystem::remove(file);
  std::filesystem::remove(file.parent_path());
  std::filesystem::remove(directory);
}

void TestWindowBounds() {
  const RECT work{20, 40, 1300, 740};
  const RECT disconnected{-2700, 75, -1700, 660};
  const RECT recovered = ClampWindowBounds(disconnected, work, {360, 300});
  const RECT expected{20, 75, 1020, 660};
  assert(EqualRect(&recovered, &expected));

  const RECT undersized{1250, 690, 1270, 705};
  const RECT minimum = ClampWindowBounds(undersized, work, {540, 450});
  const RECT expected_minimum{760, 290, 1300, 740};
  assert(EqualRect(&minimum, &expected_minimum));

  const RECT oversized{std::numeric_limits<LONG>::min(), -100,
                       std::numeric_limits<LONG>::max(), 1000};
  const RECT maximum = ClampWindowBounds(oversized, work, {360, 300});
  assert(EqualRect(&maximum, &work));

  const RECT tiny_monitor{0, 0, 200, 100};
  const RECT tiny = ClampWindowBounds(undersized, tiny_monitor, {360, 300});
  assert(EqualRect(&tiny, &tiny_monitor));
}

void TestMaximizedPlacement() {
  MONITORINFO monitor{sizeof(MONITORINFO), {-1440, 0, 0, 900},
                     {-1400, 45, 0, 900}, 0};
  WINDOWPLACEMENT window{sizeof(WINDOWPLACEMENT)};
  window.rcNormalPosition = {-1380, 80, -620, 680};
  window.showCmd = SW_SHOWMAXIMIZED;
  const auto placement = MainFromWindowPlacement(window, monitor);
  const RECT expected{-1340, 125, -580, 725};
  assert(placement.maximized);
  assert(EqualRect(&placement.normal_bounds, &expected));
  const RECT clamped = ClampWindowBounds(placement.normal_bounds, monitor.rcWork,
                                         {360, 300});
  assert(EqualRect(&clamped, &expected));

  window.showCmd = SW_SHOWMINIMIZED;
  window.flags = WPF_RESTORETOMAXIMIZED;
  assert(MainFromWindowPlacement(window, monitor).maximized);
  window.flags = 0;
  assert(!MainFromWindowPlacement(window, monitor).maximized);
}

void TestPictureInPictureBounds() {
  const RECT work{-1024, 40, 0, 740};
  const PictureInPicturePlacement corner{-450, 400, 400};
  const RECT wide = RestorePictureInPictureBounds(corner, work, 16.0 / 9.0, 240);
  const RECT expected_wide{-450, 400, -50, 625};
  assert(EqualRect(&wide, &expected_wide));

  const RECT portrait = RestorePictureInPictureBounds(corner, work, 0.5, 240);
  const RECT expected_portrait{-450, 40, -100, 740};
  assert(EqualRect(&portrait, &expected_portrait));

  const RECT moved = RestorePictureInPictureBounds(
      {10, 1400, 50}, work, 4.0 / 3.0, 240);
  const RECT expected_moved{-240, 560, 0, 740};
  assert(EqualRect(&moved, &expected_moved));
}

}  // namespace

int main() {
  TestRoundTrip();
  TestWindowBounds();
  TestMaximizedPlacement();
  TestPictureInPictureBounds();
  std::cout << "Window placement native checks passed.\n";
}
