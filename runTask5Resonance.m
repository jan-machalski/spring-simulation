function study = runTask5Resonance(opts)

if nargin < 1 || isempty(opts)
    opts = struct();
end
if ~isstruct(opts) || ~isscalar(opts)
    error('runTask5Resonance:InvalidOptions', 'opts must be a scalar struct.');
end
opts = applyDefaults(opts);
validateOptions(opts);

omega = linspace(opts.omegaMin, opts.omegaMax, opts.nFrequency);
nK = numel(opts.kValues);
amplitude = zeros(nK, numel(omega));
phase = zeros(nK, numel(omega));
resonanceOmega = zeros(size(opts.kValues));
resonanceAmplitude = zeros(size(opts.kValues));
validation = cell(size(opts.kValues));

for q = 1:nK
    k = opts.kValues(q);
    denominator = sqrt((opts.c - opts.m*omega.^2).^2 + (k*omega).^2);
    amplitude(q, :) = opts.c * abs(opts.A0) ./ denominator;
    phase(q, :) = opts.phi0 - atan2(k*omega, opts.c - opts.m*omega.^2);

    resonanceOmega(q) = sqrt(max(0, opts.c/opts.m - k^2/(2*opts.m^2)));
    if resonanceOmega(q) > 0
        resonanceAmplitude(q) = responseAmplitude(opts, k, resonanceOmega(q));
        phaseR = opts.phi0 - atan2(k*resonanceOmega(q), ...
            opts.c - opts.m*resonanceOmega(q)^2);
        validation{q} = validateAtResonance(opts, k, resonanceOmega(q), ...
            resonanceAmplitude(q), phaseR);
    else
        resonanceOmega(q) = 0;
        resonanceAmplitude(q) = responseAmplitude(opts, k, 0);
        validation{q} = struct('omega', 0, 'amplitudeFit', NaN, ...
            'phaseFit', NaN, 'amplitudeExact', resonanceAmplitude(q), ...
            'phaseExact', NaN, 'simulation', []);
    end
end

phase = unwrap(phase, [], 2);

figure('Name', 'Zadanie 5 - charakterystyka amplitudowa');
hold on;
colors = lines(nK);
for q = 1:nK
    plot(omega, amplitude(q, :), 'Color', colors(q, :), 'LineWidth', 1.3, ...
        'DisplayName', sprintf('k = %.4g', opts.kValues(q)));
    if resonanceOmega(q) > 0
        plot(resonanceOmega(q), resonanceAmplitude(q), 'o', ...
            'Color', colors(q, :), 'HandleVisibility', 'off');
    end
end
grid on; xlabel('Częstotliwość \omega'); ylabel('Amplituda A(\omega)');
title('Charakterystyka amplitudowa w stanie ustalonym');
legend('Location', 'best');
hold off;

figure('Name', 'Zadanie 5 - charakterystyka fazowa');
hold on;
for q = 1:nK
    plot(omega, phase(q, :), 'Color', colors(q, :), 'LineWidth', 1.3, ...
        'DisplayName', sprintf('k = %.4g', opts.kValues(q)));
end
grid on; xlabel('Częstotliwość \omega'); ylabel('Przesunięcie fazowe \phi(\omega) [rad]');
title('Charakterystyka fazowa w stanie ustalonym');
legend('Location', 'best');
hold off;

figure('Name', 'Zadanie 5 - amplituda rezonansowa a tłumienie');
plot(opts.kValues, resonanceAmplitude, 'o-', 'LineWidth', 1.3, ...
    'MarkerFaceColor', 'auto');
grid on; xlabel('Współczynnik tłumienia k');
ylabel('Amplituda maksymalna A(\omega_r)');
title('Amplituda rezonansowa w funkcji tłumienia');

fprintf('Rezonans (wartości analityczne):\n');
for q = 1:nK
    fprintf('k = %.5g: omega_r = %.7g rad/s, A(omega_r) = %.7g', ...
        opts.kValues(q), resonanceOmega(q), resonanceAmplitude(q));
    if resonanceOmega(q) > 0
        fprintf(', dopasowanie RK4: A = %.7g, phi = %.7g rad\n', ...
            validation{q}.amplitudeFit, validation{q}.phaseFit);
    else
        fprintf(' (maksimum przy omega = 0; brak piku rezonansowego)\n');
    end
