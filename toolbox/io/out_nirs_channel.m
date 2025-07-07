function out_nirs_channel(BstChannelFile, OutputChannelFile)
% out_nirs_channel: Exports a Brainstorm channel file in an BIDS _channels.tsv file
%
% USAGE:  out_nirs_channel(BstFile, OutputChannelFile);
%
% INPUT: 
%     - BstFile    : full path to Brainstorm file to export
%     - OutputFile : full path to output file

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
% Authors: Jacob Busgang, 2025


% Load brainstorm channel file
BstMat = in_bst_channel(BstChannelFile);

% Get all the positions
Name = {};
Type = {};
Source = {};
Detector = {};
WavelengthNominal = {};
Units = {};
for i = 1:length(BstMat.Channel)
    tokens = regexp(BstMat.Channel(i).Name, 'S([0-9]+)D([0-9]+)WL([0-9]+)', 'tokens');
   if ~isempty(tokens)
       Name{end+1} = strrep(BstMat.Channel(i).Name, ' ', '_');
       Type{end+1} = strrep(BstMat.Channel(i).Type, 'NIRS', 'NIRSCWAMPLITUDE'); % Included in loop to later add other options
       Source{end+1} = sprintf('S%s', tokens{1}{1}); 
       Detector{end+1} = sprintf('D%s', tokens{1}{2}); 
       WavelengthNominal{end+1} =  tokens{1}{3}; 
       Units{end+1} = 'V';
   end
end

fid = fopen(OutputChannelFile, 'w');
if (fid < 0)
   error('Cannot open file'); 
end
% Write header: column names
ColNames = {'name','type', 'source', 'detector', 'wavelength_nominal', 'units'};


T = table(Name',Type', Source',Detector', WavelengthNominal', Units', 'VariableNames',ColNames);
writetable(T,OutputChannelFile,"FileType","text", "Delimiter",'\t' );

end

