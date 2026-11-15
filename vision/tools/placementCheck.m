function rows = placementCheck(configFile, outDir)
%PLACEMENTCHECK  Camera placement lookup table, before anything is mounted.
%   placementCheck('config/placement.json', 'out/placement') evaluates
%   camera spots along the side fence (TV-CAL-03, TV-CAL-04) and writes:
%     placement_table.md   one row per side-fence distance (Chris's lookup)
%     placement_table.csv  the same, for MATLAB
%     placement_all.csv    every placement evaluated
%     placement_error.png  error and ball size against fence distance (MATLAB only)
%     placement_layout.png the recommended layout for cfg.layoutFence (MATLAB only)
%   PROVISIONAL: lens angles are GoPro's published figures, not a calibration.
if nargin < 1, configFile = fullfile(fileparts(mfilename('fullpath')), '..', 'config', 'placement.json'); end
if nargin < 2, outDir = fullfile(pwd, 'out', 'placement'); end
if ~exist(outDir, 'dir'), mkdir(outDir); end

cfg = tv.readJson(configFile);
[rows, all] = tv.placement.lookupTable(cfg);
c = tv.court.constants();

% --- the lookup table in words ---------------------------------------------
fid = fopen(fullfile(outDir, 'placement_table.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '| Side fence from doubles sideline | Mount | Spot along the fence (both cameras, same side) | Height | Frame | Aim | Far-corner bounce error | Ball at far corner | Worst spot in the air | Why not the fence |\n');
fprintf(fid, '|---|---|---|---|---|---|---|---|---|---|\n');
for r = rows'
    if strcmp(r.mount, 'light stand')
        mount = sprintf('light stand, %.1f m from the sideline', r.standoff);
    elseif strcmp(r.mount, 'none')
        mount = 'nothing meets every target; best fence spot shown';
    else
        mount = 'fence';
    end
    fprintf(fid, '| %g m | %s | %s | %.1f m | %s | %s | %.1f cm | %.1f px | %.1f cm | %s |\n', ...
        r.fence, mount, spotText(r.mountX), r.height, r.aspect, aimText(r.yaw, r.pitch), ...
        r.errorCm, r.ballPx, r.worstVolumeErrorCm, dashIfEmpty(r.whyNotFence));
end
fclose(fid);

% --- CSVs --------------------------------------------------------------------
fid = fopen(fullfile(outDir, 'placement_table.csv'), 'w');
fprintf(fid, 'fence_m,mount,standoff_m,mount_x_m,height_m,aspect,yaw_deg,pitch_deg,coverage,far_corner_error_cm,ball_px,min_cross_deg,worst_volume_error_cm,worst_x_m,worst_y_m,worst_z_m,why_not_fence\n');
for r = rows'
    fprintf(fid, '%g,%s,%g,%g,%g,%s,%.1f,%.1f,%.3f,%.2f,%.2f,%.1f,%.2f,%.1f,%.1f,%.1f,"%s"\n', r.fence, r.mount, r.standoff, ...
        r.mountX, r.height, r.aspect, r.yaw, r.pitch, r.coverage, r.errorCm, r.ballPx, r.minCrossDeg, ...
        r.worstVolumeErrorCm, r.worstVolumePoint, r.whyNotFence);
end
fclose(fid);
fid = fopen(fullfile(outDir, 'placement_all.csv'), 'w');
fprintf(fid, 'standoff_m,mount_x_m,height_m,aspect,yaw_deg,pitch_deg,coverage,far_corner_error_cm,ball_px,min_cross_deg,passes\n');
for r = all'
    fprintf(fid, '%g,%g,%g,%s,%.1f,%.1f,%.3f,%.2f,%.2f,%.1f,%d\n', r.standoff, r.mountX, r.height, ...
        r.aspect, r.yaw, r.pitch, r.coverage, r.errorCm, r.ballPx, r.minCrossDeg, r.passes);
end
fclose(fid);

if exist('OCTAVE_VERSION', 'builtin'), return; end   % plots need MATLAB

% --- plot: error and ball size against fence distance -------------------------
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 900 520]);
d = [rows.fence];
yyaxis left
plot(d, [rows.errorCm], '-o', 'LineWidth', 2); hold on
plot(d, [rows.worstVolumeErrorCm], '--s', 'LineWidth', 1.5);
yline(cfg.criteria.maxBounceErrorCm, ':', 'target');
ylabel('bounce error, cm (1 px, one frame)');
yyaxis right
plot(d, [rows.ballPx], '-^', 'LineWidth', 2);
yline(cfg.criteria.minBallPx, ':', 'smallest ball');
ylabel('ball at far corner, px (4K)');
xlabel('side fence distance from doubles sideline, m');
legend({'far-corner bounce', 'worst spot, ball in the air (3D)', '', 'ball size'}, 'Location', 'northwest');
title('Recommended placement for each fence distance (provisional lens figures)');
grid on
exportgraphics(fig, fullfile(outDir, 'placement_error.png'), 'Resolution', 150);
close(fig);

% --- plot: layout and error map for one fence distance ------------------------
r = rows([rows.fence] == cfg.layoutFence);
lens = tv.lens.build(cfg.lenses, cfg.recommendLens, r.aspect);
[gx, gy] = meshgrid(linspace(-c.halfLength - 3, c.halfLength + 3, 61), linspace(-c.halfDoubles, c.halfDoubles, 25));
e = 100 * tv.placement.stereoError(lens, r.cam1, r.cam2, [gx(:), gy(:), repmat(c.ballRadius, numel(gx), 1)], cfg.criteria.pixelSigma);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1000 620]);
contourf(gx, gy, reshape(e, size(gx)), 0:0.5:6, 'LineStyle', 'none'); hold on
cb = colorbar; cb.Label.String = 'bounce error, cm (1 px, one frame)';
drawCourt(c);
for cam = [r.cam1, r.cam2]
    plot(cam.pos(1), cam.pos(2), 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'k');
    quiver(cam.pos(1), cam.pos(2), 4*cosd(cam.yaw), 4*sind(cam.yaw), 0, 'k', 'LineWidth', 1.5);
