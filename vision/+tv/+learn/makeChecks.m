function items = makeChecks(st, pick, readFrame, opts)
%MAKECHECKS  Crops for "Ball check": about 256 x 256 px around the detector's ball.
%   readFrame(c) returns the full frame for a candidate (session, camera,
%   frame). Each crop is centred on the predicted ball (or the frame's
%   centre of action when there is none), kept inside the frame, saved as
%   JPEG in the store's checks-out folder. Returns what POST /checks wants
%   plus what the PC must remember to map answers back (originX/Y, cam,
%   frame), saved in checks-out/pending.mat.
if nargin < 4, opts = struct(); end
if ~isfield(opts, 'size'), opts.size = 256; end
s = opts.size;
items = struct('sessionId', {}, 'frameRef', {}, 'cropPath', {}, 'predX', {}, 'predY', {}, 'width', {}, 'height', {}, ...
               'originX', {}, 'originY', {}, 'cam', {}, 'frame', {}, 'file', {});
for c = pick(:)'
    F = readFrame(c);
    [H, W, ~] = size(F);
    centre = c.xy;  if any(isnan(centre)), centre = [W / 2, H / 2]; end
    x0 = round(min(max(centre(1) - s / 2, 0), W - s));  y0 = round(min(max(centre(2) - s / 2, 0), H - s));
    crop = F(y0 + 1:y0 + s, x0 + 1:x0 + s, :);
    ref = tv.learn.frameRef(c.cam, c.frame);
    file = fullfile(st.checksOut, sprintf('%s_%s.jpg', regexprep(c.sessionId, '[^\w-]', '_'), ref));
    imwrite(crop, file, 'Quality', 90);
    items(end+1) = struct('sessionId', c.sessionId, 'frameRef', ref, 'cropPath', ['checks/' ref '.jpg'], ... %#ok<AGROW>
        'predX', c.xy(1) - x0, 'predY', c.xy(2) - y0, 'width', s, 'height', s, ...
        'originX', x0, 'originY', y0, 'cam', c.cam, 'frame', c.frame, 'file', file);
end
P = items;
f = fullfile(st.checksOut, 'pending.mat');
if exist(f, 'file'), S = load(f); P = [S.P(:); items(:)]; end
save(f, 'P');
end
