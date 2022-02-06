function [hFig, iDS, iFig] = view_helmet(ChannelFile, hFig)
% VIEW_HELMET: Display MEG helmet for a channel file.
%
% USAGE:  [hFig, iDS, iFig] = view_helmet(ChannelFile)
%         [hFig, iDS, iFig] = view_helmet(ChannelFile, hFig)

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
% Authors: Francois Tadel, 2011-2018

% Parse inputs
if (nargin < 2) || isempty(hFig)
    hFig = [];
end

% ===== VIEW SENSORS =====
% View MEG sensors
Modality = 'MEG';
[hFig, iDS, iFig] = view_channels(ChannelFile, Modality, 1, 0, hFig);
% Get sensors patch
hSensorsPatch = findobj(hFig, 'Tag', 'SensorsPatch');
if isempty(hSensorsPatch)
    return
end
% Get sensors positions
vert = get(hSensorsPatch, 'Vertices');

% ===== CREATE HELMET SURFACE =====
% Get the acquisition device
Device = bst_get('ChannelDevice', ChannelFile);
% Distance sensors/helmet
switch (Device)
    case 'Vectorview306'
        dist = .019;
    case 'CTF'
        dist = .015;
    case '4D'
        dist = .015;
    case 'KIT'
        dist = .020;
    case 'KRISS'
        dist = .025;
    case 'BabyMEG'
        dist = .008;
    case 'RICOH'
        dist = .020;
    otherwise
        dist = 0;
end
% Shrink sensor patch to create the inner helmet surface
if (dist > 0)
    center = mean(vert);
    vert = bst_bsxfun(@minus, vert, center);
    [th,phi,r] = cart2sph(vert(:,1),vert(:,2),vert(:,3));
    [vert(:,1),vert(:,2),vert(:,3)] = sph2cart(th, phi, r - dist);
    vert = bst_bsxfun(@plus, vert, center);
end

% ===== DISPLAY HELMET SURFACE =====
% Copy sensor patch object
hHelmetPatch = copyobj(hSensorsPatch, get(hSensorsPatch,'Parent'));
% Make the sensor patch invisible
set(hSensorsPatch, 'Visible', 'off');
% Set patch properties
set(hHelmetPatch, 'Vertices',   vert, ...
                   'LineWidth',  1, ...
                   'EdgeColor',  [.5 .5 .5], ...
                   'EdgeAlpha',  1, ...
                   'FaceColor',  'y', ...
                   'FaceAlpha',  .3, ...
                   'Marker',     'none', ...
                   'Tag',        'HelmetPatch');

end

