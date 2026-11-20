function [clips, cutT, score] = cuts(info, opts)
%CUTS  Where an edited video jumps from one clip to the next (first real footage, 17 Nov).
%   An export of "included rallies" (e.g. SwingVision) joins rallies filmed by a fixed camera:
%   the picture barely changes at a cut, except that the players jump. A cut is a frame whose
%   change from the previous frame (FFmpeg's scene score, on a small copy) is a lone spike:
%   above opts.minScore and opts.factor times the median of its neighbours, and the largest
%   within +-opts.halfWin frames. Returns clips [firstFrame lastFrame] (0-based), the cut
%   times (s) and the per-frame scores. The GoPros record whole sessions; this is only for
%   edited footage.
%   RETUNE(real footage): minScore (0.03), factor (8), halfWin (6), minClipS (1).
if nargin < 2, opts = struct(); end
d = struct('minScore', 0.03, 'factor', 8, 'halfWin', 6, 'minClipS', 1);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
meta = [tempname() '.txt'];
tv.util.run(sprintf('%s -v error %s -an -vf "scale=480:-2,select=''gte(scene,0)'',metadata=print:file=%s" -f null -', ...
    tv.util.ffmpeg(), tv.media.inputArgs(info.file), strrep(meta, '\', '/')));
txt = fileread(meta);  delete(meta);
v = regexp(txt, 'scene_score=([0-9.]+)', 'tokens');
score = cellfun(@(c) str2double(c{1}), v)';
n = numel(score);  h = opts.halfWin;
isCut = false(n, 1);
for i = h + 1:n - h
    nb = score([i - h:i - 1, i + 1:i + h]);
    if score(i) > opts.minScore && score(i) > opts.factor * max(median(nb), 0.002) && score(i) == max(score(i - h:i + h))
        isCut(i) = true;
    end
end
f = find(isCut) - 1;                                  % 0-based frame that starts a new clip
edges = [0; f(:); info.nFrames];
clips = [edges(1:end - 1), edges(2:end) - 1];
keep = (clips(:, 2) - clips(:, 1) + 1) / info.fps >= opts.minClipS;
clips = clips(keep, :);
cutT = info.pts(f + 1);
end
