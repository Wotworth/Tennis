function [status, out] = shell(cmd)
%SHELL  system(cmd), without MATLAB's own library path leaking into FFmpeg.
%   On Linux and macOS MATLAB sets LD_LIBRARY_PATH to its own libraries,
%   which can break external programs; the command runs without it.
%   On Windows the command runs as is.
if ~ispc
    cmd = ['env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH ' cmd];
end
[status, out] = system(cmd);
end
