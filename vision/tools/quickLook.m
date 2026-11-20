function res = quickLook(files, outDir, calibFrom)
%QUICKLOOK  A short two-camera stretch of a real session, processed here before the PC exists (Chris, 20 Nov).
%   res = quickLook({cam1Stretch, cam2Stretch}, outDir)              calibrates from this stretch
%   res = quickLook({cam1Stretch, cam2Stretch}, outDir, calibFile)   uses another clip's calibration
%   The stretches are about 10 s cut out of each camera's file with FFmpeg reading it over the
%   shared link, so only the parts needed are downloaded (my session has about 4 GB of disk):
%       ffmpeg -ss <start> -i "<link>" -t 10 -c copy cam1.mp4
%   (no re-encoding; the cut starts at the key frame before <start>). Both cameras' stretches must
%   cover the same moment, give or take a second; the opening ball bounce (Tuesday's checklist)
%   should be inside it.
%   The cameras were not touched between clips, so one calibration serves every clip of the
%   session: the first clip (the empty court) is calibrated, and its outDir/stages/calib.mat is
%   given as calibFile for the rest. The timing between the cameras is solved for each clip on its
%   own, from the ball (the coarse start times come from each file). Every frame is searched.
%   A doubtful calibration does not hold the stretch (there is no app to ask yet): the alert is
%   printed and processing goes on.
if nargin < 3, calibFile = ''; else, calibFile = calibFrom; end
% a clip GoPro split into chapters: its other chapters beside it are read with it (22 Nov)
for k = 1:numel(files), files{k} = withChapters(files{k}); end
cfg = tv.pipeline.defaults();
cfg.calibFrom = calibFile;
cfg.doubtfulCalibration = 'continue';
cfg.frames = 'all';
cfg.outputs.reel = false;
cfg.notify = @(title, text) fprintf('[alert] %s: %s\n', title, text);
res = tv.pipeline.run(files, outDir, cfg);
fprintf('quick look: %d rallies, %d shots; camera 2 clock offset %.4f s\n', numel(res.rallies), numel(res.shots), res.sync.startOffset(2) + res.sync.delta);
end

function f = withChapters(file)
[d, b, e] = fileparts(file);
t = regexp(b, '^G([XH])\d{2}(\d{4})$', 'tokens', 'once');
if isempty(t) || ~strcmpi(e, '.MP4'), f = file; return; end
L = dir(fullfile(d, sprintf('G%s*%s%s', t{1}, t{2}, e)));
g = tv.ingest.chapters({L.name});
k = find(cellfun(@(x) any(strcmp(x, [b e])), {g.files}), 1);
if isempty(k), f = file; return; end
f = tv.media.joinChapters(fullfile(d, g(k).files));
end
