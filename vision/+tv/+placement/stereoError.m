function e = stereoError(lens, cam1, cam2, P, pixelSigma, dims)
%STEREOERROR  1-sigma horizontal position error (m) of points seen by both cameras.
%   Linearised triangulation: a pixel error of pixelSigma in each image
%   coordinate of each camera gives the position covariance
%   pixelSigma^2 * inv(J'*J), where J (4-by-3) is how the four pixel
%   coordinates move per metre of ball movement. Returns the error along the
%   worst horizontal direction, for each row of P (N-by-3); with dims = 3,
%   along the worst direction in 3D (for a ball in the air).
%   This is one frame from each camera. A fitted flight path uses many
%   frames and should do better; calibration and timing errors are extra.
if nargin < 6, dims = 2; end
e = zeros(size(P, 1), 1);
for n = 1:size(P, 1)
    J = [jac(cam1, P(n, :)); jac(cam2, P(n, :))];
    S = pixelSigma^2 * inv(J' * J);
    e(n) = sqrt(max(eig(S(1:dims, 1:dims))));
end

    function J = jac(cam, p)
        h = 1e-4;  J = zeros(2, 3);
        for i = 1:3
            dp = zeros(1, 3);  dp(i) = h;
            [u1, v1] = tv.lens.project(lens, cam, p + dp);
            [u0, v0] = tv.lens.project(lens, cam, p - dp);
            J(:, i) = [u1 - u0; v1 - v0] / (2*h);
        end
    end
end
