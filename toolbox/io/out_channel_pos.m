function out_channel_pos( BstFile, OutputFile )
% OUT_CHANNEL_POS: Exports a Brainstorm channel file in CTF-compatible Polhemus file.
%
% USAGE:  out_channel_pos( BstFile,    OutputFile );
%         out_channel_pos( ChannelMat, OutputFile );
%
% INPUT: 
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.pos' extension)

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
% Authors: Francois Tadel, Elizabeth Bock, 2012-2013

% Load brainstorm channel file
if ischar(BstFile)
    ChannelMat = in_bst_channel(BstFile);
else
    ChannelMat = BstFile;
end
% Scaling factor for all the coordinates
Factor = 100;
% List EEG channels
if isfield(ChannelMat, 'Channel') && ~isempty(ChannelMat.Channel)
    iEEG = good_channel(ChannelMat.Channel, [], {'EEG','ECOG','SEEG'});
else
    iEEG = [];
end
nEEG = length(iEEG);
% Count head shape points
if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Loc)
    nHS = size(ChannelMat.HeadPoints.Loc, 2);
    % Find fiducials in the head points
    iCardinal = find(strcmpi(ChannelMat.HeadPoints.Type, 'CARDINAL'));
    iHPI      = find(strcmpi(ChannelMat.HeadPoints.Type, 'HPI'));
    iHeadshape = setdiff(1:nHS, [iCardinal iHPI]);
else
    nHS = 0;
end

% Open .pos file
fid = fopen(OutputFile, 'w');
if (fid < 0)
   error('Cannot open file'); 
end
% Write number of EEG electrodes OR headshape points
if (nEEG > 0)
    fprintf(fid, '%d\n', nEEG);
else
    fprintf(fid, '%d\n', nHS);
end
% Write EEG electrodes: Index, Label, X, Y, Z
for i = 1:nEEG
    sChan = ChannelMat.Channel(iEEG(i));
    if ~isempty(sChan.Loc)
        fprintf(fid, '%d\t%s\t%3.8f\t%3.8f\t%3.8f\n', i, sChan.Name, sChan.Loc(:,1) .* Factor);
    end
end
% Write head shape points: Index, X, Y, Z
if (nHS > 0)
    % Head shape
    for i = 1:length(iHeadshape)
        fprintf(fid,'%d\t%s\t%3.8f\t%3.8f\t%3.8f\n', i+nEEG, '', ChannelMat.HeadPoints.Loc(:,iHeadshape(i)) .* Factor);
    end
    % Fiducials
    for i = 1:length(iCardinal)
        fprintf(fid,'%s\t%3.8f\t%3.8f\t%3.8f\n', ChannelMat.HeadPoints.Label{iCardinal(i)}, ChannelMat.HeadPoints.Loc(:,iCardinal(i)) .* Factor);
    end
    % HPI coils
    for i = 1:length(iHPI)
        fprintf(fid,'%s\t%3.8f\t%3.8f\t%3.8f\n', ChannelMat.HeadPoints.Label{iHPI(i)}, ChannelMat.HeadPoints.Loc(:,iHPI(i)) .* Factor);
    end
end
% % Last, list the three fiducials
% % find the average of the first nFidSets of collections
% DigitizeOptions = bst_get('DigitizeOptions');
% nFidSets = DigitizeOptions.nFidSets;
% for i = 1:nFidSets
%     iPoint = (i*3)-2;
%     na(i,:) = ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint));
%     lft(i,:) = ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint+1));
%     rt(i,:) = ChannelMat.HeadPoints.Loc(:, iCardinal(iPoint+2));
% end
% fprintf(fid,'%s\t%s\t%3.8f\t%3.8f\t%3.8f\n', 'nasion', '', mean(na,1)*100);
% fprintf(fid,'%s\t%s\t%3.8f\t%3.8f\t%3.8f\n', 'left', '', mean(lft,1)*100);
% fprintf(fid,'%s\t%s\t%3.8f\t%3.8f\t%3.8f\n', 'right', '', mean(rt,1)*100);

% Close file
fclose(fid);






