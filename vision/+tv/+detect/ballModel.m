function m = ballModel(indoor, override)
%BALLMODEL  Which learned ball classifier a session uses (TV-DET-04; Chris, 19 Nov: say exactly
%   when the round-4 fallback is used).
%   m = tv.detect.ballModel(indoor) returns m.net and m.pre (weight files) and m.name.
%   - Outdoors (indoor false, the default): round 5, ballnet_v5. It rejects the ball's shadow,
%     and with it any small dark moving spot with no colour of its own.
%   - A court marked indoor in the app (the session's indoor flag): round 4, ballnet_v4. No sun
%     means no hard shadows, and under roof lights a ball can be darker than a pale floor or wall,
%     which round 4 accepts and round 5 mostly does not.
%   - override (a weight file's path, e.g. from the PC's config for one session): used as given.
%     That is the only other way round 4 is chosen; nothing switches by itself during a session.
%   Both use round 4's first pass (ballnet_v4_pre).
if nargin < 1 || isempty(indoor), indoor = false; end
dir0 = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'models');
m.pre = fullfile(dir0, 'ballnet_v4_pre.json');
if nargin >= 2 && ~isempty(override)
    m.net = override;  m.name = 'set by hand';
elseif indoor
    m.net = fullfile(dir0, 'ballnet_v4.json');  m.name = 'round 4 (indoor court)';
else
    m.net = fullfile(dir0, 'ballnet_v5.json');  m.name = 'round 5';
end
end
