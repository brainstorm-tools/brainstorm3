function out_channel_gardel(BstFile, OutputFile, Transf)
% OUT_CHANNEL_GARDEL: Exports a Brainstorm channel file to a GARDEL supported .txt file
%
% USAGE:  out_channel_gardel(BstFile,    OutputFile, Transf);
%         out_channel_gardel(ChannelMat, OutputFile, sMri);
%
% INPUT: 
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.txt' extension)
%    - Transf     : 4x4 transformation matrix to apply to the 3D positions before saving
%                   or entire MRI structure for conversion to MNI space

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
% Authors: Chinmay Chinara, 2025

% Parse inputs
if (nargin < 3) || isempty(Transf)
    Transf = [];
end

% Load brainstorm channel file
if ischar(BstFile)
    ChannelMat = in_bst_channel(BstFile);
else
    ChannelMat = BstFile;
end

% List SEEG channels
iEEG = [];
if isfield(ChannelMat, 'Channel') && ~isempty(ChannelMat.Channel)
    iEEG = good_channel(ChannelMat.Channel, [], {'SEEG'});
end
nEEG = length(iEEG);

% Open output .txt file
fid = fopen(OutputFile, 'w');
if (fid < 0)
   error('Cannot open file: %s', OutputFile); 
end

% Write header
fprintf(fid, 'MRI_voxel\n');
% Write electrode data from Brainstorm to GARDEL
for i = 1:nEEG
    sChan = ChannelMat.Channel(iEEG(i));
    % Default location
    Loc = sChan.Loc(:,1);
    % Apply transformation
    if ~isempty(Transf)
        if isstruct(Transf)
            Loc = cs_convert(Transf, 'scs', 'voxel', Loc')';
        else
            R = Transf(1:3,1:3);
            T = Transf(1:3,4);
            Loc = R * Loc + T * ones(1, size(Loc,2));
        end
    end
    % Fields in order: electrode name, contact number, loc_X, loc_Y, loc_Z, anatomical label id (dummy), anatomical label name (dummy)
    % Note: dummy anatomical label values will be recomputed when the exported file is loaded into GARDEL tool
    % TODO: replace the dummy anatomical label values with actual ones computed from Brainstorm
    contactNumber = strrep(sChan.Name, sChan.Group, '');
    fprintf(fid, '%s\t%s\t%3.12f\t%3.12f\t%3.12f\t%d\t%s\n', sChan.Group, contactNumber, Loc, 1, 'grey');
end

% Close file
fclose(fid);