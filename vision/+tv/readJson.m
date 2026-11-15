function s = readJson(file)
%READJSON  Read a JSON file into a struct.
s = jsondecode(fileread(file));
end
