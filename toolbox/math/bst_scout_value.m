function [Fs, Comp] = bst_scout_value(F, ScoutFunction, Orient, nComponents, XyzFunction, isSignFlip, scoutName, Cov)
% BST_SCOUT_VALUE: Combine Ns time series using the given function. Used to get scouts/clusters values.
%
% USAGE:  Fs = bst_scout_value(F, ScoutFunction, Orient=[], nComponents=1, XyzFunction='none', isSignFlip=0)
%         Fs = bst_scout_value(F, ScoutFunction)
%
% INPUTS:
%     - F              : [Nsources * Ncomponents, Ntime] double matrix, source time series
%     - ScoutFunction  : String, function to use to combine the Nsources time series {'mean', 'std', 'mean_norm', 'max', 'power', 'pca', 'fastpca', 'stat', 'all', 'none'}
%     - Orient         : [Nsources x 3], Orientation of each source - usually the normal at the vertex in the cortex mesh
%     - nComponents    : {1,2,3}, Number of components per vertex in matrix F 
%                        If 0, the number varies, the properties of each region are defined in input GridAtlas
%     - XyzFunction    : String, function used to group the the 2 or 3 components per vertex: return only one value per vertex {'norm', 'pca', 'none'}
%     - isSignFlip     : In the case of signed minimum norm values, this will flip the signs of sources with opposite orientations
%     - scoutName      : Name of the scout or cluster you're extracting
%     - Cov            : Covariance matrix between rows of F, but pre-computed across trials. Used for PCA.

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

% ===== PARSE INPUTS =====
if (nargin < 8) 
    Cov = [];
end
if (nargin < 7)
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
if (nargin < 3)
    Orient = [];
end
if (nargin < 2) || isempty(ScoutFunction)
    ScoutFunction = 'none';
end

% ===== ORIENTATION SIGN FLIP =====
% Flip only if there are mixed signs in F (+ and -)
FlipMask = [];
if isSignFlip && (nComponents == 1) && ~isempty(Orient) && ~ismember(lower(ScoutFunction), {'all', 'none'}) && ...
        (size(F,1) > 1) && ~all(F(:) > 0)
    % Check for NaN or Inf values
    if (any(isnan(Orient(:))) || any(isinf(Orient(:))))
        disp('BST> Warning: The vertex normals contain some NaN or Inf values, cannot flip signs. Please check the quality of the cortex surface.');
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
    if ~isempty(FlipMask)
        if all(FlipMask == 1)
            FlipMask = [];
        else
            % Multiply the values by FlipMask
            F = bst_bsxfun(@times, F, FlipMask);
            disp(['BST> Flipped the sign of ' num2str(nnz(FlipMask == -1)) ' sources.']);
        end
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
    case 0,  error('You should call this function for each region individually.');
    case 1,  % Nothing to do
    case 2,  F = cat(3, F(1:2:end,:), F(2:2:end,:));
    case 3,  F = cat(3, F(1:3:end,:), F(2:3:end,:), F(3:3:end,:));
end
nRow  = size(F,1);
nTime = size(F,2);
explained = 0;
Comp = [];

