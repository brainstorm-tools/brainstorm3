function [sFile, ChannelMat, errMsg, DataMat, ImportOptions] = in_fopen(DataFile, FileFormat, ImportOptions)
% IN_FOPEN:  Open a file for reading in Brainstorm.
%
% USAGE:  [sFile, ChannelMat, errMsg, DataMat] = in_fopen(DataFile, FileFormat, ImportOptions)
%         [sFile, ChannelMat, errMsg, DataMat] = in_fopen(DataFile, FileFormat)
%         [sFile, ChannelMat, errMsg, DataMat] = in_fopen(DataMat,  'BST-DATA')
%
% INPUT:
%     - DataFile      : Full path to file to open
%     - FileFormat    : Description of the file format (look in import_data.m for list of supported formats)
%     - ImportOptions : Structure that describes how to import the recordings (look in db_template.m for a description of all the fields).
%       => Fields used: ChannelAlign, ChannelReplace, DisplayMessages, EventsMode, EventsTrackMode
%
% OUTPUT:
%     - sFile      : Brainstorm structure to pass to the in_fread() function.
%     - ChannelMat : Channel structure

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
% Authors: Francois Tadel, 2009-2019

if (nargin < 3) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end
sFile = [];
ChannelMat = [];
DataMat = [];
errMsg = [];

% SEEG: Detect file format
if ismember(FileFormat, {'SEEG-ALL', 'ECOG-ALL'})
    [fPath,fBase,fExt] = bst_fileparts(DataFile);
    switch lower(fExt)
        case '.trc',  FileFormat = 'EEG-MICROMED';
        case '.eeg'
            if file_exist(fullfile(fPath, [fBase, '.vhdr'])) || file_exist(fullfile(fPath, [fBase, '.ahdr']))
                FileFormat = 'EEG-BRAINAMP';
            else
                FileFormat = 'EEG-NK';
            end
        case '.e',    FileFormat = 'EEG-NICOLET';
        case '.bin',  FileFormat = 'EEG-DELTAMED';
        case '.rda',  FileFormat = 'EEG-COMPUMEDICS-PFS';
        case '.edf',  FileFormat = 'EEG-EDF';
        case '.bdf',  FileFormat = 'EEG-BDF';
    end
end

