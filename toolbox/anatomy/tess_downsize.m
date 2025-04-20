function [NewTessFile, iSurface, I, J] = tess_downsize( TessFile, newNbVertices, Method )
% TESS_DOWNSIZE: Reduces the number of vertices in a surface file.
%
% USAGE:  [NewTessFile, iSurface, I, J] = tess_downsize(TessFile, newNbVertices=[ask], Method=[ask]);
% 
% INPUT: 
%    - TessFile      : Full path to surface file to decimate
%    - newNbVertices : Desired number of vertices
%    - Method        : {'reducepatch', 'reducepatch_subdiv', 'iso2mesh', 'iso2mesh_project'}
% OUTPUT:
%    - NewTessFile : Filename of the newly created file
%    - iSurface    : Index of the new surface file
%    - I,J         : Indices of the vertices that were kept (see intersect function)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2008-2022


%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(Method)
    Method = [];
end
if (nargin < 2) || isempty(newNbVertices)
    newNbVertices = [];
end
% File name: string or cell array of strings
MultipleFiles = [];
if iscell(TessFile)
    if (length(TessFile) > 1)
        MultipleFiles = TessFile;
    end
    TessFile = TessFile{1};
end
% Save current modifications
panel_scout('SaveModifications');
% Initialize returned values
NewTessFile = '';
iSurface = [];
I = [];
J = [];


%% ===== ASK FOR MISSING OPTIONS =====
% Get the number of vertices
VarInfo = whos('-file',file_fullpath(TessFile),'Vertices');
oldNbVertices = VarInfo.size(1);
% If new number of vertices was not provided: ask user
if isempty(newNbVertices)
    % Ask user the new number of vertices
    newNbVertices = java_dialog('input', 'New number of vertices:', ...
                                         'Resample surface', [], num2str(oldNbVertices));
    if isempty(newNbVertices)
        return
    end
    % Read user input
    newNbVertices = str2double(newNbVertices);
end
% Check if new number of vertices is valid
if isempty(newNbVertices) || isnan(newNbVertices)
    error('Invalid vertices number');
end
if (newNbVertices >= oldNbVertices)
    NewTessFile = TessFile;
    disp(sprintf('TESS> Surface has %d vertices, cannot downsample to %d vertices.', oldNbVertices, newNbVertices));
    return;
end

% Ask for resampling method
if isempty(Method)
    % Downsize methods strings
    methods_str = {['<HTML><B><U>Matlab''s reducepatch:</U></B><BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - Inhomogeneous mesh: large faces at the top of the gyri<BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - Keeps the atlases and the subjects co-registration'], ...
                   ['<HTML><B>Matlab''s reducepatch + subdivide large faces:</B><BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - The large faces at the top of the gyri are subdivided in three<BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - <U>Deletes</U> the atlases and the subjects co-registration'], ...
                   ['<HTML><B>iso2mesh/CGAL library:</B><BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - Homogeneous mesh: all the faces have similar sizes<BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - <U>Deletes</U> the atlases and the subject co-registration<BR>' ...
                    '&nbsp;&nbsp;&nbsp;| - If the downsample looks dark, right-click > Swap faces']};
        %          ['<HTML><B>iso2mesh/CGAL + project on the original surface:</B><BR>' ...
        %           '&nbsp;&nbsp;&nbsp;| - Homogeneous mesh but possible <U>topological problems</U><BR>' ...
        %           '&nbsp;&nbsp;&nbsp;| - <U>Damages</U> the atlases and the subject co-registration']},

    % Identify textured surfaces (color info is present) and show available methods for them
    VarInfo = whos('-file',file_fullpath(TessFile), 'Color');
    if ~isempty(VarInfo) && all(VarInfo.size ~= 0)
        methods_str = methods_str(1); % Inhomogeneous mesh
    end
    % Ask method
    ind = java_dialog('radio', 'Select the resampling method:', 'Resample surface', [], methods_str, 1);
    if isempty(ind)
        return
    end
    % Select corresponding method name
    switch (ind)
        case 1,  Method = 'reducepatch';
        case 2,  Method = 'reducepatch_subdiv';
        case 3,  Method = 'iso2mesh';
        case 4,  Method = 'iso2mesh_project';
    end
