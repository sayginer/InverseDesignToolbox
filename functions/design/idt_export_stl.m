function info = idt_export_stl(model, X, file, opt)
% IDT_EXPORT_STL  Save the final manufacturable shape of a brick layout as an STL file and preview it.
%
%   info = idt_export_stl(model, X, 'results/my_design')
%   info = idt_export_stl(model, X, file, opt)
%
%   model : from idt_build_model      X : design layout (model.NumVars x 1 logical), e.g. post.X or out.X
%   file  : output name (with or without .stl). A name without a folder goes to the results/ folder.
%   opt   : struct with any of
%       Content  'cad'     'cad'   : the imported CAD assembly (holder + design frame + fixed frame) with every removed
%                                    brick cut out as a box pocket. ONE exact solid: round holes stay round, flat faces
%                                    are single large triangles. This is the part you print.
%                          'bricks': only the kept design bricks, merged, as flat-faced boxes
%       Units    'mm'      STL has no units; the numbers are written in mm (or 'm')
%       Preview  true      show a figure of the saved file (3-D view, top view)
%       SaveSelection false  also write the brick table (csv) and the selection (mat) next to the STL
%
% The file is READ BACK and checked, so the preview shows exactly what you saved:
%   .Watertight   every edge belongs to exactly two triangles (a closed surface: slicers need this)
%   .Shells       number of separate solid pieces (1 = one connected part)
%   .Volume       enclosed volume (mm^3 if Units = 'mm'),  .BBox  bounding box,  .NumTriangles
%   .Content      what was really exported (falls back to 'structure' if the CAD boolean fails: then the surface is the
%                 faceted analysis-mesh skin; a warning says so)
%
% STL is a surface format for slicers and CAD import. STEP cannot be written from MATLAB.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 4, opt = struct(); end
    opt = idt_fill_defaults(opt, struct('Content', 'cad', 'Units', 'mm', 'Preview', true, 'SaveSelection', false));
    if nargin < 2 || isempty(X), X = true(model.NumVars, 1); end

    [folder, name, ~] = fileparts(file);
    if isempty(folder), folder = fullfile(idt_root(), 'results'); end
    if ~isfolder(folder), mkdir(folder); end
    base = fullfile(folder, name);

    ex = export_geometry(model, X, base, 'Content', opt.Content, 'Units', opt.Units, 'SaveSelection', opt.SaveSelection);
    stl = [base '.stl'];

    %% read the file back and check it (idt_stl_check: closed surface, pieces, volume, preview)
    info = idt_stl_check(stl, opt.Units, opt.Preview, ex.Content);
    if ~info.Watertight
        warning('idt_export_stl:NotWatertight', ['The STL is not a closed surface; a slicer may complain. This usually means ' ...
            'kept bricks touch only along an edge or corner: clean the layout first (idt_clean_bricks).']);
    end
    if strcmp(ex.Content, 'structure') && strcmpi(opt.Content, 'cad')
        warning('idt_export_stl:Fallback', 'The CAD cut failed; the STL is the faceted analysis-mesh skin, not the exact CAD shape.');
    end
end
