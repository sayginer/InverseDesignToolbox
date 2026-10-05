function figs = idt_plot_model(model, varargin)
% IDT_PLOT_MODEL  Figures that let you CHECK the model setup before any analysis.
%
%   figs = idt_plot_model(model)
%   figs = idt_plot_model(model, 'Which', {'geometry','bricks','bc','mesh'})
%
%   geometry : every part + the fused assembly with its face numbers (read FixedFaces here!)
%   bricks   : the brick grid laid over the geometry (skipped when P.Design.Type = 'none')
%   bc       : fixed nodes (red), load arrow (magenta), numbered output points (green)
%   mesh     : tetrahedral mesh, surface + cut-away
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    p = inputParser;
    addParameter(p, 'Which', {'geometry', 'bricks', 'bc', 'mesh'});
    parse(p, varargin{:});
    which = p.Results.Which;
    figs = gobjects(0);
    if any(strcmp(which, 'geometry')), figs = [figs, plot_geometry(model.Geom)]; end
    if any(strcmp(which, 'bricks')) && model.NumVars > 0
        figs(end+1) = plot_bricks(model.Geom, model.Bricks);
    end
    if any(strcmp(which, 'bc')),       figs(end+1) = plot_bc(model.Geom, model.BC); end
    if any(strcmp(which, 'mesh')),     figs(end+1) = plot_mesh(model.Mesh); end
end
