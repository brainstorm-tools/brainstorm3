function converted_raw_File = in_spikesorting_convertforkilosort( varargin )
% IN_SPIKESORTING_RAWELECTRODES: Loads and creates if needed separate raw
% electrode files for spike sorting purposes.
%
% USAGE: OutputFiles = in_spikesorting_convertforkilosort(sInputs, ram)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Konstantinos Nasiotis, 2018-2019; Martin Cousineau, 2018

sInput = varargin{1};
if nargin < 2 || isempty(varargin{2})
    ram = 1e9; % 1 GB
else
    ram = varargin{2};
end

protocol = bst_get('ProtocolInfo');
parentPath = bst_fullfile(bst_get('BrainstormTmpDir'), ...
                       'Unsupervised_Spike_Sorting', ...
                       protocol.Comment, ...
                       sInput.FileName);

% Make sure the temporary directory exist, otherwise create it
if ~exist(parentPath, 'dir')
    mkdir(parentPath);
end

DataMat = in_bst_data(sInput.FileName, 'F');
ChannelMat = in_bst_channel(sInput.ChannelFile);
sFile = DataMat.F;


% Separate the file to max length based on RAM
numChannels = length(ChannelMat.Channel);
max_samples = ram / 8 / numChannels;

converted_raw_File = bst_fullfile(parentPath, ['raw_data_no_header_' sInput.Condition(5:end) '.dat']);

bst_progress('start', 'Spike-sorting', 'Converting to KiloSort Input...', 0, ceil(sFile.prop.samples(2)/max_samples));

if exist(converted_raw_File, 'file') == 2
    disp('File already converted')
    return
end


%% Check if a projector has been computed and ask if the selected components
% should be removed
if ~isempty(ChannelMat.Projector)
    isOk = java_dialog('confirm', ...
        ['(ICA/PCA) Artifact components have been computed for removal.' 10 10 ...
             'Remove the selected components?'], 'Artifact Removal');
    if isOk
        ImportOptions = db_template('ImportOptions');
        ImportOptions.UseCtfComp     = 0;
        ImportOptions.UseSsp         = 1;
    end
end 

%% Convert the acquisition system file to an int16 without a header.
fid = fopen(converted_raw_File, 'a');

isegment = 1;
nsegment_max = 0;

while nsegment_max < sFile.prop.samples(2)
    nsegment_min = (isegment-1) * max_samples;
    nsegment_max = isegment * max_samples - 1;
    if nsegment_max > sFile.prop.samples(2)
        nsegment_max = sFile.prop.samples(2);
    end
    
    F = in_fread(sFile, ChannelMat, [], [nsegment_min,nsegment_max], [], ImportOptions);

    F = F*10^6 ;  % This assumes that F signals are in V. I convert it to uV there are big numbers and int16 precision doesn't zero it out.
    fwrite(fid, F,'int16');
    
    isegment = isegment + 1;
end
fclose(fid);

