function [sK, vol, Mref3] = tet_element_matrices(X, E, nu)
% TET_ELEMENT_MATRICES  Vectorized isoparametric TET4 / TET10 element stiffness matrices.
%
%   [sK, vol, Mref3] = tet_element_matrices(X, E, nu)
%
%   X    Ne x npe x 3 node coordinates (npe = 4 or 10; PDE Toolbox node order,
%        mid-edge nodes on edges 12 23 13 14 24 34)
%   E,nu Ne x 1 Young's modulus and Poisson's ratio per element
%
%   sK     (3npe)^2 x Ne  element stiffness, one column per element (column-major Ke(:))
%   vol    Ne x 1 element volumes
%   Mref3  (3npe) x (3npe) reference consistent mass: Me = rho * vol * Mref3
%
% Author: Dr. Osman Sayginer (InverseDesignToolbox)

    Ne = size(X, 1); npe = size(X, 2); nd = 3 * npe;
    R = tet_reference(npe);
    lam = E .* nu ./ ((1 + nu) .* (1 - 2*nu));
    mu  = E ./ (2 * (1 + nu));
    vol = zeros(Ne, 1);
    sK  = zeros(nd^2, Ne);
    Mref3 = kron(R.Mref, eye(3));

    chunk = 20000;
    for c0 = 1:chunk:Ne
        idx = c0:min(Ne, c0 + chunk - 1); n = numel(idx);
        Xc = X(idx, :, :);
        Kc = zeros(n, nd, nd);
        for g = 1:numel(R.w)
            dN = R.dN(:, :, g);
            J = cell(3, 3);
            for a = 1:3
                for b = 1:3, J{a,b} = Xc(:, :, b) * dN(a, :)'; end
            end
            detJ = J{1,1}.*(J{2,2}.*J{3,3} - J{2,3}.*J{3,2}) ...
                 - J{1,2}.*(J{2,1}.*J{3,3} - J{2,3}.*J{3,1}) ...
                 + J{1,3}.*(J{2,1}.*J{3,2} - J{2,2}.*J{3,1});
            Ji = cell(3, 3);
            Ji{1,1} = (J{2,2}.*J{3,3} - J{2,3}.*J{3,2}) ./ detJ;
            Ji{1,2} = (J{1,3}.*J{3,2} - J{1,2}.*J{3,3}) ./ detJ;
            Ji{1,3} = (J{1,2}.*J{2,3} - J{1,3}.*J{2,2}) ./ detJ;
            Ji{2,1} = (J{2,3}.*J{3,1} - J{2,1}.*J{3,3}) ./ detJ;
            Ji{2,2} = (J{1,1}.*J{3,3} - J{1,3}.*J{3,1}) ./ detJ;
            Ji{2,3} = (J{1,3}.*J{2,1} - J{1,1}.*J{2,3}) ./ detJ;
            Ji{3,1} = (J{2,1}.*J{3,2} - J{2,2}.*J{3,1}) ./ detJ;
            Ji{3,2} = (J{1,2}.*J{3,1} - J{1,1}.*J{3,2}) ./ detJ;
            Ji{3,3} = (J{1,1}.*J{2,2} - J{1,2}.*J{2,1}) ./ detJ;
            gr = cell(1, 3);                                  % gradients of shape functions, n x npe
            for k = 1:3
                gr{k} = Ji{k,1} * dN(1, :) + Ji{k,2} * dN(2, :) + Ji{k,3} * dN(3, :);
            end
            wt = R.w(g) * abs(detJ);
            vol(idx) = vol(idx) + wt;
            lw = lam(idx) .* wt; mw = mu(idx) .* wt;
            GG = 0;
            for k = 1:3, GG = GG + reshape(gr{k}, n, npe, 1) .* reshape(gr{k}, n, 1, npe); end
            for a = 1:3
                for b = 1:3
                    T = lw .* (reshape(gr{a}, n, npe, 1) .* reshape(gr{b}, n, 1, npe)) ...
                      + mw .* (reshape(gr{b}, n, npe, 1) .* reshape(gr{a}, n, 1, npe));
                    if a == b, T = T + mw .* GG; end
                    Kc(:, a:3:end, b:3:end) = Kc(:, a:3:end, b:3:end) + T;
                end
            end
        end
        sK(:, idx) = reshape(permute(Kc, [2 3 1]), nd^2, n);
    end
end

function R = tet_reference(npe)
% Reference-element data: Gauss rule, shape-function derivatives, consistent mass.
    persistent cache
    if isempty(cache), cache = struct(); end
    key = sprintf('n%d', npe);
    if isfield(cache, key), R = cache.(key); return; end

    if npe == 4
        L = [0.25 0.25 0.25 0.25]; w = 1/6;
    else
        a = 0.5854101966249685; b = 0.1381966011250105;
        L = [a b b b; b a b b; b b a b; b b b a]; w = ones(4, 1) / 24;
    end
    ng = numel(w);
    dN = zeros(3, npe, ng);
    for g = 1:ng, [~, dN(:, :, g)] = shape(L(g, :), npe); end

    % consistent mass via Duffy-collapsed 4-point Gauss-Legendre (exact to degree 7)
    [xg, wg] = gl4();
    Mref = zeros(npe);
    for i = 1:4, for j = 1:4, for k = 1:4
        u = xg(i); v = xg(j); s = xg(k);
        x1 = u; x2 = v * (1 - u); x3 = s * (1 - u) * (1 - v);
        jac = (1 - u)^2 * (1 - v);
        N = shape([1 - x1 - x2 - x3, x1, x2, x3], npe);
        Mref = Mref + wg(i) * wg(j) * wg(k) * jac * (N' * N);
    end, end, end
    Mref = 6 * Mref;                                  % relative to element volume
    assert(abs(sum(Mref(:)) - 1) < 1e-12, 'Reference mass matrix check failed.');

    R = struct('w', w, 'dN', dN, 'Mref', Mref);
    cache.(key) = R;
end

function [N, dN] = shape(L, npe)
% Shape functions and d/d(xi,eta,zeta) for volume coordinates L = [L1 L2 L3 L4].
    dL = [-1 -1 -1; 1 0 0; 0 1 0; 0 0 1];            % dL_k / d(xi,eta,zeta)
    if npe == 4
        N = L; dN = dL';
        return;
    end
    pairs = [1 2; 2 3; 1 3; 1 4; 2 4; 3 4];
    N = zeros(1, 10); dNdL = zeros(10, 4);
    for i = 1:4
        N(i) = L(i) * (2*L(i) - 1);
        dNdL(i, i) = 4*L(i) - 1;
    end
    for k = 1:6
        a = pairs(k, 1); b = pairs(k, 2);
        N(4+k) = 4 * L(a) * L(b);
        dNdL(4+k, a) = 4 * L(b);
        dNdL(4+k, b) = 4 * L(a);
    end
    dN = (dNdL * dL)';                                 % 3 x 10
end

function [x, w] = gl4()
    x0 = [-0.8611363115940526 -0.3399810435848563 0.3399810435848563 0.8611363115940526];
    w0 = [0.3478548451374538 0.6521451548625461 0.6521451548625461 0.3478548451374538];
    x = (x0 + 1) / 2; w = w0 / 2;
end
