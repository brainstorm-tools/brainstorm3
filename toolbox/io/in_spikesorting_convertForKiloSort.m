function converted_raw_File = in_spikesorting_convertForKiloSort( sInput, sProcess )
% IN_SPIKESORTING_RAWELECTRODES: Loads and creates if needed separate raw
% electrode files for spike sorting purposes.
%
% USAGE: OutputFiles = process_spikesorting_unsupervised('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
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
% Authors: Konstantinos Nasiotis, 2018; Martin Cousineau, 2018

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
numChannels = length(ChannelMat.Channel);
sFiles = {};


% Separate the file to length
isegment = 1;
nsegment_max = 0;


nget_samples = sProcess.options.binsize.Value{1}*(10^6);   % This is the length of the segment that will be appended.
                                                           % The reason why we need this is for
                                                           % machines that don't have enough RAM. The
                                                           % larger this number, the faster it saves
                                                           % the files.

                                                           
                                                           
converted_raw_File = bst_fullfile(parentPath, ['raw_data_no_header_' sInput.Condition(5:end) '.bin']);
                                                           
bst_progress('start', 'Spike-sorting', 'Converting to KiloSort Input...', 0, ceil(sFile.prop.samples(2)/nget_samples));


% Make sure the file is deleted because everything will be appended.
if exist(converted_raw_File, 'file') == 2
    file_delete(converted_raw_File, 1, 3);
    disp('Previous converted file succesfully deleted')
end



%% The files are read twice. Is there a faster way to do this?

%% The converted file needs to be a .bin file in INT16. I need to convert
%  the signals to int16 first. Since the signals also has negative values, I
%  have to search all of them to find the minimum value that needs to be
%  added.


minimum_value = 0;
while nsegment_max<sFile.prop.samples(2)
    nsegment_min = (isegment-1)*nget_samples;
    nsegment_max = isegment*nget_samples - 1;
    if nsegment_max>sFile.prop.samples(2)
        nsegment_max = sFile.prop.samples(2);
    end
    [F, ~] = in_fread(sFile, ChannelMat, [], [nsegment_min,nsegment_max], [], []);
    
    minimum_value = min([minimum_value min(min(F))]);
    clear F
    isegment = isegment + 1;

end








%% Convert the acquisition system file to an int16 without a header.
fid = fopen(converted_raw_File, 'a');  % THIS JUST APPENDS

isegment = 1;
nsegment_max = 0;

while nsegment_max<sFile.prop.samples(2)
    nsegment_min = (isegment-1)*nget_samples;
    nsegment_max = isegment*nget_samples - 1;
    if nsegment_max>sFile.prop.samples(2)
        nsegment_max = sFile.prop.samples(2);
    end
    
    [F, ~] = in_fread(sFile, ChannelMat, [], [nsegment_min,nsegment_max], [], []);
%   [F, TimeVector] = in_fread(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels, ImportOptions)

    % KILOSORT USES INT16 AS INPUT
    % THIS IS WHAT THEY HAD IN THE make_eMouseData
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    F = (F + abs(minimum_value))*10^6 ;  % This assumes that F signals are in V. You need to convert it to uV so you have big numbers and int16 precision doesn't zero it out.            
    fwrite(fid, F,'int16');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 

%     fwrite(fid, F,'double'); % This will create bigger files for some acquisition systems (int16, int32)
%                              % If we could grab the precision automatically
%                              % it would be ideal
    
    clear F
    isegment = isegment + 1;
    bst_progress('inc', 1);

end
% fclose(fid)
fclose('all');

