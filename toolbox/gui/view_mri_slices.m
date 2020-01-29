function hFig = view_mri_slices(varargin)
% VIEW_MRI_SLICES: Displays a given number of slices, in the given direction.
%
% USAGE:  view_mri_slices(mriCube, orientation, nbSlices [, cmapname])
%         view_mri_slices(mriFileName, orientation, nbSlices [, cmapname])
% INPUT: 
%     - mriCube     : [Nx,Ny,Nz] matrix
%     - mriFileName : full path to a .mat mri file
%     - orientation : {'x','y','z'}
%     - nbSlices    : number of slices displayed in the window
%     - cmapname    : colormap name used to display slices (default:'gray')
%  
% OUTPUT: handle to created Matlab figure

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
% Authors: Francois Tadel, 2006 (University of Geneva), 2008-2010 (USC)


%% ===== PARSE INPUTS =====
if ((nargin == 3) || (nargin == 4))
    % Call: viewMriSlices(mriFileName, orientation, nbSlices)
    if (ischar(varargin{1}))
        mriFileName = varargin{1};
        % Load MRI .MAT file
        mriMat = in_mri_bst(mriFileName);
        % Get some of the MRI fields 
        mriCube = mriMat.Cube;
    % Call: viewMriSlices(mriCube, orientation, nbSlices)
    elseif (ndims(varargin{1}) == 3)
        mriCube = varargin{1};
    else
        error('First argument must be either MRI volume or a MRI filename');
    end
    % Mri size
    mriSize = size(mriCube);
    
    % Orientation
    orientation = varargin{2};
    % Interprete the direction
    switch lower(orientation)
        case {'sagittal', 'x'}
            dim = 1;
            nbMaxSlices = mriSize(1);
        case {'coronal', 'y'}
            dim = 2;
            nbMaxSlices = mriSize(2);
        case {'axial', 'z'}
            dim = 3;
            nbMaxSlices = mriSize(3);
        otherwise
            error('view_mri_slices:BadOrientation', 'Invalid slice orientation : ''%s''', orientation);
    end
    % NbSlices
    nbSlices = min(varargin{3}, nbMaxSlices);   
else
    error('Usage : view_mri_slices(mri, orientation, nbSlices)');
end



%% ===== CREATE IMAGE LIST =====
indexesToKeep = floor(linspace(0.2*nbMaxSlices, 0.8*nbMaxSlices, nbSlices));
if (dim == 2) || (dim == 3)
    indexesToKeep = bst_flip(indexesToKeep,2);
end
for sliceIndex=1:length(indexesToKeep)
    imageList(:,:,sliceIndex) = rot90(mri_getslice(mriCube, indexesToKeep(sliceIndex), dim));
end
% Apply radiological orientation (if necessary)
MriOptions = bst_get('MriOptions');
if MriOptions.isRadioOrient
    imageList = bst_flip(imageList, 2);
end

% Switch to the format required by the functions immovie and montage : [MxNx1xK]
imageListSize = size(imageList);
imageList = reshape(imageList, imageListSize(1), imageListSize(2), 1, imageListSize(3));


%% ===== MONTAGE ===== 
% Montage of all images on the same image (montage.m modified)
[nRows, nCols, nBands, nFrames] = size(imageList);

% Estimate nMontageColumns and nMontageRows given the desired ratio of
% Columns to Rows to be one (square montage).
aspectRatio = 1; 
nMontageCols = realsqrt(aspectRatio * nRows * nFrames / nCols);

% Make sure montage rows and columns are integers. The order in the adjustment
% matters because the montage image is created horizontally across columns.
nMontageCols = ceil(nMontageCols); 
nMontageRows = ceil(nFrames / nMontageCols);

% Create the montage image.
montageImg = imageList(1,1); % to inherit type from imageList
montageImg(1,1) = 0; 
montageImg = repmat(montageImg, [nMontageRows*nRows, nMontageCols*nCols, nBands, 1]);

rows = 1 : nRows; 
cols = 1 : nCols;
for i = 0:nMontageRows-1
  for j = 0:nMontageCols-1,
    k = j + i * nMontageCols + 1;
    if k <= nFrames
      montageImg(rows + i * nRows, cols + j * nCols, :) = imageList(:,:,:,k);
    else
      break;
    end
  end
end

%% ===== DISPLAY RESULTS =====
% Get default directories
LastUsedDirs = bst_get('LastUsedDirs');
% Build default filename
defaultFile = bst_fullfile(LastUsedDirs.ExportImage, 'mri.tif');
% Display image
hFig = view_image(montageImg, 'bone', sprintf('View slices (orientation:%s)', orientation), defaultFile);


end



