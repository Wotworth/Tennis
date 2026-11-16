function P = listFiles(root, pattern)
%LISTFILES  Every file under root whose name matches the wildcard pattern (recursive; tests).
if nargin < 2, pattern = '*'; end
P = {};
if ~exist(root, 'dir'), return; end
F = dir(fullfile(root, pattern));
F = F(~[F.isdir]);
P = fullfile(root, {F.name});
D = dir(root);
for d = D([D.isdir] & ~strncmp({D.name}, '.', 1))'
    P = [P, tv.testing.listFiles(fullfile(root, d.name), pattern)]; %#ok<AGROW>
end
end
