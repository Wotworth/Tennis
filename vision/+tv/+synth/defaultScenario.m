function sc = defaultScenario()
%DEFAULTSCENARIO  A short synthetic practice session with known answers (TV-TST-01).
%   Two rallies with a changeover between them, two players (Chris in a
%   magenta cap for the first rally only), a ball lying near the net post,
%   wind, and every camera imperfection the pipeline must undo: lens
%   distortion, rolling shutter, motion blur, a clock offset and drift
%   between the cameras, frame rate 119.88, flicker and noise.
%   Small frames keep CI fast; the ball is drawn larger (ballDrawScale) so
%   it covers about as many pixels as it would at 4K.
c = tv.court.constants();
sc.seed = 7;
sc.utcStart = '2026-11-14T15:00:00.000Z';    % truth time 0 = camera 1 clock 0

% --- cameras: the placement table's row for a fence 4 m out ------------------
sc.frameSize     = [960 540];                 % [width height] for tests (4K on the PC)
sc.lensName      = 'Wide';  sc.aspect = '16:9';
sc.standoff      = 4;  sc.mountX = c.halfLength;  sc.mountHeight = 3.5;
sc.fps           = 120000 / 1001;             % 119.88: never exactly 120 (TV-ING-10)
sc.shutter       = 1 / 1920;
sc.readout       = [0.0080, 0.0085];          % s, rolling-shutter readout per camera
sc.clockOffset   = [0, 0.0137];               % s, Delta: camera 2 clock -> truth (TV-SYNC)
sc.clockDrift    = [0, 40e-6];                % epsilon: camera 2 runs 40 ppm slow
sc.recordStart   = [0, -0.4370];              % s, each camera's clock at its first frame
sc.duration      = 26;                        % s of footage from camera 1's start
sc.coarseError   = [0.004, -0.011];           % s, error in each file's start time (a frame or two)
sc.aimErrorDeg   = [0.6 -0.4 0.3; -0.5 0.5 -0.2];  % yaw, pitch, roll errors vs the planned aim
sc.serials       = {'C3501325000001', 'C3501325000002'};

% --- picture -----------------------------------------------------------------
sc.ballDrawScale = 4;                         % drawn ball diameter / true diameter
sc.ballRGB       = [205 230 40];              % optic yellow under daylight
sc.noiseSigma    = 2.0;                       % 8-bit levels
sc.flicker       = 0.006;                     % fractional brightness wobble
sc.flickerHz     = 0.7;
sc.crf           = 14;                        % H.264 quality: low but not zero compression

% --- air ---------------------------------------------------------------------
sc.weather = struct('tempC', 21, 'relHumidity', 0.55, 'pressurePa', 100900);
sc.wind    = [1.2 -0.6 0];                    % m/s, steady
sc.CD      = 0.507;

% --- players -------------------------------------------------------------------
sc.players(1) = struct('name', 'Chris', 'height', 1.89, 'shirt', [40 70 160], ...
    'shorts', [30 30 35], 'cap', [215 40 150], 'capUntil', 9.5);
sc.players(2) = struct('name', 'Opponent', 'height', 1.80, 'shirt', [235 235 230], ...
    'shorts', [60 60 70], 'cap', [25 25 25], 'capUntil', Inf);

% --- rallies -------------------------------------------------------------------
% Each shot: target bounce [x y], speed (m/s), CL, spin ('top', 'slice', 'flat').
% The server is listed first; the ends swap between rallies (changeover).
sc.rallies(1).start  = 2.0;   sc.rallies(1).server = 1;   sc.rallies(1).serverEnd = -1;
sc.rallies(1).shots  = { [5.0  2.3], 42, 0.05, 'top';
                         [-9.0 -2.8], 25, 0.12, 'top';
                         [8.8  3.0], 28, 0.14, 'top';
                         [-8.2  1.2], 19, 0.10, 'slice';
                         [12.6 -1.5], 30, 0.12, 'top' };    % long: out by 0.7 m
sc.rallies(2).start  = 19.5;  sc.rallies(2).server = 2;   sc.rallies(2).serverEnd = -1;
sc.rallies(2).shots  = { [4.6  1.9], 38, 0.05, 'top';
                         [-7.5 3.4], 22, 0.12, 'top';
                         [9.6 -3.6], 27, 0.15, 'top';
                         [-6.0 0.5], 18, 0.00, 'net' };     % into the net
sc.staticBall = [0.6, -5.9, c.ballRadius];       % a ball lying by the net post
end