end


%% ===== PROCESS MULTIPLE FILES =====
if ~isempty(MultipleFiles)
    for i = 1:length(MultipleFiles)
        [NewTessFile, iSurface, I, J] = tess_downsize( MultipleFiles{i}, newNbVertices, Method );
    end
    return;
end
    
%% ===== LOAD FILE =====
% Progress bar
bst_progress('start', 'Resample surface', 'Loading file...');
% Load file
TessMat = in_tess_bst(TessFile);
% Prepare variables
TessMat.Faces    = double(TessMat.Faces);
TessMat.Vertices = double(TessMat.Vertices);
TessMat.Color    = double(TessMat.Color);
dsFactor = newNbVertices / size(TessMat.Vertices, 1); 


%% ===== RESAMPLE =====
bst_progress('start', 'Resample surface', ['Resampling surface: ' TessMat.Comment '...']);
% Resampling methods
switch (Method)
    % ===== REDUCEPATCH =====
    % Matlab's reducepatch
    case 'reducepatch'
        % Reduce number of vertices
        [NewTessMat.Faces, NewTessMat.Vertices] = reducepatch(TessMat.Faces, TessMat.Vertices, dsFactor);
        % Find the vertices that were kept by reducepatch
        [tmp, I, J] = intersect(TessMat.Vertices, NewTessMat.Vertices, 'rows');
        % Re-order the vertices so that they are in the same order in the output surface
        [I, iSort] = sort(I);
        NewTessMat.Vertices = TessMat.Vertices(I,:);
        if ~isempty(TessMat.Color)
            NewTessMat.Color = TessMat.Color(I,:);
        end
        J = J(iSort);
        % Re-order the vertices in the faces
        iSortFaces(J) = 1:length(J);
        NewTessMat.Faces = iSortFaces(NewTessMat.Faces);
        MethodTag = '';
        % Set the 
        J = (1:length(J))';

    % ===== REDUCEPATCH + SUBDIV =====
    % Reducepatch + subdivide the large faces into smaller triangles
    case 'reducepatch_subdiv'
        % Reduce number of vertices
        [NewTessMat.Faces, NewTessMat.Vertices] = reducepatch(TessMat.Faces, TessMat.Vertices, dsFactor * 0.94);
        % Find the vertices that were kept by reducepatch
        [tmp, I, J] = intersect(TessMat.Vertices, NewTessMat.Vertices, 'rows');

        % Progress bar
        bst_progress('start', 'Resample surface', 'Analyzing surface...');
        % Calulate face areas and perimeter
        FaceArea  = tess_area(NewTessMat.Vertices, NewTessMat.Faces);
        % Vertex connectivity, normals, Curvature
        VertConn    = tess_vertconn(NewTessMat.Vertices, NewTessMat.Faces);
        [VertNormals, FaceNormals] = tess_normals(NewTessMat.Vertices, NewTessMat.Faces, VertConn);
        Curvature   = tess_curvature(NewTessMat.Vertices, VertConn, VertNormals);
        % Get center of each face
        FaceCenter = (NewTessMat.Vertices(NewTessMat.Faces(:,1),:) + NewTessMat.Vertices(NewTessMat.Faces(:,2),:) + NewTessMat.Vertices(NewTessMat.Faces(:,3),:)) ./ 3;
        % Get center of mass of the vertices
        SurfCenter = mean(NewTessMat.Vertices, 1);
        % Get large faces to subdivide (perimeter or area)
        iBigFaces = find((sum(FaceNormals .* bst_bsxfun(@minus, FaceCenter, [0 0 SurfCenter(3)]), 2) > 0.04) & ...  % Faces pointing outwards (normal in the same direction as position vector)
                         (sum(Curvature(NewTessMat.Faces) > 0, 2) >= 2) & ...       % Curvature has to be > 0
                         (FaceArea > mean(FaceArea) + 1*std(FaceArea)));            % Face area threshold
        % If there are not enough points to add (white matter): perform search on all the surface
        if (length(iBigFaces) < .75 * (newNbVertices - size(NewTessMat.Vertices,1)))
            iBigFaces = find(FaceArea > mean(FaceArea) + 2.5 * std(FaceArea));
        end
        % Display message
        disp(sprintf('BST> Subdividing %d faces from the %d faces generated by reducepatch.', length(iBigFaces), length(NewTessMat.Faces)));
        
