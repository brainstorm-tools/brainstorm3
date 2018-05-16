function [neighbours, ChannelConn] = channel_neighbours( ChannelFile, iChannels )
% CHANNEL_NEIGHBOURS: Get the channels neighbourhood, in FieldTrip format.
% 
% USAGE:  [neighbours, ChannelConn] = channel_neighbours( ChannelFile, iChannels )
%         [neighbours, ChannelConn] = channel_neighbours( ChannelMat,  iChannels )

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015

% Load channels structure
if isstruct(ChannelFile)
    ChannelMat = ChannelFile;
else
    ChannelMat = in_bst_channel(ChannelFile);
end

% Get channel vertices
[chan_loc, markers_loc, vertices] = figure_3d('GetChannelPositions', ChannelMat, iChannels);
% Tesselate the vertices
Faces = channel_tesselate(markers_loc, 1);
% Build connectivity matrix
ChannelConn = tess_vertconn(markers_loc, Faces);
% Build neighbourhood
neighbours = repmat(struct('label',[],'neighblabel',[]), 1, size(markers_loc,1));
for i = 1:length(neighbours)
    iNeighbours = iChannels(ChannelConn(i,:));
    neighbours(i).label       = ChannelMat.Channel(iChannels(i)).Name;
    neighbours(i).neighblabel = {ChannelMat.Channel(iNeighbours).Name};
end

% ==============================================================
% % THIS IS REPLACING FIELDTRIP CODE BELOW
% % Prepare neighbour structure for clustering
% neicfg                 = struct();
% neicfg.method          = 'distance';
% neicfg.neighbourdist   = OPT.MaxDist;
% if isfield(ftAllFiles{1}, 'elec') && ~isempty(ftAllFiles{1}.elec)
%     neicfg.elec = ftAllFiles{1}.elec;
% elseif isfield(ftAllFiles{1}, 'grad') && ~isempty(ftAllFiles{1}.grad)
%     neicfg.grad = ftAllFiles{1}.grad;
% else
%     bst_report('Error', sProcess, sInputsA, 'ftData.elec and ftData.grad are both empty or do not exist. Impossible to define neighbours.');
%     return;
% end
% % Get neighbours
% neighbours = ft_prepare_neighbours(neicfg);
% statcfg.neighbours = neighbours;
% ==============================================================


