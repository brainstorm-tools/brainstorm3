function hFig = script_view_mri_overlay(MriFile, OverlayCube)
% SCRIPT_VIEW_MRI_OVERLAY: Display a MRI in the MRI viewer with user defined layer.
%
% INPUT: 
%    - MriFile     : Full path to a brainstorm MRI file
%    - OverlayCube : 3D double matrix that has the same dimensions as the .Cube field in MriFile

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
% Authors: Francois Tadel, 2010

minVol = min(OverlayCube(:));
maxVol = max(OverlayCube(:));

% Display MRI viewer
hFig = view_mri(MriFile);
% Get displayed objects description
TessInfo = getappdata(hFig, 'Surface');

% Add overlay cube
TessInfo(1).DataSource.Type      = 'Source';
TessInfo(1).DataSource.FileName  = 'whatever...';
TessInfo(1).Data             = OverlayCube;
TessInfo(1).OverlayCube      = OverlayCube;
TessInfo(1).OverlayThreshold = 0;
TessInfo(1).OverlaySizeThreshold = 1;
TessInfo(1).DataLimitValue   = [minVol, maxVol];
TessInfo(1).DataMinMax       = [minVol, maxVol];
%TessInfo(1).DataAlpha       = ...

% Update display
setappdata(hFig, 'Surface', TessInfo);
figure_mri('UpdateMriDisplay', hFig);


