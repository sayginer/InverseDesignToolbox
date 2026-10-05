function bricks = idt_make_bricks(P, geom)
% IDT_MAKE_BRICKS  MODEL STAGE B - define the design domain.
%
%   bricks = idt_make_bricks(P, geom)
%
% P.Design.Type = 'bricks': cut part P.Design.Part into a grid of switchable bricks
% (size from MinPrintSize / Density / Layers, see docs/01_model_setup.md).
% P.Design.Type = 'none'  : no design domain (the geometry is analysed as imported).
% Look at the result with plot_bricks(geom, bricks).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    P = idt_prepare_params(P);
    D = P.Design;
    switch lower(D.Type)
        case 'bricks'
            bricks = create_bricks(geom, 'DesignPart', D.Part, 'MinPrintSize', D.MinPrintSize, ...
                                   'Density', D.Density, 'Layers', D.Layers, ...
                                   'MinFill', D.MinFill, 'MaxOverlap', D.MaxOverlap);
        case 'none'
            % a brick structure with zero bricks, so the engine treats every element as permanent
            grid = struct('N', [1 1 1], 'Size', [1 1 1] * 1e-3, 'Min', [1e3 1e3 1e3], 'Overlap', [0 0 0], ...
                          'EdgeTarget', 1e-3, 'Density', 0, 'NumBricks', 1, 'MinPrintSize', 1e-3, ...
                          'Fabricable', true, 'IsCubic', true);
            bricks = struct('Mode', 'box', 'DesignPart', [], 'Box', [1e3 1e3+1 1e3 1e3+1 1e3 1e3+1], ...
                            'Name', 'none', 'Grid', grid, 'Present', false, 'Fill', 0, 'Overlap', 0, ...
                            'NumPresent', 0, 'NumExcluded', 0);
            fprintf('  No design domain: the geometry is analysed exactly as imported.\n\n');
        otherwise
            error('idt_make_bricks:DesignType', 'P.Design.Type must be ''bricks'' or ''none''.');
    end
end
