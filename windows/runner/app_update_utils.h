#ifndef RUNNER_APP_UPDATE_UTILS_H_
#define RUNNER_APP_UPDATE_UTILS_H_

#include <windows.h>

#include <filesystem>
#include <string>
#include <string_view>

namespace app_update {

constexpr wchar_t kRunningMutexName[] = L"Local\\com.kstkarus.iris.running";
constexpr wchar_t kInstallingMutexName[] =
    L"Local\\com.kstkarus.iris.installing";

inline std::wstring NormalizePath(std::wstring_view value) {
  std::wstring normalized =
      std::filesystem::path(std::wstring(value)).lexically_normal().native();
  while (normalized.size() > 3 &&
         (normalized.back() == L'\\' || normalized.back() == L'/')) {
    normalized.pop_back();
  }
  return normalized;
}

inline bool SamePath(std::wstring_view first, std::wstring_view second) {
  const std::wstring normalized_first = NormalizePath(first);
  const std::wstring normalized_second = NormalizePath(second);
  return !normalized_first.empty() && !normalized_second.empty() &&
         CompareStringOrdinal(
             normalized_first.data(), static_cast<int>(normalized_first.size()),
             normalized_second.data(),
             static_cast<int>(normalized_second.size()), TRUE) == CSTR_EQUAL;
}

inline bool IsDirectChildPath(std::wstring_view directory,
                              std::wstring_view candidate) {
  if (directory.find(L'\0') != std::wstring_view::npos ||
      candidate.find(L'\0') != std::wstring_view::npos) {
    return false;
  }
  const std::filesystem::path normalized_directory =
      std::filesystem::path(std::wstring(directory)).lexically_normal();
  const std::filesystem::path normalized_candidate =
      std::filesystem::path(std::wstring(candidate)).lexically_normal();
  return normalized_directory.is_absolute() &&
         normalized_candidate.is_absolute() &&
         SamePath(normalized_candidate.parent_path().native(),
                  normalized_directory.native());
}

inline bool IsOwnedInstallerFileName(std::wstring_view filename) {
  constexpr std::wstring_view prefix = L"iris-";
  constexpr std::wstring_view suffix = L".exe";
  if (filename.size() < prefix.size() + suffix.size() ||
      filename.substr(0, prefix.size()) != prefix ||
      filename.substr(filename.size() - suffix.size()) != suffix) {
    return false;
  }

  std::size_t cursor = prefix.size();
  for (int component = 0; component < 3; ++component) {
    const std::size_t first_digit = cursor;
    while (cursor < filename.size() && filename[cursor] >= L'0' &&
           filename[cursor] <= L'9') {
      ++cursor;
    }
    if (cursor == first_digit) return false;
    if (component < 2) {
      if (cursor >= filename.size() || filename[cursor] != L'.') {
        return false;
      }
      ++cursor;
    }
  }
  if (cursor >= filename.size() || filename[cursor++] != L'-' ||
      filename.size() - cursor != 64 + suffix.size()) {
    return false;
  }
  for (std::size_t i = cursor; i < cursor + 64; ++i) {
    const wchar_t character = filename[i];
    if (!((character >= L'0' && character <= L'9') ||
          (character >= L'a' && character <= L'f'))) {
      return false;
    }
  }
  return filename.substr(cursor + 64) == suffix;
}

inline bool BeginAppStartup(HANDLE* running_mutex,
                            const wchar_t* installing_name =
                                kInstallingMutexName,
                            const wchar_t* running_name = kRunningMutexName) {
  if (running_mutex == nullptr) return false;

  HANDLE installing_mutex = CreateMutexW(nullptr, FALSE, installing_name);
  if (installing_mutex == nullptr) return false;
  const DWORD wait_result = WaitForSingleObject(installing_mutex, 0);
  if (wait_result != WAIT_OBJECT_0 && wait_result != WAIT_ABANDONED) {
    CloseHandle(installing_mutex);
    return false;
  }

  *running_mutex = CreateMutexW(nullptr, FALSE, running_name);
  const bool released = ReleaseMutex(installing_mutex) != FALSE;
  CloseHandle(installing_mutex);
  if (!released || *running_mutex == nullptr) {
    if (*running_mutex != nullptr) {
      CloseHandle(*running_mutex);
      *running_mutex = nullptr;
    }
    return false;
  }
  return true;
}

}  // namespace app_update

#endif  // RUNNER_APP_UPDATE_UTILS_H_
