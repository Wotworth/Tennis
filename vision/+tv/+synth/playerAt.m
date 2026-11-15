function xy = playerAt(truth, p, T)
%PLAYERAT  Truth ground position [x y] of player p at truth time T.
w = truth.players{p};
xy = [interp1(w(:,1), w(:,2), T, 'linear', w(end,2)), interp1(w(:,1), w(:,3), T, 'linear', w(end,3))];
first = T < w(1,1);
xy(first, :) = repmat(w(1, 2:3), nnz(first), 1);
end
