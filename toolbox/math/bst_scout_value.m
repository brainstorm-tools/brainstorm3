function [Fs, PcaFirstComp] = bst_scout_value(F, ScoutFunction, Orient, nComponents, XyzFunction, isSignFlip, ScoutName, DataCov, PcaReference)
% BST_SCOUT_VALUE: Combine Ns time series using the given function. Used to get scouts/clusters values.
%
% USAGE:  Fs = bst_scout_value(F, ScoutFunction, Orient=[], nComponents=1, XyzFunction='none', isSignFlip=0, ScoutName=[], OrientCov=[], PcaReference=[])
%
% INPUTS:
%     - F             : [Nsources * Ncomponents, Ntime] double matrix, source time series
%     - ScoutFunction : String, function to use to combine the Nsources time series {'mean', 'std', 'mean_norm', 'max', 'power', 'pca', 'fastpca', 'stat', 'all', 'none'}
%     - Orient        : [Nsources x 3], Orientation of each source - usually the normal at the vertex in the cortex mesh
%     - nComponents   : {1,2,3}, Number of components per vertex in matrix F 
%                       If 0, the number varies, the properties of each region are defined in input GridAtlas
%     - XyzFunction   : String, function used to group the the 2 or 3 components per vertex: return only one value per vertex {'norm', 'pca', 'pcaa', 'none'}
%     - isSignFlip    : In the case of signed minimum norm values, this will flip the signs of sources with opposite orientations
%     - ScoutName     : Name of the scout or cluster you're extracting
%     - DataCov       : Covariance matrix between rows of F, pre-computed for one or more epochs. Used for PCA.
%                       For PCA ScoutFunction: [Nrows x Nrows], for PCA XyzFunction only (no ScoutFunction): [3 x 3 x Nsources] 3 source orientations at each location
%     - PcaReference  : Reference PCA components (see PcaFirstComp below for possible sizes) pre-computed across epochs, used to pick consistent sign for each epoch
%
% OUTPUTS:
%     - Fs           : Combined time series. [Ncomponents x Ntime] for ScoutFunction only, [Nsources x Ntime] for XyzFunction, or [1 x Ntime] for both.
%     - PcaFirstComp : First mode of the PCA, as column(s). [Nsources, Ncomponents] for ScoutFunction only, [3 x Nsources] for XyzFunction, or [Nsources * Ncomponents, 1] for both.
%
% NOTES: 
%     ScoutFunction is applied before XyzFunction. 
%     For XyzFunction 'pca' or 'pcaa', it should be applied before extracting scouts, or at the same time with the same PCA function.
%     For ScoutFunction 'pca' or 'pcaa' with nComponents > 1, XyzFunction must match.

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
% Authors: Sylvain Baillet, Francois Tadel, John Mosher, Marc Lalancette, 2010-2022

TODO: check if/when empty possible for scout

% ===== PARSE INPUTS =====
if (nargin < 8) || isempty(PcaReference)
    PcaReference = [];
end
if (nargin < 8) || isempty(DataCov)
    DataCov = [];
end
if (nargin < 7) || isempty(ScoutName)
    ScoutName = [];
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

% Enforce limitations on combining PCA on scout or xyz with other functions.
if strncmpi(ScoutFunction, 'pca', 3) && nComponents > 1 && ~strcmpi(ScoutFunction, XyzFunction)
    error('For PCA ScoutFunction with nComponents > 1, XyzFunction must match.');
elseif nComponents > 1 && strncmpi(XyzFunction, 'pca', 3) && ~ismember(ScoutFunction, {'all', 'none'})
    error('For PCA XyzFunction, it should be applied before extracting scouts, or at the same time with the same PCA function.');
end

% ===== ORIENTATION SIGN FLIP =====
% Force sign flip for pcaa (or pca if no reference component provided) on scout, so that overall
% component sign fits convention for source orientations pointing in/out, when a scout is mostly flat.
if strcmpi(ScoutFunction, 'pcaa') || (strcmpi(ScoutFunction, 'pca') && isempty(PcaReference))
    isSignFlip = true;
