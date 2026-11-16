function keys = testsetKeys(st)
%TESTSETKEYS  'session|camN-fM' keys of every hand-labelled frame (kept out of training).
f = fullfile(st.testset, 'testset.mat');
keys = {};
if exist(f, 'file'), S = load(f); keys = {S.T.key}; end
end
