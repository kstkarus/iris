// Assertions execute the checks even when this test is built with NDEBUG.
#ifdef NDEBUG
#undef NDEBUG
#endif

#include "app_update_utils.h"

#include <cassert>
#include <string>
#include <thread>

int wmain() {
  const std::wstring root =
      LR"(C:\Users\iris\AppData\Roaming\com.kstkarus\iris\app_updates)";
  assert(app_update::IsOwnedInstallerFileName(
      L"iris-1.2.3-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.exe"));
  assert(!app_update::IsOwnedInstallerFileName(
      L"iris-1.2.3-0123456789ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef.exe"));
  assert(!app_update::IsOwnedInstallerFileName(L"iris-1.2.3-0123456789abcdef.exe"));
  assert(app_update::IsDirectChildPath(
      root, root + LR"(\iris-1.2.3-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.exe)"));
  assert(!app_update::IsDirectChildPath(
      root, root + LR"(\..\other\iris-1.2.3-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef.exe)"));

  const std::wstring suffix = std::to_wstring(GetCurrentProcessId());
  const std::wstring installing_name = L"Local\\iris.update-test.installing." + suffix;
  const std::wstring running_name = L"Local\\iris.update-test.running." + suffix;
  HANDLE running = nullptr;
  assert(app_update::BeginAppStartup(&running, installing_name.c_str(),
                                     running_name.c_str()));
  assert(running != nullptr);
  CloseHandle(running);

  HANDLE ready = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  HANDLE release = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  assert(ready != nullptr && release != nullptr);
  std::thread installer([&]() {
    HANDLE installing =
        CreateMutexW(nullptr, FALSE, installing_name.c_str());
    assert(installing != nullptr);
    assert(WaitForSingleObject(installing, 5000) == WAIT_OBJECT_0);
    SetEvent(ready);
    assert(WaitForSingleObject(release, 5000) == WAIT_OBJECT_0);
    ReleaseMutex(installing);
    CloseHandle(installing);
  });
  assert(WaitForSingleObject(ready, 5000) == WAIT_OBJECT_0);
  running = nullptr;
  assert(!app_update::BeginAppStartup(&running, installing_name.c_str(),
                                     running_name.c_str()));
  assert(running == nullptr);
  SetEvent(release);
  installer.join();
  CloseHandle(release);
  CloseHandle(ready);
}