% figure;
        % Loop over each face
        iRmFaces = [];
        bst_progress('start', 'Resample surface', 'Subdividing large faces...', 1, length(iBigFaces));
        for i = 1:length(iBigFaces)
            bst_progress('inc', 1);
            % Get the face and, the positions of its vertices, and the center of the face
            f = NewTessMat.Faces(iBigFaces(i),:);
            v = NewTessMat.Vertices(f,:);
            c = mean(v,1);
            
            % === BOUNDING BOX ===
            % Get maximum distance to consider around the face
            dmax = 1.2 * max(sqrt(sum(bst_bsxfun(@minus, v, c) .^ 2, 2)));
            % Select the vertices of the high-res surface that in a small sphere around the center of the face
            iVertBox = find(sum(bst_bsxfun(@minus, TessMat.Vertices, c) .^ 2, 2) < dmax.^2);
          
%             % Display selection
%             cla; hold on;
%             plot3(TessMat.Vertices(iVertBox,1), TessMat.Vertices(iVertBox,2), TessMat.Vertices(iVertBox,3), '.', 'tag', 'ptri');
%             plot3(c(1), c(2), c(3), '*y');
%             patch('Vertices', v, 'Faces', [1 2 3], 'FaceColor', 'r');
%             axis vis3d equal; drawnow; rotate3d on; 

            % Get the vertices for the target face in the hi-resolution surface
            s1 = find(I(J == f(1)) == iVertBox);
            s2 = find(I(J == f(2)) == iVertBox);
            s3 = find(I(J == f(3)) == iVertBox);
            % Error?
            if isempty(s1) || isempty(s2) || isempty(s3)
                disp(sprintf('BST> Cannot subdivide big face #%d (box too small), skipping...', i));
                continue;
            end
            % Get a subset of the vertex connectivity matrix
            boxVertConn = TessMat.VertConn(iVertBox, iVertBox);
            
            % === FIND PATH TO COMMON NODES ===
            % Expand areas around all the vertices until they all overlap
            iter_max = 20;
            iter = 1;
            sx = [];
            while isempty(sx) && (iter < iter_max)
                s1 = union(s1, find(any(boxVertConn(s1,:),1)));
                s2 = union(s2, find(any(boxVertConn(s2,:),1)));
                s3 = union(s3, find(any(boxVertConn(s3,:),1)));
                sx = intersect(intersect(s1, s2), s3);
                iter = iter + 1;
            end
            
            % Expand areas around all the vertices until they all overlap
            iter_max = 50;
            iter = 1;
            istop = 0;
            d1 = 0;
            d2 = 0;
            d3 = 0;
            while (istop < 2) && (iter <= iter_max)
                % Grow from vertex #1
                i1 = find(any(boxVertConn(s1,:),1));
                s1 = [s1, setdiff(i1,s1)];
                d1 = [d1, i1*0+iter];
                % Grow from vertex #2
                i2 = find(any(boxVertConn(s2,:),1));
                s2 = [s2, setdiff(i2,s2)];
                d2 = [d2, i2*0+iter];
                % Grow from vertex #1
                i3 = find(any(boxVertConn(s3,:),1));
                s3 = [s3, setdiff(i3,s3)];
                d3 = [d3, i1*0+iter];
                % If all the vertices are in the region: stop immediately
                if (length(s1) == length(iVertBox)) && (length(s2) == length(iVertBox)) && (length(s3) == length(iVertBox))
                    istop = 10;
                % Do one more iterations after all the vertices are identified
                elseif (istop > 0) || (all(ismember([s2 s3],s1)) && all(ismember([s1 s3],s2)) && all(ismember([s1 s2],s3)))
                    istop = istop + 1;
                else
                    iter = iter + 1;
                end
            end
            % If an error occured: skip face
            if (iter > iter_max)
                disp(sprintf('BST> Cannot subdivide big face #%d (more than %d nodes distance), skipping...', i, iter_max));
                continue;
            end
            % Take intersection of the three regions
            [sx,ix,jx] = intersect(s1, s2);
            d1 = d1(ix);
            d2 = d2(jx);
            [sx,ix,jx] = intersect(sx, s3);
            d1 = d1(ix);
            d2 = d2(ix);
            d3 = d3(jx);
            dx = d1 + d2 + d3;
            
