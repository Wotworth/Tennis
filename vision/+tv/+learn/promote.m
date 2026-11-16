function [promoted, entry] = promote(st, oldModel, newModel, T, frames, note)
%PROMOTE  Keep a retrained detector only if it is no worse on the test set (Chris, 15 Nov).
%   Both models are scored on the hand-labelled test set (tv.learn.evaluate).
%   The new one is promoted only if its recall AND its precision are both at
%   least the old one's; otherwise the old one stays and the reason is
%   logged. Every attempt is appended to history.json (the weekly message
%   reports it). Models: structs with .name and .detect (function handle).
if nargin < 6, note = ''; end
a = tv.learn.evaluate(oldModel.detect, T, frames);
b = tv.learn.evaluate(newModel.detect, T, frames);
promoted = b.recall >= a.recall && b.precision >= a.precision;
why = 'better or equal on both';
if ~promoted
    parts = {};
    if b.recall < a.recall, parts{end+1} = sprintf('recall fell %.3f -> %.3f', a.recall, b.recall); end
    if b.precision < a.precision, parts{end+1} = sprintf('precision fell %.3f -> %.3f', a.precision, b.precision); end
    why = strjoin(parts, '; ');
end
entry = struct('utc', tv.util.nowUtc(), 'old', oldModel.name, 'new', newModel.name, ...
    'oldRecall', a.recall, 'oldPrecision', a.precision, 'newRecall', b.recall, 'newPrecision', b.precision, ...
    'testFrames', a.frames, 'promoted', promoted, 'why', why, 'note', note);
H = [];
if exist(st.history, 'file'), H = jsondecode(fileread(st.history)); end
if isempty(H), H = entry; else, H = [H(:); entry]; end
tv.util.writeJson(st.history, H);
if promoted && isfield(newModel, 'file') && ~isempty(newModel.file)
    copyfile(newModel.file, fullfile(st.models, 'current.mat'));
end
end
