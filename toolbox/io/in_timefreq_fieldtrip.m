function [DataMat] = in_timefreq_fieldtrip(DataFile)
% IN_TIMEFREQ_FIELDTRIP: Read timefreq structures from FieldTrip structures 
% USAGE:  [DataMat, ChannelMat] = in_time_fieldtrip( DataFile )

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
% Authors: Alexandre Chalard

% Get format
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('timefreqmat');
DataMat.Comment  = fBase;
DataMat.Device   = 'FieldTrip';
DataMat.DataType = 'timefreq';

% Load structure
ftMat = load(DataFile);
fields = fieldnames(ftMat);

% Check all the required fields
if ~isfield(ftMat, 'time') || ~isfield(ftMat, 'label') || (~isfield(ftMat, 'freq') && ~isfield(ftMat, 'powspctrm'))
    error(['This file is not a valid FieldTrip timefreq structure .' 10 'Missing fields: "time", "label", "freq" or "powspctrm".']);
end

% No bad channels information
nChannels = length(ftMat.label);
DataMat.ChannelFlag = ones(nChannels, 1);

% Mandatory field for bst 
DataMat.TF        = permute(ftMat.powspctrm,[1 3 2]);
DataMat.TFmask    = ones(size(DataMat.TF,3),size(DataMat.TF,2));
DataMat.Time      = ftMat.time;
DataMat.Freqs     = ftMat.freq;
DataMat.RowNames  = ftMat.label;
DataMat.Method    = 'From FieldTrip';

% Add optional field & maybe add channel file to allow topographic display


end


