function out_channel_megdraw( BstFile, OutputFile )
% OUT_CHANNEL_MEGDRAW: Exports a Brainstorm channel file in MegDraw file.
%
% USAGE:  out_channel_megdraw( BstFile, OutputFile );
%
% INPUT: 
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.eeg' extension)

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
% Authors: Elizabeth Bock, 2012

ChannelMat = in_bst_channel(BstFile);
fid = fopen(OutputFile, 'w');
if (fid < 0)
    error('Cannot open file');
end
iEEG = find(~cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], 'EEG')));
iHeadshape = find(~cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], 'EXTRA')));
iCardinal = find(~cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], 'CARDINAL')));

% 2 Fiducial points
% typically 2 fiducials are recorded for this format.  Only print
% one if two are not available
maxCardinal = 2;
nCardinal = length(iCardinal);
if nCardinal < 2
    % tell the user
    isOk = java_dialog('confirm', ['Warning: The fiducials were only collected once for this session.' 10 10 ... 
                           'The megDraw format requires two collections of fiducials at the beginning ' 10 ...
                           'and two at the end.' 10 10 ...
                           'Would you like to proceed with saving in this file format?' 10 10], ...
                           'Save megDraw headshape');
    if ~isOk
        return
    end
    maxCardinal = 1;
end
for i = 1:maxCardinal
    iPoint = (i*3)-2;
    fprintf(fid,'%s\t%3.5f\t%3.5f\t%3.5f\n', 'NA', ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint))*100);
    fprintf(fid,'%s\t%3.5f\t%3.5f\t%3.5f\n', 'OG', ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint+1))*100);
    fprintf(fid,'%s\t%3.5f\t%3.5f\t%3.5f\n', 'OD',  ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint+2))*100);
end

%EEG points (index, label, coord)
nEEG = length(iEEG);
if ~isempty(iEEG)
    for i = 1:nEEG
        fprintf(fid,'%3.5f\t%3.5f\t%3.5f\n', ChannelMat.HeadPoints.Loc(:,iEEG(i))*100);
    end
end
% Next, list headshape
if ~isempty(iHeadshape)
    for i = 1:length(iHeadshape)
        fprintf(fid,'%3.5f\t%3.5f\t%3.5f\n', ChannelMat.HeadPoints.Loc(:,iHeadshape(i))*100);
    end
end
% list remaining fiducials
for i = 3:floor(length(iCardinal)/3)
    iPoint = (i*3)-2;
    fprintf(fid,'%s\t%3.5f\t%3.5f\t%3.5f\n', 'NA', ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint))*100);
    fprintf(fid,'%s\t%3.5f\t%3.5f\t%3.5f\n', 'OG', ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint+1))*100);
    fprintf(fid,'%s\t%3.5f\t%3.5f\t%3.5f\n', 'OD',  ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint+2))*100);
end
fclose(fid);



