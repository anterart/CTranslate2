#include "ctranslate2/ops/layer_norm.h"

#include "ctranslate2/cuda/utils.h"

namespace ctranslate2 {
  namespace ops {

    template <Device D, typename T>
    void LayerNorm::compute(const StorageView& beta,
                            const StorageView& gamma,
                            const StorageView& input,
                            StorageView& output) const {
      static thread_local StorageView bias_cudnn(input.device());
      static thread_local StorageView scale_cudnn(input.device());

      size_t depth = input.dim(-1);
      size_t batch_size = input.size() / depth;
      T one = 1;
      T zero = 0;

      if (batch_size > scale_cudnn.size()) {
        scale_cudnn.resize({batch_size}).fill(one);
        bias_cudnn.resize({batch_size}).fill(zero);
      }

      cudnnTensorDescriptor_t input_desc;
      cudnnTensorDescriptor_t scale_bias_desc;
      cudnnBatchNormMode_t bn_mode = CUDNN_BATCHNORM_SPATIAL;
      CUDNN_CHECK(cudnnCreateTensorDescriptor(&input_desc));
      CUDNN_CHECK(cudnnCreateTensorDescriptor(&scale_bias_desc));
      CUDNN_CHECK(cudnnSetTensor4dDescriptor(input_desc,
                                             CUDNN_TENSOR_NCHW,
                                             CUDNN_DATA_FLOAT,
                                             1 /* n */,
                                             batch_size,
                                             depth,
                                             1 /* w */));
      CUDNN_CHECK(cudnnDeriveBNTensorDescriptor(scale_bias_desc, input_desc, bn_mode));

      CUDNN_CHECK(cudnnBatchNormalizationForwardTraining(cuda::get_cudnn_handle(),
                                                         bn_mode,
                                                         &one,
                                                         &zero,
                                                         input_desc,
                                                         input.data<T>(),
                                                         input_desc,
                                                         output.data<T>(),
                                                         scale_bias_desc,
                                                         scale_cudnn.data<T>(),
                                                         bias_cudnn.data<T>(),
                                                         0 /* exponentialAverageFactor */,
                                                         nullptr,
                                                         nullptr,
                                                         CUDNN_BN_MIN_EPSILON,
                                                         nullptr,
                                                         nullptr));

      CUDNN_CHECK(cudnnDestroyTensorDescriptor(input_desc));
      CUDNN_CHECK(cudnnDestroyTensorDescriptor(scale_bias_desc));

      primitives<D>::mul_batch_broadcast(gamma.data<T>(), output.data<T>(), depth, output.size());
      primitives<D>::add_batch_broadcast(beta.data<T>(), output.data<T>(), depth, output.size());
    }

#define DECLARE_IMPL(T)                                                 \
    template void                                                       \
    LayerNorm::compute<Device::CUDA, T>(const StorageView& beta,        \
                                        const StorageView& gamma,       \
                                        const StorageView& input,       \
                                        StorageView& output) const;

    DECLARE_IMPL(float)

  }
}