"""Run one CUDA kernel through JetPack's driver, without nvcc or Python packages.

PTX is compiled in memory by the installed driver. The caller disables the JIT
disk cache and imposes a timeout. Run as the SSH user to test device permissions.
"""
import ctypes as ct
import json
import sys


PTX = b"""
.version 6.0
.target sm_53
.address_size 64
.visible .entry hpc_check(.param .u64 output)
{
    .reg .u64 %pointer;
    .reg .u32 %value;
    ld.param.u64 %pointer, [output];
    mov.u32 %value, 42;
    st.global.u32 [%pointer], %value;
    ret;
}
"""


def check_cuda(driver=None):
    driver = driver if driver is not None else ct.CDLL("libcuda.so.1")
    pointer = ct.c_void_p
    device_pointer = ct.c_uint64
    signatures = {
        "cuInit": [ct.c_uint],
        "cuDeviceGetCount": [ct.POINTER(ct.c_int)],
        "cuDeviceGet": [ct.POINTER(ct.c_int), ct.c_int],
        "cuDeviceGetName": [ct.c_char_p, ct.c_int, ct.c_int],
        "cuDriverGetVersion": [ct.POINTER(ct.c_int)],
        "cuCtxCreate_v2": [ct.POINTER(pointer), ct.c_uint, ct.c_int],
        "cuCtxDestroy_v2": [pointer],
        "cuModuleLoadData": [ct.POINTER(pointer), pointer],
        "cuModuleUnload": [pointer],
        "cuModuleGetFunction": [ct.POINTER(pointer), pointer, ct.c_char_p],
        "cuMemAlloc_v2": [ct.POINTER(device_pointer), ct.c_size_t],
        "cuMemFree_v2": [device_pointer],
        "cuMemsetD32_v2": [device_pointer, ct.c_uint, ct.c_size_t],
        "cuLaunchKernel": [pointer] + [ct.c_uint] * 7 + [
            pointer, ct.POINTER(pointer), ct.POINTER(pointer)],
        "cuCtxSynchronize": [],
        "cuMemcpyDtoH_v2": [pointer, device_pointer, ct.c_size_t],
    }
    for name, args in signatures.items():
        function = getattr(driver, name)
        function.argtypes = args
        function.restype = ct.c_int

    def call(name, *args):
        result = getattr(driver, name)(*args)
        if result != 0:
            raise RuntimeError(f"{name} failed with CUDA error {result}")

    context, module, function = pointer(), pointer(), pointer()
    memory = device_pointer()
    count, device, version = ct.c_int(), ct.c_int(), ct.c_int()
    device_name = ct.create_string_buffer(128)
    try:
        call("cuInit", 0)
        call("cuDeviceGetCount", ct.byref(count))
        if count.value != 1:
            raise RuntimeError(f"Expected one Orin GPU, found {count.value}")
        call("cuDeviceGet", ct.byref(device), 0)
        call("cuDeviceGetName", device_name, len(device_name), device)
        call("cuDriverGetVersion", ct.byref(version))
        call("cuCtxCreate_v2", ct.byref(context), 0, device)
        image = ct.create_string_buffer(PTX)
        call("cuModuleLoadData", ct.byref(module), image)
        call("cuModuleGetFunction", ct.byref(function), module, b"hpc_check")
        call("cuMemAlloc_v2", ct.byref(memory), ct.sizeof(ct.c_uint32))
        call("cuMemsetD32_v2", memory, 0, 1)
        parameters = (pointer * 1)(ct.cast(ct.byref(memory), pointer))
        call("cuLaunchKernel", function, 1, 1, 1, 1, 1, 1, 0, None, parameters, None)
        call("cuCtxSynchronize")
        output = ct.c_uint32()
        call("cuMemcpyDtoH_v2", ct.byref(output), memory, ct.sizeof(output))
        if output.value != 42:
            raise RuntimeError(f"CUDA kernel returned {output.value}, expected 42")
        return {"device": device_name.value.decode(), "driver_api_version": version.value,
                "kernel_result": output.value, "status": "passed"}
    finally:
        # Attempt all cleanup even if one call fails, while preserving the first
        # execution error. A cleanup error also prevents successful acceptance.
        execution_failed = sys.exc_info()[0] is not None
        cleanup_errors = []
        for name, value in [("cuMemFree_v2", memory), ("cuModuleUnload", module),
                            ("cuCtxDestroy_v2", context)]:
            if value.value:
                try:
                    call(name, value)
                except RuntimeError as error:
                    cleanup_errors.append(str(error))
        if cleanup_errors and not execution_failed:
            raise RuntimeError("; ".join(cleanup_errors))


if __name__ == "__main__":
    try:
        print(json.dumps(check_cuda()))
    except (OSError, AttributeError, RuntimeError) as error:
        sys.exit(f"Jetson CUDA acceptance failed: {error}")
