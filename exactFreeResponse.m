function [xExact, vExact] = exactFreeResponse(params, x0, v0, t)

validateScalar(params, 'm');
validateScalar(params, 'c');
validateScalar(params, 'k');
validateScalarValue(x0, 'x0');
validateScalarValue(v0, 'v0');
if params.m <= 0 || params.c <= 0 || params.k < 0
    error('exactFreeResponse:InvalidParameters', 'Require m > 0, c > 0, and k >= 0.');
end
if ~isnumeric(t) || any(~isfinite(t(:))) || any(t(:) < 0)
    error('exactFreeResponse:InvalidTime', 't must contain finite, nonnegative times.');
end

A = [0, 1; -params.c/params.m, -params.k/params.m];
z0 = [x0; v0];
xExact = zeros(size(t));
vExact = zeros(size(t));
for i = 1:numel(t)
    z = expm(A * t(i)) * z0;
    xExact(i) = z(1);
    vExact(i) = z(2);
end
end

function validateScalar(s, name)
if ~isstruct(s) || ~isfield(s, name)
    error('exactFreeResponse:MissingParameter', 'Missing parameter "%s".', name);
end
validateScalarValue(s.(name), name);
end

function validateScalarValue(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error('exactFreeResponse:InvalidValue', '"%s" must be a finite numeric scalar.', name);
end
end
