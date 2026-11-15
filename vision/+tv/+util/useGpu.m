function tf = useGpu()
%USEGPU  True when a supported NVIDIA GPU is available to MATLAB.
%   Every GPU path has a CPU fallback: on GitHub's servers and in Octave this
%   is false and the same code runs on ordinary arrays. Set the environment
%   variable TV_NO_GPU=1 to force the CPU path on the PC (for comparisons).
persistent cached
if isempty(cached)
    cached = false;
    if isempty(getenv('TV_NO_GPU')) && ~exist('OCTAVE_VERSION', 'builtin')
        try
            cached = canUseGPU();
        catch
            cached = false;
        end
    end
end
tf = cached;
end
