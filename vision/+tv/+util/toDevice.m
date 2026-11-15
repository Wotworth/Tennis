function x = toDevice(x)
%TODEVICE  Move an array to the GPU when one is available, else leave it (CPU fallback).
if tv.util.useGpu(), x = gpuArray(x); end
end
