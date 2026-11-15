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
cfg.playerHz = 10;                  % TV-PLY-01: 10 fps between rallies (30 inside: RETUNE)
cfg.weather = struct('tempC', 15, 'relHumidity', 0.6, 'pressurePa', 101325, 'wind10', [0 0]);
cfg.indoor = false;
cfg.lines = 'singles';
cfg.CDprior = struct('CD', 0.507, 'CDsd', 0.024);
cfg.refineRounds = 3;
cfg.outputs = struct('plots', true, 'reel', true);
cfg.minCrossDeg = 20;               % usable stereo crossing angle; RETUNE(real footage)
cfg.alerts = struct('ntfyServer', 'https://ntfy.sh');
cfg.notify = @(title, text) tv.ops.notify(cfg, title, text);
end
