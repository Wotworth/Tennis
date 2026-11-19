function lo = lineOptsFor(widthPx)
%LINEOPTSFOR  Line-pixel settings for real footage, scaled to the picture's width (TV-CAL-10).
%   The settings found on Chris's first real videos (1920 px wide, 17 Nov; tv.calib.linePixels):
%   a ridge at least 20 levels brighter than both sides, looked for 3 and 7 px out (near lines
%   are wide), and only thinned pieces at least 40 px long (trees, fence mesh and the net's mesh
%   give short ridges). The two lengths are in pixels, so they grow with the picture: a 4K frame
%   gets reaches of 6 and 14 px and pieces of 80 px.
%   Used by both pipelines since 19 Nov (Chris: the two-camera path was still on the settings
%   tuned on clean synthetic pictures).
%   RETUNE(real footage): all three, on the first GoPro footage from beside a court.
%   lineOptsFor('synthetic'): the settings for the generator's clean pictures (tv.synth), which the
%   tests on synthetic footage pass as cfg.lineOpts. At 960 px wide their far lines are under a
%   pixel wide and fainter than 20 levels, and the real-footage settings lose them (19 Nov: both
%   Wide cameras 0.6 to 1.0 m off with them).
if ischar(widthPx) || isstring(widthPx)
    lo = struct('minContrast', 6, 'minLength', 0, 'reach', 3);
    return
end
k = widthPx / 1920;
lo = struct('minContrast', 20, 'minLength', round(40 * k), 'reach', unique(max(2, round([3 7] * k))));
end
