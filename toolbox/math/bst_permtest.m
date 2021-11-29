function [pv,S0,nGoodA,nGoodB,PS] = bst_permtest(A, B, TestType, dimPerm, nPerm, tails, isZeroBad)
% PERMTEST: Generic randomization test.
%
% USAGE:  [pv,S0,nGoodA,nGoodB,PS] = bst_permtest(A, B, TestType, dimPerm, nPerm, tails, isZeroBad)
%
% INPUTS:
%    - A, B     : [Ma x Mb...] Variables to test   
%    - TestType : {'ttest_equal', 'ttest_unequal', 'ttest_paired', 'wilcoxon_paired', 'wilcoxon', 'signtest'}
%         ttest_equal   : Student's t-value, equal variance
%         ttest_unequal : Student's t-value, unequal variance
%         ttest_paired  : Student's t-value, paired data
%         signtest      : Sign of the differences (paired)
%         wilcoxon      : Signed ranks (paired)
%         absmean       : Difference of absolute values of means
%    - dimPerm   : Dimension to permute (ie. subjects)
%    - nPerm     : Number of permutations
%    - tails     : 'one+' (X1>X2), 'one-' (X1<X2), 'two' (X1<X2 or X1>X2)
%    - isZeroBad : If 1, excludes zeros from all the calculations
%
% OUTPUTS:
%    - pv    : [Ma x Mb...] p-values of the observed data, computed from the permutations
%    - S0    : [Ma x Mb...] Observed values of the statistic
%    - nGoodA: [Ma x Mb...] Number of good samples for each set of measures in A
%    - nGoodB: [Ma x Mb...] Number of good samples for each set of measures in B
%    - PS    : [P x Ma x Mb... ] Matrix of permutation statistics (may be quite big!)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Karim Jerbi, Karim N'Diaye, 2005-2006
%          Francois Tadel, 2016  (complete recoding)


% ===== PERMUTE INPUT =====
bst_progress('text', 'Initialization...');
% List of paired tests
isPaired = ismember(TestType, {'ttest_paired', 'wilcoxon_paired', 'signtest'});
% Put the dimension to permute in the 1st dimension
dimData = setdiff(1:ndims(A), dimPerm);
sizeData = size(A);
sizeData = sizeData(dimData);
A = permute(A, [dimPerm, dimData]);
B = permute(B, [dimPerm, dimData]);
% Number of samples to permute
nA = size(A,1);
nB = size(B,1);
nAvgA = [];
nAvgB = [];
nGoodA = [];
nGoodB = [];
% Concatenate two input variables
X = cat(1, A, B);
% Try to compile the needed mex function
if (exist('bst_meanvar', 'file') ~= 3)
    if ~bst_compile_mex('toolbox/math/bst_meanvar', 0)
        error('Cannot compile mex function bst_meanvar.c...');
    end
end
% Compute indices of (x,y,z) orientations for unconstrained sources
if strcmpi(TestType, 'absmean_unconstr')
    % Oriention X
    M = false(sizeData);
    M(1:3:end,:,:,:) = 1;
    iOrientX = find(M);
    % Oriention Y
    M = false(sizeData);
    M(2:3:end,:,:,:) = 1;
    iOrientY = find(M);
    % Oriention Z
    M = false(sizeData);
    M(3:3:end,:,:,:) = 1;
    iOrientZ = find(M);
    % Output size: only 1 every 3 rows
    sizeData(1) = sizeData(1) / 3;
end

% ===== LIST OF PERMUTATIONS =====
% Paired
if isPaired
    P = round(rand(nPerm, nA));
    P = [P, 1-P] .* nA(1) + repmat(1:nA, [nPerm,2]);
% Independent
else
    [ignore,P] = sort(rand(nPerm, nA+nB), 2);
end