end
axis equal; xlabel('x, m (along the court)'); ylabel('y, m (across)');
ylim([r.cam1.pos(2) - 1, c.halfDoubles + 1]);
title(sprintf('Fence %g m out: %s, %.1f m high, Wide %s', r.fence, r.mount, r.height, r.aspect));
exportgraphics(fig, fullfile(outDir, 'placement_layout.png'), 'Resolution', 150);
close(fig);
end

function s = spotText(x)
c = tv.court.constants();
dx = x - c.halfLength;
if abs(dx) < 0.05
    s = 'level with each baseline';
elseif dx > 0
    s = sprintf('%.1f m behind each baseline', dx);
else
    s = sprintf('%.1f m in from each baseline, toward the net', -dx);
end
end

function s = aimText(yaw, pitch)
turn = round(90 - yaw);               % camera 1; camera 2 is its mirror image
pitch = round(pitch);
if pitch < 0, tilt = sprintf('tilted %.0f° down', -pitch);
elseif pitch > 0, tilt = sprintf('tilted %.0f° up', pitch);
else, tilt = 'level';
end
s = sprintf('turned %.0f° toward the net, %s', turn, tilt);
end

function s = dashIfEmpty(s)
if isempty(s), s = '-'; end
end

function drawCourt(c)
L = c.halfLength;  D = c.halfDoubles;  S = c.halfSingles;  sv = c.serviceLine;
seg = [-L -D L -D; -L D L D; -L -S L -S; -L S L S; -L -D -L D; L -D L D; ...
       -sv -S -sv S; sv -S sv S; -sv 0 sv 0; 0 -c.postY 0 c.postY];
for k = 1:size(seg, 1)
    plot(seg(k, [1 3]), seg(k, [2 4]), 'w-', 'LineWidth', 1.5);
end
end
