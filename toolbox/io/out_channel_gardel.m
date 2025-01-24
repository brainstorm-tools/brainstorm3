function out_channel_gardel(BstFile, OutputFile, Transf)
% OUT_CHANNEL_GARDEL: Exports a Brainstorm channel file to GARDEL format .txt file
%
% USAGE:  out_channel_gardel( BstFile,    OutputFile );
%         out_channel_gardel( ChannelMat, OutputFile );
%
% INPUT: 
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.txt' extension)

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

%% ===== PARSE INPUTS =====
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
if isfield(ChannelMat, 'Channel') && ~isempty(ChannelMat.Channel)
    iEEG = good_channel(ChannelMat.Channel, [], {'SEEG'});
else
    iEEG = [];
end
nEEG = length(iEEG);

% Open .txt file
fid = fopen(OutputFile, 'w');
if (fid < 0)
   error('Cannot open file'); 
end
% Write header
fprintf(fid, '%s\n', 'MRI_voxel');

for i = 1:nEEG
    sChan = ChannelMat.Channel(iEEG(i));
    if ~isempty(sChan.Loc)
        R = Transf(1:3,1:3);
        T = Transf(1:3,4);
        Loc = R * sChan.Loc(:,1) + T * ones(1, size(sChan.Loc(:,1),2));
        fprintf(fid, '%s\t%s\t%3.8f\t%3.8f\t%3.8f\n', sChan.Group, strrep(sChan.Name, sChan.Group, ''), Loc);
    end
end

% Close file
fclose(fid);






