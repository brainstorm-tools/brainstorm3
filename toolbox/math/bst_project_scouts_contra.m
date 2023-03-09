function sAtlas = bst_project_scouts_contra(srcSurfFile, sAtlas, sMri, GridLoc)
% BST_PROJECT_SCOUTS_CONTRA: Project surface and volume scouts from left to right hemisphere and viceversa
%
% USAGE:  sAtlas = bst_project_scouts_contra(srcSurfFile, sAtlas)                 % Surface scouts
%         sAtlas = bst_project_scouts_contra(srcSurfFile, sAtlas, sMri, GridLoc)  % Volume scouts
%
% PROJECT SURFACE SCOUTS REFERENCE:
%    - Requires the FreeSurfer registered contralateral spheres: Option -contrasurfreg in FreeSurfer 6.X
%      See tutorial: https://neuroimage.usc.edu/brainstorm/Tutorials/LabelFreeSurfer#Contralateral_registration
%    - Use the contralateral spheres if available at the subject level: sSurf.Reg.SphereLR.Vertices
%    - Otherwise, use the registered spheres available in the template anatomy (available in ICBM152_2022):
%      1) project scouts on anatomy template (high-resolution cortex surface)
%      2) project left-right in the template anatomy
%      3) project back to the subject surface
%
% PROJECT VOLUME SCOUTS REFERENCE:
%    - Contralateral projection is based on MNI-coordinates
%    - If the original scout has less than 4 vertices, the projected scout consists in the set of projected vertices
%    - Else, the boundary of the original scout vertices is projected and used find the projected scout
%
%
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
% Authors: Edouard Delaire, 2022
%          Francois Tadel, 2022-2023
%          Raymundo Cassani, 2023

isVolume = 0;
% Check for volume defined Atlas
if nargin > 3 && ~isempty(sMri) && ~isempty(GridLoc)
    isVolume = 1;
end

% Load surface
sSurf = in_tess_bst(srcSurfFile);

