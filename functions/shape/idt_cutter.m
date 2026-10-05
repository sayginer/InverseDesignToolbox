function c = idt_cutter(type, x, y, a, b, angleDeg)
% IDT_CUTTER  One through-thickness cutter: a hole or a rectangle that is subtracted from the design part.
%
%   c = idt_cutter('hole', x, y, radius)
%   c = idt_cutter('rect', x, y, width, height)
%   c = idt_cutter('rect', x, y, width, height, angleDeg)
%
%   x, y       center of the cutter [m]
%   radius     hole radius [m]
%   width      rectangle size along its own x axis [m],  height along its own y axis [m]
%   angleDeg   rotation of the rectangle about its center, counter-clockwise seen from +z [degrees]
%
% A cutter goes through the full thickness of the design part (like a laser or CNC cut). Several cutters are
% a struct array:   cut = [idt_cutter('hole', 0, 10e-3, 3e-3), idt_cutter('rect', 12e-3, 0, 8e-3, 4e-3, 30)];
% An empty cutter list is  cut = idt_cutter([]);  (the part is left as it is).
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 1 || isempty(type)
        c = struct('Type', {}, 'X', {}, 'Y', {}, 'A', {}, 'B', {}, 'AngleDeg', {});
        return;
    end
    switch lower(type)
        case 'hole'
            assert(nargin >= 4, 'idt_cutter:Args', 'A hole needs x, y and radius.');
            c = struct('Type', 'hole', 'X', x, 'Y', y, 'A', a, 'B', a, 'AngleDeg', 0);
        case 'rect'
            assert(nargin >= 5, 'idt_cutter:Args', 'A rectangle needs x, y, width and height.');
            if nargin < 6, angleDeg = 0; end
            c = struct('Type', 'rect', 'X', x, 'Y', y, 'A', a, 'B', b, 'AngleDeg', angleDeg);
        otherwise
            error('idt_cutter:Type', 'Cutter type must be ''hole'' or ''rect''.');
    end
end
