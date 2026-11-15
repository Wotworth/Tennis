function seed(n)
%SEED  Seed the random generator (MATLAB and Octave give different but repeatable streams).
n = mod(round(n), 2^32);              % MATLAB needs a whole number from 0 to 2^32-1
if exist('OCTAVE_VERSION', 'builtin')
    rand('state', n);  randn('state', n); %#ok<RAND>
else
    rng(n, 'twister');
end
end
