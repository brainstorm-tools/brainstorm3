function bst_set( varargin )
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
%    - bst_set('PythonExe',         PythonExe)
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
%    - bst_set('YScale',                YScale)
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

%% ==== PROTOCOL ====
    case 'iProtocol'
        if isnumeric(contextValue)
            GlobalData.DataBase.iProtocol = contextValue;
        else
            error('iProtocol should be a number.');
        end
    case {'ProtocolSubjects', 'ProtocolStudies'}
        for structField = fieldnames(contextValue)'
            GlobalData.DataBase.(contextName)(GlobalData.DataBase.iProtocol).(structField{1}) = contextValue.(structField{1});
        end
        GlobalData.DataBase.isProtocolModified(GlobalData.DataBase.iProtocol) = 1;
    case 'ProtocolInfo'
        for structField = fieldnames(contextValue)'
            GlobalData.DataBase.(contextName)(GlobalData.DataBase.iProtocol).(structField{1}) = contextValue.(structField{1});
        end
    case 'isProtocolLoaded'
        GlobalData.DataBase.isProtocolLoaded(GlobalData.DataBase.iProtocol) = contextValue;
    case 'isProtocolModified'
        GlobalData.DataBase.isProtocolModified(GlobalData.DataBase.iProtocol) = contextValue;

%% ==== SUBJECT ====
    case 'Subject'
        % Get subjects list
        ProtocolSubjects = bst_get('ProtocolSubjects');
        iSubject = varargin{2};
        sSubject = varargin{3};
        % If default subject
        if (iSubject == 0)
            ProtocolSubjects.DefaultSubject = sSubject;
        else
            ProtocolSubjects.Subject(iSubject) = sSubject;
        end
        % Update DataBase
        bst_set('ProtocolSubjects', ProtocolSubjects);
        
        
%% ==== STUDY ====
    case 'Study'
        % Get studies list
        ProtocolStudies = bst_get('ProtocolStudies');
        iStudies = varargin{2};
        sStudies = varargin{3};
        iAnalysisStudy = -2;
        iDefaultStudy  = -3;
        for i = 1:length(iStudies)
            % Normal study
            if (iStudies(i) > 0)
                ProtocolStudies.Study(iStudies(i)) = sStudies(i);
            % Inter-subject analysis study
            elseif (iStudies(i) == iAnalysisStudy)
                ProtocolStudies.AnalysisStudy = sStudies(i);
            % Default study
            elseif (iStudies(i) == iDefaultStudy)
                ProtocolStudies.DefaultStudy = sStudies(i);
            end
        end
        % Update DataBase
        bst_set('ProtocolStudies', ProtocolStudies);
        
        
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
        
    case {'UniformizeTimeSeriesScales', 'XScale', 'YScale', 'FlipYAxis', 'AutoScaleY', 'ShowXGrid', 'ShowYGrid', 'ShowZeroLines', 'ShowEventsMode', ...
          'Resolution', 'AutoUpdates', 'ExpertMode', 'DisplayGFP', 'ForceMatCompression', 'GraphicsSmoothing', 'DownsampleTimeSeries', ...
          'DisableOpenGL', 'InterfaceScaling', 'TSDisplayMode', 'UseSigProcToolbox', 'LastUsedDirs', 'DefaultFormats', ...
          'BFSProperties', 'ImportDataOptions', 'ImportEegRawOptions', 'RawViewerOptions', 'MontageOptions', 'TopoLayoutOptions', ...
          'StatThreshOptions', 'ContactSheetOptions', 'ProcessOptions', 'BugReportOptions', 'DefaultSurfaceDisplay', ...
          'MagneticExtrapOptions', 'MriOptions', 'NodelistOptions', 'IgnoreMemoryWarnings', 'SystemCopy', ...
          'TimefreqOptions_morlet', 'TimefreqOptions_hilbert', 'TimefreqOptions_fft', 'TimefreqOptions_psd', 'TimefreqOptions_plv', ...
          'OpenMEEGOptions', 'DuneuroOptions', 'DigitizeOptions', 'CustomColormaps', 'FieldTripDir', 'SpmDir', 'BrainSuiteDir', 'PythonExe', ...
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




