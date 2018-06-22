function varargout = process_import_mri( varargin )
% PROCESS_IMPORT_MRI: Import MRI in the database.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import MRI';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 2;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ImportAnatomy#Import_the_anatomy';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import MRI...', ...               % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'files', ...                       % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'mri'), ... % Get all the available file formats
        'MriIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: MRI file
    sProcess.options.mrifile.Comment = 'MRI filename:';
    sProcess.options.mrifile.Type    = 'filename';
    sProcess.options.mrifile.Value   = SelectOptions;
    % Option: NAS
    sProcess.options.label1.Comment = '<BR>Fiducial coordinates in millimeters (x,y,z):';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.nas.Comment = 'NAS:&nbsp;&nbsp;&nbsp;';
    sProcess.options.nas.Type    = 'value';
    sProcess.options.nas.Value   = {[0 0 0], 'list', 2};
    % Option: LPA
    sProcess.options.lpa.Comment = 'LPA:&nbsp;&nbsp;&nbsp;';
    sProcess.options.lpa.Type    = 'value';
    sProcess.options.lpa.Value   = {[0 0 0], 'list', 2};
    % Option: RPA
    sProcess.options.rpa.Comment = 'RPA:&nbsp;&nbsp;&nbsp;';
    sProcess.options.rpa.Type    = 'value';
    sProcess.options.rpa.Value   = {[0 0 0], 'list', 2};
    % Option: AC
    sProcess.options.ac.Comment = 'AC:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    sProcess.options.ac.Type    = 'value';
    sProcess.options.ac.Value   = {[0 0 0], 'list', 2};
    % Option: PC
    sProcess.options.pc.Comment = 'PC:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    sProcess.options.pc.Type    = 'value';
    sProcess.options.pc.Value   = {[0 0 0], 'list', 2};
    % Option: IH
    sProcess.options.ih.Comment = 'IH:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    sProcess.options.ih.Type    = 'value';
    sProcess.options.ih.Value   = {[0 0 0], 'list', 2};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return
    end
    % Get filenames to import
    MriFile = sProcess.options.mrifile.Value{1};
    if (length(sProcess.options.mrifile.Value) < 2) || isempty(sProcess.options.mrifile.Value{2})
        FileFormat = 'All';
    else
        FileFormat = sProcess.options.mrifile.Value{2};
    end
    if isempty(MriFile)
        bst_report('Error', sProcess, [], 'MRI file not selected.');
        return
    end
    % Fiducials positions
    NAS = sProcess.options.nas.Value{1};
    if (length(NAS) ~= 3) || all(NAS == 0)
        NAS = [];
    end
    LPA = sProcess.options.lpa.Value{1};
    if (length(LPA) ~= 3) || all(LPA == 0)
        LPA = [];
    end
    RPA = sProcess.options.rpa.Value{1};
    if (length(RPA) ~= 3) || all(RPA == 0)
        RPA = [];
    end
    AC  = sProcess.options.ac.Value{1};
    if (length(AC) ~= 3) || all(AC == 0)
        AC = [];
    end
    PC  = sProcess.options.pc.Value{1};
    if (length(PC) ~= 3) || all(PC == 0)
        PC = [];
    end
    IH  = sProcess.options.ih.Value{1};
    if (length(IH) ~= 3) || all(IH == 0)
        IH = [];
    end

    % ===== GET/CREATE SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create subject is it does not exist yet
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName);
    end
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Cannot create subject "' SubjectName '".']);
        return
    end
    
    % ===== IMPORT FILES =====
    % Import MRI file
    DbMriFile = import_mri(iSubject, MriFile, FileFormat);
    if isempty(DbMriFile)
        bst_report('Error', sProcess, [], ['Cannot import file: "' MriFile '".']);
        return
    end
    % Save fiducials in MRI
    figure_mri('SetSubjectFiducials', iSubject, NAS, LPA, RPA, AC, PC, IH);
    
    OutputFiles = {'import'};
end



