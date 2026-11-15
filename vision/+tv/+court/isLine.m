function tf = isLine(x, y)
%ISLINE  True where ground point (x, y) lies on a painted line.
L = tv.court.lines();
tf = false(size(x));
for k = 1:size(L, 1)
    a = L(k, 1:2);  b = L(k, 3:4);  hw = L(k, 5);
    ab = b - a;  t = ((x - a(1)) * ab(1) + (y - a(2)) * ab(2)) / (ab * ab');
    t = max(0, min(1, t));
    d = hypot(x - (a(1) + t * ab(1)), y - (a(2) + t * ab(2)));
    tf = tf | d <= hw;
end
end
