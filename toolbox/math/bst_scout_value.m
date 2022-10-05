function [Fs, PcaFirstComp] = bst_scout_value(F, ScoutFunction, Orient, nComponents, XyzFunction, isSignFlip, scoutName, OrientCov, PcaReference)
% BST_SCOUT_VALUE: Combine Ns time series using the given function. Used to get scouts/clusters values.
%
% USAGE:  Fs = bst_scout_value(F, ScoutFunction, Orient=[], nComponents=1, XyzFunction='none', isSignFlip=0, scoutName=[], OrientCov=[], PcaReference=[])
%
% INPUTS:
%     - F              : [Nsources * Ncomponents, Ntime] double matrix, source time series
%     - ScoutFunction  : String, function to use to combine the Nsources time series {'mean', 'std', 'mean_norm', 'max', 'power', 'pca', 'fastpca', 'stat', 'all', 'none'}
%     - Orient         : [Nsources x 3], Orientation of each source - usually the normal at the vertex in the cortex mesh
%     - nComponents    : {1,2,3}, Number of components per vertex in matrix F 
%                        If 0, the number varies, the properties of each region are defined in input GridAtlas
%     - XyzFunction    : String, function used to group the the 2 or 3 components per vertex: return only one value per vertex {'norm', 'pca', 'pcaa', 'none'}
%     - isSignFlip     : In the case of signed minimum norm values, this will flip the signs of sources with opposite orientations
%     - scoutName      : Name of the scout or cluster you're extracting
%     - OrientCov      : [3 x 3 x Nsources] Covariance between 3 rows of F (3 source orientations) at each location, pre-computed for one or more epochs
%     - PcaReference   : [3 x Nsources] Reference PCA components (see PcaFirstComp below) pre-computed across epochs, used to pick consistent sign for each epoch
%
% OUTPUTS:
%     - Fs           : [Nscouts x Ntime] Combined time series
%     - PcaFirstComp : First mode of the PCA, as column(s). [Nsources * Ncomponents, 1] for ScoutFunction only, [3 x Nsources] for XyzFunction, or [Nsources * Ncomponents, 1] for both.
%
% Currently, ScoutFunction is applied before XyzFunction. 
% When using XyzFunction='pca' or 'pcaa', it is recommended to apply it before extracting scouts, so this should be done in 2 steps.

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
% Authors: Sylvain Baillet, Francois Tadel, John Mosher, 2010-2021
%          Marc Lalancette, 2022

% ===== PARSE INPUTS =====
if (nargin < 8) || isempty(PcaReference)
    PcaReference = [];
end
if (nargin < 8) || isempty(OrientCov)
    OrientCov = [];
end
if (nargin < 7) || isempty(scoutName)
    scoutName = [];
end
if (nargin < 6) || isempty(isSignFlip)
    isSignFlip = 0;
end
if (nargin < 5) || isempty(XyzFunction)
    XyzFunction = 'none';
end
if (nargin < 4) || isempty(nComponents)
    nComponents = 1;
end
if (nargin < 3) || isempty(Orient)
    Orient = [];
end
% Initialize return values
PcaFirstComp = [];


% ===== ORIENTATION SIGN FLIP =====
% Force sign flip for pcaa on scout, so that overall component sign fits convention for
% source orientations pointing in/out, at least when a scout is mostly flat.
if strcmpi(ScoutFunction, 'pcaa')
    isSignFlip = true;
end
% Flip only if there are mixed signs in F (+ and -)
if isSignFlip && (nComponents == 1) && ~isempty(Orient) && ~ismember(lower(ScoutFunction), {'all', 'none'}) && ...
        (size(F,1) > 1) && ~all(F(:) > 0)
    % Check for NaN or Inf values
    if (any(isnan(Orient(:))) || any(isinf(Orient(:))))
        disp('BST> Warning: The vertex normals contain some NaN or Inf values, cannot flip signs. Please check the quality of the cortex surface.');
        FlipMask = [];
    else
        % Take the SVD to get the dominant orientation in this patch
        % v(:,1) is the dominant orientation
        [u,s,v] = svd(Orient, 0);
        % Get the flip mask for the data values
        FlipMask = sign(u(:,1));
        % We want to flip the sign of the minimum number of time series, so
        % if there are mostly positive values: multiply the values by -FlipMask
        if (nnz(FlipMask > 0) < nnz(FlipMask < 0))
            FlipMask = -FlipMask;
        end
    end

    % If not all the values are of the same sign, flip
    if ~isempty(FlipMask) && ~all(FlipMask == 1)
