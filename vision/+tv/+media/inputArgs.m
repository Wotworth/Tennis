function a = inputArgs(file)
%INPUTARGS  FFmpeg's input arguments for a recording: one file, or a chapter list (.ffconcat).
%   A recording GoPro split into chapters is read as one continuous recording through FFmpeg's concat
%   demuxer (tv.media.joinChapters writes the list), with nothing copied or re-encoded (22 Nov).
if numel(file) > 9 && strcmpi(file(end - 8:end), '.ffconcat')
    a = sprintf('-f concat -safe 0 -i "%s"', file);
else
    a = sprintf('-i "%s"', file);
end
end
