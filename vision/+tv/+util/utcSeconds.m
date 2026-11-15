function s = utcSeconds(isoUtc)
%UTCSECONDS  Seconds since 1 Jan 2000 for an ISO-8601 UTC time (to the millisecond).
v = sscanf(isoUtc, '%d-%d-%dT%d:%d:%f');
s = (datenum(v(1), v(2), v(3)) - datenum(2000, 1, 1)) * 86400 + v(4) * 3600 + v(5) * 60 + v(6);
end
