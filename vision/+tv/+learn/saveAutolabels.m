function saveAutolabels(st, sessionId, L)
%SAVEAUTOLABELS  Store one session's auto-labels (training only), refusing test-set frames.
keys = tv.learn.testsetKeys(st);
bad = intersect({L.key}, keys);
assert(isempty(bad), 'tv:learn:mix', 'Auto-labels for test-set frames are not allowed: %s', strjoin(bad, ', '));
n = numel(L);
save(fullfile(st.autolabels, [regexprep(sessionId, '[^\w-]', '_') '.mat']), 'L', 'n');
end
