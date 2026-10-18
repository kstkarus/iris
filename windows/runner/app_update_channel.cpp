#include "app_update_channel.h"

#include <windows.h>

#include <shellapi.h>
#include <shlobj.h>
#include <flutter/standard_method_codec.h>

#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "app_update_utils.h"

namespace {
constexpr wchar_t kInstallRegistryKey[] =
    L"Software\\com.kstkarus\\iris\\Installer";
constexpr wchar_t kInstallRegistryValue[] = L"InstallLocation";

std::optional<std::wstring> Utf8ToWide(const std::string& value) {
  if (value.find('\0') != std::string::npos || value.empty()) {
    return std::nullopt;
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         value.data(),
                                         static_cast<int>(value.size()), nullptr,
                                         0);
  if (length <= 0) return std::nullopt;
  std::wstring result(length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), result.data(),
                          length) != length) {
    return std::nullopt;
  }
  return result;
}

std::optional<std::string> WideToUtf8(const std::wstring& value) {
  if (value.empty()) return std::nullopt;
  const int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                         value.data(),
                                         static_cast<int>(value.size()), nullptr,
                                         0, nullptr, nullptr);
  if (length <= 0) return std::nullopt;
  std::string result(length, '\0');
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), result.data(), length,
                          nullptr, nullptr) != length) {
    return std::nullopt;
  }
  return result;
}

std::optional<std::wstring> ReadInstallLocation() {
  DWORD byte_count = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, kInstallRegistryKey,
                   kInstallRegistryValue, RRF_RT_REG_SZ, nullptr, nullptr,
                   &byte_count) != ERROR_SUCCESS ||
      byte_count < sizeof(wchar_t) || byte_count > 32768 * sizeof(wchar_t)) {
    return std::nullopt;
  }

  std::vector<wchar_t> value(byte_count / sizeof(wchar_t) + 1, L'\0');
  if (RegGetValueW(HKEY_CURRENT_USER, kInstallRegistryKey,
                   kInstallRegistryValue, RRF_RT_REG_SZ, nullptr, value.data(),
                   &byte_count) != ERROR_SUCCESS ||
      value.front() == L'\0') {
    return std::nullopt;
  }
  return std::wstring(value.data());
}

std::optional<std::wstring> CurrentExecutableDirectory() {
  std::vector<wchar_t> path(32768, L'\0');
  const DWORD length =
      GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size() - 1) return std::nullopt;
  const std::filesystem::path executable(std::wstring(path.data(), length));
  if (!app_update::SamePath(executable.filename().native(), L"iris.exe")) {
    return std::nullopt;
  }
  return executable.parent_path().lexically_normal().native();
}

std::optional<std::wstring> InstallationDirectory() {
  const auto registered_location = ReadInstallLocation();
  const auto executable_directory = CurrentExecutableDirectory();
  if (!registered_location || !executable_directory) return std::nullopt;
  const std::filesystem::path registered(*registered_location);
  if (!registered.is_absolute() ||
      !app_update::SamePath(registered.lexically_normal().native(),
                            *executable_directory)) {
    return std::nullopt;
  }
  return registered.lexically_normal().native();
}

std::optional<std::wstring> UpdateDirectory() {
  PWSTR roaming_app_data = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, KF_FLAG_DEFAULT,
                                 nullptr, &roaming_app_data)) ||
      roaming_app_data == nullptr) {
    return std::nullopt;
  }
  const std::filesystem::path support_directory(roaming_app_data);
  CoTaskMemFree(roaming_app_data);
  // Matches path_provider_windows and Runner.rc CompanyName/ProductName.
  return (support_directory / L"com.kstkarus" / L"iris" / L"app_updates")
      .lexically_normal()
      .native();
}

std::optional<std::wstring> ValidatedInstallerPath(
    const std::wstring& path) {
  if (path.empty() || path.find(L'\0') != std::wstring::npos) {
    return std::nullopt;
  }
  const std::filesystem::path candidate(path);
  const auto update_directory = UpdateDirectory();
  if (!candidate.is_absolute() || !update_directory ||
      !app_update::IsDirectChildPath(*update_directory, path) ||
      !app_update::IsOwnedInstallerFileName(candidate.filename().native())) {
    return std::nullopt;
  }

  const DWORD directory_attributes = GetFileAttributesW(update_directory->c_str());
  if (directory_attributes == INVALID_FILE_ATTRIBUTES ||
      (directory_attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 ||
      (directory_attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    return std::nullopt;
  }
  const std::wstring normalized_path = app_update::NormalizePath(path);
  const DWORD file_attributes = GetFileAttributesW(normalized_path.c_str());
  if (file_attributes == INVALID_FILE_ATTRIBUTES ||
      (file_attributes & (FILE_ATTRIBUTE_DIRECTORY |
                          FILE_ATTRIBUTE_REPARSE_POINT)) != 0) {
    return std::nullopt;
  }
  return normalized_path;
}

const flutter::EncodableValue* MapValue(
    const flutter::EncodableMap* map, const char* key) {
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(key));
  return found == map->end() ? nullptr : &found->second;
}

void LaunchInstaller(const std::wstring& installer_path,
                     const std::wstring& install_directory,
                     flutter::MethodResult<flutter::EncodableValue>* result) {
  const std::wstring arguments =
      L"/SILENT /NORESTART /NOCLOSEAPPLICATIONS /NORESTARTAPPLICATIONS "
      L"/UPDATEPID=" +
      std::to_wstring(GetCurrentProcessId()) + L" /DIR=\"" +
      install_directory + L"\"";
  SHELLEXECUTEINFOW info{sizeof(SHELLEXECUTEINFOW)};
  info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI;
  info.lpVerb = L"open";
  info.lpFile = installer_path.c_str();
  info.lpParameters = arguments.c_str();
  info.nShow = SW_SHOWNORMAL;
  if (!ShellExecuteExW(&info) || info.hProcess == nullptr) {
    if (info.hProcess != nullptr) CloseHandle(info.hProcess);
    result->Error("installer_start_failed", "Windows could not start the installer.");
    return;
  }
  CloseHandle(info.hProcess);
  result->Success(flutter::EncodableValue(true));
}
}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateAppUpdateChannel(flutter::BinaryMessenger* messenger,
                      std::function<void()> request_exit) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "iris/app_update",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [request_exit = std::move(request_exit)](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "installationDirectory") {
          const auto directory = InstallationDirectory();
          const auto encoded = directory ? WideToUtf8(*directory) : std::nullopt;
          result->Success(encoded ? flutter::EncodableValue(*encoded)
                                  : flutter::EncodableValue());
        } else if (call.method_name() == "install") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          const auto* path_value = MapValue(arguments, "path");
          const auto* encoded_path =
              path_value == nullptr
                  ? nullptr
                  : std::get_if<std::string>(path_value);
          const auto installer_path =
              encoded_path == nullptr ? std::nullopt : Utf8ToWide(*encoded_path);
          const auto install_directory = InstallationDirectory();
          if (!installer_path || !install_directory) {
            result->Error("invalid_file", "The Iris update installer is invalid.");
            return;
          }
          const auto validated_path = ValidatedInstallerPath(*installer_path);
          if (!validated_path) {
            result->Error("invalid_file", "The Iris update installer is invalid.");
            return;
          }
          LaunchInstaller(*validated_path, *install_directory, result.get());
        } else if (call.method_name() == "exit") {
          result->Success();
          request_exit();
        } else {
          result->NotImplemented();
        }
      });
  return channel;
}