% DATA-DEPENDENT CANCELATION: REMOVED ON 14-APR-2016 AFTER SKYPE DISCUSSION WITH RL, JM, DP
%         % Multiply the values by FlipMask
%         tmpF = bst_bsxfun(@times, F, FlipMask);
%         % Evaluate if the maximum of the average increased 
%         maxOld = max(abs(mean(F,1)));
%         maxNew = max(abs(mean(tmpF,1)));
%         ratioMax = maxNew(1) ./ maxOld(1);
%         % If ratio is > 1: the sign flip had a positive effect, keep it
%         if (ratioMax > 1)
%             disp(['BST> Flipped the sign of ' num2str(nnz(FlipMask == -1)) ' sources.']);
%             F = tmpF;
%         else
%             disp(['BST> Sign flipping cancelled because it decreases the signal amplitude (ratio=' num2str(ratioMax) ').']);
%         end
        % Multiply the values by FlipMask
        F = bst_bsxfun(@times, F, FlipMask);
        disp(['BST> Flipped the sign of ' num2str(nnz(FlipMask == -1)) ' sources.']);
    end
end

% ===== RETURN ALL =====
% No function to apply at all: return initial data (with flipped signs)
if (strcmpi(ScoutFunction, 'none') || strcmpi(ScoutFunction, 'all')) && strcmpi(XyzFunction, 'none')
    Fs = F;
    return;
end

% ===== MULTIPLE COMPONENTS =====
% Reshape F matrix in 3D: [nRow, nTime, nComponents]
switch (nComponents)
    case 0,     error('You should call this function for each region individually.');
    case 1      % Nothing to do
    case {2,3}, F = permute(reshape(F, nComponents, [], size(F,2)), [2, 3, 1]); % permute/reshape faster than cat
end
nRow  = size(F,1);
nTime = size(F,2);
explained = 0;

%% ===== COMBINE ALL VERTICES =====
switch (lower(ScoutFunction))       
    % MEAN : Average of the patch activity at each time instant
    case 'mean'
        Fs = mean(F,1);
    % STD : Standard deviation of the patch activity at each time instant
    case 'std'
        Fs = std(F,[],1);
    % STDERR : Standard error
    case 'stderr'
        Fs = std(F,[],1) ./ nRow;
    % RMS
    case 'rms'
        Fs = sqrt(sum(F.^2,1)); 
        
    % MEAN_NORM : Average of the norms of all the vertices each time instant 
    % If only one components: computes mean(abs(F)) => Compatibility with older versions
    case 'mean_norm'
        if (nComponents == 1)
            % Average absolute values
            Fs = mean(abs(F),1);
        else
            % Average norms
            Fs = mean(sqrt(sum(F.^2, 3)), 1);
        end
        
    % MAX : Strongest at each time instant (in absolue values)
    case 'max'
        % If one component: max(abs)
        if (nComponents == 1)
            Fs = bst_max(F,1);
        else
            % Get the maximum of the norm across orientations, at each time
            [tmp__, iMax] = max(sum(F.^2, 3), [], 1);
            % Build indices of the values to read
            iMaxF = sub2ind(size(F), [iMax,iMax,iMax], ...
                                     [1:nTime,1:nTime,1:nTime], ...
                                     [1*ones(1,nTime), 2*ones(1,nTime), 3*ones(1,nTime)]);
            Fs = reshape(F(iMaxF), 1, nTime, 3);
        end

    % POWER: Average of the square of the all the signals
    case 'power'
        if (nComponents == 1)
            Fs = mean(F.^2, 1);
        else
            Fs = mean(sum(F.^2, 3), 1);
        end

    % PCA : Display first mode of PCA of time series within each scout region
    case 'pca'
        % Signal decomposition
        Fs = zeros(1, nTime, nComponents);
        for i = 1:nComponents
            [Fs(1,:,i), explained] = PcaFirstMode(F(:,:,i));
        end
        
    % FAST PCA : Display first mode of PCA of time series within each scout region
    case 'fastpca'
        % Reduce dimensions first
        nMax = 50; % Maximum number of variables to run the PCA on
        if nRow > nMax
            % Norm or not
            if (nComponents == 1)
                Fn = abs(F);
            else
                Fn = sqrt(sum(F.^2, 3));
            end
            % Find the nMax most powerful/spiky source time series
            %powF = sum(F.*F,2);
            powF = max(Fn,[],2) ./ (mean(Fn,2) + eps*min(Fn(:)));
            [tmp__, isF] = sort(powF,'descend');
            F = F(isF(1:nMax),:,:);
        end
        % Signal decomposition
        Fs = zeros(1, nTime, nComponents);
        for i = 1:nComponents
            [Fs(1,:,i), explained] = PcaFirstMode(F(:,:,i));
        end
        
    % STAT : Average values as if they were statistical results => ignore all the zero-values
    case 'stat'
        % Get the number of samples per time point
        w = sum(F~=0, 1);
        w(w == 0) = 1;
        % Divide each time point by the number of valid samples
        Fs = bst_bsxfun(@rdivide, sum(F,1), w);
        
    % ALL : Return all the time series (do not combine them)
    case {'all', 'none'}
        Fs = F;
        
    % Otherwise: error
    otherwise
        error(['Unknown scout function: ' ScoutFunction]);
end


