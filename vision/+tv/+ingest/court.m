function [k, courts] = court(lat, lon, courts, maxM)
%COURT  Which saved court a session was played on, by GPS (TV-ING-22).
%   The nearest saved court within maxM metres (default 150). Without a GPS
%   fix (lat NaN, usually indoors) it returns 0: the caller matches the
%   background frame instead (TV-IND-02). An unknown place adds a new court
%   (outdoor if it has GPS) and returns its index; that court needs a fresh
%   calibration.
if nargin < 4, maxM = 150; end
k = 0;
if isnan(lat), return; end
best = maxM;
for i = 1:numel(courts)
    d = haversine(lat, lon, courts(i).lat, courts(i).lon);
    if d < best, best = d; k = i; end
end
if k == 0
    courts(end+1) = struct('name', sprintf('court %d', numel(courts) + 1), 'lat', lat, 'lon', lon, ...
        'indoor', false, 'sideFenceM', NaN);
    k = numel(courts);
end
end

function d = haversine(la1, lo1, la2, lo2)
R = 6371000;
p1 = deg2rad(la1);  p2 = deg2rad(la2);
a = sin((p2 - p1) / 2)^2 + cos(p1) * cos(p2) * sin(deg2rad(lo2 - lo1) / 2)^2;
d = 2 * R * asin(sqrt(a));
end
