function x = fromDevice(x)
%FROMDEVICE  Bring an array back from the GPU (no-op on the CPU path).
if isa(x, 'gpuArray'), x = gather(x); end
end
