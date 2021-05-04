function argout1 = bst_set( varargin )
% BST_SET: Set a Brainstorm structure.
%
% DESCRIPTION:  This function is used to abstract the way that these structures are stored.
%
% USAGE:
% ====== DIRECTORIES ==================================================================
%    - bst_set('BrainstormHomeDir', BrainstormHomeDir)
%    - bst_set('BrainstormTmpDir',  BrainstormTmpDir)
%    - bst_set('BrainstormDbDir',   BrainstormDbDir)
%    - bst_set('LastUsedDirs',      sDirectories)
%    - bst_set('FieldTripDir',      FieldTripDir)
%    - bst_set('SpmDir',            SpmDir)
%    - bst_set('BrainSuiteDir',     BrainSuiteDir)
%    - bst_set('PythonConfig',      PythonConfig)
%
% ====== PROTOCOLS ====================================================================
%    - bst_set('iProtocol',         iProtocol)
%    - bst_set('ProtocolInfo',      sProtocolInfo)
%    - bst_set('ProtocolSubjects',  ProtocolSubjects)
%    - bst_set('isProtocolLoaded',  isProtocolLoaded)
%    - bst_set('isProtocolModified',isProtocolModified)
%    - bst_set('ProtocolStudies',   ProtocolStudies)
%    - bst_set('Study',   iStudy,   sStudy)    : Set a study in current protocol 
%    - bst_set('Subject', iSubject, sSubject)  : Set a subject in current protocol
%
% ====== GUI =================================================================
%    - bst_set('Layout',    sLayout)
%    - bst_set('Layout',    PropName, PropValue)
%    - bst_set('Clipboard', Nodes, isCut)  : Copy operation from the tree
%
% ====== CONFIGURATION =================================================================
%    - bst_set('Version',      Version)
%    - bst_set('ByteOrder',    value)        : 'b' for big endian, 'l' for little endian
%    - bst_set('AutoUpdates',  isAutoUpdates)
%    - bst_set('ExpertMode',   isExpertMode)
%    - bst_set('DisplayGFP',   isDisplayGFP)
%    - bst_set('DownsampleTimeSeries',  isDownsampleTimeSeries)
%    - bst_set('GraphicsSmoothing',     isGraphicsSmoothing)
%    - bst_set('ForceMatCompression',   isForceCompression)
%    - bst_set('IgnoreMemoryWarnings',  isIgnoreMemoryWarnings)
%    - bst_set('SystemCopy',            isSystemCopy)
%    - bst_set('DisableOpenGL',         isDisableOpenGL)
%    - bst_set('InterfaceScaling',      InterfaceScaling)
%    - bst_set('TSDisplayMode',         TSDisplayMode)    : {'butterfly','column'}
%    - bst_set('ElectrodeConfig',       ElectrodeConfig, Modality)
%    - bst_set('DefaultFormats'         defaultFormats)
%    - bst_set('BFSProperties',         [scalpCond,skullCond,brainCond,scalpThick,skullThick])
%    - bst_set('ImportEegRawOptions',   ImportEegRawOptions)
%    - bst_set('BugReportOptions',      BugReportOptions)
%    - bst_set('DefaultSurfaceDisplay', displayStruct)
%    - bst_set('MagneticExtrapOptions', extrapStruct)
%    - bst_set('TimefreqOptions_morlet',  Options)
%    - bst_set('TimefreqOptions_fft',     Options)
%    - bst_set('TimefreqOptions_psd',     Options)
%    - bst_set('TimefreqOptions_hilbert', Options)
%    - bst_set('TimefreqOptions_plv',     Options)
%    - bst_set('OpenMEEGOptions',         Options)
%    - bst_set('DuneuroOptions',         Options)
%    - bst_set('GridOptions_headmodel',   Options)
%    - bst_set('GridOptions_dipfit',      Options)
%    - bst_set('UniformizeTimeSeriesScales', isUniform)
%    - bst_set('FlipYAxis',             isFlipY)
%    - bst_set('AutoScaleY',            isAutoScaleY)
%    - bst_set('FixedScaleY',           Modality,  Value)
%    - bst_set('XScale',                XScale)
%    - bst_set('ShowXGrid',             isShowXGrid)
%    - bst_set('ShowYGrid',             isShowYGrid)
%    - bst_set('ShowZeroLines',         isShowZeroLines)
%    - bst_set('ShowEventsMode',        ShowEventsMode)
%    - bst_set('Resolution',            [resX,resY])
%    - bst_set('UseSigProcToolbox',     UseSigProcToolbox)
%    - bst_set('RawViewerOptions',      RawViewerOptions)
%    - bst_set('TopoLayoutOptions',     TopoLayoutOptions)
%    - bst_set('StatThreshOptions',     StatThreshOptions)
%    - bst_set('ContactSheetOptions',   ContactSheetOptions)
%    - bst_set('ProcessOptions',        ProcessOptions)
%    - bst_set('MriOptions',            MriOptions)
%    - bst_set('CustomColormaps',       CustomColormaps)
%    - bst_set('DigitizeOptions',       DigitizeOptions)
%    - bst_set('ReadOnly',              ReadOnly)
%    - bst_set('LastPsdDisplayFunction', LastPsdDisplayFunction)
%    - bst_set('PlotlyCredentials',     Username, ApiKey, Domain)
%    - bst_set('KlustersExecutable',    ExecutablePath)
%    - bst_set('ExportBidsOptions'),    ExportBidsOptions)
%
% SEE ALSO bst_get

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
% Authors: Francois Tadel, 2008-2016; Martin Cousineau, 2017

