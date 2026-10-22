function validateSpringMassGeometry(cfg, state, t)
if isfield(cfg, 'restLength')
    length = cfg.restLength + state(1) - signalValue(cfg.w, t);
    if length <= 0
        error('SpringMassSimulation:InvalidGeometry', ...
            ['Ciężarek osiągnął lub przekroczył mocowanie (t=%.4g s, długość=%.4g m). ' ...
             'Zmień odchylenie lub wymuszenie. Model nie zawiera zderzeń z mocowaniem.'], t, length);
    end
end
end

