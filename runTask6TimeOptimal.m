function result = runTask6TimeOptimal(opts)

if nargin < 1 || isempty(opts)
    opts = struct();
end
if ~isstruct(opts) || ~isscalar(opts)
    error('runTask6TimeOptimal:InvalidOptions', 'opts must be a scalar struct.');
end
opts = applyDefaults(opts);
validateOptions(opts);

distance = opts.xf - opts.x0;
if distance == 0
    T = 0;
    t = 0;
    x = opts.x0;
    v = 0;
    a = 0;
else
    T = 2 * sqrt(abs(distance) / opts.aMax);
    t = linspace(0, T, opts.nSamples)';
    halfTime = T / 2;
    direction = sign(distance);
    x = zeros(size(t));
    v = zeros(size(t));
    a = zeros(size(t));

    first = t < halfTime;
    second = ~first & t < T;
    ended = t >= T;

    x(first) = opts.x0 + 0.5*direction*opts.aMax*t(first).^2;
    v(first) = direction*opts.aMax*t(first);
    a(first) = direction*opts.aMax;

    remaining = T - t(second);
    x(second) = opts.xf - 0.5*direction*opts.aMax*remaining.^2;
    v(second) = direction*opts.aMax*remaining;
    a(second) = -direction*opts.aMax;

    x(ended) = opts.xf;
    v(ended) = 0;
    a(ended) = 0;
end

w = x + (opts.m*a + opts.k*v) ./ opts.c;
externalForce = zeros(size(t));
[springForce, dampingForce, aFromForces] = springMassForces(x, v, w, externalForce, opts);

figure('Name', 'Zadanie 6 - sterowanie optymalne');
subplot(4, 1, 1);
plot(t, x, 'LineWidth', 1.3); hold on; yline(opts.xf, ':k');
grid on; ylabel('x(t)'); title(sprintf('Czas minimalny T = %.6g s', T));
subplot(4, 1, 2);
plot(t, v, 'LineWidth', 1.3); hold on; yline(0, ':k');
grid on; ylabel('v(t)');
subplot(4, 1, 3);
plot(t, a, 'LineWidth', 1.3); hold on;
yline(opts.aMax, ':k'); yline(-opts.aMax, ':k');
grid on; ylabel('a(t)');
subplot(4, 1, 4);
plot(t, w, 'LineWidth', 1.3);
grid on; xlabel('Czas t'); ylabel('w(t)');

figure('Name', 'Zadanie 6 - siły');
plot(t, springForce, 'LineWidth', 1.2); hold on;
plot(t, dampingForce, 'LineWidth', 1.2);
plot(t, aFromForces*opts.m, '--', 'LineWidth', 1.2);
grid on; xlabel('Czas t'); ylabel('Siła');
legend('f(t)', 'g(t)', 'Siła wypadkowa', 'Location', 'best');
title('Siły odpowiadające wyznaczonej trajektorii');
hold off;

fprintf('Czas minimalny: T = %.8g s\n', T);
fprintf('Stan końcowy: x(T) = %.8g, v(T) = %.8g\n', x(end), v(end));
fprintf('Maksymalne |a| = %.8g (ograniczenie %.8g)\n', max(abs(a)), opts.aMax);
fprintf('Wymagane sterowanie: w(t) = x(t) + (m*a(t) + k*v(t))/c, h(t)=0.\n');

result = struct('options', opts, 't', t, 'x', x, 'v', v, 'a', a, ...
    'aFromForces', aFromForces, 'w', w, 'springForce', springForce, ...
    'dampingForce', dampingForce, 'externalForce', externalForce, ...
    'T', T, 'switchTime', T/2, 'finalPosition', x(end), ...
    'finalVelocity', v(end), 'maxAbsAcceleration', max(abs(a)));
end

function opts = applyDefaults(opts)
defaults = struct('m', 1, 'c', 1, 'k', 1, 'x0', 0, ...
    'xf', 1, 'aMax', 1, 'nSamples', 1001, 'v0', 0, 'vf', 0);
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
        opts.(names{i}) = defaults.(names{i});
    end
end
end

function validateOptions(opts)
names = {'m','c','k','x0','xf','aMax','nSamples','v0','vf'};
for i = 1:numel(names)
    value = opts.(names{i});
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('runTask6TimeOptimal:InvalidOption', ...
            'Option "%s" must be a finite numeric scalar.', names{i});
    end
end
if opts.m <= 0 || opts.c <= 0 || opts.k < 0 || opts.aMax <= 0 || ...
        opts.nSamples < 3 || opts.nSamples ~= floor(opts.nSamples)
    error('runTask6TimeOptimal:InvalidOption', ...
        'Require m,c,aMax > 0, k >= 0, and integer nSamples >= 3.');
end
if opts.v0 ~= 0 || opts.vf ~= 0
    error('runTask6TimeOptimal:UnsupportedBoundary', ...
        'This implementation follows task 6 with v(0)=v(T)=0.');
end
end
