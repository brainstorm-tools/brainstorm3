function [hFig, iDS, iFig] = view_covariance(TimefreqFile, DisplayMode, hFig)
% VIEW_CONNECT: Display a NxN connectivity matrix
%
% USAGE: [hFig, iDS, iFig] = view_connect(TimefreqFile, DisplayMode='GraphFull', hFig=[])
%
% INPUT: 
%     - TimefreqFile : Path to connectivity file to visualize
%     - DisplayMode  : {'GraphFull'}
%     - hFig         : If defined, display file in existing figure
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2012-2016; Martin Cousineau, 2019-2021;
% Helen Lin & Yaqi Li, 2020-2021

%% ===== PARSE INPUTS =====
if (nargin < 2)
    DisplayMode = 'image';
end

if (nargin < 3) || isempty(hFig) || isequal(hFig,0)
    hFig = [];
    CreateMode = [];
elseif isequal(hFig,'NewFigure')
    hFig = [];
    CreateMode = 'AlwaysCreate';
end

% Initializations
iDS     = [];
iFig    = [];

%% ===== LOAD CONNECT FILE =====
% Find file in database
[sStudy, iStudy, iNoiseCov] = bst_get('NoiseCovFile', TimefreqFile);
if isempty(sStudy)
    error('File is not registered in database.');
end
sCov = in_bst_matrix( sStudy.NoiseCov(iNoiseCov).FileName);

% Load channel information
ChannelMat = in_bst_channel(sStudy.Channel.FileName);
% Get channel names
RefRowNames = {ChannelMat.Channel.Name};
RowNames = {ChannelMat.Channel.Name};

% Check that the matrix is square, and have same RowNames cannot display [NxM] connectivity matrix where N~=M
if ~isequal(RefRowNames, RowNames) && ~strcmpi(DisplayMode, 'Image')
    bst_error('The connectivity matrix cannot be displayed as the row and column names are not equal', 'View connectivity matrix', 0);
    return;
end

%% ===== DISPLAY AS IMAGE =====

% Get covariance matrix
C = sCov.NoiseCov;
TimeVector = [];

rowFileStr = '';
colFileStr = '';
DimLabels = {['From' rowFileStr], ['To' colFileStr]};

% Plot as a flat image
Labels = {RefRowNames, ...
          RowNames, ...
          TimeVector, ...
          []};

[hFig, iDSs, iFig] = view_image_reg(C, Labels, [1,2], DimLabels, TimefreqFile, hFig, [], 1, '$freq', '');

% Reload call
ReloadCall = {'view_covariance', TimefreqFile, DisplayMode, hFig};
setappdata(hFig, 'ReloadCall', ReloadCall);

% Close progress bar and return
bst_progress('stop');

end