global GlobalData;

%% ==== PARSE INPUTS ====
if ((nargin >= 1) && ischar(varargin{1}))
    contextName  = varargin{1};
    if (nargin >= 2)
        contextValue = varargin{2};
    else
        contextValue = [];
    end
else
    error('Usage : bst_set(contextName, contextValue)');
end
argout1 = [];

% Get required context structure
switch contextName      
%% ==== BRAINSTORM CONFIGURATION ====
    case 'Version'
        GlobalData.Program.Version = contextValue;
    case 'BrainstormHomeDir'
        GlobalData.Program.BrainstormHomeDir = contextValue;
    case 'BrainstormDbDir'
        GlobalData.DataBase.BrainstormDbDir = contextValue;
    case 'BrainstormTmpDir'
        GlobalData.Preferences.BrainstormTmpDir = contextValue;
    case 'ProgramStartTime'
        GlobalData.Program.StartTime = contextValue;

%% ==== PROTOCOL ====
    case 'iProtocol'
        if isnumeric(contextValue)
            GlobalData.DataBase.iProtocol = contextValue;
        else
            error('iProtocol should be a number.');
        end
    
    case 'ProtocolSubjects'
        %contextValue = db_template('ProtocolSubjects');
        sqlConn = sql_connect();
        
        % Delete existing subjects and anatomy files
        sql_query(sqlConn, 'delete', 'subject');
        sql_query(sqlConn, 'delete', 'anatomyfile');
        
        for iSubject = 0:length(contextValue.Subject)
            if iSubject == 0
                sSubject = contextValue.DefaultSubject;
            else
                sSubject = contextValue.Subject(iSubject);
            end
            if isempty(sSubject)
                continue
            end
            if iSubject == 0
                sSubject.Id = 0;
            else
                sSubject.Id = [];
            end
            
            % Extract selected anat/surf files to get inserted ID later
            categories = {'Anatomy', 'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM'};
            selectedFiles = cell(1, length(categories));
            for iCat = 1:length(categories)
                field = ['i' categories{iCat}];
                if ~isempty(sSubject.(field)) && ischar(sSubject.(field))
                    selectedFiles{iCat} = sSubject.(field);
                    sSubject.(field) = [];
                else
                    selectedFiles{iCat} = [];
                end
            end
            
            % Insert subject
            SubjectId = sql_query(sqlConn, 'insert', 'subject', sSubject);
            
            % Insert anatomy & surface files
            [sAnatomy, selectedFiles(1)] = db_set(sqlConn, 'FilesWithSubject', 'anatomy', sSubject.Anatomy, SubjectId, selectedFiles(1));
            [sSurface, selectedFiles(2:end)] = db_set(sqlConn, 'FilesWithSubject', 'surface', sSubject.Surface, SubjectId, selectedFiles(2:end));
            
            % Update subject entry to add selected anat/surf files, if any
            hasSelFiles = 0;
            selFiles = struct();
            for iCat = 1:length(categories)
                if ~isempty(selectedFiles{iCat})
                    hasSelFiles = 1;
                    selFiles.(['i' categories{iCat}]) = selectedFiles{iCat};
                end
            end
            if hasSelFiles
                sql_query(sqlConn, 'update', 'subject', selFiles, struct('Id', SubjectId));
            end
        end
        
        sql_close(sqlConn);
        
    case 'ProtocolStudies'
        sqlConn = sql_connect();
        
        for iStudy = -1:length(contextValue.Study)
            if iStudy == -1
                sStudy = contextValue.DefaultStudy;
            elseif iStudy == 0
                sStudy = contextValue.AnalysisStudy;
            else
                sStudy = contextValue.Study(iStudy);
            end
            
            % Skip empty Default / Analysis studies
            if isempty(sStudy) || ((iStudy < 1 || ismember(sStudy.Name, {'@default_study', '@intra', '@inter'})) ...
                    && isempty(sStudy.Channel) && isempty(sStudy.Data) ...
                    && isempty(sStudy.HeadModel) && isempty(sStudy.Result) ...
                    && isempty(sStudy.Stat) && isempty(sStudy.Image) ...
                    && isempty(sStudy.NoiseCov) && isempty(sStudy.Dipoles) ...
                    && isempty(sStudy.Timefreq) && isempty(sStudy.Matrix))
                continue
            end
            
            % If study exists: save its metadata and delete its files
            categories = {'Channel', 'HeadModel'};
            if ~isempty(sStudy.Id)
                for iCat = 1:length(categories)
                    field = ['i' categories{iCat}];
                    if ~isempty(sStudy.(field)) && isnumeric(sStudy.(field))
                        sFile = db_get('FunctionalFile', sqlConn, sStudy.(field), 'FileName');
                        if ~isempty(sFile)
                            sStudy.(field) = sFile.FileName;
                        end
                    end
                end
                
                sql_query(sqlConn, 'delete', 'functionalfile', struct('Study', sStudy.Id));
                sql_query(sqlConn, 'delete', 'study', struct('Id', sStudy.Id));
            end
            
            % Get ID of parent subject
            sSubject = sql_query(sqlConn, 'select', 'subject', 'Id', struct('FileName', sStudy.BrainStormSubject));
            sStudy.Id = [];
            sStudy.Subject = sSubject.Id;
            sStudy.Condition = char(sStudy.Condition);
            
            % Extract selected channel/head model to get inserted ID later
            selectedFiles = cell(1, length(categories));
            for iCat = 1:length(categories)
                category = categories{iCat};
                field = ['i' category];
                if ~isempty(sStudy.(field)) && ischar(sStudy.(field))
                    selectedFiles{iCat} = sStudy.(field);
                elseif isempty(sStudy.(field)) && ~isempty(sStudy.(category))
                    selectedFiles{iCat} = sStudy.(category)(1).FileName;
                end
            end
            
            % Insert study
            StudyId = sql_query(sqlConn, 'insert', 'study', sStudy);
            sStudy.Id = StudyId;
            
            % Insert functional files
            selectedFiles = db_set(sqlConn, 'FilesWithStudy', sStudy, selectedFiles);
            
            % Update study entry to add selected functional files, if any
            hasSelFiles = 0;
            selFiles = struct();
            for iCat = 1:length(categories)
                if ~isempty(selectedFiles{iCat})
                    hasSelFiles = 1;
                    selFiles.(['i' categories{iCat}]) = selectedFiles{iCat};
                end
            end
            if hasSelFiles
                sql_query(sqlConn, 'update', 'Study', selFiles, struct('Id', StudyId));
            end
        end
        
        sql_close(sqlConn);
        
    case 'ProtocolInfo'
        for structField = fieldnames(contextValue)'
            GlobalData.DataBase.(contextName)(GlobalData.DataBase.iProtocol).(structField{1}) = contextValue.(structField{1});
        end
    case 'isProtocolLoaded'
        GlobalData.DataBase.isProtocolLoaded(GlobalData.DataBase.iProtocol) = contextValue;

