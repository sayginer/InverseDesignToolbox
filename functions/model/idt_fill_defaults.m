function S = idt_fill_defaults(S, D)
% IDT_FILL_DEFAULTS  Recursively add every field of D that is missing in S.
%
%   S = idt_fill_defaults(S, D)
%
% Fields already in S are never changed. Used so that a user only has to specify what differs
% from the defaults, and so that parameter files saved by an older version keep working.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    if nargin < 1 || isempty(S), S = struct(); end
    f = fieldnames(D);
    for i = 1:numel(f)
        k = f{i};
        if ~isfield(S, k)
            S.(k) = D.(k);
        elseif isstruct(D.(k)) && isstruct(S.(k)) && isscalar(D.(k)) && isscalar(S.(k))
            S.(k) = idt_fill_defaults(S.(k), D.(k));
        end
    end
end
