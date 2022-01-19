function varargout = channel_extrapm( varargin )
% CHANNEL_EXTRAPM: Get or compute magnetic extrapolation matrix between two sets of sensors
%
% USAGE:  [WExtrap, src_xyz] = channel_extrapm('GetTopoInterp', ChannelFile, iChan, Vertices, Faces, bfs_center, bfs_radius, F);
%         [WExtrap, src_xyz] = channel_extrapm('ComputeInterp', srcChan, destChan, bfs_center, bfs_radius, Whitener, epsilon)
%         [WExtrap, src_xyz] = channel_extrapm('ComputeInterp', srcChan, destChan, bfs_center, bfs_radius)
%                sourcespace = channel_extrapm('ComputeSphereGrid', bfs_center, bfs_radius)

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
% Authors: François Tadel, 2009-2012
%          Rey R. Ramirez, 2009

eval(macro_method);
end


%% ===== GET TOPOGRAPHY INTERPOLATION =====
% Read/Compute/Save magnetic interpolation in a channel file.
% USAGE:   WExtrap = GetTopoInterp(ChannelFile, iChan, Vertices, Faces, bfs_center, bfs_radius, F)
%          WExtrap = GetTopoInterp(ChannelFile, iChan, Vertices, Faces, bfs_center, bfs_radius)
function WExtrap = GetTopoInterp(ChannelFile, iChan, Vertices, Faces, bfs_center, bfs_radius, F) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 7)
        F = [];
    end
    % Check matrices orientation
    if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
        error('Faces and Vertices must have 3 columns (X,Y,Z).');
    end

    % Load channel file
    ChannelMat = in_bst_channel(ChannelFile);
    % Get extrapolation options
    MagneticExtrapOptions = bst_get('MagneticExtrapOptions');
    isWhiten = MagneticExtrapOptions.ForceWhitening || all(ismember({'MEG GRAD', 'MEG MAG'}, {ChannelMat.Channel(iChan).Type}));
    epsilon  = MagneticExtrapOptions.EpsilonValue;
    % Compute whitener
    nTime = size(F,2);
    if isWhiten && (nTime > 20)
        NoiseVar = diag(var(F,[],2));
        Whitener = bst_whitener(NoiseVar);
    else
        Whitener = [];
    end

    % Compute normals at each vertex
    VerticesNormals = tess_normals(Vertices, Faces);
    % Create a pseudo-channel file of virtual magnetometers
    destChan = repmat(db_template('channeldesc'), [1, length(Vertices)]);
    for i = 1:length(Vertices)
        destChan(i).Name   = num2str(i);
        destChan(i).Type   = 'MEG';
        destChan(i).Loc    = Vertices(i,:)';
        destChan(i).Orient = VerticesNormals(i,:)';
        destChan(i).Weight = 1;
    end
    % Compute interpolation
    [WExtrap, src_xyz] = ComputeInterp(ChannelMat.Channel(iChan), destChan, bfs_center, bfs_radius, Whitener, epsilon);
end



%% ===== COMPUTE INTERPOLATION =====
% USAGE:  [WExtrap, src_xyz] = ComputeInterp(srcChan, destChan, bfs_center, bfs_radius, Whitener, epsilon)
%         [WExtrap, src_xyz] = ComputeInterp(srcChan, destChan, bfs_center, bfs_radius)
function [WExtrap, src_xyz] = ComputeInterp(srcChan, destChan, bfs_center, bfs_radius, Whitener, epsilon)
    % ===== PARSE INPUTS =====
    if (nargin < 6) || isempty(epsilon)
        epsilon = 0.0001;
    end
    if (nargin < 5) || isempty(Whitener)
        Whitener = [];
    end
    if (nargin < 4) || isempty(bfs_radius)
        bfs_radius = 0.07;
    end
    if (size(bfs_center,2) == 1)
        bfs_center = bfs_center';
    end
    WExtrap = [];

    % ===== COMPUTE SOURCE SPACE =====   
    % Computing spherical volume sourcespace.