%% ==== SUBJECT ====
    case 'Subject'
        iSubject = varargin{2};
        sSubject = varargin{3};
        sqlConn = sql_connect();
        
        % If default subject
        if (iSubject == 0)
            sExistingSubject = sql_query(sqlConn, 'select', 'subject', 'Id', struct('Name', '@default_subject'));
        else
            sExistingSubject = sql_query(sqlConn, 'select', 'subject', 'Id', struct('Id', iSubject));
        end
        
        % Extract selected anat/surf files to get inserted ID later
        categories = {'Anatomy', 'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM'};
        selectedFiles = cell(1, length(categories));
        for iCat = 1:length(categories)
            field = ['i' categories{iCat}];
            if ~isempty(sSubject.(field)) && ischar(sSubject.(field))
                selectedFiles{iCat} = sSubject.(field);
                sSubject.(field) = [];
            else
                selectedFiles{iCat} = [];
            end
        end
        
        % If subject exists, UPDATE query
        if ~isempty(sExistingSubject)
            sSubject.Id = sExistingSubject.Id;
            result = sql_query(sqlConn, 'update', 'subject', sSubject, struct('Id', sExistingSubject.Id));
            if result
                argout1 = sExistingSubject.Id;
            end
        else
            sSubject.Id = [];
            iSubject = sql_query(sqlConn, 'insert', 'subject', sSubject);
            if ~isempty(iSubject)
                argout1 = iSubject;
            end
        end
        
        if ~isempty(argout1)
            % Delete existing anatomy files
            sql_query(sqlConn, 'delete', 'anatomyfile', struct('Subject', argout1));
            
            % Insert new anatomy files
            [sAnatomy, selectedFiles(1)] = db_set(sqlConn, 'FilesWithSubject', 'anatomy', sSubject.Anatomy, argout1, selectedFiles(1));
            [sSurface, selectedFiles(2:end)] = db_set(sqlConn, 'FilesWithSubject', 'surface', sSubject.Surface, argout1, selectedFiles(2:end));
            
            % Update subject entry to add selected anat/surf files, if any
            hasSelFiles = 0;
            selFiles = struct();
            for iCat = 1:length(categories)
                if ~isempty(selectedFiles{iCat})
                    hasSelFiles = 1;
                    selFiles.(['i' categories{iCat}]) = selectedFiles{iCat};
                end
            end
            if hasSelFiles
                sql_query(sqlConn, 'update', 'subject', selFiles, struct('Id', argout1));
            end
            
        end
        sql_close(sqlConn);
        
        