%% ===== COMBINE ALL ORIENTATIONS =====
% If there are more than one component in output
if (nComponents > 1) && (size(Fs,3) > 1 || isempty(Fs))
    nRow = size(Fs,1); % 1 or nComp if ScoutFunction, otherwise original nRow
    % Start from the scouts time series
    F = Fs;
    % Different options to combine the three orientations
    switch lower(XyzFunction)
        % Compute the PCA of all the components
        case 'pca'
            PcaFirstComp = zeros(nComponents, nRow);
            % For each vertex: Signal decomposition
            explained = 0;
            for i = 1:nRow
                Fi = permute(F(i,:,:), [3,2,1]); % permute faster than squeeze
                % Use trial data covariance if provided
                if ~isempty(OrientCov)
                    [U, S] = eig((OrientCov(:,:,i) + OrientCov(:,:,i)')/2, 'vector'); % ensure exact symmetry for real results.
                    [S, iSort] = sort(S, 'descend');
                else % use data
                    % Here, we will probably want to remove the offset removal, but keeping as before for now.
                    [U, S] = svd(bsxfun(@minus, Fi, sum(Fi,2)./size(Fi,2)), 'econ', 'vector'); % sum faster than mean
                    iSort = 1;
                end
                explained = explained + S(1).^2 / sum(S.^2);
                PcaFirstComp(:,i) = U(:, iSort(1));
            end
            explained = explained / nRow;
            %warning('This older PCA implementation suffers from sign flipping between epochs.');
            if ~isempty(PcaReference)
                % Use PCA across epochs (here in OrientCov) to consistently select the component sign for each epoch.
                CompSign = sign(sum(PcaFirstComp .* PcaReference));
                PcaFirstComp = bsxfun(@times, CompSign, PcaFirstComp);
            % else we'll have to deal with sign ambiguity elsewhere.
            end
            Fs = sum(bsxfun(@times, permute(PcaFirstComp, [2,3,1]), F), 3); % dot product of Comp with F on 3rd dim, gives size (nRow, nTime)

        case 'pcaa'
            if ~ismember(lower(ScoutFunction), {'all', 'none', 'mean', 'pca'})
                error('PCA across epochs on orientations after scout function other than PCA, mean, or none is not implemented.');
                % To deal with other (non linear) scout functions would require 2 steps to load all scout epochs.
            end
            % Here, F may be empty, if we save the result as a shared kernel.
            % Get number of sources from covariance.
            nRow = size(OrientCov, 3);
            PcaFirstComp = zeros(nComponents, nRow);
            % For each vertex: Signal decomposition
            explained = 0;
            for i = 1:nRow
                [U, S] = eig((OrientCov(:,:,i) + OrientCov(:,:,i)')/2, 'vector'); % ensure exact symmetry for real results.
                [S, iSort] = sort(S, 'descend');
                explained = explained + S(1) / sum(S);
                PcaFirstComp(:,i) = U(:, iSort(1));
            end
            explained = explained / nRow;
            % Flip sign for consistency if computation repeated.
            CompSign = sign(sum(PcaFirstComp));
            PcaFirstComp = bsxfun(@times, CompSign, PcaFirstComp);
            if ~isempty(F)
                Fs = sum(bsxfun(@times, permute(PcaFirstComp, [2,3,1]), F), 3); % dot product of Comp with F on 3rd dim, gives size (nRow, nTime)
            end
            
        % Compute the norm across the directions
        case 'norm'
            Fs = sqrt(sum(Fs.^2, 3));
        
        % None: remap the components in a 2D matrix
        case 'none'
            % We consider that a Scout function was applied 
            % (case where no function is applied is handled at the beginning of the function)
            Fs = permute(Fs, [3,2,1]);
            
    % Otherwise: error
    otherwise
        error(['Unknown scout function: ' ScoutFunction]);
    end
end

%% Display percentage of signal explained by 1st component of PCA
% This is somewhat incomplete: doesn't combine scout and xyz, or components of scout (loop).
if explained
    msg = ['BST> First PCA component explains ' num2str(explained * 100) '% of the signal'];
    if scoutName
        msg = [msg ' of cluster ' scoutName];
    end
    disp([msg '.']);
end
end


%% ===== PCA: FIRST MODE =====
function [F, explained] = PcaFirstMode(F)
    % Signal decomposition / Remove average over time for each row
    [U, S] = svd(bsxfun(@minus, F, sum(F,2)./size(F,2)), 'econ', 'vector'); %sum(F,2)./size(F,2)
    %S = diag(S);
    explained = S(1).^2 / sum(S.^2);
    U = U(:,1);
    % Correct sign of the first PC to be consistent across epochs as best we can, and project data onto first PCA component.
    F = sign(sum(U)) * U' * F;

    % Explanation of this choice of sign correction for scouts
    % Here we choose the sign such that the projected PCA timeseries has positive correlation with the 
    % orientation-corrected (isSignFlip=true) mean timeseries. In other words, we want the following to be positive:
    %   sign(mean(F,1) * (U' * F)') 
    % We can simplify this since U is an eigen-vector of the F covariance matrix:
    %   = sign(ones * F * F' * U) = sign(ones * U) = sign(sum(U))
end


