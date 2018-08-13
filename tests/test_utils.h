#pragma once

#include <gtest/gtest.h>

#include "ctranslate2/storage_view.h"

using namespace ctranslate2;

template <typename T>
void expect_array_eq(const T* x, const T* y, size_t n, T abs_diff = 0) {
  for (size_t i = 0; i < n; ++i) {
    if (abs_diff == 0) {
      EXPECT_EQ(x[i], y[i]) << "Value mismatch at index " << i;
    } else {
      EXPECT_NEAR(x[i], y[i], abs_diff) << "Absolute difference greater than "
                                        << abs_diff << " at index " << i;
    }
  }
}

template<>
inline void expect_array_eq(const float* x, const float* y, size_t n, float abs_diff) {
  for (size_t i = 0; i < n; ++i) {
    if (abs_diff == 0) {
      EXPECT_FLOAT_EQ(x[i], y[i]) << "Value mismatch at index " << i;
    } else {
      EXPECT_NEAR(x[i], y[i], abs_diff) << "Absolute difference greater than "
                                        << abs_diff << " at index " << i;
    }
  }
}

template <typename T>
void assert_vector_eq(const std::vector<T>& got, const std::vector<T>& expected) {
  ASSERT_EQ(got.size(), expected.size());
  for (size_t i = 0; i < got.size(); ++i) {
    ASSERT_EQ(got[i], expected[i]) << "Value mismatch for dimension " << i;
  }
}

inline void expect_storage_eq(const StorageView& got,
                              const StorageView& expected,
                              float abs_diff = 0) {
  StorageView got_cpu = got.to(Device::CPU);
  StorageView expected_cpu = expected.to(Device::CPU);
  ASSERT_EQ(got.dtype(), expected.dtype());
  assert_vector_eq(got.shape(), expected.shape());
  TYPE_DISPATCH(got.dtype(), expect_array_eq(got_cpu.data<T>(), expected_cpu.data<T>(), got.size(), static_cast<T>(abs_diff)));
}