function C = idt_shape_options(C, model)
% IDT_SHAPE_OPTIONS  Defaults and checks for the cutter design space (what an optimizer may place).
%
%   C = idt_shape_options(C, model)        C may be [] or hold only the fields you want to change.
%
% The design space of the shape module is a FIXED number of through-thickness cutters (holes and rectangles)
% that are subtracted from the design part P.Design.Part. Every cutter has a few numbers; an optimizer searches
% them, a student can also set them by hand (idt_cutter).
%
%  NumHoles     3        holes, each with  x, y, radius
%  NumRects     2        rectangles, each with  x, y, width, height, angle
%  Region       []       [xmin xmax ymin ymax] [m]: where cutter CENTERS may be. Default: the bounding box of the design part.
%  HoleRadius   []       [rmin rmax] [m]: radius range. The radius variable runs from 0 to rmax; a hole smaller than rmin is
%                        switched OFF (so the optimizer can use fewer holes). Default: [Hmax, 0.15 x smallest part extent].
%  RectSize     []       [smin smax] [m]: width and height range. Same rule: variables run from 0 to smax, a rectangle with
%                        width or height below smin is switched OFF. Default: [2 x Hmax, 0.5 x smallest part extent].
%  AllowRotation true    false = rectangles keep their angle 0 (axis-aligned)
%  Margin       []       [m] a cutter that comes closer than this to the supports, the load or an output point is switched
%                        OFF (those places stay solid). Default: Hmax.
%  MinWall      2e-3     [m] smallest wall the cutters may leave (material between two cutters, or a cutter and a free edge).
%                        Thinner walls are reported (idt_cutters_wall), drawn red in idt_plot_cutters and penalized by the
%                        optimizer. Set it from your printer (about two nozzle widths). 0 = no wall rule.
%                        Walls that already exist in the uncut part are not counted.
%
% Why "smin = a few mesh elements": the analysis removes whole mesh elements, so a hole must span several of them.
% A smaller hole would be rounded to the mesh and make the analysis unreliable.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    D = struct('NumHoles', 3, 'NumRects', 2, 'Region', [], 'HoleRadius', [], 'RectSize', [], ...
               'AllowRotation', true, 'Margin', [], 'MinWall', 2e-3);
    if nargin < 1 || isempty(C), C = struct(); end
    C = idt_fill_defaults(C, D);

    ip   = model.Params.Design.Part;
    bb   = model.Geom.Parts(ip).BBox;                         % [xmin xmax ymin ymax zmin zmax]
    Hmax = model.Params.Mesh.Hmax;
    Lmin = min([bb(2) - bb(1), bb(4) - bb(3)]);
    if isempty(C.Region),     C.Region     = bb(1:4); end
    if isempty(C.HoleRadius), C.HoleRadius = [Hmax, 0.15 * Lmin]; end
    if isempty(C.RectSize),   C.RectSize   = [2 * Hmax, 0.5 * Lmin]; end
    if isempty(C.Margin),     C.Margin     = Hmax; end

    assert(C.NumHoles >= 0 && C.NumRects >= 0 && C.NumHoles + C.NumRects >= 1, ...
        'idt_shape_options:Count', 'Use at least one cutter (NumHoles + NumRects >= 1).');
    assert(numel(C.Region) == 4 && C.Region(1) < C.Region(2) && C.Region(3) < C.Region(4), ...
        'idt_shape_options:Region', 'Region must be [xmin xmax ymin ymax].');
    assert(numel(C.HoleRadius) == 2 && C.HoleRadius(1) < C.HoleRadius(2), 'HoleRadius must be [rmin rmax].');
    assert(numel(C.RectSize) == 2 && C.RectSize(1) < C.RectSize(2), 'RectSize must be [smin smax].');
end