% ===== PROJECT SURFACE SCOUTS =====
if ~isVolume
    % Number of nearest neighbors in interpolation between spheres
    nbNeighbors = 8;
    % Signature string for the current transformation
    Signature_LR = sprintf('%s%d_LR', srcSurfFile, length(sSurf.Vertices));


    % ===== COMPUTE INTERPOLATION =====
    % Try to get an existing valid interpolation matrix
    if isfield(sSurf, 'tess2tess_interp') && all(isfield(sSurf.tess2tess_interp, {'Signature_LR', 'Wmat_LR', 'Wmat_RL'})) && ...
            strcmpi(sSurf.tess2tess_interp.Signature_LR, Signature_LR) && ~isempty(sSurf.tess2tess_interp.Wmat_LR)
        % Identify left and right hemispheres
        [rH, lH]  = tess_hemisplit(sSurf);
        % Reuse saved interpolations
        Wmat_RL = sSurf.tess2tess_interp.Wmat_RL;
        Wmat_LR = sSurf.tess2tess_interp.Wmat_LR;
        defSurfFile = [];

    % Check for contralateral surfaces in subject
    elseif isfield(sSurf, 'Reg') && isfield(sSurf.Reg, 'SphereLR') && isfield(sSurf.Reg.SphereLR, 'Vertices') && (size(sSurf.Reg.SphereLR.Vertices, 1) == size(sSurf.Vertices, 1))
        % Identify left and right hemispheres
        [rH, lH]  = tess_hemisplit(sSurf);
        % Pre-compute WMAT directly between left and right
        Wmat_RL = bst_shepards(sSurf.Reg.Sphere.Vertices(lH, : ), sSurf.Reg.SphereLR.Vertices(rH, : ),  nbNeighbors, 0);
        Wmat_LR = bst_shepards(sSurf.Reg.Sphere.Vertices(rH, : ), sSurf.Reg.SphereLR.Vertices(lH, : ),  nbNeighbors, 0);
        % Save interpolation matrices
        sSurf.tess2tess_interp.Wmat_LR      = Wmat_LR;
        sSurf.tess2tess_interp.Wmat_RL      = Wmat_RL;
        sSurf.tess2tess_interp.Signature_LR = Signature_LR;
        bst_save(file_fullpath(srcSurfFile), sSurf, 'v7');
        defSurfFile = [];

    % Check for contralateral surfaces in template: 
    % If available, 1) project scouts on template, 2) project left-right, 3) project back to subject
    else
        % Get default anatomy from the protocol
        sSubjectDef = bst_get('Subject', 0);
        % If input is the low-resolution cortex
        if ~isempty(strfind(srcSurfFile, '_low'))
            defCortexFile = 'tess_cortex_pial_low.mat';
        else
            defCortexFile = 'tess_cortex_pial_high.mat';
        end
        % Get high-resolution cortex surface
        iCortexDef = find(~cellfun(@(c)isempty(strfind(c, defCortexFile)), {sSubjectDef.Surface.FileName}));
        if isempty(iCortexDef)
            error(['No registered contralateral spheres available for this cortex surface.' 10 ...
                'No cortex surface available in default anatomy: ' defCortexFile]);
        end
        defSurfFile = sSubjectDef.Surface(iCortexDef(1)).FileName;

        % Load cortex surface
        sSurfDef = in_tess_bst(defSurfFile);
        % Check for contralateral surfaces in subject
        if ~isfield(sSurfDef, 'Reg') || ~isfield(sSurfDef.Reg, 'SphereLR') || ~isfield(sSurfDef.Reg.SphereLR, 'Vertices') || (size(sSurfDef.Reg.SphereLR.Vertices, 1) ~= size(sSurfDef.Vertices, 1))
            error(['No registered contralateral spheres available for this cortex surface.' 10 ...
                'No registered contralateral spheres available in the default anatomy.' 10 ... 
                'See FreeSurfer tutorial for computing contralateral registration: ' 10 ...
                'https://neuroimage.usc.edu/brainstorm/Tutorials/LabelFreeSurfer']);
        end
        % Display warning
        disp([10 'BST> WARNING: Using contralateral registration from the template anatomy.' 10 ...
              'BST>          For faster and more accurate results, consider computing the' 10 ...
              'BST>          contralateral registration for each subject using FreeSurfer.' 10 ...
              'BST>          https://neuroimage.usc.edu/brainstorm/Tutorials/LabelFreeSurfer' 10]);

        % Identify left and right hemispheres
        [rH, lH]  = tess_hemisplit(sSurfDef);
        % Signature string for the current transformation
        SignatureDef_LR = sprintf('%s%d_LR', defSurfFile, length(sSurfDef.Vertices));

        % Try to get an existing valid left-right interpolation matrix in the template surface
        if isfield(sSurfDef, 'tess2tess_interp') && all(isfield(sSurfDef.tess2tess_interp, {'Signature_LR', 'Wmat_LR', 'Wmat_RL'})) && ...
                strcmpi(sSurfDef.tess2tess_interp.Signature_LR, SignatureDef_LR) && ~isempty(sSurfDef.tess2tess_interp.Wmat_LR)
            Wmat_RL = sSurfDef.tess2tess_interp.Wmat_RL;
            Wmat_LR = sSurfDef.tess2tess_interp.Wmat_LR;
        % Otherwise, compute interpolation
        else
            % Compute interpolation matrices between left and right hemispheres
            Wmat_RL = bst_shepards(sSurfDef.Reg.Sphere.Vertices(lH, : ), sSurfDef.Reg.SphereLR.Vertices(rH, : ),  nbNeighbors, 0);
            Wmat_LR = bst_shepards(sSurfDef.Reg.Sphere.Vertices(rH, : ), sSurfDef.Reg.SphereLR.Vertices(lH, : ),  nbNeighbors, 0);
            % Save interpolations
            sSurfDef.tess2tess_interp.Wmat_LR      = Wmat_LR;
            sSurfDef.tess2tess_interp.Wmat_RL      = Wmat_RL;
            sSurfDef.tess2tess_interp.Signature_LR = SignatureDef_LR;
            bst_save(file_fullpath(defSurfFile), sSurfDef, 'v7');
        end
    end

    % ===== PROJECT TO TEMPLATE =====
    if ~isempty(defSurfFile)
        [nScoutProj, sSurfDef, sAtlas] = bst_project_scouts(srcSurfFile, defSurfFile, sAtlas, 0, 0);
        if (nScoutProj == 0)
            error('Cannot project the scouts to the template cortex surface.');
        end
    end

    % ===== PROCESS ATLAS/SCOUTS =====
    for iAtlas = 1:length(sAtlas)
        for iScout = 1:length(sAtlas(iAtlas).Scouts)
            % Find scout indices in left OR right hemisphere
            isLeft = ~isempty(intersect(lH,  sAtlas(iAtlas).Scouts(iScout).Vertices));
            isRight = ~isempty(intersect(rH, sAtlas(iAtlas).Scouts(iScout).Vertices));
            if isRight && ~isLeft
                Wmat =  Wmat_RL;
                iVertHemi = lH;
                [~, sScout_Vertices] = intersect(rH, sAtlas(iAtlas).Scouts(iScout).Vertices);
            elseif isLeft && ~isRight
                Wmat =  Wmat_LR;
                iVertHemi = rH;
                [~, sScout_Vertices] = intersect(lH, sAtlas(iAtlas).Scouts(iScout).Vertices);
            else
                bst_error('The scout should contain only left or right vertices.');
                return;
            end

            % Project scouts one by one and keep for each vertex only the maximum probability
            % Vertex map on the original surface
            vMap                    = zeros(size(Wmat, 2),1);
            vMap(sScout_Vertices)   = 1;

            % Project to destination surface
            vMapProj = full(Wmat * vMap);
            % Keep the highest values, in order to obtain the same number of vertices as the original scout
            [~, NewIndex] = bst_maxk(vMapProj, length(sScout_Vertices));
            newVertices = iVertHemi(sort(NewIndex(:)'));
            % Save in input structure
            sAtlas(iAtlas).Scouts(iScout).Vertices = newVertices;
            sAtlas(iAtlas).Scouts(iScout) = panel_scout('SetScoutsSeed', sAtlas(iAtlas).Scouts(iScout), sSurf.Vertices);

            % Update label and region
            % Remove hemisphere suffix if present
            sAtlas(iAtlas).Scouts(iScout).Label = regexprep(sAtlas(iAtlas).Scouts(iScout).Label, ' (L|R)$', '');
            if isRight
                sAtlas(iAtlas).Scouts(iScout).Label = [sAtlas(iAtlas).Scouts(iScout).Label ' L'];
                sAtlas(iAtlas).Scouts(iScout).Region = strrep(sAtlas(iAtlas).Scouts(iScout).Region, 'R', 'L');
            else
                sAtlas(iAtlas).Scouts(iScout).Label = [sAtlas(iAtlas).Scouts(iScout).Label ' R'];
                sAtlas(iAtlas).Scouts(iScout).Region = strrep(sAtlas(iAtlas).Scouts(iScout).Region, 'L', 'R');
            end
        end
    end

    % ===== PROJECT BACK TO SUBJECT =====
    if ~isempty(defSurfFile)
        [nScoutProj, ~, sAtlas] = bst_project_scouts(defSurfFile, srcSurfFile, sAtlas, 0, 0);
        if (nScoutProj == 0)
            error('Cannot project the scouts to the subject surface.');
        end
    end

% ===== PROJECT VOLUME SCOUTS =====
else
    % ===== PROCESS ATLAS/SCOUTS =====
    for iAtlas = 1:length(sAtlas)
        for iScout = 1:length(sAtlas(iAtlas).Scouts)
            disp(sAtlas(iAtlas).Scouts(iScout).Label)
            nOrgVertices = length(sAtlas(iAtlas).Scouts(iScout).Vertices);
            % SCS coordinates
            scs_coords = GridLoc(sAtlas(iAtlas).Scouts(iScout).Vertices, :);
            % Convert to MNI coordinates
            mni_coords = cs_convert(sMri, 'scs', 'mni', scs_coords);
            % Scout hemisphere
            isRight = sum(mni_coords(:,1)) > 0;
            % Flip MNI coordinates on the X axis
            mni_coords(:, 1) = -mni_coords(:, 1);
            % Convert back to SCS
            scs_coords = cs_convert(sMri, 'mni', 'scs', mni_coords);
            if  nOrgVertices < 4
                % Find closets grid point to projected points
                vi = zeros(1, nOrgVertices);
                for iVertex = 1 : nOrgVertices
                    % Compute the distance from each point to the seed
                    [tmp, I] = min(sqrt(sum(bst_bsxfun(@minus, GridLoc, scs_coords(iVertex, :)) .^ 2, 2)));
                    vi(iVertex) = I;
                end
            else
                % Find boundary for set of projected points
                faces = boundary(scs_coords, 0);
                % Find grid points inside polyhedron
                vi = find(inpolyhedron(struct('faces', faces, 'vertices', scs_coords), GridLoc));
                if isempty(vi)
                    % Find the vertex that is closer to the center of the projected points
                    [tmp, I] = min(sqrt(sum(bst_bsxfun(@minus, GridLoc, mean(scs_coords, 1)) .^ 2, 2)));
                    vi = I;
                end
            end
            vi = vi(:)'; % Force to be column vector
            % Save in input structure
            sAtlas(iAtlas).Scouts(iScout).Vertices = vi;
            % Set seed for new Scout
            sAtlas(iAtlas).Scouts(iScout) = panel_scout('SetScoutsSeed', sAtlas(iAtlas).Scouts(iScout), GridLoc);
            % Grow new scout around it seed to march the number of vertices in origin scout
            nToGrow = nOrgVertices - length(vi);
            if nToGrow ~= 0
                seedXYZ = GridLoc(sAtlas(iAtlas).Scouts(iScout).Seed, :);
                viPossible = 1:size(GridLoc,1);
                % Remove the points that are already in the new scout
                viPossible = setdiff(viPossible, vi);
                % If there are some candidates, find the closest ones
                if ~isempty(viPossible) && (length(viPossible) <= nToGrow)
                    vi = union(vi, viPossible);
                elseif ~isempty(viPossible)
                    % Compute the distance from each point to the seed
                    distFromSeed = sqrt(sum(bst_bsxfun(@minus, GridLoc(viPossible,:), seedXYZ) .^ 2, 2))';
                    % Add the the closest points
                    [tmp, I] = sort(distFromSeed);
                    vi = union(vi, viPossible(I(1:nToGrow)));
                end
                % Update vertices
                sAtlas(iAtlas).Scouts(iScout).Vertices = vi;
            end
            % Update label and region
            % Remove hemisphere suffix if present
            sAtlas(iAtlas).Scouts(iScout).Label = regexprep(sAtlas(iAtlas).Scouts(iScout).Label, ' (L|R)$', '');
            if isRight
                sAtlas(iAtlas).Scouts(iScout).Label = [sAtlas(iAtlas).Scouts(iScout).Label ' L'];
                sAtlas(iAtlas).Scouts(iScout).Region = strrep(sAtlas(iAtlas).Scouts(iScout).Region, 'R', 'L');
            else
                sAtlas(iAtlas).Scouts(iScout).Label = [sAtlas(iAtlas).Scouts(iScout).Label ' R'];
                sAtlas(iAtlas).Scouts(iScout).Region = strrep(sAtlas(iAtlas).Scouts(iScout).Region, 'L', 'R');
            end
        end
    end
end
        