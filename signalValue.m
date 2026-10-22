function y = signalValue(signal, t)

if nargin < 1 || isempty(signal)
    signal = struct('type', 'constant', 'A', 0);
end
if ~isstruct(signal) || ~isscalar(signal)
    error('signalValue:InvalidSignal', 'Signal must be a scalar struct.');
end
kind = lower(stringField(signal, 'type', 'constant'));
A = numericField(signal, 'A', 0);
omega = numericField(signal, 'omega', 1);
phase = numericField(signal, 'phase', 0);
t0 = numericField(signal, 't0', 0);

switch kind
    case {'constant', 'const'}
        y = A + zeros(size(t));
    case {'step', 'heaviside'}
        y = A .* (t >= t0);
    case {'square', 'signsin'}
        y = A .* sign(sin(omega .* t + phase));
    case {'sine', 'sinusoidal'}
        y = A .* sin(omega .* t + phase);
    otherwise
        error('signalValue:UnknownType', ...
            'Unknown signal type "%s". Use constant, step, square, or sine.', kind);
end
end

function value = numericField(s, name, defaultValue)
if isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error('signalValue:InvalidField', 'Signal field "%s" must be a finite numeric scalar.', name);
end
end

function value = stringField(s, name, defaultValue)
if isfield(s, name) && ~isempty(s.(name))
    raw = s.(name);
else
    raw = defaultValue;
end
if ~(ischar(raw) || (isstring(raw) && isscalar(raw)))
    error('signalValue:InvalidType', 'Signal field "%s" must be text.', name);
end
value = char(raw);
end
