/******************************************************************************
 * Copyright (c) 2011, Duane Merrill.  All rights reserved.
 * Copyright (c) 2011-2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the NVIDIA CORPORATION nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ******************************************************************************/

/**
 * \file
 * Error and event logging routines.
 *
 * The following macros definitions are supported:
 * - \p CUB_LOG.  Simple event messages are printed to \p stdout.
 */

#pragma once

#include <cub/util_namespace.cuh>
#include <cub/util_arch.cuh>

#include <nv/target>

#include <cstdio>

CUB_NAMESPACE_BEGIN

/**
 * \addtogroup UtilMgmt
 * @{
 */


/// CUB error reporting macro (prints error messages to stderr)
#if (defined(DEBUG) || defined(_DEBUG)) && !defined(CUB_STDERR)
    #define CUB_STDERR
#endif

/**
 * \brief %If \p CUB_STDERR is defined and \p error is not \p cudaSuccess, the
 * corresponding error message is printed to \p stderr (or \p stdout in device
 * code) along with the supplied source context.
 *
 * \return The CUDA error.
 */
__host__ __device__
__forceinline__
cudaError_t Debug(cudaError_t error, const char *filename, int line)
{
  // Clear the global CUDA error state which may have been set by the last
  // call. Otherwise, errors may "leak" to unrelated kernel launches.
  cudaGetLastError();

#ifdef CUB_STDERR
  if (error)
  {
    NV_IF_TARGET(
      NV_IS_HOST, (
        fprintf(stderr,
                "CUDA error %d [%s, %d]: %s\n",
                error,
                filename,
                line,
                cudaGetErrorString(error));
        fflush(stderr);
      ),
      (
        printf("CUDA error %d [block (%d,%d,%d) thread (%d,%d,%d), %s, %d]\n",
               error,
               blockIdx.z,
               blockIdx.y,
               blockIdx.x,
               threadIdx.z,
               threadIdx.y,
               threadIdx.x,
               filename,
               line);
      )
    );
  }
#else
  (void)filename;
  (void)line;
#endif

  return error;
}

/**
 * \brief Debug macro
 */
#ifndef CubDebug
    #define CubDebug(e) CUB_NS_QUALIFIER::Debug((cudaError_t) (e), __FILE__, __LINE__)
#endif


/**
 * \brief Debug macro with exit
 */
#ifndef CubDebugExit
    #define CubDebugExit(e) if (CUB_NS_QUALIFIER::Debug((cudaError_t) (e), __FILE__, __LINE__)) { exit(1); }
#endif


/**
 * \brief Log macro for printf statements.
 */
#if !defined(_CubLog)
#if defined(_NVHPC_CUDA) || !(defined(__clang__) && defined(__CUDA__))

// NVCC / NVC++
#define _CubLog(format, ...)                                                   \
  do                                                                           \
  {                                                                            \
    NV_IF_TARGET(NV_IS_HOST,                                                   \
                 (printf(format, __VA_ARGS__);),                               \
                 (printf("[block (%d,%d,%d), thread (%d,%d,%d)]: " format,     \
                         blockIdx.z,                                           \
                         blockIdx.y,                                           \
                         blockIdx.x,                                           \
                         threadIdx.z,                                          \
                         threadIdx.y,                                          \
                         threadIdx.x,                                          \
                         __VA_ARGS__);));                                      \
  } while (false)

#else // Clang:

// XXX shameless hack for clang around variadic printf...
//     Compilies w/o supplying -std=c++11 but shows warning,
//     so we silence them :)
#pragma clang diagnostic ignored "-Wc++11-extensions"
#pragma clang diagnostic ignored "-Wunnamed-type-template-args"
template <class... Args>
inline __host__ __device__ void va_printf(char const *format,
                                          Args const &...args)
{
#ifdef __CUDA_ARCH__
  printf(format,
         blockIdx.z,
         blockIdx.y,
         blockIdx.x,
         threadIdx.z,
         threadIdx.y,
         threadIdx.x,
         args...);
#else
  printf(format, args...);
#endif
}
#ifndef __CUDA_ARCH__
#define _CubLog(format, ...) CUB_NS_QUALIFIER::va_printf(format, __VA_ARGS__);
#else
#define _CubLog(format, ...)                                                   \
  CUB_NS_QUALIFIER::va_printf("[block (%d,%d,%d), thread "                     \
                              "(%d,%d,%d)]: " format,                          \
                              __VA_ARGS__);
#endif
#endif
#endif

/** @} */       // end group UtilMgmt

CUB_NAMESPACE_END