%             delete(findobj(0, 'tag', 'ptri')); plot3(TessMat.Vertices(iVertBox(s1),1), TessMat.Vertices(iVertBox(s1),2), TessMat.Vertices(iVertBox(s1),3), '.g', 'tag', 'ptri');
%             delete(findobj(0, 'tag', 'ptri')); plot3(TessMat.Vertices(iVertBox(s2),1), TessMat.Vertices(iVertBox(s2),2), TessMat.Vertices(iVertBox(s2),3), '.b', 'tag', 'ptri');
%             delete(findobj(0, 'tag', 'ptri')); plot3(TessMat.Vertices(iVertBox(s3),1), TessMat.Vertices(iVertBox(s3),2), TessMat.Vertices(iVertBox(s3),3), '.y', 'tag', 'ptri');

            % === SELECT VERTICES INSIDE THE FACE ===
            % Convert sx back to full indices list
            sx = iVertBox(sx);
            % Keep only the ones that project on the face INSIDE the triangle
            isInside = bst_intriangle(v(1,:), v(2,:), v(3,:), TessMat.Vertices(sx,:));
            sx = sx(isInside);
            dx = dx(isInside);
            if isempty(sx)
                disp(sprintf('BST> Cannot subdivide big face #%d (no candidate in the triangle), skipping...', i));
                continue;
            end
            % plot3(TessMat.Vertices(sx,1), TessMat.Vertices(sx,2), TessMat.Vertices(sx,3), '.y');

            % === SELECT VERTICES INSIDE THE FACE ===
            % Keep the closest path to all the nodes
            pathLength = min(dx);
            sx = sx(dx <= pathLength + 2);
%             plot3(TessMat.Vertices(sx,1), TessMat.Vertices(sx,2), TessMat.Vertices(sx,3), '.y');

            % === KEEP THE MOST CENTRAL LOCATION ===
            % Find the closest to the face center
            [d,imin] = min(sqrt(sum(bst_bsxfun(@minus, TessMat.Vertices(sx,:), c) .^ 2, 2)));
            sx = sx(imin);
            % Make sure it is not already in the destination surface
            if ismember(sx, I)
                disp(sprintf('BST> Cannot subdivide big face #%d (vertex already selected), skipping...', i));
                continue;
            end
