function iNewDipoles = import_dipoles(iStudy, DataFile, DipolesFiles)
% IMPORT_DIPOLES: Imports a dipoles file (Neuromag xfit or CTF).
% 
% USAGE:  
%         iNewDipoles = import_dipoles(iStudy, DataFile, DipolesFiles) : Read files and save them in brainstorm database
%         iNewDipoles = import_dipoles(iStudy, DataFile)               : Ask files to user, read it, and save it in database
%         iNewDipoles = import_dipoles(iStudy)                         : Same wihtout attaching dipoles to any data file
%
% INPUT:
%    - iStudy       : Index of the study where to import the DipolesFiles
%    - DipolesFiles : Full filename, or cell array of filenames, of the dipoles files to import
%                     => if not specified : file to import is asked to the user

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
% Authors: Francois Tadel, 2010-2012

%% ===== PARSE INPUTS =====
% Argument: DipolesFiles
if (nargin < 3)
    DipolesFiles = [];
elseif ~iscell(DipolesFiles)
    DipolesFiles = {DipolesFiles};
end
% Argument: DataFile
if (nargin < 3) || isempty(DataFile)
    DataFile = '';
end

% Detect file format
FileFormat = '';
if ~isempty(DipolesFiles)
    % Get the file extenstion
    [fPath, fBase, fExt] = bst_fileparts(DipolesFiles{1});
    if ~isempty(fExt)
        fExt = lower(fExt(2:end));
        % Detect file format by extension
        switch lower(fExt)
            case 'bdip', FileFormat = 'BDIP';
            case 'mat',  FileFormat = 'BST';
            case 'dip',  FileFormat = 'CTFDIP';    
            otherwise,   error('Unsupported file format.');
        end
        % Display assumed file format
        disp(['Default file format for this extension: ' FileFormat]);
        disp('If you want to specify the extension, please run this function without arguments.');
    end
end


%% ===== SELECT DIPOLES FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(DipolesFiles)
    % Get default import directory and formats
    LastUsedDirs   = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get Dipoles file
    [DipolesFiles, FileFormat] = java_getfile('open', ...
            'Import dipoles...', ...   % Window title
            LastUsedDirs.ImportData, ...    % Last used directory
            'multiple', 'files', ...        % Selection mode
            {{'.bdip'},    'Xfit binary (*.bdip)',      'BDIP'; ...
             {'_dipoles'}, 'Brainstorm (dipoles*.mat)', 'BST'; ...
             {'.dip'},     'CTF dipoles (*.dip)',       'CTFDIP' ...
            }, DefaultFormats.DipolesIn);
    % If no file was selected: exit
    if isempty(DipolesFiles)
        return
    % Make sure it's an array of files
    elseif ~iscell(DipolesFiles)
        DipolesFiles = {DipolesFiles};
    end
    % Save default import directory
    LastUsedDirs.ImportData = bst_fileparts(DipolesFiles{1});
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.DipolesIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end


%% ===== GET INFORMATION =====
% Get various information
isProgressBar = bst_progress('isVisible');
ProtocolInfo = bst_get('ProtocolInfo');
iNewDipoles = [];
% Get output study
sStudy = bst_get('Study', iStudy);
% Get channel file
ChannelFile = bst_get('ChannelFileForStudy', sStudy.FileName);


%% ===== GET COORDINATES TRANSFORMATION =====
TransfMeg = [];
% Get coordinates transformations
if ~isempty(ChannelFile)
    % Load channel file transformations
    ChannelMat = in_bst_channel(ChannelFile, 'TransfMeg');
    % If transformation Neuromag Head CS -> SCS transformation is defined
    if isfield(ChannelMat, 'TransfMeg') && ~isempty(ChannelMat.TransfMeg) && (length(ChannelMat.TransfMeg) >= 2)
        TransfMeg = ChannelMat.TransfMeg{2};
        % Add other transformations if there are some
        for i = 3:length(ChannelMat.TransfMeg)
            TransfMeg = ChannelMat.TransfMeg{i} * TransfMeg;
        end
    else
        errMsg = ['Warning: No transformation defined in this channel file.' 10 ...
                  'The dipoles locations might not be registered with the anatomy.'];
    end
