function V = SurfaceSmooth(Surf, Faces, VoxSize, DisplTol, IterTol, Freedom, Verbose)
    % Smooth closed triangulated surface to remove "voxel" artefacts.
    %
    % V = SurfaceSmooth(Surf, [], VoxSize, DisplTol, IterTol, Freedom, Verbose)
    % V = SurfaceSmooth(Vertices, Faces, VoxSize, DisplTol, IterTol, Freedom, Verbose)
    %
    % Smooth a triangulated surface, trying to optimize getting rid of blocky
    % voxel segmentation artefacts but still respect initial segmentation.
    % This is achieved by restricting vertex displacement along the surface
    % normal to half the voxel size, and by compensating normal displacement
    % of a voxel by an opposite distributed shift in its neighbors.  That
    % way, the total normal displacement is approximately zero (before
    % potential restrictions are applied).
    %
    % Tangential motion is currently left unrestricted, which means the mesh
    % will readjust over many iterations, much more than necessary to obtain
    % a smoothed surface.  On the other hand, this produces a more uniform
    % triangulation, which may be desirable in some cases, e.g. after a
    % reducepatch operation.  This tangential motion may also make the normal
    % restriction a bit less accurate.  This all depends on how irregular the
    % mesh was to start with.  To avoid long running times and some of the
    % tangential deformation, DisplTol and IterTol can be used to limit the
    % number of iterations.
    %
    % To separate these two effects (normal smoothing and tangential mesh
    % uniformization), the function can be run to achieve each type of motion
    % separately, by setting Freedom to the appropriate value (see below).
    % Even if both effects are desired, but precision in the normal
    % displacement restriction is preferred over running time, I would
    % suggest running twice (norm., tang.) or three times (tang., norm.,
    % tang.), but only once in the normal direction.  Note that tangential
    % motion is not perfect and may cause a small amount of smoothing as
    % well.
    %
    % Input variables:
    %  Surf: Instead of Vertices and Faces, a single structure can be given
    %    with fields 'Vertices' and 'Faces' (lower-case v, f also work).  In this
    %    case, leave Faces empty [].
    %  Vertices [nV, 3]: Point 3d coordinates.
    %  Faces [nF, 3]: Triangles, i.e. 3 point indices.
    %  VoxSize (default inf): Length of voxels, this determines the amount of
    %    smoothing.  For a voxel size of 1, vertices are allowed to move only
    %    0.5 units in the surface normal direction.  This is somewhat optimal
    %    for getting rid of artefacts: it allows steps to become flat even at
    %    shallow angles and a single voxel cube would be transformed to a
    %    sphere of identical voxel volume.
    %  DisplTol (default 0.01*VoxSize): Once the maximum displacement of
    %    vertices is less than this distance, the algorithm stops.  If two
    %    values are given, e.g. [0.01, 0.01], the second value is compared to
    %    normal displacement only. The first limit encountered stops
    %    iterating.  This allows stopping earlier if only smoothing is
    %    desired and not mesh uniformity.
    %  IterTol (default 100): If the algorithm did not converge, it will stop
    %    after this many iterations.
    %  Freedom (default 2): Indicate which motion is allowed by the
    %    algorithm with an integer value: 0 for (restricted) normal
    %    smoothing, 1 for (unrestricted) tangential motion to get a more
    %    uniform triangulation, or 2 for both at the same time.
    %  Verbose (default 0): If 1, writes initial and final volumes and
    %    areas on the command line.  Also gives the number of iterations and
    %    final displacement when the algorithm converged.  (A warning is
    %    always given if convergence was not obtained in IterTol iterations.)  If
    %    > 1, details are given at each iteration.
    %
    % Output: Modified voxel coordinates [nV, 3].
    %
    % Written by Marc Lalancette, Toronto, Canada, 2014-02-04
    % Volume calculation from divergence theorem idea:
    %  http://www.mathworks.com/matlabcentral/fileexchange/26982-volume-of-a-surface-triangulation

    % Note: Although this seems to work relatively well, it is still very new
    % and not fully tested.  Despite the description above which is what was
    % intended, the algorithm had the tendency to drive growing oscillations
    % (from iteration to iteration) on the surface.  Thus a basic damping
    % mechanism was added: I simply multiply each movement by a fraction that
    % seems to avoid oscillations and still converge rapidly enough.

    % Attempt at damping oscillations. Reduce any movement by a certain
    % fraction. (Multiply movements by this factor.)
    DampingFactor = 0.91;

    % Add visualizations to debug.
    isDebugFigures = true;

    if ~isstruct(Surf)
        if nargin < 2 || isempty(Faces)
            error('Faces required as second input or "faces" field of first input.');
        else
            SurfV = Surf;
            clear 'Surf';
            Surf.Vertices = SurfV;
            Surf.Faces = Faces;
            clear SurfV Faces;
        end
    else
        if isfield(Surf, 'faces')
            Surf.Faces = Surf.faces;
            Surf = rmfield(Surf, 'faces');
        end
        if isfield(Surf, 'vertices')
            Surf.Vertices = Surf.vertices;
            Surf = rmfield(Surf, 'vertices');
        elseif ~isfield(Surf, 'Vertices')
            error('Surf.Vertices field required when second input is empty.');
        end
    end
    if nargin < 3 || isempty(VoxSize)
        VoxSize = inf;
        if nargin < 5 || isempty(IterTol)
            error(['Unrestricted smoothing (no VoxSize) would lead to a sphere of similar volume, ', ...
                'unless limited by the number of iterations.']);
        end
    end
    if nargin < 4 || isempty(DisplTol)
        DisplTol = 0.01 * VoxSize;
    end
    if numel(DisplTol) == 1
        % Only stop when total displacement reaches the limit, normal displacement alone
        % isn't checked for stopping.
        DisplTol = [DisplTol, 0];
    end
    if nargin < 5 || isempty(IterTol)
        IterTol = 100;
    end
    if nargin < 6 || isempty(Freedom)
        Freedom = 2; % 0=norm, 1=tang, 2=both.
    end
    if nargin < 7 || isempty(Verbose)
        Verbose = false;
    end

    % Verify surface is a triangulation.
    if size(Surf.Faces, 2) > 3
        error('SurfaceSmooth only works with a triangulated surface.');
    end

    % Optimal allowed normal displacement, in units of voxel side length.
    % Based on turning a single voxel into a sphere of same volume: max
    % needed displacement is in corner:
    %  sqrt(3)/2 - 1/(4/3*pi)^(1/3) = 0.2457
    % In middle of face it is rather:
    %  1/(4/3*pi)^(1/3) - 1/2 = 0.1204
    % Based on very gentle sloped staircase, it would be 0.5, but for 45
    % degree steps, we only need cos(pi/4)/2 = 0.3536.  So something along
    % those lines seems like a good compromize.  For now try to make steps
    % completely disappear.
    MaxNormDispl = 0.5 * VoxSize;
    %   MaxDispl = 2 * VoxSize; % To avoid large scale slow flows tangentially, which could distort.

    nV = size(Surf.Vertices, 1);
    %nF = size(Surf.Faces, 1);

    % Remove duplicate faces.  Not necessary considering we have to use
    % unique on the edges later anyway.
    %   Surf.Faces = unique(Surf.Faces, 'rows');

    if Verbose
        if isDebugFigures
            [FdA, VdA, FN, VN] = CalcVertexNormals(Surf);
            ViewSurfWithNormals(Surf.Vertices, Surf.Faces, VN, FN, VdA, FdA)
        else
            [FdA, VdA, FN] = CalcAreas(Surf);
        end
        FaceCentroidZ = ( Surf.Vertices(Surf.Faces(:, 1), 3) + ...
            Surf.Vertices(Surf.Faces(:, 2), 3) + Surf.Vertices(Surf.Faces(:, 3), 3) ) /3;
        Pre.Volume = FaceCentroidZ' * (FN(:, 3) .* FdA);
        Pre.Area = sum(FdA);
        fprintf('Total enclosed volume before smoothing: %g\n', Pre.Volume);
        fprintf('Total area before smoothing: %g\n', Pre.Area);
    end

    % Calculate connectivity matrix.

    % Euler characteristic (2-2handles) = V - E + F
    % For simple closed surface, E = 3*F/2
    %   disp(nV)
    %   disp(2 + nF/2)

    % This expression works when each edge is found once in each direction,
    % i.e. as long as all normals are consistently pointing in (or out).
    %   C = sparse(Faces(:), [Faces(:, 2); Faces(:, 3); Faces(:, 1)], true);
    % Seems users had patches that didn't satisfy this restriction, or had
    % duplicate faces or had possibly intersecting surfaces with 3 faces
    % sharing an edge.
    [Edges, ~, iE] = unique(sort([Surf.Faces(:), ...
        [Surf.Faces(:, 2); Surf.Faces(:, 3); Surf.Faces(:, 1)]], 2), 'rows'); % [Surf.Faces...] = Edges(iE,:)
    % Look for boundaries of open surface.
    isBoundE = false(size(Edges, 1), 1);
    isBoundV = false(nV, 1);
    iE = sort(iE);
    n = 1;
    for i = 2:numel(iE)
        if iE(i) ~= iE(i-1)
            if n == 1
                % Only one copy, boundary edge.
                isBoundE(iE(i-1)) = true;
            else
                n = 1;
            end
        else
            if n == 2
                % This makes a 3rd copy of the same edge. Strange surface.
                isBoundE(iE(i)) = true;
            end
            n = n + 1;
        end
    end
    % This was very slow for many edges.
    %   for i = 1:size(Edges, 1)
    %       isBoundE(i) = sum(iE == i) < 2;
    %   end
    if any(isBoundE)
        if Verbose
            warning('Open surface detected. Results may be unexpected.');
        end
        isBoundV(Edges(isBoundE, :)) = true;
    end
    iBoundV = find(isBoundV);
    iBulkV = setdiff(1:nV, iBoundV);
    % Vertex connectivity matrix, does not include diagonal (self)
    C = sparse(Edges, Edges(:, [2,1]), true); % Fills symetrically 1>2, 2>1
    %C = C | C';
    % Logical matrix would be huge, so use sparse. However tests in R2011b
    % indicate that using logical sparse indexing is sometimes slightly
    % faster (possibly when using linear indexing) but sometimes noticeably
    % slower.  Seems here using a cell array is better.
    CCell = cell(nV, 1);
    CCellBulk = cell(nV, 1);
    for v = 1:nV
        CCell{v} = find(C(:, v));
        CCellBulk{v} = setdiff(CCell{v}, iBoundV);
    end
    clear C
    % Number of connected neighbors at each vertex.
    %   nC = full(sum(C, 1));

    V = Surf.Vertices;
    LastMaxDispl = [inf, inf]; % total, normal only
    Iter = 0;
    NormDispl = zeros(nV, 1);
    while LastMaxDispl(1) > DisplTol(1) && LastMaxDispl(2) > DisplTol(2) && ...
            Iter < IterTol
        Iter = Iter + 1;
        [~, VdA, ~, N] = CalcVertexNormals(Surf);
        % Double boundary vertex areas to balance their "pull". But not very precise, depends on boundary shape.
        VdA(isBoundV) = 2 * VdA(isBoundV);
        VWeighted = bsxfun(@times, VdA, Surf.Vertices);

        % Moving step.  (This is slow.)
        switch Freedom
            case 2 % Both.
                for v = iBulkV
                    % Neighborhood average.  Improved to weigh by area element to avoid
                    % tangential deformation based on number of neighbors (e.g. shrinking
                    % towards vertices with fewer neighbors).
                    NeighdA = sum(VdA(CCell{v}));
                    NeighdABulk = sum(VdA(CCellBulk{v}));
                    NeighborAverage = sum(VWeighted(CCell{v}, :) / NeighdA, 1); % / nC(v);
                    % Neighborhood correction displacement along normal. Volume
                    % corresponding to this point's normal movement, distributed (divided)
                    % over neighborhood area + itself, which will be shifted inversely.
                    NormalDisplCorr = (NeighborAverage - Surf.Vertices(v, :)) * N(v, :)' / (NeighdABulk/VdA(v) + 1); % / (nC(v) + 1);
                    % Central point is moved to average of neighbors, but shifted back a
                    % bit as they all will be.
                    V(v, :) = V(v, :) + DampingFactor * ( NeighborAverage - Surf.Vertices(v, :) - NormalDisplCorr * N(v, :) );
                    % Neighbors are shifted a bit too along their own normals, such that
                    % the total change in volume (normal displacement times surface area)
                    % is close to zero.
                    V(CCellBulk{v}, :) = V(CCellBulk{v}, :) - DampingFactor * NormalDisplCorr * N(CCellBulk{v}, :);
                end
            case 0 % Normal motion only.
                for v = iBulkV
                    NeighdA = sum(VdA(CCell{v}));
                    NeighdABulk = sum(VdA(CCellBulk{v}));
                    NeighborAverage = sum(VWeighted(CCell{v}, :) / NeighdA, 1); % / nC(v);
                    % d * a / (b+a) = d / (b/a + 1)
                    NormalDisplCorr = (NeighborAverage - Surf.Vertices(v, :)) * N(v, :)' / (NeighdABulk/VdA(v) + 1); % / (nC(v) + 1);
                    % The vertex should move the projected distance minus the correction.
                    % 1 - a/(b+a) = b/(b+a) = 1/(1+a/b) = (b/a) * 1/(b/a+1)
                    V(v, :) = V(v, :) + DampingFactor * NeighdABulk/VdA(v) * NormalDisplCorr * N(v, :);
                    V(CCellBulk{v}, :) = V(CCellBulk{v}, :) - DampingFactor * NormalDisplCorr * N(CCellBulk{v}, :);
                end
            case 1 % Tangential motion only.  Unrestricted.
                for v = iBulkV
                    NeighdA = sum(VdA(CCell{v}));
                    NeighborAverage = sum(VWeighted(CCell{v}, :) / NeighdA, 1); % / nC(v);
                    NormalDisplacement = (NeighborAverage - Surf.Vertices(v, :)) * N(v, :)'; % / (nC(v) + 1);
                    V(v, :) = V(v, :) + DampingFactor * ( (NeighborAverage - Surf.Vertices(v, :)) - NormalDisplacement * N(v, :) );
                    % No compensation among neighbors.
                end
            otherwise
                error('Unrecognized Freedom parameter. Should be 0, 1 or 2.');
        end
        % Restricting step.
        % Displacements along normals (N at last positions, Surf.Vertices), added to
        % previous normal displacement since we want to restrict total normal
        % displacement.
        D = NormDispl + dot((V - Surf.Vertices), N, 2);
        % New restricted total normal displacement.
        NormDispl = sign(D) .* min(abs(D), MaxNormDispl);
        % Amounts to move back if greater than allowed.
        D = D - NormDispl;
        Where = abs(D) > DisplTol(1) * 1e-6; % > 0, but ignore precision errors.
        % Fix.
        if any(Where)
            V(Where, :) = V(Where, :) - [D(Where), D(Where), D(Where)] .* N(Where, :);
        end
        % New restriction on tangential displacement. [Not implemented.]
        %     MaxDispl

        if Verbose > 1
            [LastMaxDispl(1), iMax(1)] = max(sqrt( sum((V - Surf.Vertices).^2, 2)) );
            [LastMaxDispl(2), iMax(2)] = max(abs(dot(V - Surf.Vertices, N, 2)));
            TangDisplVec = CrossProduct(V - Surf.Vertices, N);
            [LastMaxDispl(3), iMax(3)] = max(sqrt(TangDisplVec(:,1).^2 + TangDisplVec(:,2).^2 + TangDisplVec(:,3).^2));
            fprintf('Iter %d: max displ %1.4g at vox %d; norm %1.4g (vox %d); tang %1.4g (vox %d)\n', ...
                Iter, LastMaxDispl(1), iMax(1), ...
                sign((V(iMax(2),:) - Surf.Vertices(iMax(2),:)) * N(iMax(2),:)')*LastMaxDispl(2), iMax(2), ...
                sign(TangDisplVec(iMax(3), 1))*LastMaxDispl(3), iMax(3));
            % Signs are to see if these are oscillations or translations.
        else
            LastMaxDispl(1) = sqrt( max(sum((V - Surf.Vertices).^2, 2)) );
            LastMaxDispl(2) = max(dot(V - Surf.Vertices, N, 2));
        end
        Surf.Vertices = V;
    end

    if Iter >= IterTol && Verbose
        warning('SurfaceSmooth did not converge within %d iterations. \nLast max point displacement = %f', ...
            IterTol, LastMaxDispl(1));
    elseif Verbose
        fprintf('SurfaceSmooth converged in %d iterations. \nLast max point displacement = %f\n', ...
            Iter, LastMaxDispl(1));
    end
    if Verbose && IterTol > 0
        [FdA, ~, FN] = CalcVertexNormals(Surf);
        FaceCentroidZ = ( Surf.Vertices(Surf.Faces(:, 1), 3) + ...
            Surf.Vertices(Surf.Faces(:, 2), 3) + Surf.Vertices(Surf.Faces(:, 3), 3) ) /3;
        Post.Volume = FaceCentroidZ' * (FN(:, 3) .* FdA);
        Post.Area = sum(FdA);
        fprintf('Total enclosed volume after smoothing: %g\n', Post.Volume);
        fprintf('Relative volume change: %g %%\n', ...
            100 * (Post.Volume - Pre.Volume)/Pre.Volume);
        fprintf('Total area after smoothing: %g\n', Post.Area);
        fprintf('Relative area change: %g %%\n', ...
            100 * (Post.Area - Pre.Area)/Pre.Area);
    end



end

% Much faster than using the Matlab version.
function c = CrossProduct(a, b)
    c = [a(:,2).*b(:,3)-a(:,3).*b(:,2), ...
        a(:,3).*b(:,1)-a(:,1).*b(:,3), ...
        a(:,1).*b(:,2)-a(:,2).*b(:,1)];
end

% ----------------------------------------------------------------------
function [FaceArea, VertexArea, FaceNormals, VertexNormals] = CalcVertexNormals(Surf)
    % Get face and vertex normals and areas

    % First, see if Brainstorm function is present.
    isBst = exist('tess_normals', 'file') == 2;
    
    % Get areas first.
    if isBst
        [FaceArea, VertexArea] = CalcAreas(Surf);
        % Might need to use connectivity matrix if we get bad normals.
        [VertexNormals, FaceNormals] = tess_normals(Surf.Vertices, Surf.Faces); % , VertConn
    else
        [FaceArea, VertexArea, FaceNormals, VertexNormals] = CalcAreas(Surf);
    end
end

%   % Calculate dA normal vectors to each vertex.
%   function [N, VdA, FN, FdA] = CalcVertexNormals(S)
%     N = zeros(nV, 3);
%     % Get face normal vectors with length the size of the face area.
%     FNdA = CrossProduct( (S.Vertices(S.Faces(:, 2), :) - S.Vertices(S.Faces(:, 1), :)), ...
%       (S.Vertices(S.Faces(:, 3), :) - S.Vertices(S.Faces(:, 2), :)) ) / 2;
%     % For vertex normals, add adjacent face normals, then normalize.  Also
%     % add 1/3 of each adjacent area element for vertex area.
%     FdA = sqrt(FNdA(:,1).^2 + FNdA(:,2).^2 + FNdA(:,3).^2);
%     VdA = zeros(nV, 1);
%     for ff = 1:size(S.Faces, 1) % (This is slow.)
%       N(S.Faces(ff, :), :) = N(S.Faces(ff, :), :) + FNdA([ff, ff, ff], :);
%       VdA(S.Faces(ff, :), :) = VdA(S.Faces(ff, :), :) + FdA(ff)/3;
%     end
%     N = bsxfun(@rdivide, N, sqrt(N(:,1).^2 + N(:,2).^2 + N(:,3).^2));
%     FN = bsxfun(@rdivide, FNdA, FdA);
%   end

% % Calculate areas of faces and vertices.
% function [FdA, VdA, FN] = CalcAreas(S)
%     % Get face normal vectors with length the size of the face area.
%     FN = CrossProduct( (S.Vertices(S.Faces(:, 2), :) - S.Vertices(S.Faces(:, 1), :)), ...
%         (S.Vertices(S.Faces(:, 3), :) - S.Vertices(S.Faces(:, 2), :)) ) / 2;
%     FdA = sqrt(FN(:,1).^2 + FN(:,2).^2 + FN(:,3).^2); % no sum for speed
%     if nargout > 2
%         FN = bsxfun(@rdivide, FN, FdA);
%     end
%     % For vertex areas, add 1/3 of each adjacent area element.
%     VdA = zeros(size(S.Vertices, 1), 1);
%     for iV = 1:3
%         VdA(s.Faces(:, iV)) = VdA(s.Faces(:, iV)) + FdA / 3;
%     end
% end

% % Find boundary vertices.
% function isBound = FindBoundary(Faces)
%     nF = size(Faces, 1);
%     Found = logical(nF);
%     Inside = logical(nF);
%     for f = 1:nF
%         for e = 1:3
%             if Found(Faces(f, e), Faces(f, mod(e, 3)+1))
%                 Inside(Faces(f, e), Faces(f, mod(e, 3)+1)) = true;
%             else
%                 Found(Faces(f, e), Faces(f, mod(e, 3)+1)) = true;
%             end
%         end
%     end
%     isBound = Found & ~Inside;
% end


function ViewSurfWithNormals(Vertices, Faces, VNorm, FNorm, VArea, FArea)
    figure;
    hold on;
    axis equal;

    % Create surface patch
    patch('Faces', Faces, 'Vertices', Vertices, ...
        'FaceColor', 'grey', 'EdgeColor', 'k', 'FaceAlpha', 0.6);

    % Compute face centers
    face_centers = mean(reshape(Vertices(Faces', :), [], 3, size(Faces, 2)), 2);
    face_centers = squeeze(face_centers);

    % Scale normals for visualization
    normal_length = 0.05 * mean(range(Vertices)); % Adjust scaling as needed
    FNorm = normal_length * bsxfun(@times, FNorm, FArea) / max(FArea);
    VNorm = normal_length * bsxfun(@times, VNorm, VArea) / max(VArea);

    % Plot face normals (Red)
    quiver3(face_centers(:,1), face_centers(:,2), face_centers(:,3), ...
        FNorm(:,1), FNorm(:,2), FNorm(:,3), ...
        'r', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);

    % Plot vertex normals (Blue)
    quiver3(Vertices(:,1), Vertices(:,2), Vertices(:,3), ...
        VNorm(:,1), VNorm(:,2), VNorm(:,3), ...
        'b', 'LineWidth', 1, 'MaxHeadSize', 0.5);

    % Lighting and view settings
    camlight;
    lighting gouraud;
    view(3);
end


function [FaceArea, VertexArea, FaceNormals, VertexNormals] = CalcAreas(S)
    % Compute face areas, and divides them to assign vertex areas. 
    % Face areas are split into three parts such that each point is assigned to the
    % vertex it is closest to, similar to Voronoi diagrams, using triangle
    % circumcenters. 

    nV = size(S.Vertices, 1);
    nF = size(S.Faces, 1);
    
    % Extract triangle vertex positions
    Vertices = reshape(S.Vertices(S.Faces(:), :), [nF, 3, 3]); % nF, 3 (x,y,z), 3 (iV)
    % Edge vectors, ordered such that each is opposite to the correspondingly indexed
    % vertex (edge 1 is from v2 to v3, opposite vertex 1).
    % circshift +1 moves elements to the next (larger) index, so the last element
    % gets to position 1. So here we're doing, e.g. v3 - v2 in first position.
    Edges = circshift(Vertices, 1, 3) - circshift(Vertices, -1, 3); % nF, 3 (x,y,z), 3 (iE)

    % Get face normal vectors with length the size of the face area.
    FaceNormals = CrossProduct(Edges(:,:,3), Edges(:,:,1)) / 2;
    FaceArea = sqrt(FaceNormals(:,1).^2 + FaceNormals(:,2).^2 + FaceNormals(:,3).^2); % no sum for speed
    if nargout > 2
        FaceNormals = bsxfun(@rdivide, FaceNormals, FaceArea);
    end

    % Edge lengths
    EdgeSq = squeeze(Edges(:,1,:).^2 + Edges(:,2,:).^2 + Edges(:,3,:).^2); % nF, 3 (iE)
    % Circumcenter barycentric weights
    BaryWeights = EdgeSq .* (circshift(EdgeSq, 1, 2) + circshift(EdgeSq, -1, 2) - EdgeSq); % nF, 3 (iE)

    FaceVertAreas = zeros(nF, 3);

    % Process in 4 batches
    % Logical index for faces that have not been processed
    isRemain = true(nF, 1);
    % First three cases: circumcenter outside triangular face, past one of 3 edges
    % This divides the area into two triangles, and one pentagon (or rectangle if
    % original face has a right angle).
    for iLongest = 1:3
        isDo = BaryWeights(:,iLongest) <= 0;
        isRemain = isRemain & ~isDo;
        iSh = circshift(1:3, 1-iLongest); % place iLongest in first position
        % Two vertices of long edge; areas are triangles with right angle
        % -1/4 face area * ratio of adjoining short edge to projection of long edge on that short edge.
        % (show with similar right triangle and edge length ratios) Minus sign because of
        % "dot product" with vectors always making obtuse angle.
        FaceVertAreas(isDo,iSh(2)) = 0.25 * EdgeSq(isDo,iSh(3)) .* FaceArea(isDo,:) ./ -sum(Edges(isDo,:,iSh(1)) .* Edges(isDo,:,iSh(3)), 2);
        FaceVertAreas(isDo,iSh(3)) = 0.25 * EdgeSq(isDo,iSh(2)) .* FaceArea(isDo,:) ./ -sum(Edges(isDo,:,iSh(1)) .* Edges(isDo,:,iSh(2)), 2);
        % Vertex opposite long edge; area has 4 or 5 sides, just assign remaining area.
        FaceVertAreas(isDo,iSh(1)) = FaceArea(isDo,:) - FaceVertAreas(isDo,iSh(2)) - FaceVertAreas(isDo,iSh(3));
    end
    % Last case: circumcenter is inside face, each region is a quadrilateral
    % Normalize weights and scale with half face area
    BaryWeights = BaryWeights ./ (BaryWeights(:,1) + BaryWeights(:,2) + BaryWeights(:,3));
    FaceVertAreas(isRemain,:) = 1/2 * FaceArea(isRemain,:) .* (circshift(BaryWeights(isRemain,:), 1, 2) + circshift(BaryWeights(isRemain,:), -1, 2));

    % Now sum back to single vertex area list
    VertexArea = accumarray(S.Faces(:), FaceVertAreas(:), [nV, 1]);

    % Use areas as weights to average face normals, if requested
    if nargout > 3
        VertexNormals = zeros(nV, 3);
        % Have to do each coordinate (x,y,z) sequentially with accumarray
        for i = 1:3
            % Weight face normals by face vertex area, which we will normalize at the
            % end by dividing by total vertex area. 
            WeightedFaceVertN = bsxfun(@times, FaceVertAreas, FaceNormals(:,i));
            VertexNormals(:,i) = accumarray(S.Faces(:), WeightedFaceVertN(:), [nV, 1]);
        end
        % Normalize for the area weights
        VertexNormals = bsxfun(@rdivide, VertexNormals, VertexArea);
        
        % Final check no NaN
        if any(isnan(VertexNormals))
            error('NaN values in VertexNormals.');
        end
    end
    if any(isnan(VertexArea))
        error('NaN values in VertexArea.');
    end

end
