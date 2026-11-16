function in = inInterest(P, box)
%ININTEREST  True for points (N-by-3, court frame) inside the court of interest (TV-ADJ-03).
%   Points with NaN are outside. P N-by-2 tests the ground footprint only (players).
in = P(:, 1) >= box.x(1) & P(:, 1) <= box.x(2) & P(:, 2) >= box.y(1) & P(:, 2) <= box.y(2);
if size(P, 2) >= 3, in = in & P(:, 3) >= box.z(1) & P(:, 3) <= box.z(2); end
end