else
    errMsg = ['Warning: No channel file defined for this study.' 10 10 ...
              'You should import the sensors definition before importing the dipoles, ' 10 ...
              'if not the dipoles locations might not be registered with the anatomy.'];
end
% Warning if no transformation
if isempty(TransfMeg)
    % Ask user confirmation
    isConfirm = java_dialog('confirm', [errMsg 10 10 'Import dipoles anyway ?' 10 10], 'Import dipoles');
    % If cancelled: exit
    if ~isConfirm
        return
    end
end


% Loop on each file
for iFile = 1:length(DipolesFiles)
    %% ===== LOAD DIPOLES FILE =====
    % Progress bar
    if ~isProgressBar
        bst_progress('start', 'Import dipoles', ['Loading file "' DipolesFiles{iFile} '"...']);
    end
    % Load file
    switch FileFormat
        case 'BDIP'
            DipolesMat = in_dipoles_bdip(DipolesFiles{iFile});
        case 'BST'
            DipolesMat = load(DipolesFiles{iFile});
        case 'CTFDIP'
            DipolesMat = in_dipoles_ctfdip(DipolesFiles{iFile});  
        otherwise
            error('Unsupported file format.');
    end
    % Add data file
    DipolesMat.DataFile = DataFile;
    % Check that something was read
    if isempty(DipolesMat)
        error('Dipoles file could not be imported.');
    end
    % Add History field
    DipolesMat = bst_history('add', DipolesMat, 'import', ['Import from: ' DipolesFiles{iFile}]);
    
    %% ===== CHANGE COORDINATE SYSTEM =====
    if ~isempty(TransfMeg)
        R = TransfMeg(1:3,1:3); % Rotation
        T = TransfMeg(1:3,4);   % Translation
        % Add History field
        DipolesMat = bst_history('add', DipolesMat, 'import', sprintf('Rotation: [%1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f]', R'));
        DipolesMat = bst_history('add', DipolesMat, 'import', sprintf('Translation: [%1.3f,%1.3f,%1.3f]', T));
        % Process each dipole
        for iDip = 1:length(DipolesMat.Dipole)
            % Position
            DipolesMat.Dipole(iDip).Loc = R * DipolesMat.Dipole(iDip).Loc + T;
            % Orientation (amplitude in each direction)
            DipolesMat.Dipole(iDip).Amplitude = R * DipolesMat.Dipole(iDip).Amplitude;
        end
    end

    
    %% ===== SAVE NEW FILE =====
    % Get imported base name
    [tmp__, importedBaseName, importedExt] = bst_fileparts(DipolesFiles{iFile});
    importedBaseName = strrep(importedBaseName, 'dipoles_', '');
    importedBaseName = strrep(importedBaseName, '_dipoles', '');
    importedBaseName = strrep(importedBaseName, 'dipoles', '');
    % Limit number of chars
    if (length(importedBaseName) > 15)
        importedBaseName = importedBaseName(1:15);
    end
    % Create output filename
    OutputFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudy.FileName), ['dipoles_', importedBaseName, '.mat']);
    OutputFile = file_unique(OutputFile);
    % Save new file in Brainstorm format
    bst_save(OutputFile, DipolesMat, 'v7');
    
    
    %% ===== UPDATE DATABASE =====
    % Create structure
    BstDipolesMat = db_template('Dipoles');
    BstDipolesMat.FileName = file_short(OutputFile);
    BstDipolesMat.Comment  = DipolesMat.Comment;
    BstDipolesMat.DataFile = DataFile;
    % Add to study
    iDipole = length(sStudy.Dipoles) + 1;
    sStudy.Dipoles(iDipole) = BstDipolesMat;
    iNewDipoles = [iNewDipoles, iDipole];
end

% Save study
bst_set('Study', iStudy, sStudy);
% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Save database
db_save();

% Progress bar
if ~isProgressBar
    bst_progress('stop');
end


