function [Fs, PcaFirstComp, HistoryMsg] = bst_scout_value(F, ScoutFunction, Orient, nComponents, XyzFunction, isSignFlip, ScoutName, Covar, PcaReference)
% BST_SCOUT_VALUE: Combine Ns time series using the given function. Used to get scouts/clusters values.
%
% USAGE:  Fs = bst_scout_value(F, ScoutFunction, Orient=[], nComponents=1, XyzFunction='none', isSignFlip=0, ScoutName=[], Covar=[], PcaReference=[])
%
% INPUTS:
%     - F             : [Nsources * Ncomponents, Ntime] double matrix, source time series
%     - ScoutFunction : String, function to use to combine the Nsources time series: 
%                       {'mean', 'std', 'mean_norm', 'max', 'power', 'pca', 'pca2023', 'fastpca', 'stat', 'all', 'none'}
%     - Orient        : [Nsources x 3], Orientation of each source - usually the normal at the vertex in the cortex mesh
%     - nComponents   : {1,2,3}, Number of components per vertex in matrix F 
%                       If 0, the number varies, the properties of each region are defined in input GridAtlas
%     - XyzFunction   : String, function used to group the the 2 or 3 components per vertex: return only one value per vertex {'norm', 'pca', 'pca2023', 'none'}
%     - isSignFlip    : In the case of signed minimum norm values, this will flip the signs of sources with opposite orientations
%     - ScoutName     : Name of the scout or cluster you're extracting
%     - Covar         : Covariance matrix between rows of F, pre-computed for one or more epochs. Used for PCA 2023 version.
%                       For PCA ScoutFunction: [Nrows x Nrows]; for PCA XyzFunction only (no ScoutFunction): 
%                       [3 x 3 x Nsources] 3 source orientations at each location
%     - PcaReference  : Reference PCA components (see PcaFirstComp below for possible sizes) pre-computed across 
%                       epochs, used to pick consistent sign for each epoch
%
% OUTPUTS:
%     - Fs           : Combined time series. [Ncomponents x Ntime] for ScoutFunction only, [Nsources x Ntime] 
%                      for XyzFunction, or [1 x Ntime] for both.
%     - PcaFirstComp : First mode of the PCA, as column(s). [Nsources, Ncomponents] for ScoutFunction only, 
%                      [3 x Nsources] for XyzFunction, or [Nsources * Ncomponents, 1] for both.
%     - HistoryMsg   : For PCA, indication of kept variance in 1st principal component(s), as a cell array of strings.
%                      Note that this is computed with the PCA options (PCA time window and possibly DC offset
%                      on baseline), which may differ from the data on which the component is later applied.
%
% NOTES: 
%     ScoutFunction is applied before XyzFunction. But when both are pca2023, they are done simultaneously. 
%       Within the Brainstorm interface, this only happens when viewing time series from the scout panel.
%     For ScoutFunction 'pca2023', the PCA component (vector of source coefficients) is rescaled by 1/sqrt(nVertices)
%       to match the scaling of 'mean', and to be more easily comparable between scouts.

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
% Authors: Sylvain Baillet, Francois Tadel, John Mosher, Marc Lalancette, 2010-2023

% ===== PARSE INPUTS =====
if (nargin < 9) || isempty(PcaReference)
    PcaReference = [];
end
if (nargin < 8) || isempty(Covar)
    Covar = [];
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
HistoryMsg = {};

% ===== ORIENTATION SIGN FLIP =====
% PCA & orientation sign flipping: by flipping here for PCA, the resulting component sign is as if the activity
% was coming from a source with the dominant orientation, regardless of where the component weights are strong. 
if strncmpi(ScoutFunction, 'pca', 3) && isempty(PcaReference)
    isSignFlip = true;