switch (FileFormat)
    % ===== SUPPORTED AS CONTINUOUS FILES =====
    case 'FIF'
        [sFile, ChannelMat] = in_fopen_fif(DataFile, ImportOptions);
        % Multiple FIF linked: add number of files to the folder name in the database
        if strcmpi(FileFormat, 'FIF') && isfield(sFile, 'header') && isfield(sFile.header, 'fif_list') && (length(sFile.header.fif_list) >= 2)
            [fPath,fBase] = bst_fileparts(DataFile);
            sFile.condition = sprintf('%s_(%d)', fBase, length(sFile.header.fif_list));
        end
    case {'CTF', 'CTF-CONTINUOUS'}
        [sFile, ChannelMat] = in_fopen_ctf(DataFile);
    case '4D'
        [sFile, ChannelMat] = in_fopen_4d(DataFile, ImportOptions);
    case 'KIT'
        [sFile, ChannelMat, errMsg] = in_fopen_kit(DataFile);
    case 'RICOH'
        [sFile, ChannelMat, errMsg] = in_fopen_ricoh(DataFile);
    case 'KDF'
        [sFile, ChannelMat] = in_fopen_kdf(DataFile);
    case 'ITAB'
        [sFile, ChannelMat] = in_fopen_itab(DataFile);
    case 'MEGSCAN-HDF5'
        [sFile, ChannelMat] = in_fopen_megscan(DataFile);
    case 'EEG-ANT-CNT'
        [sFile, ChannelMat] = in_fopen_ant(DataFile);
    case 'EEG-ANT-MSR'
        [sFile, ChannelMat] = in_fopen_msr(DataFile);
    case {'EEG-BLACKROCK', 'EEG-RIPPLE'}
        [sFile, ChannelMat] = in_fopen_blackrock(DataFile);
    case 'EEG-BRAINAMP'
        [sFile, ChannelMat] = in_fopen_brainamp(DataFile);
    case 'EEG-DELTAMED'
        [sFile, ChannelMat] = in_fopen_deltamed(DataFile);
    case 'EEG-COMPUMEDICS-PFS'
        [sFile, ChannelMat] = in_fopen_compumedics_pfs(DataFile);
    case 'EEG-CURRY'
        [sFile, ChannelMat] = in_fopen_curry(DataFile);
    case {'EEG-EDF', 'EEG-BDF'}
        [sFile, ChannelMat, ImportOptions] = in_fopen_edf(DataFile, ImportOptions);
    case 'EEG-EEGLAB'
        [sFile, ChannelMat] = in_fopen_eeglab(DataFile, ImportOptions);
    case 'EEG-EGI-RAW'
        sFile = in_fopen_egi(DataFile, [], [], ImportOptions);
    case 'EEG-EMOTIV'
        [sFile, ChannelMat] = in_fopen_emotiv(DataFile);
    case 'EEG-GTEC'
        [sFile, ChannelMat] = in_fopen_gtec(DataFile);
    case 'EEG-MANSCAN'
        [sFile, ChannelMat] = in_fopen_manscan(DataFile);
    case 'EEG-EGI-MFF'
        [sFile, ChannelMat] = in_fopen_mff(DataFile, ImportOptions);
    case 'EEG-MICROMED'
        [sFile, ChannelMat] = in_fopen_micromed(DataFile);
    case 'EEG-NEURONE'
        [sFile, ChannelMat] = in_fopen_neurone(DataFile);
    case 'EEG-NEUROSCAN-CNT'
        [sFile, ChannelMat] = in_fopen_cnt(DataFile, ImportOptions);
    case 'EEG-NEUROSCAN-EEG'
        [sFile, ChannelMat] = in_fopen_eeg(DataFile);
    case 'EEG-NEUROSCAN-AVG'
        [sFile, ChannelMat] = in_fopen_avg(DataFile);
    case 'EEG-NEUROSCOPE'
        [sFile, ChannelMat] = in_fopen_neuroscope(DataFile);
    case 'EEG-NEURALYNX'
        [sFile, ChannelMat] = in_fopen_neuralynx(DataFile);
    case 'EEG-NICOLET'
        [sFile, ChannelMat] = in_fopen_nicolet(DataFile);
    case 'EEG-NK'
        [sFile, ChannelMat] = in_fopen_nk(DataFile);
    case 'EEG-SMR'
        [sFile, ChannelMat] = in_fopen_smr(DataFile);
    case 'EYELINK'
        [sFile, ChannelMat] = in_fopen_eyelink(DataFile);
    case 'NIRS-BRS'
        [sFile, ChannelMat] = in_fopen_nirs_brs(DataFile);
    case 'BST-BIN'
        [sFile, ChannelMat] = in_fopen_bst(DataFile);
    case 'SPM-DAT'
        [sFile, ChannelMat] = in_fopen_spm(DataFile);
    case 'EEG-INTAN'
        [sFile, ChannelMat] = in_fopen_intan(DataFile);
    case 'EEG-PLEXON'
        [sFile, ChannelMat] = in_fopen_plexon(DataFile);
    case 'EEG-TDT'
        [sFile, ChannelMat] = in_fopen_tdt(DataFile);
    case {'NWB', 'NWB-CONTINUOUS'}
        [sFile, ChannelMat] = in_fopen_nwb(DataFile);
        
    % ===== IMPORTED STRUCTURES =====
    case 'BST-DATA'
        [sFile, ChannelMat, DataMat] = in_fopen_bstmat(DataFile);
        
    % ===== OBJECTS IN MEMORY =====
    case 'MNE-PYTHON'
        [sFile, ChannelMat] = in_fopen_mne(DataFile, ImportOptions);
        
    % ===== CONVERT TO CONTINUOUS =====
    case 'EEG-ASCII'
        [DataMat, ChannelMat] = in_data_ascii(DataFile);
    case 'EEG-BESA'
        [DataMat, ChannelMat] = in_data_besa(DataFile);
    case 'EEG-BRAINVISION'
        DataMat = in_data_ascii(DataFile);
    case 'EEG-CARTOOL'
        DataMat = in_data_cartool(DataFile);
    case 'EEG-ERPCENTER'
        DataMat = in_data_erpcenter(DataFile);
    case 'EEG-ERPLAB'
        [DataMat, ChannelMat] = in_data_erplab(DataFile);
    case 'EEG-MUSE-CSV'
        [DataMat, ChannelMat] = in_data_muse_csv(DataFile);
    case 'EEG-WS-CSV'
        [DataMat, ChannelMat] = in_data_ws_csv(DataFile);
    case 'EEG-MAT'
        DataMat = in_data_mat(DataFile);
    case 'EEG-NEUROSCAN-DAT'
        DataMat = in_data_neuroscan_dat(DataFile);
    case 'FT-TIMELOCK'
        [DataMat, ChannelMat] = in_data_fieldtrip(DataFile);
        % Check that time is linear
        if any(abs((DataMat(1).Time(2) - DataMat(1).Time(1)) - diff(DataMat(1).Time)) > 1e-3)
            error(['The input file has a non-linear time vector.' 10 'This is currently not supported, interpolate your recordings on continuous time vector first.']);
        end
    case 'NIRS-SNIRF'
        [DataMat, ChannelMat] = in_data_snirf(DataFile);
    otherwise
        error('Unknown file format');
end

% File can only be read in one block (imported data)
if isempty(sFile) && ~isempty(DataMat)
    sFile = in_fopen_bstmat(DataMat);
end
% File could not be opened
if isempty(sFile) && ischar(DataFile)
    error(['Cannot open data file: ', 10, DataFile]);
end

% ===== EVENTS =====
if isfield(sFile, 'events') && ~isempty(sFile.events)
    % Fix structure
    sFile.events = struct_fix_events(sFile.events);
    
    % === SORT BY NAME ===
    % Remove the common components
    [tmp__, evtLabels] = str_common_path({sFile.events.label});
    % Try to convert all the names to numbers
    evtNumber = cellfun(@str2num, evtLabels, 'UniformOutput', 0);
    % If all the events names are numbers: sort numerically
    if ~any(cellfun(@isempty, evtNumber))
        [tmp__, iSort] = sort([evtNumber{:}]);
        sFile.events = sFile.events(iSort);
    % Else: sort alphabetically by names
    else
        % [tmp__, iSort] = sort(evtLabels);
        % sFile.events = sFile.events(iSort);
    end
   
    % === ADD COLOR ===
    if isempty(sFile.events(1).color)
        ColorTable = panel_record('GetEventColorTable');
        for i = 1:length(sFile.events)
            iColor = mod(i-1, length(ColorTable)) + 1;
            sFile.events(i).color = ColorTable(iColor,:);
        end
    end
end

% Fix output datamat structure if necessary
if (nargout >= 4) && ~isempty(DataMat) && isfield(DataMat(1), 'Events')
    for i = 1:length(DataMat)
        if ~isempty(DataMat(i).Events)
            DataMat.Events = struct_fix_events(DataMat.Events);
        end
    end
end




