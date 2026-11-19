function m = ballModel(override)
%BALLMODEL  Which learned ball classifier a session uses (TV-DET-04).
%   m = tv.detect.ballModel() returns m.net and m.pre (weight files) and m.name: round 5
%   (ballnet_v5, adopted by Chris on 19 Nov) with round 4's first pass (ballnet_v4_pre).
%   m = tv.detect.ballModel(file): another classifier's weight file, set by hand for one session
%   in the PC's config (cfg.ballNetFile), e.g. round 4 (ballnet_v4) to compare. That is the only
%   way another model is used; nothing switches by itself.
%   There was a switch to round 4 for courts marked indoor (19 Nov, a few hours): dropped the same
%   day, because there is no indoor footage to show round 4 is better there (Chris: show the
%   evidence or drop it). When the first indoor session exists, run both on it and compare.
dir0 = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'models');
m.pre = fullfile(dir0, 'ballnet_v4_pre.json');
if nargin >= 1 && ~isempty(override)
    m.net = override;  m.name = 'set by hand';
else
    m.net = fullfile(dir0, 'ballnet_v5.json');  m.name = 'round 5';
end
end
