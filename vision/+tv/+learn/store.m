function s = store(root)
%STORE  Where the detector's learning data lives on the PC (Chris, 15 Nov).
%   Two stores that never mix:
%     testset/   hand-labelled frames from "Ball check" taps (the judge)
%     autolabels/ frames labelled by the pipeline itself (training only)
%   plus models/ (current.mat and every candidate) and history.json (each
%   retraining: date, old and new recall and precision, promoted or why
%   not). root defaults to the archive drive's learn folder.
s.root = root;
s.testset = fullfile(root, 'testset');
s.autolabels = fullfile(root, 'autolabels');
s.models = fullfile(root, 'models');
s.history = fullfile(root, 'history.json');
s.checksOut = fullfile(root, 'checks-out');      % crops waiting to upload
for d = {s.testset, s.autolabels, s.models, s.checksOut}
    if ~exist(d{1}, 'dir'), mkdir(d{1}); end
end
end