%% ==== STUDY ====
    case 'Study'
        % Get studies list
        iStudies = varargin{2};
        sStudies = varargin{3};
        iAnalysisStudy = -2;
        iDefaultStudy  = -3;
        
        sqlConn = sql_connect();
        for i = 1:length(iStudies)
            % Inter-subject analysis study
            if iStudies(i) == iAnalysisStudy
                sExistingStudy = sql_query(sqlConn, 'select', 'study', 'Id', struct('Name', '@inter'));
            % Default study
            elseif iStudies(i) == iDefaultStudy
                sExistingStudy = sql_query(sqlConn, 'select', 'study', 'Id', struct('Name', '@default_study'));
            % Normal study
            else
                sExistingStudy = sql_query(sqlConn, 'select', 'study', 'Id', struct('Id', iStudies(i)));
            end
            
            % Get ID of parent subject
            sSubject = sql_query(sqlConn, 'select', 'subject', 'Id', struct('FileName', sStudies(i).BrainStormSubject));
            sStudies(i).Subject = sSubject.Id;
            
            % Extract selected channel/head model to get inserted ID later
            categories = {'Channel', 'HeadModel'};
            selectedFiles = cell(1, length(categories));
            for iCat = 1:length(categories)
                category = categories{iCat};
                field = ['i' category];
                if ~isempty(sStudies(i).(field)) && ischar(sStudies(i).(field))
                    selectedFiles{iCat} = sStudies(i).(field);
                elseif ~isempty(sStudies(i).(field)) && isnumeric(sStudies(i).(field))
                    % Get FileName with previous file ID before it's deleted
                    sFile = db_get('FunctionalFile', sqlConn, sStudies(i).(field), 'FileName');
                    if ~isempty(sFile)
                        selectedFiles{iCat} = sFile.FileName;
                    end
                end
                if isempty(selectedFiles{iCat}) && ~isempty(sStudies(i).(category))
                    selectedFiles{iCat} = sStudies(i).(category)(1).FileName;
                end
            end
            
            % If study exists, UPDATE query
            if ~isempty(sExistingStudy)
                sStudies(i).Id = sExistingStudy.Id;
                result = sql_query(sqlConn, 'update', 'study', sStudies(i), struct('Id', sExistingStudy.Id));
                if result
                    iStudy = sExistingStudy.Id;
                    argout1(end + 1) = iStudy;
                else
                    iStudy = [];
                end
            % If study is new, INSERT query
            else
                sStudies(i).Id = [];
                iStudy = sql_query(sqlConn, 'insert', 'study', sStudies(i));
                if ~isempty(iStudy)
                    argout1(end + 1) = iStudy;
                end
            end
            
            % Insert functional files
            if ~isempty(iStudy)
                sql_query(sqlConn, 'delete', 'functionalfile', struct('Study', iStudy));
                selectedFiles = db_set(sqlConn, 'FilesWithStudy', sStudies(i), selectedFiles);
            
                % Update study entry to add selected functional files, if any
                hasSelFiles = 0;
                selFiles = struct();
                for iCat = 1:length(categories)
                    if ~isempty(selectedFiles{iCat})
                        hasSelFiles = 1;
                        selFiles.(['i' categories{iCat}]) = selectedFiles{iCat};
                    end
                end
                if hasSelFiles
                    sql_query(sqlConn, 'update', 'Study', selFiles, struct('Id', iStudy));
                end
            end
        end
        sql_close(sqlConn);
        
        