% ===== PERMUTATION LOOP =====
tic;
for i = 0:nPerm
    % Count time per iteration
    tTotal = toc;
    tIter = (tTotal / i);
    % Estimate remaining time
    if (i >= 10)
        nSec = round(tIter * (nPerm - i));
        if (nSec <= 60)
            strTime = sprintf('[%ds remaining]', nSec);
        else
            strTime = sprintf('[%dmin remaining]', ceil(nSec / 60));
        end
    else
        strTime = '';
    end
    if (tIter > 1) || (mod(i,10) == 0)
        bst_progress('text', sprintf('Randomizations:  %d / %d...       %s', i, nPerm, strTime));
    end
    
    % At the 0-th permutation, evaluate original data
    if (i == 0)
        iA = 1:nA;
        iB = nA + (1:nB);
    else
        iA = P(i, 1:nA);
        iB = P(i, nA+(1:nB));
    end
    switch (TestType)
        case {'ttest_equal', 'ttest_unequal', 'absmean', 'absmean_unconstr'}  % INDEPENDENT
            % Compute mean and variance
            [mA,vA,nAvgA] = bst_meanvar(double(X(iA,:)), isZeroBad);
            [mB,vB,nAvgB] = bst_meanvar(double(X(iB,:)), isZeroBad);
            % Convert number of good samples to double
            nAvgA = double(nAvgA);
            nAvgB = double(nAvgB);
            % Remove null variances
            iNull = ((vA == 0) | (vB == 0));
            vA(iNull) = eps;
            vB(iNull) = eps;
            % Compute t-test
            switch (TestType)
                case 'ttest_equal'
                    pvar = ((nAvgA-1).*vA + (nAvgB-1).*vB) ./ (nAvgA + nAvgB - 2);
                    Z = (mA-mB) ./ sqrt(pvar .* (1./nAvgA + 1./nAvgB));
                case 'ttest_unequal'
                    Z = (mA-mB) ./ sqrt(vA./nAvgA + vB./nAvgB);
                case 'absmean'
                    Z = (abs(mA)-abs(mB)) ./ sqrt(vA./nAvgA + vB./nAvgB);
                case 'absmean_unconstr'
                    % Compute the norm of the mean and variance of each condition
                    mAnorm = sqrt(mA(iOrientX).^2 + mA(iOrientY).^2 + mA(iOrientZ).^2);
                    mBnorm = sqrt(mB(iOrientX).^2 + mB(iOrientY).^2 + mB(iOrientZ).^2);
                    vAnorm = sqrt(vA(iOrientX).^2 + vA(iOrientY).^2 + vA(iOrientZ).^2);
                    vBnorm = sqrt(vB(iOrientX).^2 + vB(iOrientY).^2 + vB(iOrientZ).^2);
                    % Assuming that (x,y,z) are always good or bad together
                    nAvgA = nAvgA(iOrientX);
                    nAvgB = nAvgB(iOrientX);
                    % Compute statistic
                    Z = (mAnorm - mBnorm) ./ sqrt(vAnorm./nAvgA + vBnorm./nAvgB);
            end

        case 'ttest_paired'   % INDEPENDENT
            % Compute difference of pairs (A-B)
            D = X(iA,:) - X(iB,:);
            % Compute mean and variance
            [mD,vD,nAvgA] = bst_meanvar(double(D), isZeroBad);
            % Convert number of good samples to double
            nAvgA = double(nAvgA);
            % Remove null variances
            iNull = (vD == 0);
            vD(iNull) = eps;
            % Compute t-test
            Z = mD ./ sqrt(vD./nAvgA);

        case 'signtest'     % PAIRED
            % Compute difference of pairs (A-B)
            D = X(iA,:) - X(iB,:);
            % Measure of asymetry between the two samples
            Z = sum(sign(D),1).^2 ./ sum(abs(sign(D)),1);
            % WARNING: BAD VALUES (=ZERO) ARE NOT TAKEN INTO ACCOUNT (SHOULD NOT ALTER THE MEASURE)
            iNull = [];
            
        case 'wilcoxon_paired'     % PAIRED
            % Compute difference of pairs (A-B)
            D = X(iA,:) - X(iB,:);
            % Compute Wilcoxon statistic (sum of signed ranks)
            Z = sum(sign(D) .* dm_tiedrank(abs(D),1), 1);
            % WARNING: BAD VALUES (=ZERO) ARE NOT TAKEN INTO ACCOUNT (COULD ALTER THE MEASURE!!)
            iNull = [];
%         case 'wilcoxon'    % INDEPENDENT
%             R = dm_tiedrank(X, 1);
%             %Z = sum(R(iA,:), 1);
%             Z1 = sum(R(iA,:), 1);
%             Z2 = sum(R(iB,:), 1);
%             % ??? HOW TO HANDLE THE TWO TESTS
%             % one-:  Z2 > S02
%             % one+:  Z1 > S01
%             % two:   (Z1 > S01) | (Z2 > S02)
        otherwise
            error('Invalid statistic.')
    end
    % Remove null values
    Z(iNull) = 0;
    % Remove the permuted dimension
    Z = reshape(Z, sizeData);
    % First iteration
    if (i == 0)
        % Save the statistic for the original data
        S0 = Z;
        % Initialize sum statistic
        S = zeros(sizeData);
        % Save statistics for all the permutations
        if (nargout >= 5)
            PS = zeros([nPerm, sizeData, 1],'single');
        end
        % Count all good and bad channels for each set
        if ~isempty(nAvgA)
            nGoodA = reshape(nAvgA, sizeData);
        end
        if ~isempty(nAvgB)
            nGoodB = reshape(nAvgB, sizeData);
        end
    else
        % Count the number of times where the permuted statistic exceeds the original stat
        switch (tails)
            case 'one-'
                S = S + (Z <= S0);
            case 'one+'
                S = S + (Z >= S0);
            case 'two'
                S = S + (abs(Z) >= abs(S0));
        end
        % Save statistics for all the permutations
        if (nargout >= 5)
            PS(i,:) = Z;
        end
    end
end

% Compute resulting p-values
pv = (S+1) ./ (nPerm+1);



