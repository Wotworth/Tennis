% tools/checkCameraFile.m (Chris, 20 Nov): the check that runs on the first Mission 1 Pro file,
% tried on GoPro's own HERO8 sample (telemetry, no timecode) here.
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'tools'));

%% It reads a real GoPro file and reports each check
f = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'gopro', 'hero8.mp4');
R = checkCameraFile(f);
names = R.checks(:, 1);
assert(all(ismember({'name', 'video', 'picture size', 'frame rate', 'start time', 'telemetry', 'timecode track'}, names)))
st = R.checks(strcmp(names, 'telemetry'), 2);
assert(strcmp(st{1}, 'ok'))
assert(~any(strcmp(R.checks(:, 2), 'FAIL')))
