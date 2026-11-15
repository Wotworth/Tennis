function out = find(items, key)
%FIND  Every item with this key, at any depth.
out = items([]);
for k = 1:numel(items)
    if strcmp(items(k).key, key), out(end+1) = items(k); end %#ok<AGROW>
    if ~isempty(items(k).children), out = [out, tv.gpmf.find(items(k).children, key)]; end %#ok<AGROW>
end
end