end
% Flip only if there are mixed signs in F (+ and -)
FlipMask = [];
if isSignFlip && (nComponents == 1) && ~isempty(Orient) && ~ismember(lower(ScoutFunction), {'all', 'none'}) && ...
        (size(F,1) > 1) && ~all(F(:) > 0)
    % Check for NaN or Inf values
    if (any(isnan(Orient(:))) || any(isinf(Orient(:))))
        disp('BST> Warning: The vertex normals contain some NaN or Inf values, cannot flip signs. Please check the quality of the cortex surface.');
    else
        % Take the SVD to get the dominant orientation in this patch
        % U(:,1) is the dominant orientation
        [U,S] = svd(Orient', 'econ', 'vector');
        % Get the flip mask for the data values
        FlipMask = sign(U(:,1)); % careful: sign(0) == 0
        % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility. 
        % Keep FlipMask mostly positive; flip the sign of the minimum number of time series. 
        if (nnz(FlipMask > 0) < nnz(FlipMask < 0))
            FlipMask = -FlipMask;
        end
        % Replace zeros (exaclty orthogonal to dominant orientation) by 1: don't ignore any sources. 
        FlipMask(FlipMask == 0) = 1;

        % If not all the values are of the same sign, flip
        if all(FlipMask == 1)
            FlipMask = [];
        else
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
            F = bsxfun(@times, F, FlipMask);
            disp(['BST> Flipped the sign of ' num2str(nnz(FlipMask == -1)) ' sources.']);
            if ~isempty(DataCov)
                % Also apply to DataCov in both dimensions
                DataCov = bsxfun(@times, bsxfun(@times, DataCov, FlipMask'), FlipMask);
            end
        end
    end
end
isSignFlip = ~isempty(FlipMask);

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
    case {2,3} 
        if strncmpi(ScoutFunction, 'pca', 3) 
            % In this case, XyzFunction is also pca and we'll compute it on all sources (locations and orientations) at once.
            nComponents = 1; 
        else
            F = permute(reshape(F, nComponents, [], size(F,2)), [2, 3, 1]); % permute/reshape faster than cat
        end
end
nRow  = size(F,1);
nTime = size(F,2);
explained = 0;

%% ===== COMBINE ALL VERTICES =====
switch (lower(ScoutFunction))       
    % MEAN : Average of the patch activity at each time instant
    case 'mean'
        Fs = mean(F,1);
        if isSignFlip
            PcaFirstComp = FlipMask ./ nRow;
        else
            PcaFirstComp = ones(nRow, 1) ./ nRow;
        end
    % STD : Standard deviation of the patch activity at each time instant
    case 'std'
        Fs = std(F,[],1);
    % STDERR : Standard error
    case 'stderr'
        %% This formula was incorrect for standard error. Is it used anywhere?
        Fs = std(F,[],1) ./ sqrt(nRow);
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
        PcaFirstComp = zeros(nRow, nComponents);
        explained = 0;
        for i = 1:nComponents % nComponents should now always be 1 here, but keep code compatible with more for now
            % Use trial data covariance if provided
            if ~isempty(DataCov)
                [U, S] = eig((DataCov + DataCov')/2, 'vector'); % ensure exact symmetry for real results.
                [S, iSort] = sort(S, 'descend');
            else % use data
                % Here, we will probably want to remove the offset removal, but keeping as before for now.
                [U, S] = svd(bsxfun(@minus, F, sum(F,2)./size(F,2)), 'econ', 'vector'); % sum faster than mean
                iSort = 1;
            end
            explained = explained + S(1).^2 / sum(S.^2);
            PcaFirstComp(:,i) = U(:, iSort(1));
        end
        explained = explained / nComponents;
        % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility.
        if ~isempty(PcaReference)
            % Make projection onto reference component positive.
            CompSign = nzsign(sum(PcaFirstComp .* PcaReference));
        else
            % Keep sum of component elements (coefficients for the weighted sum of timeseries) positive.
            % Orientation-based sign flipping was previously applied, if orientations available.
            CompSign = nzsign(sum(PcaFirstComp));
        end
        PcaFirstComp = bsxfun(@times, CompSign, PcaFirstComp);
        Fs = sum(bsxfun(@times, permute(PcaFirstComp, [1,3,2]), F), 1); % dot product of Comp with F on 1st dim, gives size (1, nTime, nComponents)
        % Take into account previous sign flip for returned component (so it applies to non sign flipped data).
        if isSignFlip
            PcaFirstComp = bsxfun(@times, PcaFirstComp, FlipMask);
        end
       
    % PCA computed on all data (all epochs/files) 
    case 'pcaa'
        % DataCov is size (nRow,nRow), where nRow can be nVertex or nVertex*nComponents
        [U, S] = eig((DataCov + DataCov')/2, 'vector'); % ensure exact symmetry for real results.
        [S, iSort] = sort(S, 'descend');
        explained = S(1) / sum(S);
        PcaFirstComp = U(:, iSort(1));
        % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility. 
        % Keep sum of component elements (coefficients for the weighted sum of timeseries) positive.
        % Orientation-based sign flipping was previously applied, if orientations available.
        CompSign = nzsign(sum(PcaFirstComp));
        PcaFirstComp = CompSign * PcaFirstComp;
        Fs = U' * F; % (1, nTime)
        % Take into account previous sign flip for returned component (so it applies to non sign flipped data).
        if isSignFlip
            PcaFirstComp = PcaFirstComp .* FlipMask;
        end
        
    % FAST PCA : Display first mode of PCA of time series within each scout region
    case 'fastpca' % no component returned or "% explained" message
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
            [~, iF] = sort(powF, 'descend');
            iF = iF(1:nMax);
            F = F(iF,:,:);
        end
        % Signal decomposition
        Fs = zeros(1, nTime, nComponents);
        for i = 1:nComponents
            Fs(1,:,i) = PcaFirstMode(F(:,:,i));
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
                if ~isempty(DataCov)
                    [U, S] = eig((DataCov(:,:,i) + DataCov(:,:,i)')/2, 'vector'); % ensure exact symmetry for real results.
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
            % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility.
            if ~isempty(PcaReference)
                % Use PCA across epochs to consistently select the component sign for each epoch.
                CompSign = nzsign(sum(PcaFirstComp .* PcaReference));
            else 
                % Just keep mostly positive coefficients. Reproducible, but inconsistencies still possible.
                CompSign = nzsign(sum(PcaFirstComp));
            end
            PcaFirstComp = bsxfun(@times, CompSign, PcaFirstComp);
            Fs = sum(bsxfun(@times, permute(PcaFirstComp, [2,3,1]), F), 3); % dot product of Comp with F on 3rd dim, gives size (nRow, nTime)

        case 'pcaa'
            % Here, F may be empty, if we save the result as a shared kernel.
            % Get number of sources from covariance.
            nRow = size(DataCov, 3);
            PcaFirstComp = zeros(nComponents, nRow);
            % For each vertex: Signal decomposition
            explained = 0;
            for i = 1:nRow
                [U, S] = eig((DataCov(:,:,i) + DataCov(:,:,i)')/2, 'vector'); % ensure exact symmetry for real results.
                [S, iSort] = sort(S, 'descend');
                explained = explained + S(1) / sum(S);
                PcaFirstComp(:,i) = U(:, iSort(1));
            end
            explained = explained / nRow;
            % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility.
            % Just keep mostly positive coefficients. Here we expect pcaa is run on all available
            % data for a subject at once so consistency would not be an issue, but if that's not the
            % case, e.g. different conditions run separately, inconsistencies are still possible.
            CompSign = nzsign(sum(PcaFirstComp));
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
    if ScoutName
        msg = [msg ' of cluster ' ScoutName];
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
    % Remove ambiguity of arbitrary component sign for consistency across files/epochs (as best we can here with single trial data) and reproducibility.
    % Correct sign and project data onto first PCA component.
    CompSign = nzsign(sum(U));
    F = CompSign * U' * F;
end


% sign() function with no zeros in output (1 instead).
function S = nzsign(X)
    S = sign(X);
    S(S == 0) = 1;
end
