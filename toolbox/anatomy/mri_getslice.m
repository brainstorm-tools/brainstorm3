function s = mri_getslice(vol, n, orien, doMIP, nmean, voxsize)
% MRI_GETSLICE: Get MRI slice.
%
% USAGE:  s = mri_getslice(vol, n, orien, doMIP, nmean, voxsize)
%         s = mri_getslice(vol, n, orien, doMIP, nmean) : voxsize = [1 1 1]
%         s = mri_getslice(vol, n, orien, doMIP)        : nmean = 0
%         s = mri_getslice(vol, n, orien)               : doMIP = 0
%
% INPUT: 
%    - vol   : 3D MRI volume
%    - n     : indice of the slice to get
%    - orien : dimension along which the slice is extracted (1,2 or 3)
%    - doMIP : If 1, compute maximum intensity projection in the volume (optional, default is 0)
%    - nmean : 0, no smoothing
%              >0, smoothes across n-nmean:n+nmean consecutive views
%    - voxsize: Voxel size of the volume vol, in millimeters (has to be provided to perform an isotropic smoothing)
% OUTPUT:
%    - s     : extracted MRI slice (2D numeric array)
 
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
% Authors: Francois Tadel, Sylvain Baillet, 2008-2011

% Parse inputs
if (nargin < 6) || isempty(voxsize)
    voxsize = [1 1 1];
end
if (nargin < 5) || isempty(nmean)
    nmean = 0;
end
if (nargin < 4) || isempty(doMIP)
    doMIP = 0;
end
% Extract the required slice
if doMIP==0
    % No smoothing
    if (nmean == 0)
        % Get the slice of interest
        switch orien
            case 1,  s = squeeze(vol(n,:,:,:));
            case 2,  s = squeeze(vol(:,n,:,:));
            case 3,  s = squeeze(vol(:,:,n,:));
        end
    % Smoothing
    else        
        % Get the block of slices we want to average
        if (n-nmean < 1)
            n_block = 1:(2*nmean+1);
        elseif (n+nmean > size(vol,orien))
            n_block = size(vol,orien) + ((-2*nmean):0);
        else
            n_block = n + (-nmean:nmean);
        end

        % Get a few slices around the one we are interested about
        switch orien
            case 1
                s = squeeze(vol(n,:,:));
                sm = vol(n_block,:,:);
                sm = permute(sm, [2 3 1]);   % Makes convn much faster (having the smallest dimension in 3rd position)
                voxsize = voxsize([2 3 1]);
            case 2
                s = squeeze(vol(:,n,:));
                sm = vol(:,n_block,:);
            case 3
                s = squeeze(vol(:,:,n));
                sm = vol(:,:,n_block);
        end
        % Get the maximum value for the initial slice
        smax = max(abs(s(:)));
        if (smax == 0)
            smax = max(abs(sm(:)));
        end
        % Create isotropic 3D gaussian kernel
        [X Y Z] = meshgrid(-nmean:nmean, -nmean:nmean, -nmean:nmean);
        Dist = ((X./voxsize(1)).^2 + (Y./voxsize(2)).^2 + (Z./voxsize(3)).^2) .^ .5;
    end

% Maximum Intensity Projection (MIP): get max over all the slices
else
    % Compute maximum in required direction
    [s,I] = max(abs(vol),[],orien);
    I = squeeze(I);
    s = squeeze(s);
    sv = size(vol);
    % Get the indices of the maximums in the full volume
    switch orien
        case 1
            iDim1 = repmat(1:sv(2), 1, sv(3))';
            iDim2 = reshape(repmat(1:sv(3), sv(2), 1), [], 1);
            iVol = sub2ind(size(vol), I(:), iDim1, iDim2);
        case 2
            % Get the indices of the maxima in the full folume
            iDim1 = repmat(1:sv(1), 1, sv(3))';
            iDim2 = reshape(repmat(1:sv(3), sv(1), 1), [], 1);
            iVol = sub2ind(size(vol), iDim1, I(:), iDim2);
        case 3
            % Get the indices of the maxima in the full volume
            iDim1 = repmat(1:sv(1), 1, sv(2))';
            iDim2 = reshape(repmat(1:sv(2), sv(1), 1), [], 1);
            iVol = sub2ind(size(vol), iDim1, iDim2, I(:));
    end
    % Re-apply the sign of the detected maximum
    s = s .* reshape(sign(vol(iVol)), size(s));
    % Specific to prepare smoothing
    if (nmean > 0)
        % Get maximum of unsmoothed slice
        smax = max(s(:));
        sm = s;
        % Create isotropic 2D gaussian kernel
        [X Y] = meshgrid(-nmean:nmean, -nmean:nmean);
        voxsize(orien) = [];
        Dist = ((X./voxsize(1)).^2 + (Y./voxsize(2)).^2) .^ .5;
    end
end

% Common computation: applying the smoothing kernel
if (nmean > 0)
    % Create 3D gaussian kernel
    Sigma = nmean + .5;
    kernel = exp(-(Dist.^2) ./ Sigma.^2);
    % Convolution of the slices block with the smoothing kernel
    sm = squeeze(convn(sm, kernel, 'valid'));
    % Pad smoothed data with intial values
    s(nmean+1:end-nmean, nmean+1:end-nmean) = sm;
    % Normalize to the highest value in the original slice (before smoothing)
    if (smax ~= 0)
        s = s ./ max(abs(s(:))) .* smax;
    end
end