bfs_radius = 0.07;
    src_xyz = ComputeSphereGrid(bfs_center, bfs_radius)';
       
    % ===== COMPUTE LEADFIELDS =====
    % Single sphere model
    Param = struct('Center', bfs_center', 'Radii', bfs_radius);
    % Compute headmodels
    Gsrc2orig   = bst_meg_sph(src_xyz, srcChan,  repmat(Param, [1,length(srcChan)]));
    Gsrc2target = bst_meg_sph(src_xyz, destChan, repmat(Param, [1,length(destChan)]));
    if isempty(Gsrc2orig) || isempty(Gsrc2target)
        disp('EXTRAP> Error: One of the leadfields was not computed properly.');
        return
    end
    % Apply whitener to leadfield
    if ~isempty(Whitener)
        Gsrc2orig = Whitener * Gsrc2orig;
    end

    % Computing SVD of Grammian and truncating based on epsilon.
    [U,S,V] = svd(Gsrc2orig * Gsrc2orig');
    s = diag(S);
    ss = sum(s);
    sss = 1 - (cumsum(s)./ss);
    i = find(sss<epsilon);
    i = i(1);
    si = 1./s;
    si = si(1:i);
    %display(['Using ' num2str(i) ' singular values/vectors (i.e, dimensions)']);

    % Computing extrapolation matrix.
    coefs = V(:,1:i) * diag(si) * U(:,1:i)';
    WExtrap = Gsrc2target * Gsrc2orig' * coefs;

    % Apply whitener to the interpolator
    if ~isempty(Whitener)
        WExtrap = WExtrap * Whitener;
    end
end


%% ===== SOURCE GRID =====
% Create source space for a given channel file
function sourcespace = ComputeSphereGrid(bfs_center, bfs_radius)
    % Build a full grid
    x = .01:.01:bfs_radius;
    x = [-x 0 x];
    [X,Y,Z] = meshgrid(x,x,x);
    % Keep only the points that are within the sphere
    D = sqrt((X.^2)+(Y.^2)+(Z.^2));
    i = find((D < bfs_radius) & (D > .03));
    sourcespace = [X(i) + bfs_center(1), Y(i) + bfs_center(2), Z(i) + bfs_center(3)];

% FRANCOIS
%     % Source locations
%     mne_src = tess_sphere(362);
%     mne_src = mne_src .* .5 * bfs_radius;
%     mne_src = bst_bsxfun(@plus, mne_src, bfs_center');
    
% SYLVAIN
%     % Number of sources to interpolate on
%     nsrc = length(srcChan);
%     [x,y,z] = sphere(ceil(sqrt(nsrc)));
%     % Center source locations and scale them to the best-fitting sphere found 
%     mne_src = [x(:),y(:),z(:)];
%     mne_src_orig = mne_src(unique(round(linspace(1,size(mne_src,1),nsrc))),:);
%     mne_src = mne_src_orig * .5 * bfs_radius;
%     nsrc = size(mne_src,1);
%     mne_src = mne_src + repmat(bfs_center',nsrc,1);
end


%% ===== PLOT SOURCE SPACE =====
function hFig = PlotSourceSpace(srcChan, destChan, src_xyz) %#ok<DEFNU>
    % Create dataset
    iDS = bst_memory('GetDataSetEmpty');
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = 'MEG';
    % Create figure
    [hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

    % Sensors vertices
    srcloc  = cell2mat(cellfun(@(c)c(:,1), {srcChan.Loc},  'UniformOutput', 0))';
    destloc = cell2mat(cellfun(@(c)c(:,1), {destChan.Loc}, 'UniformOutput', 0))';
    % Tesselate
    srcfaces  = channel_tesselate( srcloc );
    destfaces = channel_tesselate( destloc );
    % Create sensors patches
    hNet = patch('Vertices',        srcloc, ...
                 'Faces',           srcfaces, ...
                 'FaceVertexCData', repmat([.7 .7 .5], [length(srcloc), 1]), ...
                 'Marker',          'none', ...
                 'LineWidth',       1, ...
                 'FaceColor',       [.7 .7 .5], ...
                 'FaceAlpha',       .5, ...
                 'EdgeColor',       [.4 .4 .3], ...
                 'EdgeAlpha',       1, ...
                 'MarkerEdgeColor', [.4 .4 .3], ...
                 'MarkerFaceColor', 'flat', ...
                 'MarkerSize',      6, ...
                 'BackfaceLighting', 'lit', ...
                 'Parent',          hAxes);
    hNet = patch('Vertices',        destloc, ...
                 'Faces',           destfaces, ...
                 'FaceVertexCData', repmat([.5 .7 .7], [length(destloc), 1]), ...
                 'Marker',          'none', ...
                 'LineWidth',       1, ...
                 'FaceColor',       [.5 .7 .7], ...
                 'FaceAlpha',       .5, ...
                 'EdgeColor',       [.3 .4 .4], ...
                 'EdgeAlpha',       1, ...
                 'MarkerEdgeColor', [.3 .4 .4], ...
                 'MarkerFaceColor', 'flat', ...
                 'MarkerSize',      6, ...
                 'BackfaceLighting', 'lit', ...
                 'Parent',          hAxes);
    % Plot sources
    hNet = line(src_xyz(1,:), src_xyz(2,:), src_xyz(3,:), ...
                    'LineWidth',       2, ...
                    'LineStyle',       'none', ...
                    'MarkerFaceColor', [1 0 0], ...
                    'MarkerEdgeColor', [.4 .4 .4], ...
                    'MarkerSize',      6, ...
                    'Marker',          'o', ...
                    'Tag',             'SourceMarkers', ...
                    'Parent',          hAxes);
    % Show figure
    set(hFig, 'Visible', 'on');
end