%             plot3(TessMat.Vertices(sx,1), TessMat.Vertices(sx,2), TessMat.Vertices(sx,3), 'og');

            % === ADD VERTEX ===
            % Add the vertex to the list of vertices
            NewTessMat.Vertices = [NewTessMat.Vertices; c];
            iVertNew = size(NewTessMat.Vertices,1);
            I(end+1) = sx;
            J(end+1) = iVertNew;
            % Add the three new faces to the new surface
            NewTessMat.Faces = [NewTessMat.Faces; ...
                                f(1), f(2), iVertNew; ...
                                f(1), iVertNew, f(3); ...
                                iVertNew, f(2), f(3)];
            iRmFaces(end+1) = iBigFaces(i);
        end
        % Verify the unicity of the vertex selection
        if (length(I) ~= length(unique(I)))
            disp('BST> Error: The same vertex was selected multiple times in the high-resolution brain.');
            disp('BST> Using the basic reducepatch results instead...');
            % Call reducepatch only
            [NewTessFile, iSurface, I, J] = tess_downsize( TessFile, newNbVertices, 'reducepatch');
            return;
        end
        % Remove the deleted faces
        NewTessMat.Faces(iRmFaces,:) = [];
        MethodTag = '_subdiv';
        I = [];
        J = [];
        
    % ===== ISO2MESH =====
    % Using iso2mesh toolbox: good surfaces with equal triangle sizes, but no 
    % correspondence of vertices in the original surface, and impossible to reconstruct the info
    case 'iso2mesh'
        % Reduce number of vertices
        NewTessMat = iso2mesh_resample(TessMat, dsFactor);
        if isempty(NewTessMat)
            return;
        end
        % Do not return any correspondence with the original vertices
        MethodTag = '_iso2mesh';
        I = [];
        J = [];
        
        
    % ===== ISO2MESH + PROJECT =====
    % Using iso2mesh toolbox: good surfaces with equal triangle sizes, but no 
    % correspondence of vertices in the original surface, and impossible to reconstruct the info
    case 'iso2mesh_project'
        % Reduce number of vertices
        NewTessMat = iso2mesh_resample(TessMat, dsFactor);
        if isempty(NewTessMat)
            return;
        end
        Vertices = NewTessMat.Vertices;
        Faces    = NewTessMat.Faces;
        % Progress bar
        bst_progress('start', 'Resample surface', 'Analyzing surface...');
        % Calculate new normals
        newVertNormals = tess_normals(Vertices, Faces);
        % Remove duplicate vertices for Delaunay tesselation
        [delaunayVert, iSrc, iDest] = unique(TessMat.Vertices, 'rows');
        % Get the nearest neighbors
        I = bst_nearest(delaunayVert, Vertices);
        % Convert back to initial indices
        I = iSrc(I);
        % Compute the scalar product of the norms between the nearest neighbors and all the original vertices
        nv = size(TessMat.Vertices, 1);
        P = newVertNormals(:,1) .* TessMat.VertNormals(I) + ...
            newVertNormals(:,2) .* TessMat.VertNormals(nv + I) + ...
            newVertNormals(:,3) .* TessMat.VertNormals(2*nv + I);
        % Values with negative P are most likely on the other side of the sulcus
        iErr = find(P < -0.6);
        iKeep = find(P >= -0.6);
        
        % Loop on those points to fix them one by one with a different neighbor
        bst_progress('start', 'Resample surface', 'Fixing surface...', 1, length(iErr));
        for i = 1:length(iErr)
            bst_progress('inc', 1);
            % Calculate the scalar product of the normals of the current vertex with all the original vertices
            prodNorm = sum(bst_bsxfun(@times, newVertNormals(iErr(i),:), TessMat.VertNormals), 2);
            % Get indices for which the scalar product is positive
            iProdOk = find(prodNorm > -0.6);
            % Remove the vertices that are already in the mesh
            iProdOk = intersect(iProdOk, iKeep);
            % Find the nearest neighbor
            [m,iFix] = min(sum(bst_bsxfun(@minus, Vertices(iErr(i),:), TessMat.Vertices(iProdOk,:)) .^ 2, 2));
            I(iErr(i)) = iProdOk(iFix);
            % Add the corrected vertex to the list of valid vertices
            iKeep(end+1) = iProdOk(iFix);
        end

        % Find repeated vertices
        if (length(unique(I)) ~= length(I))
            disp('BST> ERROR: Found some duplicated vertices. Surface topology is incorrect...');
        end
        % Replace vertices with their nearest neighbor in the original surface
        Vertices = TessMat.Vertices(I,:);
        % Output structure
        NewTessMat.Faces    = Faces;
        NewTessMat.Vertices = Vertices;
        MethodTag = '_iso2mesh_proj';
end


%% ===== REMOVE FOLDED FACES =====
% Find equal faces
tmpFaces = sort(NewTessMat.Faces, 2);
[tmpFaces, iFaces] = unique(tmpFaces, 'rows');
% If there are some folded faces: delete them
if (length(iFaces) ~= size(NewTessMat.Faces,1))
    iRmFaces = setdiff(1:size(NewTessMat.Faces,1), iFaces);
    NewTessMat.Faces(iRmFaces,:) = [];
end


%% ===== CREATE NEW SURFACE STRUCTURE =====
% Build new filename and Comment
[filepath, filebase, fileext] = bst_fileparts(file_fullpath(TessFile));
NewComment = TessMat.Comment;
% Remove previous '_nbvertV' tags from Comment field
if (NewComment(end) == 'V')
    iUnderscore = strfind(NewComment, '_');
    if isempty(iUnderscore)
        iUnderscore = strfind(NewComment, ' ');
    end
    if ~isempty(~iUnderscore)
        NewComment = NewComment(1:iUnderscore(end)-1);
    end
