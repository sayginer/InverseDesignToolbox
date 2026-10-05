function mat = get_material_properties(mat_input)
% GET_MATERIAL_PROPERTIES Returns structural material properties (E, nu, rho)
% Supports built-in engineering library, 5 editable custom slots, or custom structs.
%
% USAGE:
%   mat = get_material_properties('Aluminum-6061');
%   mat = get_material_properties('Custom-1');
%   mat = get_material_properties('Custom-2');
%
%   % Or pass a custom struct on the fly:
%   mat = get_material_properties(struct('Name','MyResin', 'E',4.5e9, 'nu',0.35, 'rho',1200));
%
% =========================================================================
% BUILT-IN STANDARD MATERIALS:
%   - 'Structural-Steel' / 'Steel'   (E = 200 GPa, nu = 0.30, rho = 7800 kg/m^3)
%   - 'Aluminum-6061'    / 'Aluminum'(E = 69 GPa,  nu = 0.33, rho = 2700 kg/m^3)
%   - 'Titanium-Ti6Al4V' / 'Titanium'(E = 114 GPa, nu = 0.34, rho = 4430 kg/m^3)
%   - 'PLA'              (3D Print)  (E = 3.5 GPa, nu = 0.36, rho = 1250 kg/m^3)
%   - 'ABS'              (3D Print)  (E = 2.2 GPa, nu = 0.38, rho = 1040 kg/m^3)
%   - 'PETG'             (3D Print)  (E = 2.1 GPa, nu = 0.38, rho = 1270 kg/m^3)
%   - 'Carbon-Fiber'     / 'CFRP'    (E = 120 GPa, nu = 0.28, rho = 1600 kg/m^3)
%   - 'Brass'                        (E = 105 GPa, nu = 0.35, rho = 8500 kg/m^3)
%   - 'Copper'                       (E = 117 GPa, nu = 0.34, rho = 8960 kg/m^3)
%
% USER EDITABLE CUSTOM SLOTS:
%   - 'Custom-1' (Default: TPU / Flexible Rubber)
%   - 'Custom-2' (Default: Nylon PA12)
%   - 'Custom-3' (Default: Glass Fiber Composite - GFRP)
%   - 'Custom-4' (Default: Magnesium Alloy - AZ91D)
%   - 'Custom-5' (Default: Inconel 718 Superalloy)
% =========================================================================
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 1 || isempty(mat_input)
        mat_input = 'Structural-Steel';
    end

    % 1. Custom struct passed directly on-the-fly
    if isstruct(mat_input)
        mat = struct();
        mat.Name = getField(mat_input, 'Name', 'Custom Material');
        mat.E    = getField(mat_input, 'E', 200e9);
        mat.nu   = getField(mat_input, 'nu', 0.30);
        mat.rho  = getField(mat_input, 'rho', 7800);
        return;
    end

    % 2. String lookup (case-insensitive, ignores hyphens and spaces)
    key = lower(char(mat_input));
    key = regexprep(key, '[-_\s]', ''); % normalize

    switch key
        %% =================================================================
        %% USER EDITABLE CUSTOM MATERIAL SLOTS (MODIFY PROPERTIES BELOW)
        %% =================================================================
        case {'custom1', 'custommaterial1', 'tpu'}
            mat.Name = 'TPU (Flexible Polymer)';
            mat.E    = 0.05e9;  % Young's Modulus: 50 MPa (0.05 GPa)
            mat.nu   = 0.45;    % Poisson's Ratio
            mat.rho  = 1200;    % Density: 1200 kg/m^3

        case {'tpuheavy', 'tpuweighted'}
            mat.Name = 'TPU-Heavy (Weighted Flexible Polymer)';
            mat.E    = 0.05e9;  % Young's Modulus: 50 MPa
            mat.nu   = 0.45;    % Poisson's Ratio
            mat.rho  = 2000;    % Density: 2000 kg/m^3 (weighted/filled TPU)

        case {'custom2', 'custommaterial2'}
            mat.Name = 'Custom-2: Nylon PA12';
            mat.E    = 1.7e9;   % Young's Modulus: 1.7 GPa
            mat.nu   = 0.39;    % Poisson's Ratio
            mat.rho  = 1010;    % Density: 1010 kg/m^3

        case {'custom3', 'custommaterial3'}
            mat.Name = 'Custom-3: Glass Fiber Composite (GFRP)';
            mat.E    = 35.0e9;  % Young's Modulus: 35 GPa
            mat.nu   = 0.25;    % Poisson's Ratio
            mat.rho  = 1900;    % Density: 1900 kg/m^3

        case {'custom4', 'custommaterial4'}
            mat.Name = 'Custom-4: Magnesium Alloy (AZ91D)';
            mat.E    = 45.0e9;  % Young's Modulus: 45 GPa
            mat.nu   = 0.35;    % Poisson's Ratio
            mat.rho  = 1810;    % Density: 1810 kg/m^3

        case {'custom5', 'custommaterial5'}
            mat.Name = 'Custom-5: Inconel 718';
            mat.E    = 211.0e9; % Young's Modulus: 211 GPa
            mat.nu   = 0.29;    % Poisson's Ratio
            mat.rho  = 8190;    % Density: 8190 kg/m^3

        %% =================================================================
        %% STANDARD BUILT-IN ENGINEERING MATERIALS
        %% =================================================================
        case {'structuralsteel', 'steel'}
            mat.Name = 'Structural Steel';
            mat.E    = 200e9;   % Pa
            mat.nu   = 0.30;
            mat.rho  = 7800;    % kg/m^3

        case {'aluminum6061', 'aluminum', 'aluminium', 'al6061', 'al'}
            mat.Name = 'Aluminum 6061-T6';
            mat.E    = 69e9;
            mat.nu   = 0.33;
            mat.rho  = 2700;

        case {'titaniumti6al4v', 'titanium', 'ti6al4v', 'ti'}
            mat.Name = 'Titanium Grade 5 (Ti-6Al-4V)';
            mat.E    = 114e9;
            mat.nu   = 0.34;
            mat.rho  = 4430;

        case {'pla', 'polylacticacid'}
            mat.Name = 'PLA (3D Printed)';
            mat.E    = 3.5e9;
            mat.nu   = 0.36;
            mat.rho  = 1250;

        case {'abs', 'acrylonitrilebutadienestyrene'}
            mat.Name = 'ABS (3D Printed)';
            mat.E    = 2.2e9;
            mat.nu   = 0.38;
            mat.rho  = 1040;

        case {'petg', 'polyethyleneterephthalateglycol'}
            mat.Name = 'PETG (3D Printed)';
            mat.E    = 2.1e9;
            mat.nu   = 0.38;
            mat.rho  = 1270;

        case {'carbonfiber', 'cfrp', 'carbon'}
            mat.Name = 'Carbon Fiber Composite (CFRP)';
            mat.E    = 120e9;
            mat.nu   = 0.28;
            mat.rho  = 1600;

        case 'brass'
            mat.Name = 'Cartridge Brass';
            mat.E    = 105e9;
            mat.nu   = 0.35;
            mat.rho  = 8500;

        case 'copper'
            mat.Name = 'Pure Copper';
            mat.E    = 117e9;
            mat.nu   = 0.34;
            mat.rho  = 8960;

        otherwise
            error(['Unknown material: "%s".\n\n' ...
                   'Available Built-in Materials:\n' ...
                   '  - ''Structural-Steel'' (or ''Steel'')\n' ...
                   '  - ''Aluminum-6061''    (or ''Aluminum'')\n' ...
                   '  - ''Titanium-Ti6Al4V'' (or ''Titanium'')\n' ...
                   '  - ''PLA''\n' ...
                   '  - ''ABS''\n' ...
                   '  - ''PETG''\n' ...
                   '  - ''Carbon-Fiber''     (or ''CFRP'')\n' ...
                   '  - ''Brass''\n' ...
                   '  - ''Copper''\n\n' ...
                   'User Custom Material Slots (edit values in get_material_properties.m):\n' ...
                   '  - ''Custom-1''\n' ...
                   '  - ''Custom-2''\n' ...
                   '  - ''Custom-3''\n' ...
                   '  - ''Custom-4''\n' ...
                   '  - ''Custom-5''\n\n' ...
                   'Or pass a custom struct on-the-fly:\n' ...
                   '  struct(''Name'',''MyMaterial'', ''E'',70e9, ''nu'',0.33, ''rho'',2700)'], ...
                   char(mat_input));
    end
end

function val = getField(s, fieldName, defaultVal)
    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = s.(fieldName);
    else
        val = defaultVal;
    end
end
