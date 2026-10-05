function file = idt_save_params(P, name)
% IDT_SAVE_PARAMS  Save the simulation parameters P to results/<name>.mat.
%
%   file = idt_save_params(P, 'VibrationIsolator')
%
% Use it at the end of a simulation script once the setup is verified, so that an optimizer
% case study can load exactly the same problem with idt_load_params(name).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    folder = fullfile(idt_root(), 'results');
    if ~isfolder(folder), mkdir(folder); end
    file = fullfile(folder, [name '.mat']);
    save(file, 'P');
    fprintf('Parameters saved to results/%s.mat\n', name);
end
