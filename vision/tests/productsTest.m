% Toolbox guard (TV-ARCH-03, Chris 16 Nov): the vision code may need only the products the
% MATLAB Home Suite and its Computer Vision add-on include. Not available on Home, and so
% never allowed: Sensor Fusion and Tracking Toolbox, MATLAB Coder, MATLAB Compiler (and
% anything else not on this list). MATLAB only (Octave has no product list).
% requiredFilesAndProducts can only see products that are installed; CI installs only allowed
% ones, so a call into a forbidden product would also fail as an unknown function in the tests.
allowed = {'MATLAB', 'Image Processing Toolbox', 'Optimization Toolbox', 'Computer Vision Toolbox', ...
    'Statistics and Machine Learning Toolbox', 'Signal Processing Toolbox', 'Deep Learning Toolbox', ...
    'Parallel Computing Toolbox', 'Curve Fitting Toolbox'};
here = fileparts(mfilename('fullpath'));
root = fileparts(here);

%% Every file in the package and the tools needs only allowed products
if exist('OCTAVE_VERSION', 'builtin'), return; end
files = [tv.testing.listFiles(fullfile(root, '+tv'), '*.m'), tv.testing.listFiles(fullfile(root, 'tools'), '*.m')];
[~, products] = matlab.codetools.requiredFilesAndProducts(files);
names = {products.Name};
bad = setdiff(names, allowed);
fprintf('products needed: %s\n', strjoin(names, ', '));
assert(isempty(bad), 'Vision code needs products outside TV-ARCH-03: %s', strjoin(bad, ', '))
