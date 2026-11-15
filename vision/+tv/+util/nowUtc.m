function s = nowUtc()
%NOWUTC  The current time as ISO-8601 UTC text.
try
    s = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
catch
    s = datestr(now, 'yyyy-mm-ddTHH:MM:SS');      % Octave: local clock
end
end
