function [hFig, iDS, iFig] = view_headpoints(ChannelFile, ScalpFile, isInterp)
% VIEW_HEADPOINTS: View surface file and head points.
%
% USAGE: view_headpoints(ChannelFile)
%        view_headpoints(ChannelFile, ScalpFile)
%
% OUTPUT: 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array
% If an error occurs : all the returned variables are set to an empty matrix []

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

global GlobalData;

% Default: no spherical harmonics
if (nargin < 3) || isempty(isInterp)
    isInterp = 0;
end

% Get study
[sStudy, iStudy] = bst_get('ChannelFile', ChannelFile);
if isempty(sStudy)
    return
end
ChannelFile = sStudy.Channel.FileName;

% Get scalp surface
if (nargin < 2) || isempty(ScalpFile)
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    if isempty(sSubject) || isempty(sSubject.iScalp)
        error('No scalp surface available for this suject.');
    end
    ScalpFile = file_fullpath(sSubject.Surface(sSubject.iScalp).FileName);
end

% Get HeadPoints
HeadPoints = channel_get_headpoints(ChannelFile, 1);
if isempty(HeadPoints)
    bst_error('No digitized head points to display for this file.', 'Add head points', 0);
    return;
end
% Load full channel file
ChannelMat = in_bst_channel(ChannelFile);

% View scalp surface if available
[hFig, iDS, iFig] = view_surface(ScalpFile, .2);

% Extend figure and dataset for this particular channel file
GlobalData.DataSet(iDS).StudyFile       = sStudy.FileName;
GlobalData.DataSet(iDS).ChannelFile     = ChannelFile;
GlobalData.DataSet(iDS).Channel         = ChannelMat.Channel;
GlobalData.DataSet(iDS).MegRefCoef      = ChannelMat.MegRefCoef;
GlobalData.DataSet(iDS).Projector       = ChannelMat.Projector;
GlobalData.DataSet(iDS).IntraElectrodes = ChannelMat.IntraElectrodes;
GlobalData.DataSet(iDS).HeadPoints      = ChannelMat.HeadPoints;

% View HeadPoints
figure_3d('ViewHeadPoints', hFig, 1);

% Show a spherical harmonic fit to the landmark data
if isInterp
    fvh = hsdig2fv(ChannelMat.HeadPoints.Loc', 5, 5/1000, 40*pi/180, 0);
    h(2) = patch(fvh, 'edgecolor', [.5 .5 .5], 'facecolor', [.5 .5 .5], 'facealpha', .8);
end