end
% Flip only if there are mixed signs in F (+ and -)
FlipMask = [];
if isSignFlip && (nComponents == 1) && ~isempty(Orient) && ~ismember(lower(ScoutFunction), {'all', 'none'}) && ...
        ( isempty(F) || (size(F,1) > 1 && ~all(F(:) > 0)) )
    % Check for NaN or Inf values
    if (any(isnan(Orient(:))) || any(isinf(Orient(:))))
        disp('BST> Warning: The vertex normals contain some NaN or Inf values, cannot flip signs. Please check the quality of the cortex surface.');
    else
        % Take the SVD to get the dominant orientation in this patch
        % U(:,1) is the dominant orientation
        [U,S] = svd(Orient, 'econ');
        % Get the flip mask for the data values
        FlipMask = sign(U(:,1)); % careful: sign(0) == 0
        % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility. 
        % Keep FlipMask mostly positive; flip the sign of the minimum number of time series. 
        if (nnz(FlipMask > 0) < nnz(FlipMask < 0))
            FlipMask = -FlipMask;
        end
        % Replace zeros (exaclty orthogonal to dominant orientation) by 1: don't ignore any sources. 
        % This also fixes the bug for volume models where all orientations=[0,0,0], which gives FlipMask=[1,0,0,0,0,0,...].
        FlipMask(FlipMask == 0) = 1;

        % If not all the values are of the same sign, flip
        if all(FlipMask == 1)
            FlipMask = [];
        else
            % Multiply the values by FlipMask
            if ~isempty(F)
                F = bsxfun(@times, F, FlipMask);
            end
            if ~isempty(Covar)
                % Also apply to Covar in both dimensions
                Covar = bsxfun(@times, bsxfun(@times, Covar, FlipMask'), FlipMask);
            end
            disp(['BST> Flipped the sign of ' num2str(nnz(FlipMask == -1)) ' sources.']);
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
% Enforce limitations on combining PCA on scout or xyz with other functions.
% But still allow deprecated previous behavior of doing 'pca' on scouts for x,y,z separately, with warning.
if nComponents > 1 && ~strcmpi(ScoutFunction, XyzFunction)
   if strcmpi(ScoutFunction, 'pca') && isempty(Covar)
       disp('BST> Warning: Extracting scouts on x,y,z separately is not recommended.');
   elseif strcmpi(XyzFunction, 'pca')  && ~ismember(ScoutFunction, {'all', 'none'})
       error('For PCA XyzFunction, it should be applied before extracting scouts, or at the same time with the same PCA function.');
   end
end
if strcmpi(ScoutFunction, 'pca2023')
    % Store nComp for rescaling, in case we're doing combined scout and xyz PCA.
    nCompPcaCombined = nComponents;
    if strcmpi(ScoutFunction, XyzFunction)
        % In this case, XyzFunction is also pca and we'll compute it on all sources (locations and orientations) at once.
        nComponents = 1;
    end
end
% Reshape F matrix in 3D: [nRow, nTime, nComponents], where nRow is the number of source locations (vertices for surface models).
switch (nComponents)
    case 0,     error('You should call this function for each region individually.');
    case 1      % Nothing to do
    case {2,3} 
        F = permute(reshape(F, nComponents, size(F,1)/nComponents, size(F,2)), [2, 3, 1]); % permute/reshape faster than cat
end
% F might be empty for PCA. Use Covar in that case.
if size(F,1) == 0
    if ndims(Covar) == 3
        nRow = size(Covar, 3);
    else
        nRow = size(Covar, 1);
    end
else
    nRow = size(F,1);
end
nTime = size(F,2);
explained = [];


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
        % This would be the value comparable to the PCA component "explained variance" / kept power.
        % Uncomment to compare with PCA.
        % explained = sum(Fs(:).^2) * nRow / sum(F(:).^2);

    % STD : Standard deviation of the patch activity at each time instant
    case 'std'
        Fs = std(F,[],1);
    % STDERR : Standard error
    case 'stderr'
        %% This formula was incorrect for standard error (fixed 2023-04). Is it used anywhere?
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
        % If one component: signed max(abs)
        if (nComponents == 1)
            Fs = bst_max(F,1);
        else
            % Get the maximum of the norm across orientations, at each time
            [~, iMax] = max(sum(F.^2, 3), [], 1);
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
        % This would be the value comparable to the PCA component "explained variance" / kept power.
        % explained = sum(Fs(:)) * nRow / sum(F(:).^2);

    % PCA : First mode of PCA of time series within each scout region
    % This case now works for all 3 'pca' choices: the legacy per-file method, the sign-corrected
    % per-file method, or the "across files" method.  This is determined by the inputs (F, Covar and
    % PcaReference).
    % As the original method is still supported, we still allows keeping 3 separate orientation components.
    case 'pca2023' % {'pca', 'pcai', 'pcaa'}
        % Signal decomposition
        % Use trial data covariance if provided
        if ~isempty(Covar)
            % Allow nComponents > 1 here if we want the same PCA component to be applied on x,y,z
            % separately, in which case Covar should be summed over x,y,z before calling this function.
            %             if nComponents > 1
            %                 error('Scout Covar provided but nComponents > 1');
            %             end
            [U, S] = eig((Covar + Covar')/2, 'vector'); % ensure exact symmetry for real results.
            [S, iSort] = sort(S, 'descend');
            PcaFirstComp = U(:, iSort(1));
            explained = S(1) / sum(S);
        else % use data
            % This is a deprecated case, but still used for display. It's not taking into account
            % baseline and data time windows like when we compute the covariance (outside this
            % function). nComponents should now always be 1 here, but keep code compatible for
            % non-standard calls and testing old behaviour.
            explained = [0, 0];
            PcaFirstComp = zeros(nRow, nComponents);
            for i = 1:nComponents
                % Keeping offset removal as before: whole trial.
                [U, S] = svd(bsxfun(@minus, F(:,:,i), sum(F(:,:,i),2)./size(F,2)), 'econ'); % sum faster than mean
                S = diag(S);
                explained = explained + [S(1).^2, sum(S.^2)];
                PcaFirstComp(:,i) = U(:, 1);
            end
            explained = explained(1) / explained(2);
        end
        % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility.
        if ~isempty(PcaReference)
            % Make projection onto reference component positive.
            CompSign = nzsign(PcaReference' * PcaFirstComp);
        else
            % Keep sum of component elements (coefficients for the weighted sum of timeseries) positive.
            % Orientation-based sign flipping was applied above, if orientations available.
            CompSign = nzsign(sum(PcaFirstComp));
        end
        PcaFirstComp = bsxfun(@times, CompSign, PcaFirstComp);
        % Rescale before applying component to timeseries. (nComp/nComp is for when we're doing
        % scout and xyz combined, to recover the real number of vertices.)
        PcaFirstComp = PcaFirstComp / sqrt(nRow * nComponents / nCompPcaCombined);
        if ~isempty(F)
            % Dot product of Comp with F on 1st dim (sources), gives size (1, nTime, nComponents).
            % Compatible with either or both having multiple components.
            Fs = sum(bsxfun(@times, permute(PcaFirstComp, [1,3,2]), F), 1); 
        else
            Fs = [];
        end
        % Take into account previous sign flip for returned component (so it applies to non sign flipped data).
        if isSignFlip
            PcaFirstComp = bsxfun(@times, PcaFirstComp, FlipMask);
        end
       
    % Unmodified now deprecated legacy PCA: with sign issues, no rescaling, and DC offset and svd on entire time window.
    case 'pca'
        Fs = zeros(1, nTime, nComponents);
        explained = [0, 0];
        for i = 1:nComponents
            [Fs(1,:,i), ExplTemp] = PcaFirstMode(F(:,:,i), true); % use legacy "bugged" sign
            explained = explained + ExplTemp;
        end
        explained = explained(1) / explained(2);
        
    %% TODO: test and probably remove this option from GUI
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
            [~, iF] = sort(powF,'descend');
            F = F(iF(1:nMax),:,:);
        end
        % Signal decomposition
        Fs = zeros(1, nTime, nComponents);
        explained = [0, 0];
        for i = 1:nComponents
            [Fs(1,:,i), ExplTemp] = PcaFirstMode(F(:,:,i), false); % use improved sign
            explained = explained + ExplTemp;
        end
        explained = explained(1) / explained(2);
        
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

% Display percentage of signal explained by 1st component(s) of PCA
% Now properly combines multiple orientations if present.
if ~isempty(explained) && nargout > 2
    HistoryMsg{end+1} = sprintf('PCA for scout: %1.1f%% of signal power kept', explained * 100);
    if ScoutName
        HistoryMsg{end} = [HistoryMsg{end} ' in ' ScoutName];
    end
    HistoryMsg{end} = [HistoryMsg{end} '.'];
end


%% ===== COMBINE ALL ORIENTATIONS =====
% If there are more than one component in output
if (nComponents > 1) && (size(Fs,3) > 1 || isempty(Fs))
    if ~isempty(Fs)
        nRow = size(Fs,1); % 1 or nComp if ScoutFunction, otherwise original nRow
    end
    explained = [];
    % Different options to combine the three orientations
    switch lower(XyzFunction)
        % Compute the PCA of all the components
        case 'pca2023' % {'pca', 'pcaa', 'pcai'}
            PcaFirstComp = zeros(nComponents, nRow);
            % For each vertex: Signal decomposition
            explained = [0, 0];
            for i = 1:nRow
                % Use trial data covariance if provided. This only happens if there were no scout extraction.
                if ~isempty(Covar)
                    [U, S] = eig((Covar(:,:,i) + Covar(:,:,i)')/2, 'vector'); % ensure exact symmetry for real results.
                    [S, iSort] = sort(S, 'descend');
                    explained = explained + [S(1), sum(S)];
                else % use data
                    Fi = permute(Fs(i,:,:), [3,2,1]); % permute faster than squeeze
                    % This is an unexpected legacy case. It's not taking into account baseline and data time windows like when we use a covariance.
                    % Keeping offset removal as before for now.
                    [U, S] = svd(bsxfun(@minus, Fi, sum(Fi,2)./size(Fi,2)), 'econ'); % sum faster than mean
                    S = diag(S);
                    iSort = 1;
                    explained = explained + [S(1).^2, sum(S.^2)];
                end
                PcaFirstComp(:,i) = U(:, iSort(1));
            end
            explained = explained(1) / explained(2);
            % Remove ambiguity of arbitrary component sign for consistency across files/epochs and reproducibility.
            if ~isempty(PcaReference)
                % Use PCA across epochs to consistently select the component sign for each epoch.
                CompSign = nzsign(sum(PcaFirstComp .* PcaReference));
            else 
                % Just keep mostly positive coefficients. Reproducible, but inconsistencies still possible.
                CompSign = nzsign(sum(PcaFirstComp));
            end
            PcaFirstComp = bsxfun(@times, CompSign, PcaFirstComp);
            if ~isempty(Fs)
                Fs = sum(bsxfun(@times, permute(PcaFirstComp, [2,3,1]), Fs), 3); % dot product of Comp with F on 3rd dim, gives size (nRow, nTime)
            end
            
        % Unmodified now deprecated legacy PCA: with sign issues, and DC offset and svd on entire time window.
        case 'pca'
            F = Fs;
            Fs = zeros(nRow, nTime);
            explained = [0, 0];
            % For each vertex: Signal decomposition
            for i = 1:nRow
                if i == 36
                    tic;
                end
                [Fs(i,:), ExplTemp] = PcaFirstMode(permute(F(i,:,:), [3,2,1]), true); % use legacy "bugged" sign
                explained = explained + ExplTemp;
            end
            explained = explained(1) / explained(2);
            
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
        error(['Unknown flattening function: ' XyzFunction]);
    end

    % Display percentage of signal explained by 1st component(s) of PCA
    % Now displayed separately from scout PCA. They shouldn't occur together anymore in recommended
    % usage: scout pca (or other scout function) followed by orient pca is deprecated. 
    if ~isempty(explained) && nargout > 2
        HistoryMsg{end+1} = sprintf('PCA for source orientation: %1.1f%% of signal power kept', explained * 100);
        if ScoutName
            HistoryMsg{end} = [HistoryMsg{end} ' in ' ScoutName];
        end
        HistoryMsg{end} = [HistoryMsg{end} '.'];
    end
end

end


%% ===== PCA: FIRST MODE =====
% Now only used for deprecated legacy pca and 'fastpca'.
function [F, explained] = PcaFirstMode(F, isLegacySign)
    % Signal decomposition / Remove average over time for each row
    FDemeaned = bsxfun(@minus, F, sum(F,2)./size(F,2));
    [U, S, V] = svd(FDemeaned, 'econ'); %sum(F,2)./size(F,2)
    S = diag(S);
    explained = [S(1).^2, sum(S.^2)];
    U = U(:,1);
    if isLegacySign
        % This section does not work properly: the resulting sign is arbitrary and leads to averaging issues.
        % Find which original signal has the largest coefficient in the first component
        [~, nmax] = max(abs(U));
        % What's the sign of absolute max amplitude in this signal?
        [~, i_omaxx] = max(abs(FDemeaned(nmax,:)));
        sign_omaxx = sign(FDemeaned(nmax,i_omaxx));
        % Sign of maximum in first component time series [at a different time - so unrelated actually]
        [~, i_Vmaxx] = max(abs(V(:,1)));
        sign_Vmaxx = sign(V(i_Vmaxx,1));
        % Reconcile signs
        CompSign = sign_Vmaxx * sign_omaxx;
    else
        % Remove ambiguity of arbitrary component sign for consistency across files/epochs and
        % reproducibility, as best we can here with single trial data.
        CompSign = nzsign(sum(U));
    end
    % Correct sign and project data onto first PCA component.
    F = CompSign * U' * F;
end


% sign() function with no zeros in output (1 instead).
function S = nzsign(X)
    S = sign(X);
    S(S == 0) = 1;
end
