function exe = ffmpeg(tool)
%FFMPEG  Path of ffmpeg (or ffprobe with tool = 'ffprobe').
%   Uses the environment variable TV_FFMPEG_DIR if set (the PC), else PATH.
if nargin < 1, tool = 'ffmpeg'; end
d = getenv('TV_FFMPEG_DIR');
if isempty(d), exe = tool; else, exe = ['"' fullfile(d, tool) '"']; end
end
