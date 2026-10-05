function r = idt_root()
% IDT_ROOT  Absolute path of the InverseDesignToolbox folder (where the SIM_*.m and CASE_*.m scripts live).
%
%   Relative file names in the parameters (STEP files, results) are resolved against this folder,
%   so the toolbox works from any current folder and on any computer.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    r = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
