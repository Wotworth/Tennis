function [rallies, onsets] = fromAudio(y, fs, opts)
%FROMAUDIO  Rallies from the sound of the ball: hits and bounces (TV-RAL-01, TV-RAL-02).
%   Sharp sounds (onsets) are found in the sound track. Sounds 0.3-3 s apart
%   belong to one rally (hit cadence is 0.8-2.5 s; a bounce falls between
%   hits). A rally needs at least opts.minOnsets sounds, so a lone bounce
%   while picking up a ball is not a rally. Each rally starts 1.5 s before
%   its first sound (the toss is silent) and ends 2 s after its last;
%   rallies less than 4 s apart are merged. Never clip a shot: when in doubt
%   the rally is kept.
%   Returns rallies [start stop] (s, file time) and onsets [time strength].
%   RETUNE(real footage): onset threshold, the 3 s cadence limit and the
%   minimum count; real courts have voices, other courts and wind. The
%   ball-motion check on low-resolution frames (spec TV-RAL-01) is not used
%   yet: the synthetic sound is clean enough without it.
if nargin < 3, opts = struct(); end
d = struct('thrFactor', 8, 'minLevel', 0.01, 'refractory', 0.08, 'maxGap', 3.0, ...
           'minOnsets', 3, 'lead', 1.5, 'tail', 2.0, 'mergeGap', 4.0);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
hp = [0; diff(y(:))];                              % high-pass: keeps the click, drops rumble
w = round(0.001 * fs);
n = floor(numel(hp) / w);
env = max(abs(reshape(hp(1:n * w), w, n)), [], 1)';
floorLevel = median(env);
thr = max(opts.thrFactor * floorLevel, opts.minLevel);
above = env > thr;
onsets = zeros(0, 2);
k = 1;
while k <= n
    if above(k)
        [pk, j] = max(env(k:min(n, k + 10)));
        onsets(end+1, :) = [(k - 1) * w / fs, pk]; %#ok<AGROW>
        k = k + j - 1 + round(opts.refractory * 1000);
    else
        k = k + 1;
    end
end
rallies = zeros(0, 2);
if isempty(onsets), return; end
grp = {onsets(1, 1)};
for i = 2:size(onsets, 1)
    if onsets(i, 1) - grp{end}(end) <= opts.maxGap, grp{end}(end+1) = onsets(i, 1);
    else, grp{end+1} = onsets(i, 1); end %#ok<AGROW>
end
for g = 1:numel(grp)
    if numel(grp{g}) < opts.minOnsets, continue; end
    r = [grp{g}(1) - opts.lead, grp{g}(end) + opts.tail];
    if ~isempty(rallies) && r(1) - rallies(end, 2) < opts.mergeGap
        rallies(end, 2) = r(2);
    else
        rallies(end+1, :) = r; %#ok<AGROW>
    end
end
rallies(:, 1) = max(rallies(:, 1), 0);
end
