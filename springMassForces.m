function [f, g, a] = springMassForces(x, v, w, h, params)
f = params.c .* (w - x);
g = -params.k .* v;
a = (f + g + h) ./ params.m;
end
