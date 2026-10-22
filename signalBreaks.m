function times = signalBreaks(signal, tEnd)
times = [];
kind = lower(char(signal.type));
switch kind
    case {'step', 'heaviside'}
        times = 0;
        if isfield(signal, 't0') && ~isempty(signal.t0), times = signal.t0; end
    case {'square', 'signsin'}
        omega = 1; phase = 0;
        if isfield(signal, 'omega') && ~isempty(signal.omega), omega = signal.omega; end
        if isfield(signal, 'phase') && ~isempty(signal.phase), phase = signal.phase; end
        if omega ~= 0
            n1 = ceil(min(phase, omega*tEnd + phase) / pi);
            n2 = floor(max(phase, omega*tEnd + phase) / pi);
            times = ((n1:n2)*pi - phase) ./ omega;
        end
end
end
