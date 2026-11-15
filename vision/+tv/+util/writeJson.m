function writeJson(file, s)
%WRITEJSON  Write a struct to a JSON file, pretty-printed where supported.
try
    txt = jsonencode(s, 'PrettyPrint', true);
catch
    txt = jsonencode(s);                       % Octave: no PrettyPrint
end
fid = fopen(file, 'w');
if fid < 0, error('tv:io', 'Cannot write %s', file); end
fwrite(fid, txt, 'char');
fclose(fid);
end