end

study = struct('options', opts, 'omega', omega, 'amplitude', amplitude, ...
    'phase', phase, 'kValues', opts.kValues, ...
    'resonanceOmega', resonanceOmega, ...
    'resonanceAmplitude', resonanceAmplitude, ...
    'numericalValidation', {validation});
end

function opts = applyDefaults(opts)
defaults = struct('m', 1, 'c', 1, 'A0', 1, 'phi0', 0, ...
    'x0', 1, 'v0', 0, 'kValues', [1 0.5 0.1 0.01], ...
    'omegaMin', 0.01, 'omegaMax', 2, 'nFrequency', 500, ...
    'dt', 0.05, 'transientTimeConstants', 6, 'validationCycles', 8);
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
        opts.(names{i}) = defaults.(names{i});
    end
end
end

function validateOptions(opts)
scalarNames = {'m','c','A0','phi0','x0','v0','omegaMin','omegaMax', ...
    'nFrequency','dt','transientTimeConstants','validationCycles'};
for i = 1:numel(scalarNames)
    value = opts.(scalarNames{i});
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('runTask5Resonance:InvalidOption', ...
            'Option "%s" must be a finite numeric scalar.', scalarNames{i});
    end
end
if ~isnumeric(opts.kValues) || ~isvector(opts.kValues) || isempty(opts.kValues) || ...
        any(~isfinite(opts.kValues(:))) || any(opts.kValues(:) <= 0)
    error('runTask5Resonance:InvalidKValues', ...
        'kValues must be a nonempty vector of positive finite values.');
end
if opts.m <= 0 || opts.c <= 0 || opts.omegaMin <= 0 || ...
        opts.omegaMax <= opts.omegaMin || opts.nFrequency < 2 || ...
        opts.nFrequency ~= floor(opts.nFrequency) || ...
        opts.dt <= 0 || opts.transientTimeConstants <= 0 || opts.validationCycles < 2
    error('runTask5Resonance:InvalidOption', ...
        'Require m,c,omegaMin,dt,transientTimeConstants > 0, omegaMax > omegaMin, nFrequency >= 2, and validationCycles >= 2.');
end
end

function value = responseAmplitude(opts, k, omega)
value = opts.c * abs(opts.A0) / ...
    sqrt((opts.c - opts.m*omega^2)^2 + (k*omega)^2);
end

function fit = validateAtResonance(opts, k, omegaR, amplitudeExact, phaseExact)
period = 2*pi/omegaR;
tEnd = opts.transientTimeConstants * (2*opts.m/k) + opts.validationCycles*period;
cfg = struct('m', opts.m, 'c', opts.c, 'k', k, ...
    'x0', opts.x0, 'v0', opts.v0, 'dt', opts.dt, 'tEnd', tEnd, ...
    'w', struct('type', 'sine', 'A', opts.A0, ...
        'omega', omegaR, 'phase', opts.phi0), ...
    'h', struct('type', 'constant', 'A', 0));
model = SpringMassSimulation(cfg);
r = model.runToEnd();
tFitStart = tEnd - opts.validationCycles*period;
mask = r.t >= tFitStart;
t = r.t(mask);
x = r.x(mask);
regressors = [sin(omegaR*t), cos(omegaR*t), ones(size(t))];
coefficients = regressors \ x;
amplitudeFit = hypot(coefficients(1), coefficients(2));
phaseFit = atan2(coefficients(2), coefficients(1));
fit = struct('omega', omegaR, 'amplitudeFit', amplitudeFit, ...
    'phaseFit', phaseFit, 'amplitudeExact', amplitudeExact, ...
    'phaseExact', phaseExact, 'simulation', r, ...
    'fitOffset', coefficients(3), 'fitStartTime', tFitStart);
end