%% ==== GUI ====
    % USAGE: bst_set('Layout', sLayout)
    %        bst_set('Layout', PropName, PropValue)
    case 'Layout'
        if (nargin == 2) && isstruct(contextValue)
            GlobalData.Preferences.Layout = contextValue;
            isUpdateScreens = 0;
        elseif (nargin == 3) && ischar(contextValue) && isfield(GlobalData.Preferences, 'Layout') && isfield(GlobalData.Preferences.Layout, contextValue)
            GlobalData.Preferences.Layout.(contextValue) = varargin{3};
            isUpdateScreens = strcmpi(contextValue, 'DoubleScreen');
        else
            error('Invalid call to bst_set.');
        end
        % Update screen configuration
        GlobalData.Program.ScreenDef = gui_layout('GetScreenClientArea');
        % Update layout right now
        gui_layout('Update');
        % If the number of screen was changed: update the maximum size of the Brainstorm window
        if isUpdateScreens
            gui_layout('UpdateMaxBstSize');
        end
        
    % USAGE: bst_set('FixedScaleY', [])
    %        bst_set('FixedScaleY', Modality, Value)
    case 'FixedScaleY'
        if (nargin == 3) && ~isempty(contextValue) && ~isempty(varargin{3})
            GlobalData.Preferences.FixedScaleY.(contextValue) = varargin{3};
        elseif (nargin == 2) && isempty(contextValue)
            GlobalData.Preferences.FixedScaleY = struct();
        end
        
    case 'ByteOrder'
        switch(contextValue)
            case {'b','ieee-le','n'}
                GlobalData.Preferences.ByteOrder = 'b';
            case {'l','ieee-be'}
                GlobalData.Preferences.ByteOrder = 'l';
            otherwise
                error('Invalid byte order.');
        end
        
    case 'Clipboard'
        if (length(varargin) >= 3)
            isCut = varargin{3};
        else
            isCut = 0;
        end
        GlobalData.Program.Clipboard.Nodes = contextValue;
        GlobalData.Program.Clipboard.isCut = isCut;
        
    case 'ElectrodeConfig'
        Modality = varargin{2};
        ElectrodeConf = varargin{3};
        if ~ismember(Modality, {'EEG','SEEG','ECOG'})
            error(['Invalid modality: ' Modality]);
        end
        GlobalData.Preferences.(contextName).(Modality) = ElectrodeConf;
        
    case {'UniformizeTimeSeriesScales', 'XScale', 'FlipYAxis', 'AutoScaleY', 'ShowXGrid', 'ShowYGrid', 'ShowZeroLines', 'ShowEventsMode', ...
          'Resolution', 'AutoUpdates', 'ExpertMode', 'DisplayGFP', 'ForceMatCompression', 'GraphicsSmoothing', 'DownsampleTimeSeries', ...
          'DisableOpenGL', 'InterfaceScaling', 'TSDisplayMode', 'UseSigProcToolbox', 'LastUsedDirs', 'DefaultFormats', ...
          'BFSProperties', 'ImportDataOptions', 'ImportEegRawOptions', 'RawViewerOptions', 'MontageOptions', 'TopoLayoutOptions', ...
          'StatThreshOptions', 'ContactSheetOptions', 'ProcessOptions', 'BugReportOptions', 'DefaultSurfaceDisplay', ...
          'MagneticExtrapOptions', 'MriOptions', 'NodelistOptions', 'IgnoreMemoryWarnings', 'SystemCopy', ...
          'TimefreqOptions_morlet', 'TimefreqOptions_hilbert', 'TimefreqOptions_fft', 'TimefreqOptions_psd', 'TimefreqOptions_plv', ...
          'OpenMEEGOptions', 'DuneuroOptions', 'DigitizeOptions', 'CustomColormaps', 'FieldTripDir', 'SpmDir', 'BrainSuiteDir', 'PythonConfig', ...
          'GridOptions_headmodel', 'GridOptions_dipfit', 'LastPsdDisplayFunction', 'KlustersExecutable', 'ExportBidsOptions'}
        GlobalData.Preferences.(contextName) = contextValue;

    case 'ReadOnly'
        GlobalData.DataBase.isReadOnly = contextValue;
    
    case 'PlotlyCredentials'
        if length(varargin) ~= 4
            error('Invalid call to bst_set.');
        end
        [username, apiKey, domain] = varargin{2:4};
        
        if isempty(domain)
            % Default Plot.ly server
            domain = 'http://plot.ly';
        end
        
        % Plotly needs a URL with HTTP and no trailing slash.
        if strfind(domain, 'https://')
            domain = strrep(domain, 'https://', 'http://');
        elseif isempty(strfind(domain, 'http://'))
            domain = ['http://', domain];
        end
        if domain(end) == '/'
            domain = domain(1:end-1);
        end
        
        saveplotlycredentials(username, apiKey);
        saveplotlyconfig(domain);
        
%% ==== ERROR ====
    otherwise
        error('Invalid context : ''%s''', contextName);
        

end

