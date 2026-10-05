function P = idt_load_params(name)
% IDT_LOAD_PARAMS  Load the simulation parameters saved by a simulation script.
%
%   P = idt_load_params('VibrationIsolator')      loads results/VibrationIsolator.mat
%
% The returned struct is exactly the P of the simulation script, so an optimizer runs on the same
% problem. You may change single fields afterwards, for example
%   P.Mesh.Order = 'quadratic';    model = idt_build_model(P);
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    file = fullfile(idt_root(), 'results', [name '.mat']);
    assert(isfile(file), 'idt_load_params:NoFile', ...
        'No saved parameters "%s". Run a SIM_*.m script first (it saves results/%s.mat).', name, name);
    S = load(file, 'P');
    P = S.P;
end
