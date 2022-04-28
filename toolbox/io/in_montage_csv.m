function sMontages = in_montage_csv(filename)
% IN_MONTAGE_CSV:  Read sensors selections file from CSV

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
% Authors: Gabriele Arnulfo 
%
% Initialize returned structure
sMontages = db_template('Montage');
sMontages.Type = 'text';
% Open file
fid = fopen(filename, 'r');
if (fid == -1)
    error('Cannot open file.');
end

sMontages.Name = 'Bipolar';

% Skip the first line 
fgetl(fid);

%actual read, split and store in separate variables
tmp = textscan(fid,'%s%s%s','delimiter',',');
dispNames = tmp{1};
srcLabels = tmp{2};
refLabels = regexprep(tmp{3},'^-','');
chNames   = unique([srcLabels refLabels],'stable');

% initialize mixing matrix
mixingMat = zeros(numel(dispNames),numel(chNames));

for iChan = 1:numel(dispNames)

		currLabel = dispNames(iChan);
		currSrcLabel = srcLabels(iChan);
		currRefLabel = refLabels(iChan);
		
		% search for the correct indices 
		mask = ismember(chNames,[currSrcLabel, currRefLabel]);

		% fill the matrix
		try
			mixingMat(iChan,mask) = [1 -1];
		catch ME
		disp(ME.message);
		end

end


sMontages.ChanNames = chNames;
sMontages.DispNames = dispNames;
sMontages.Matrix = mixingMat;

% Close file
fclose(fid);