end
% Remove previous '_nbvertV' tags from filename
if (filebase(end) == 'V')
    iUnderscore = strfind(filebase, '_');
    filebase = filebase(1:iUnderscore(end)-1);
end
% Add a '_nbvertV' tag
NewTessFile = file_unique(bst_fullfile(filepath, sprintf('%s_%dV%s', filebase, newNbVertices, fileext)));
NewComment  = sprintf('%s%s_%dV', NewComment, MethodTag, size(NewTessMat.Vertices,1));

% As per MMII convention - there should be one tessellation file per envelope
% A downsized version of e.g. a cortex is considered as a different envelope 
% ans is therefore saved in a separate tessellation file than the original.
NewTessMat.Comment  = NewComment;
% Copy history field
if isfield(TessMat, 'History')
    NewTessMat.History = TessMat.History;
end
% History: Downsample surface
NewTessMat = bst_history('add', NewTessMat, 'downsample', sprintf('Downsample surface: %d -> %d vertices', oldNbVertices, newNbVertices));


%% ===== DOWNSAMPLE SCOUTS =====
% Existing atlases
if isfield(TessMat, 'Atlas') && ~isempty(TessMat.Atlas) && ~isempty(I)
    % Copy scout structure
    NewTessMat.Atlas = TessMat.Atlas;
    % Loop on all the scouts, and keep only those vertices
    for iAtlas = 1:length(NewTessMat.Atlas)
        iRmScout = [];
        for iScout = 1:length(NewTessMat.Atlas(iAtlas).Scouts)
            % Replace the old vertices index with the new ones
            [a,b,c] = intersect(NewTessMat.Atlas(iAtlas).Scouts(iScout).Vertices, I);
            NewTessMat.Atlas(iAtlas).Scouts(iScout).Vertices = reshape(sort(J(c)), 1, []);
            % If scout has no vertex left: tag for deletion
            if isempty(NewTessMat.Atlas(iAtlas).Scouts(iScout).Vertices)
                iRmScout(end+1) = iScout;
            end
        end
        % Remove empty scouts
        if ~isempty(iRmScout)
            NewTessMat.Atlas(iAtlas).Scouts(iRmScout) = [];
        end
        % Set scouts seeds
        NewTessMat.Atlas(iAtlas).Scouts = panel_scout('SetScoutsSeed', NewTessMat.Atlas(iAtlas).Scouts, NewTessMat.Vertices);
    end
end
% Selected atlas
if isfield(TessMat, 'iAtlas') && ~isempty(TessMat.iAtlas)
    NewTessMat.iAtlas = TessMat.iAtlas;
end


%% ===== DOWNSAMPLE REGISTRATION MAPS =====
% FreeSurfer spheres
if isfield(TessMat, 'Reg') && isfield(TessMat.Reg, 'Sphere') && isfield(TessMat.Reg.Sphere, 'Vertices') && ~isempty(TessMat.Vertices) && (length(TessMat.Reg.Sphere.Vertices) == length(TessMat.Vertices))
    % Keep only the selected indices
    if ~isempty(I)
        newSphVert = TessMat.Reg.Sphere.Vertices(I,:);
        NewTessMat.Reg.Sphere.Vertices = newSphVert;
    else
        NewTessMat.Reg.Sphere = [];
    end
end

if isfield(TessMat, 'Reg') && isfield(TessMat.Reg, 'SphereLR') && isfield(TessMat.Reg.SphereLR, 'Vertices') && ~isempty(TessMat.Vertices) && (length(TessMat.Reg.SphereLR.Vertices) == length(TessMat.Vertices))
    % Keep only the selected indices
    if ~isempty(I)
        newSphVert = TessMat.Reg.SphereLR.Vertices(I,:);
        NewTessMat.Reg.SphereLR.Vertices = newSphVert;
    else
        NewTessMat.Reg.SphereLR = [];
    end
end


% BrainSuite squares
if isfield(TessMat, 'Reg') && isfield(TessMat.Reg, 'Square') && isfield(TessMat.Reg.Square, 'Vertices') && ~isempty(TessMat.Reg.Square.Vertices) && (length(TessMat.Reg.Square.Vertices) == length(TessMat.Vertices))
    % Keep only the selected indices
    if ~isempty(I)
        newSqVert = TessMat.Reg.Square.Vertices(I,:);
        NewTessMat.Reg.Square.Vertices = newSqVert;
    else
        NewTessMat.Reg.Square = [];
    end
    NewTessMat.Reg.AtlasSquare=TessMat.Reg.AtlasSquare;