%% ===== COMBINE ALL VERTICES =====
switch (lower(ScoutFunction))       
    % MEAN : Average of the patch activity at each time instant
    case 'mean'
        Fs = mean(F,1);
        if isempty(FlipMask)
            Comp = ones(nRow, 1) ./ nRow;
        else
            Comp = FlipMask ./ nRow;
        end
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
        Comp = zeros(nRow, nComponents);
        for i = 1:nComponents
            [Fs(1,:,i), explained, Comp(:,i)] = PcaFirstMode(F(:,:,i));
            % Take into account previously applied sign flipping.
            if ~isempty(FlipMask)
                Comp(:,i) = Comp(:,i) .* FlipMask;
            end
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
            [tmp__, iF] = sort(powF,'descend');
            iF = iF(1:nMax);
            F = F(iF,:,:);
        else
            iF = 1:nRow;
        end
        % Signal decomposition
        Fs = zeros(1, nTime, nComponents);
        Comp = zeros(nRow, nComponents);
        for i = 1:nComponents
            [Fs(1,:,i), explained, Comp(iF,i)] = PcaFirstMode(F(:,:,i));
            % Take into account previously applied sign flipping.
            if ~isempty(FlipMask)
                Comp(:,i) = Comp(:,i) .* FlipMask;
            end
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
if (nComponents > 1) && (size(Fs,3) > 1)
    nRow = size(Fs,1); % 1 or nComp if ScoutFunction, otherwise original nRow (=nSource)
    % Start from the scouts time series
    F = Fs;
    % Different options to combine the three orientations
    switch lower(XyzFunction)
        % Compute the PCA of all the components
        case 'pca'
            warning('This older PCA implementation suffers from sign flipping between trials.  Global PCA should be used instead.');
            Fs = zeros(nRow, nTime);
            ScoutComp = Comp;
            Comp = zeros(nComponents, nRow);
            % For each vertex: Signal decomposition
            for i = 1:nRow
                [Fs(i,:), explained, Comp(:,i)] = PcaFirstMode(squeeze(F(i,:,:))');
            end
            % Combine scout and orientation components
            if ~isempty(ScoutComp)
                Comp = ScoutComp * Comp; % (nRow before scout func, 1)
            end
            
        case 'pcag'
            Fs = zeros(nRow, nTime);
            if ~isempty(Comp)
                % We must compute the new covariance matrix for the scout.
                Cov = Comp' * Cov * Comp; 
                [U, S] = eig((Cov + Cov')/2);
                [S, iSort] = sort(diag(S), 'descend');
                explained = explained * (S(1) / sum(S));
                U = U(:, iSort(1));
                % Flip sign for consistency across files/epochs. 
                % This simple choice of sign is equivalent to choosing positive correlation of the 
                % component timeseries (concatenated across trials) with the mean timeseries across xyz.
                CompSign = sign(sum(U,1));
                U = CompSign .* U;
                Fs = sum(bsxfun(@times, permute(U, [2,3,1]), F(1,:,:)), 3); % matrix mult of U with F on 3rd dim, gives size (1, nTime)
                % Combine scout PCA and orientation PCA components
                Comp = Comp * U; % (original nRow, 1)
            elseif ~ismember(lower(ScoutFunction), {'all', 'none', 'mean', 'pca', 'pcag'})
                error('Global PCA on orientations (XyzFunction = ''pcag'') after scout function other than PCA or mean not implemented.')
                % To deal with other (non linear) scout functions would require 2 steps to load all scout trials.
            else
                Comp = zeros(nComponents, nRow);
                % For each vertex: Signal decomposition
                for i = 1:nRow
                    %VertCov = Cov(nC*(i-1)+(1:nC), nC*(i-1)+(1:nC));
                    [U, S] = eig((Cov(:,:,i) + Cov(:,:,i)')/2);
                    [S, iSort] = sort(diag(S), 'descend');
                    %                 explained = S(1) / sum(S);
                    U = U(:, iSort(1));
                    % Flip sign for consistency across files/epochs.
                    CompSign = sign(ones(1, size(U,1)) * Cov(:,:,i) * U);
                    U = CompSign .* U;
                    Fs(i,:) = sum(bsxfun(@times, permute(U, [2,3,1]), F(i,:,:)), 3); % matrix mult of U with F on 3rd dim, gives size (1, nTime)
                    Comp(:,i) = U;
                end
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
if explained
    msg = ['BST> Kept component(s) explains ' num2str(explained * 100) '% of the signal'];
    if scoutName
        msg = [msg ' of cluster ' scoutName];
    end
    disp([msg '.']);
end
end


%% ===== PCA: FIRST MODE =====
function [F, explained, U] = PcaFirstMode(F)
    % Do not remove average over time for each row again, it could be better computed previously over baseline.
    % Signal decomposition
    [U, S] = svd(F, 'econ');
    S = diag(S);
    explained = S(1).^2 / sum(S.^2);
    U = U(:,1);
    % Correct sign of the first PC to hopefully be consistent across epochs.
    % Choose sign to have positive correlation with mean timeseries.  Works best if isSignFlip was true when applied to scouts. 
    % For unconstrained source orientation flattening, this doesn't really work: it still leads to cancellation across trials.
    %sign_meancorr = sign(mean(F,1) * (U' * F)');
    % Mathematically equivalent simpler expression, using the definition of the eigen-decomp: 
    % U*S^2*U' = F*F' => U1' * F * F' * ones = S1^2 sum(U1)
    sign_meancorr = sign(sum(U));
    F = sign_meancorr * U' * F;
end


