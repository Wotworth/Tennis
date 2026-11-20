function C = clapOffsets(y1, y2, fs, dt0, opts)
%CLAPOFFSETS  Sharp sounds both cameras heard, and the time between them (Chris's home test c, 21 Nov).
%   C = tv.sync.clapOffsets(y1, y2, fs, dt0)
%   y1, y2: the two recordings' sound (mono, the same sample rate fs). dt0: where camera 2's file
%   time is expected to be when camera 1's is 0 is not needed exactly: camera 2 hears a sound at
%   about t1 - dt0, with dt0 = start of camera 2's file minus start of camera 1's (from the
%   timecode), to within opts.searchS.
%   Claps are found in camera 1's sound: an onset at least opts.ratio times the loudness of the
%   seconds round it, at least opts.gapS apart. Each is matched in camera 2's sound by
%   cross-correlating a short window (opts.winS) over +/- opts.searchS, to a fraction of a sample.
%   C rows: [t1 t2 offset peakCorr]: camera 1's file time, camera 2's, and offset = t1 - t2 (s), which
%   changes along the recording by the drift between the two clocks.
if nargin < 5, opts = struct(); end
d = struct('ratio', 12, 'gapS', 5, 'winS', [-0.05 0.25], 'searchS', 1.0, 'minCorr', 0.5);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = d.(fn{k}); end, end
y1 = y1(:) - mean(y1);  y2 = y2(:) - mean(y2);
h1 = hp(y1, fs);  h2 = hp(y2, fs);
% onsets in camera 1, on a 1 kHz loudness trace: 5 ms loudness against the median of the 5 s round it
b = max(1, round(fs / 1000));  m = floor(numel(h1) / b);
e = sqrt(mean(reshape(h1(1:m * b) .^ 2, b, m), 1))';
e = sqrt(movmean(e .^ 2, 5));
M = ceil(numel(e) / 1000);  ep = [e; repmat(median(e), M * 1000 - numel(e), 1)];
bm = median(reshape(ep, 1000, M), 1)';                 % each second's median, then over 5 seconds
bm = movmedian(bm, 5);
bg = repelem(bm, 1000);  bg = bg(1:numel(e)) + eps;
hot = find(e > opts.ratio * bg);                      % loud moments; the loudest of each group,
ci = zeros(0, 1);                                      % groups split by opts.gapS of quiet
g0 = 1;
for q = 2:numel(hot) + 1
    if q > numel(hot) || hot(q) - hot(q - 1) > opts.gapS * 1000
        grp = hot(g0:q - 1);  [~, k] = max(e(grp));  ci(end+1, 1) = grp(k); %#ok<AGROW>
        g0 = q;
    end
end
cand = zeros(0, 1);
for q = ci(:)'                                          % back to full rate: the onset's own sample
    a = (q - 3) * b + 1;  z = min(numel(h1), (q + 1) * b);
    if a < 1, continue; end
    [~, k] = max(abs(h1(a:z)));  cand(end+1, 1) = a + k - 1; %#ok<AGROW>
end
C = zeros(0, 4);
for i = cand(:)'
    t1 = (i - 1) / fs;
    a = i + round(opts.winS(1) * fs);  b = i + round(opts.winS(2) * fs);
    if a < 1 || b > numel(h1), continue; end
    w = h1(a:b);
    c0 = round((t1 - dt0) * fs) + 1;                     % camera 2's sample at about the same moment
    s = round(opts.searchS * fs);
    lo = c0 + round(opts.winS(1) * fs) - s;  hi = c0 + round(opts.winS(2) * fs) + s;
    if lo < 1 || hi > numel(h2), continue; end
    seg = h2(lo:hi);
    L = numel(w);  nl = numel(seg) - L + 1;
    r = zeros(nl, 1);  nw = norm(w);
    for j = 1:nl                                        % normalised cross-correlation
        x = seg(j:j + L - 1);  r(j) = (w' * x) / (nw * norm(x) + eps);
    end
    [pk, j] = max(r);
    if pk < opts.minCorr, continue; end
    dj = 0;
    if j > 1 && j < nl                                  % parabola through the peak: a fraction of a sample
        dj = 0.5 * (r(j - 1) - r(j + 1)) / (r(j - 1) - 2 * r(j) + r(j + 1));
    end
    i2 = lo + j - 1 + dj - round(opts.winS(1) * fs);    % camera 2's sample matching camera 1's onset
    t2 = (i2 - 1) / fs;
    C(end+1, :) = [t1, t2, t1 - t2, pk]; %#ok<AGROW>
end
end

function y = hp(x, fs)
% first difference: a crude high-pass that keeps the clap's crack and drops hum and wind
y = [0; diff(x)];
end
