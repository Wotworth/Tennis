function seed(n)
%SEED  Seed the random generator (MATLAB and Octave give different but repeatable streams).
if exist('OCTAVE_VERSION', 'builtin')
    rand('state', n);  randn('state', n); %#ok<RAND>
else
    rng(n, 'twister');
end
end
