function [F, owner] = boundary_faces(tets)
% BOUNDARY_FACES  Free (unshared) triangular faces of a tet mesh (corner nodes only).
%
%   [F, owner] = boundary_faces(tets)
%
%   tets  : Ne x >=4 element connectivity (only the four corner nodes are used)
%   F     : Nf x 3 node numbers of every face that belongs to exactly one element (the outer surface)
%   owner : Nf x 1 element number each face belongs to
%
% Used for drawing the surface of a (partly removed) mesh and for the skin export of export_geometry.
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)
    Ne = size(tets, 1);
    t = tets(:, 1:4);
    all = [t(:, [1 2 3]); t(:, [1 2 4]); t(:, [1 3 4]); t(:, [2 3 4])];
    [~, ~, ic] = unique(sort(all, 2), 'rows');
    cnt = accumarray(ic, 1);
    single = cnt(ic) == 1;
    F = all(single, :);
    row = find(single);
    owner = mod(row - 1, Ne) + 1;
end
