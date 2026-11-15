function [yaw, pitch, coverage] = aim(lens, pos, pts, marginPx)
%AIM  Best yaw and pitch (degrees) for a camera at pos to see the points pts.
%   First maximises how many points sit inside the frame, at least marginPx
%   from its edges (room for aiming by hand). Among aims that see the same
%   number, it keeps the one with the most room to spare at the worst point.
%   Coarse 3-degree search, then a 0.5-degree refinement around the best.
centreYaw = atan2d(-pos(2), -pos(1));            % straight at the net centre
[yaw, pitch] = search(centreYaw + (-90:3:90), -75:3:15);
[yaw, pitch, coverage] = search(yaw + (-3:0.5:3), pitch + (-3:0.5:3));

    function [bestYaw, bestPitch, cov] = search(yaws, pitches)
        [Y, Pt] = ndgrid(yaws, pitches);
        [r, d, f] = tv.placement.cameraAxes(Y(:), Pt(:));   % A-by-3 each
        Q  = pts - pos;                               % N-by-3
        Xc = Q * r';  Yc = Q * d';  Zc = Q * f';      % N-by-A
        [u, v, ok] = tv.lens.toPixels(lens, Xc, Yc, Zc);
        slack = min(lens.widthPx/2 - marginPx - abs(u), lens.heightPx/2 - marginPx - abs(v));
        slack(~ok) = -lens.widthPx;
        inside = sum(slack >= 0, 1);
        score  = inside + 0.49 * tanh(min(slack, [], 1) / (lens.widthPx/2));
        [~, best] = max(score);
        bestYaw = Y(best);  bestPitch = Pt(best);
        cov = inside(best) / size(pts, 1);
    end
end
