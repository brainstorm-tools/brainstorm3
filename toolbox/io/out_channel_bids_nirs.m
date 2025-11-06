function out_channel_bids_nirs(BstChannelFile, OutputChannelFile, units, status)
% OUT_CHANNELK_BIDS_NIRS: Exports a Brainstorm NIRS channel file in an BIDS
%                   _channels.tsv file. 
%
% 
% USAGE:  out_channel_bids_nirs(BstChannelFile, OutputChannelFile, Units);
%
% INPUT: 
%     - BstChannelFile    : full path to Brainstorm file to export
%     - OutputChannelFile : full path to output file

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

if nargin < 3
    file_units = '';
end

if nargin < 4
    status = [];
end

% Load brainstorm channel file
BstMat = in_bst_channel(BstChannelFile);

T = table({}, {} , {}, {}, {}, {}, {}, 'VariableNames', {'name','type', 'source', 'detector', 'wavelength_nominal', 'units', 'status'});

channels = BstMat.Channel;

for i = 1:length(channels)
    
    units = '';

    if  strcmp(channels(i).Type, 'NIRS')
        tokens = regexp(channels(i).Name, '^S([0-9]+)D([0-9]+)(WL\d+|HbO|HbR|HbT)$', 'tokens');
        Name   = sprintf('S%s-D%s', tokens{1}{1}, tokens{1}{2});
    
        if contains(channels(i).Group, 'WL') 
            if isempty(file_units)  && ~(contains(file_units, {'unitless', 'OD', 'dOD'}))
                Type          = 'NIRSCWAMPLITUDE'; 
                WavelengthNominal  =  strrep(tokens{1}{3}, 'WL', ''); 
            else
                Type          = 'NIRSCWOPTICALDENSITY';
                WavelengthNominal  =  strrep(tokens{1}{3}, 'WL', ''); 
                units         = 'unitless';
            end
        elseif contains(channels(i).Group, 'HbO')
            Type          = 'NIRSCWHBO';
            WavelengthNominal  =  'n/a'; 
        elseif contains(channels(i).Group, 'HbR')
            Type       = 'NIRSCWHBR';
            WavelengthNominal  =  'n/a'; 
        elseif contains(channels(i).Group, 'HbT')
            continue;
        else
            warning('Channel %d (%s) cannot be exported', i, channels(i).Name)
        end
    
        if isempty(units) 
            switch(Type)
                case 'NIRSCWAMPLITUDE'
                    units = 'V';
                case {'NIRSCWHBO', 'NIRSCWHBR'}
                    units = 'mol/l';
            end
        end
    

    
        Source       = sprintf('S%s', tokens{1}{1}); 
        Detector     = sprintf('D%s', tokens{1}{2}); 
    
    else

        Name         = channels(i).Name;
        Type         = 'MISC';
        Source       = 'n/a'; 
        Detector     = 'n/a'; 
        WavelengthNominal = 'n/a';
        units        = 'unitlesss';

    end

    if isempty(status) || status(i)  
        chan_status  = 'good';
    else
        chan_status  = 'bad';
    end

    T(end+1, :) = {Name, Type, Source, Detector, WavelengthNominal, units, chan_status};

end

fid = fopen(OutputChannelFile, 'w');
if (fid < 0)
   error('Cannot open file'); 
end

writetable(T, OutputChannelFile, 'FileType', 'text', 'Delimiter','\t' );

end

