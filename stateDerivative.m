function dz = stateDerivative(t, z, params, wSignal, hSignal)

if numel(z) ~= 2
    error('stateDerivative:InvalidState', 'State z must contain [x; v].');
end
validateParameters(params);
w = signalValue(wSignal, t);
h = signalValue(hSignal, t);
x = z(1);
v = z(2);
[~, ~, a] = springMassForces(x, v, w, h, params);
dz = [v; a];
end

function validateParameters(p)
required = {'m', 'c', 'k'};
for i = 1:numel(required)
    name = required{i};
    if ~isfield(p, name) || ~isnumeric(p.(name)) || ~isscalar(p.(name)) || ~isfinite(p.(name))
        error('stateDerivative:InvalidParameters', 'Parameter "%s" must be a finite scalar.', name);
    end
end
if p.m <= 0 || p.c <= 0 || p.k < 0
    error('stateDerivative:InvalidParameters', 'Require m > 0, c > 0, and k >= 0.');
end
end
