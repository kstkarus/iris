#ifndef RUNNER_APP_UPDATE_CHANNEL_H_
#define RUNNER_APP_UPDATE_CHANNEL_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <functional>
#include <memory>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateAppUpdateChannel(flutter::BinaryMessenger* messenger,
                      std::function<void()> request_exit);

#endif  // RUNNER_APP_UPDATE_CHANNEL_H_