end



%% ===== UPDATE DATABASE =====
% Save downsized surface file
bst_save(NewTessFile, NewTessMat, 'v7');
% Make output filename relative
NewTessFile = file_short(NewTessFile);
% Get subject
[sSubject, iSubject] = bst_get('SurfaceFile', TessFile);
% Register this file in Brainstorm database
iSurface = db_add_surface(iSubject, NewTessFile, NewComment);

% Close progress bar
bst_progress('stop');

end


%% ===== iso2mesh_resample =====
% Resample a surface using iso2mesh/CGAL library
% Author: Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
function NewTessMat = iso2mesh_resample(TessMat, dsFactor)
    % Install/load iso2mesh plugin
    isInteractive = 1;
    [isInstalled, errInstall] = bst_plugin('Install', 'iso2mesh', isInteractive);
    if ~isInstalled
        error('Plugin "iso2mesh" not available.');
    end
    % Running iso2mesh routine
    [Vertices,Faces] = meshresample(TessMat.Vertices, TessMat.Faces, dsFactor);
    % Error handling
    if isempty(Vertices) || isempty(Faces)
        error(['Iso2mesh failed downsampling this surface:' 10 'See Matlab command window for more information.']);
    end
    % Report results
    NewTessMat.Vertices = Vertices;
    NewTessMat.Faces    = Faces;
    % Swap faces
    % NewTessMat.Faces = NewTessMat.Faces(:,[2 1 3]);
end


% OLD VERSION: FUNCTION cgalsimp2 WAS INCLUDED IN BRAINSTORM DISTRIBUTION 
% %% ===== iso2mesh_resample =====
% % Resample a surface using iso2mesh/CGAL library
% % Author: Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
% function NewTessMat = iso2mesh_resample(TessMat, dsFactor, nCall)
%     % First call
%     if (nargin < 3) || isempty(nCall)
%         nCall = 1;
%     end
%     % Get the executable name
%     switch(bst_get('OsType'))
%         case {'linux32', 'linux64'}, exePath = 'cgalsimp2.mexglx';
%         case 'mac32',                exePath = 'cgalsimp2.mexmaci';
%         case 'mac64',                exePath = 'cgalsimp2.mexmaci64';
%         case {'win32', 'win64'},     exePath = 'cgalsimp2.exe';
%         otherwise, error('CGAL executable is not available on your OS.');
%     end
%     % Add the full path
%     exePath = bst_fullfile(bst_get('BrainstormHomeDir'), 'external', 'iso2mesh', exePath);
%     % Get temporary mesh file
%     fin  = file_unique(bst_fullfile(bst_get('BrainstormTmpDir'), 'mesh_in.off'));
%     fout = file_unique(bst_fullfile(bst_get('BrainstormTmpDir'), 'mesh_out.off'));
%     % Save input file
%     out_tess_off(TessMat, fin);
%     % Execute cgalsimp2 with a system call
%     [status, result] = system(['"' exePath '" "' fin '" ' num2str(dsFactor) ' "' fout '"']);
%     if status
%         file_delete(fin, 1);
%         error(['CGAL failed downsampling this surface:' 10 result]);
%     end
%     % Read results
%     NewTessMat = in_tess_off(fout);
%     % Delete mesh files
%     file_delete({fin, fout}, 1);
%     % If no results are produced: Fix the surface and call it again
%     if isempty(NewTessMat.Vertices)
%         % If it is already the second call
%         if (nCall > 2)
%             error('CGAL failed downsampling this surface.');
%         end
%         % Remove duplicate faces
%         TessMat.Faces = removedupelem(TessMat.Faces);
%         % Remove isolated nodes
%         [TessMat.Vertices, TessMat.Faces] = removeisolatednode(TessMat.Vertices, TessMat.Faces);
%         % Run again the function
%         NewTessMat = iso2mesh_resample(TessMat, dsFactor, nCall + 1);
%     end
% end



