function s = utcPlus(isoUtc, seconds)
%UTCPLUS  ISO-8601 UTC time string plus seconds, to the millisecond.
%   Done in plain arithmetic (days since year 0) so MATLAB and Octave agree.
d = isoToDays(isoUtc) + seconds / 86400;
s = daysToIso(d);
end

function d = isoToDays(s)
v = sscanf(s, '%d-%d-%dT%d:%d:%f');
d = datenum(v(1), v(2), v(3), v(4), v(5), v(6));
end

function s = daysToIso(d)
ms = round(d * 86400000);                 % whole milliseconds
d  = ms / 86400000;
v  = datevec(d);
sec = round(mod(ms, 60000)) / 1000;
s = sprintf('%04d-%02d-%02dT%02d:%02d:%06.3fZ', v(1), v(2), v(3), v(4), v(5), sec);
end
