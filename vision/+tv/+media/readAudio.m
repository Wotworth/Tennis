function [y, fs] = readAudio(info)
%READAUDIO  The recording's sound as mono doubles, at its own sample rate.
wav = [tempname() '.wav'];
tv.util.run(sprintf('%s -y -v error -i "%s" -vn -ac 1 -c:a pcm_s16le "%s"', tv.util.ffmpeg(), info.file, wav));
[y, fs] = audioread(wav);
delete(wav);
end
