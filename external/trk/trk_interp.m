function [tracks_interp,trk_mean_length] = trk_interp(tracks,nPoints_new,spacing,tie_at_center)
%TRK_INTERP - Interpolate tracks with cubic B-splines
%Streamlines will be resampled to have a new number of vertices. May be useful
%to groom your tracks first. Can be multithreaded if Parallel Computing Toolbox
%is installed.
%
% Syntax: [tracks_interp,trk_mean_length] = trk_interp(tracks,nPoints_new,spacing,tie_at_center)
%
% Inputs:
%    tracks      - Struc array output of TRK_READ [1 x nTracks]
%    nPoints_new - Constant # mode: Number of vertices for each streamline
%                  (spacing between vertices will vary between streamlines)
%                  (Default: 100)
%    spacing     - Constant spacing mode: Spacing between each vertex (# of
%                  vertices will vary between streamlines). Note: Only supply
%                  nPoints_new *OR* spacing!
%    tie_at_center - (Optional) Use with nPoints_new to add an additional
%                  "tie-down" point at the midpoint of the tract. Recommended.
%                  http://github.com/johncolby/along-tract-stats/wiki/tie-at-center
%
% Outputs:
%    tracks_interp   - Interpolated tracks in matrix format.
%                      [nPoints_new x 3 x nTracks]
%    trk_mean_length - The length of the mean tract geometry if using the
%                      spacing parameter, above. Useful to then normalize track
%                      lengths between subjects.
%
% Example:
%    exDir                   = '/path/to/along-tract-stats/example';
%    subDir                  = fullfile(exDir, 'subject1');
%    trkPath                 = fullfile(subDir, 'CST_L.trk');
%    volPath                 = fullfile(subDir, 'dti_fa.nii.gz');
%    volume                  = read_avw(volPath);
%    [header tracks]         = trk_read(trkPath);
%    tracks_interp           = trk_interp(tracks, 100);
%    tracks_interp           = trk_flip(header, tracks_interp, [97 110 4]);
%    tracks_interp_str       = trk_restruc(tracks_interp);
%    [header_sc tracks_sc]   = trk_add_sc(header, tracks_interp_str, volume, 'FA');
%    [scalar_mean scalar_sd] = trk_mean_sc(header_sc, tracks_sc);
%
% Other m-files required: Curve Fitting Toolbox (aka Spline Toolbox)
% Subfunctions: none
% MAT-files required: none
%
% See also: TRK_READ, SPLINE

% Author: John Colby (johncolby@ucla.edu)
% UCLA Developmental Cognitive Neuroimaging Group (Sowell Lab)
% Apr 2010

if nargin<4, tie_at_center = []; end
if nargin<3, spacing = []; end
if nargin<2 || isempty(nPoints_new), nPoints_new = 100; end

tracks_interp   = zeros(nPoints_new, 3, length(tracks));
trk_mean_length = [];
pp = repmat({[]},1,length(tracks));

% Interpolate streamlines so that each has the same number of vertices, spread
% evenly along its length (i.e. vertex spacing will vary between streamlines)
for iTrk=1:length(tracks)
    tracks_tmp = tracks(iTrk);
    
    % Martin: bugfix for single point fibers
    if tracks_tmp.nPoints == 1
        tracks_interp(:,:,iTrk) = repmat(tracks_tmp.matrix, nPoints_new, 1);
        continue
    end
    
    % Determine streamline segment lengths
    segs = sqrt(sum((tracks_tmp.matrix(2:end,1:3) - tracks_tmp.matrix(1:(end-1),1:3)).^2, 2));
    dist = [0; cumsum(segs)];
    
    % Remove duplicates
    [dist I J]= unique(dist);
    % Martin: bugfix for fibers with same points
    if length(dist) == 1
        dist = 0:1;
        I = 1:2;
    end
    
    % Fit spline
    % Martin: bugfix for fibers with more than 3 dimensions
    pp{iTrk} = spline(dist, tracks_tmp.matrix(I,1:3)');
    
    % Resample streamline along the spline
    tracks_interp(:,:,iTrk) = ppval(pp{iTrk}, linspace(0, max(dist), nPoints_new))';
end

% Interpolate streamlines so that the vertices have equal spacing for a central
% "tie-down" origin. This means streamlines will have varying #s of vertices
if ~isempty(spacing)
    % Calculate streamline lengths
    lengths = trk_length(tracks_interp);
    
    % Determine the mean tract geometry and grab the middle vertex
    track_mean      = mean(tracks_interp, 3);
    trk_mean_length = trk_length(track_mean);
    middle          = track_mean(round(length(track_mean)/2),:);
    
    % Interpolate streamlines again, but this time sample with constant vertex
    % spacing for all streamlines. This means that the longer streamlines will now
    % have more vertices.
    tracks_interp = repmat(struct('nPoints', 0, 'matrix', [], 'tiePoint', 0), 1, length(tracks));
    for iTrk=1:length(tracks)
        tracks_interp(iTrk).matrix  = ppval(pp{iTrk}, 0:spacing:lengths(iTrk))';
        tracks_interp(iTrk).nPoints = size(tracks_interp(iTrk).matrix, 1);
        
        % Also determine which vertex is the "tie down" point by finding the one
        % closest to the middle point of the mean tract geometry
        dists = sqrt(sum(bsxfun(@minus, tracks_interp(iTrk).matrix, middle).^2,2));
        [tmp, ind] = min(dists);
        tracks_interp(iTrk).tiePoint = ind;
    end
end

% Streamlines will all have the same # of vertices, but now they will be spread
% out so that an equal proportion lies on either side of a central origin. 
if ~isempty(nPoints_new) && ~isempty(tie_at_center)
    % Make nPoints_new odd
    nPoints_new_odd = floor(nPoints_new/2)*2+1;
    
    % Calculate streamline lengths
    lengths = trk_length(tracks);
    
    % Determine the mean tract geometry and grab the middle vertex
    track_mean      = mean(tracks_interp, 3);
    trk_mean_length = trk_length(track_mean);
    middle          = track_mean(round(length(track_mean)/2),:);
    
    tracks_interp_tmp = zeros(nPoints_new_odd, 3, length(tracks));
    
    for iTrk=1:length(tracks)
        dists = sqrt(sum(bsxfun(@minus, tracks_interp(:,:,iTrk), middle).^2,2));
        [tmp, ind] = min(dists);
        
        first_half  = ppval(pp{iTrk}, linspace(0, lengths(iTrk)*(ind/nPoints_new), ceil(nPoints_new_odd/2)))';
        second_half = ppval(pp{iTrk}, linspace(lengths(iTrk)*(ind/nPoints_new), lengths(iTrk), ceil(nPoints_new_odd/2)))';
        tracks_interp_tmp(:,:,iTrk) = [first_half; second_half(2:end,:)];
    end
    
    tracks_interp = tracks_interp_tmp;
end
