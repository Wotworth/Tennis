function cfg = defaults()
%DEFAULTS  Pipeline settings. The PC's config/tennisvision.json overrides them.
%   Every number here that came from synthetic footage is marked
%   RETUNE(real footage) where it is used.
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cfg.placementFile = fullfile(here, 'config', 'placement.json');
cfg.lensName = 'Wide';  cfg.aspect = '16:9';
cfg.shutter = 1 / 1920;
cfg.readoutPrior = 0.008;           % s; RETUNE(real footage): measured in TV-PH-2 (spec)
cfg.ballApparentScale = 1;          % synthetic footage draws the ball larger
cfg.chunk = 240;                    % frames decoded at once
cfg.detector = 'learned';           % TV-DET-04: the learned ball detector ('classical': the first, colour-based one)
cfg.ballNetFile = '';               % its classifier's weights; empty = round 5 (tv.detect.ballModel)
cfg.calibFrom = '';                 % a calib.mat (outDir/stages) from another clip of the same session: its cameras are used as they are
cfg.frames = 'all';                 % Chris, 20 Nov: 'all' searches every frame; 'sound' only the sound's rally windows (not before a
                                    % first pass is shown to miss under 1% of rally frames on real sessions and Chris agrees)
cfg.play = struct('score', 0.5, 'binS', 0.25, 'binShare', 0.25, 'mergeS', 4, 'leadS', 1.5, 'tailS', 2, 'pairGapM', 0.75, 'minHeightM', 0.2, 'linkS', 0.05, 'minSpeed', 4, 'maxSpeed', 75);   % rallies from the ball in play (tv.rally.fromPlay); RETUNE(real footage)
cfg.ballCut = 0.05;                 % spots the classifier scores under this are not tracked
cfg.chainOpts = struct();           % tv.track.chains settings (its own defaults when empty)
cfg.playerHz = 10;                  % TV-PLY-01: 10 fps between rallies (30 inside: RETUNE)
cfg.weather = struct('tempC', 15, 'relHumidity', 0.6, 'pressurePa', 101325, 'wind10', [0 0]);
cfg.indoor = false;
cfg.indoorDefaults = struct('tempC', 18, 'relHumidity', 0.5);   % TV-IND-01; the PC's config overrides
cfg.chrisLabel = '';                % set by an app answer (TV-PLY-07)
cfg.lines = 'singles';
cfg.CDprior = struct('CD', 0.507, 'CDsd', 0.024);
cfg.refineRounds = 3;
cfg.outputs = struct('plots', true, 'reel', true);
% Chris, 16 Nov: only his court (TV-ADJ-01 to 08). RETUNE(real footage): all of these.
cfg.court = struct('behindBaseline', 5, 'beyondSideline', 2, 'maxHeight', 12);   % m; sidelines = doubles
cfg.gate = struct('epipolarPx', 4, ...      % TV-ADJ-02: summed reprojection error of a pair (4K: scaled)
                  'minInsideFrac', 0.5, ... % TV-ADJ-04: share of a track's paired points inside
                  'minPairedFrac', 0.3, ... % share of a track seen by both cameras
                  'maxSpeed', 75, ...       % m/s between neighbouring 3D points
                  'sameBallM', 2, ...       % two overlapping tracks in one camera are one ball only within this (m)
                  'rollMaxZ', 0.3, 'rollMinS', 0.3, 'rollShare', 0.9, ... % a track this low (m) for this long (s) is a rolling ball
                  'otherPairM', 0.5, 'otherPairS', 0.25, ... % a point paired with another ball's track: kept only within this (m) of its own path, judged within this (s) of an own point (21 Nov)
                  'perBall', false, ...     % fit a second ball in view at once apart (tv.recon.ballGroups); off: CI 17 Nov lost more flights with it
                  'playerInsideFrac', 0.6); % TV-ADJ-05: share of a person's time inside
cfg.adjacentTest = struct('maxFalsePos', 0.005, 'maxFalseNeg', 0.02, 'maxSwaps', 0);   % AC-14 to AC-16
cfg.lineOpts = [];                  % court-line pixel settings: empty = real footage, scaled to the picture (tv.calib.lineOptsFor)
cfg.minLineSupport = 0.35;          % a camera's fitted court with paint under less than this share of its lines is doubtful (TV-CAL-11).
                                    % PROVISIONAL (Chris, 19 Nov: set it from the Hero 7 side clip): midway between the highest wrong fit
                                    % seen on real pictures since the 19 Nov fix (0.18) and the lowest right one (0.54). RETUNE(real footage)
cfg.doubtfulCalibration = 'hold';   % TV-CAL-21: 'hold' stops the session before detection and asks for the four corners (the watcher
                                    % sends the picture to the app); 'continue' processes with the alert only
cfg.corners = {[], []};             % TV-CAL-22: per camera, the four doubles-court corners tapped on its calibration picture
                                    % (4-by-2, the full picture's pixels, any order); empty = fit from the lines
cfg.calibAccepted = [false false];  % TV-CAL-22: Chris looked at the drawn fit and said the lines are right
cfg.maxTapRms = 0.01;               % taps that miss the fitted corners by more than this share of the picture's width are asked for again; RETUNE(real footage)
cfg.checkPictureWidth = 3840;       % the calibration picture sent to the app is no wider than this (px)
cfg.minCrossDeg = 20;               % usable stereo crossing angle; RETUNE(real footage)
cfg.alerts = struct('ntfyServer', 'https://ntfy.sh');
cfg.notify = @(title, text) tv.ops.notify(cfg, title, text);
% Chris, 16 Nov: pause while too hot. A no-op here; the closet PC's config sets
% tv.ops.thermalGuard with its limits (tv.ingest.loadConfig).
cfg.thermalGuard = @() 0;
end
