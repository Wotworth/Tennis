function S = summary(file)
%SUMMARY  What the GoPro telemetry says about one recording (TV-ING-12, TV-ING-13).
%   S.serial, S.model     camera serial (CASN) and model (MINF), from the
%                         file's global GPMF block (moov/udta)
%   S.payloads            one row per telemetry sample (about 1 s):
%                         [start duration fix lat lon alt maxGyro]
%                         fix: 0 none, 2 2D, 3 3D; maxGyro rad/s (bumps)
%   S.gpsUtc              GPS UTC text per payload ('' without a fix)
%   S.utcOffset           seconds to add to file time to get UTC seconds
%                         since 2000 (tv.util.utcSeconds), from GPS when it
%                         has a fix, else NaN (then the camera clock is used)
%   S.settings            shutter (s), ISO and white balance per payload,
%                         where the camera records them
S.serial = '';  S.model = '';
u = tv.gpmf.udta(file);
if ~isempty(u)
    g = tv.gpmf.parse(u);
    c = tv.gpmf.find(g, 'CASN');  if ~isempty(c), S.serial = tv.gpmf.values(c(1)); end
    m = tv.gpmf.find(g, 'MINF');  if ~isempty(m), S.model = tv.gpmf.values(m(1)); end
end
[P, T] = tv.gpmf.extract(file);
n = numel(P);
S.payloads = nan(n, 7);  S.gpsUtc = repmat({''}, n, 1);
S.settings = nan(n, 3);
offsets = [];
for k = 1:n
    items = tv.gpmf.parse(P{k});
    S.payloads(k, 1:2) = T(k, :);
    if isempty(S.serial)
        c = tv.gpmf.find(items, 'CASN');  if ~isempty(c), S.serial = tv.gpmf.values(c(1)); end
    end
    for st = tv.gpmf.find(items, 'STRM')
        ch = st.children;  ks = {ch.key};
        scal = 1;
        if any(strcmp(ks, 'SCAL')), scal = tv.gpmf.values(ch(find(strcmp(ks, 'SCAL'), 1))); scal = scal(:)'; end
        if any(strcmp(ks, 'GPS5'))
            fix = 0;  if any(strcmp(ks, 'GPSF')), fix = tv.gpmf.values(ch(strcmp(ks, 'GPSF'))); end
            g5 = tv.gpmf.values(ch(strcmp(ks, 'GPS5'))) ./ scal;
            S.payloads(k, 3:6) = [fix(1), median(g5(:, 1:3), 1)];
            if any(strcmp(ks, 'GPSU')) && fix(1) >= 2
                S.gpsUtc{k} = tv.gpmf.values(ch(strcmp(ks, 'GPSU')));
                offsets(end+1) = gpsuSeconds(S.gpsUtc{k}) - T(k, 1); %#ok<AGROW>
            end
        end
        if any(strcmp(ks, 'GYRO'))
            gy = tv.gpmf.values(ch(strcmp(ks, 'GYRO'))) ./ scal;
            S.payloads(k, 7) = max(sqrt(sum(gy.^2, 2)));
        end
        if any(strcmp(ks, 'SHUT')), v = tv.gpmf.values(ch(strcmp(ks, 'SHUT'))); S.settings(k, 1) = median(v(:)); end
        if any(strcmp(ks, 'ISOE')), v = tv.gpmf.values(ch(strcmp(ks, 'ISOE'))); S.settings(k, 2) = median(v(:)); end
        if any(strcmp(ks, 'WBAL')), v = tv.gpmf.values(ch(strcmp(ks, 'WBAL'))); S.settings(k, 3) = median(v(:)); end
    end
end
S.utcOffset = NaN;  S.utcSource = 'camera clock';
if ~isempty(offsets), S.utcOffset = median(offsets);  S.utcSource = 'gps'; end
end

function s = gpsuSeconds(u)
% GPSU 'yymmddhhmmss.sss' -> seconds since 2000 (as tv.util.utcSeconds)
v = sscanf(u, '%2d%2d%2d%2d%2d%f');
s = (datenum(2000 + v(1), v(2), v(3)) - datenum(2000, 1, 1)) * 86400 + v(4) * 3600 + v(5) * 60 + v(6);
end
