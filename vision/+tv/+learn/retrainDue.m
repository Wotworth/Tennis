function [due, why] = retrainDue(st, nowDays, opts)
%RETRAINDUE  Is it time to retrain? 20,000 new auto-labelled frames, or a month (Chris, 15 Nov).
%   Counts auto-labels written since the last attempt in history.json.
%   nowDays: datenum of now. The caller only retrains overnight when the
%   PC is idle (no import or session running).
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'minNew'), opts.minNew = 20000; end
if ~isfield(opts, 'maxDays'), opts.maxDays = 30; end
last = 0;
if exist(st.history, 'file')
    H = jsondecode(fileread(st.history));
    if ~isempty(H), last = datenum(H(end).utc(1:10), 'yyyy-mm-dd'); end
end
n = 0;
d = dir(fullfile(st.autolabels, '*.mat'));
for k = 1:numel(d)
    if d(k).datenum > last, S = load(fullfile(d(k).folder, d(k).name), 'n'); n = n + S.n; end
end
due = false;  why = sprintf('%d new frames, %.0f days since the last attempt', n, nowDays - last);
if n >= opts.minNew, due = true; why = ['enough new frames: ' why];
elseif last > 0 && nowDays - last >= opts.maxDays && n > 0, due = true; why = ['a month has passed: ' why];
elseif last == 0 && n > 0 && n >= opts.minNew, due = true; end
end
