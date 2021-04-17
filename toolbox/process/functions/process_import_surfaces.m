function varargout = process_import_surfaces( varargin )
% PROCESS_IMPORT_SURFACES: Import three surfaces in the database.

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
% Authors: Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import surfaces';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 3;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ImportAnatomy#Import_the_anatomy';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % File selection options
    SelectOptions = {...
        '', ...                                % Filename
        '', ...                                % FileFormat
        'open', ...                            % Dialog type: {open,save}
        'Import surface file...', ...          % Window title
        'ImportAnat', ...                      % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                          % Selection mode: {single,multiple}
        'files', ...                           % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'surface'), ... % Get all the available file formats
        'SurfaceIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: Head surface
    sProcess.options.headfile.Comment = 'Head surface:';
    sProcess.options.headfile.Type    = 'filename';
    sProcess.options.headfile.Value   = SelectOptions;
    % Option: Hemisphere 1
    sProcess.options.cortexfile1.Comment = 'Hemisphere 1:';
    sProcess.options.cortexfile1.Type    = 'filename';
    sProcess.options.cortexfile1.Value   = SelectOptions;
    % Option: Hemisphere 2
    sProcess.options.cortexfile2.Comment = 'Hemisphere 2:';
    sProcess.options.cortexfile2.Type    = 'filename';
    sProcess.options.cortexfile2.Value   = SelectOptions;
    % Option: Inner skull
    sProcess.options.innerfile.Comment = 'Inner skull:';
    sProcess.options.innerfile.Type    = 'filename';
    sProcess.options.innerfile.Value   = SelectOptions;
    % Option: Outer skull
    sProcess.options.outerfile.Comment = 'Outer skull:';
    sProcess.options.outerfile.Type    = 'filename';
    sProcess.options.outerfile.Value   = SelectOptions;
    % Option: Number of vertices
    sProcess.options.nverthead.Comment = 'Number of vertices (head): ';
    sProcess.options.nverthead.Type    = 'value';
    sProcess.options.nverthead.Value   = {7000, '', 0};
    % Option: Number of vertices
    sProcess.options.nvertcortex.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertcortex.Type    = 'value';
    sProcess.options.nvertcortex.Value   = {15000, '', 0};
    % Option: Number of vertices
    sProcess.options.nvertskull.Comment = 'Number of vertices (skull): ';
    sProcess.options.nvertskull.Type    = 'value';
    sProcess.options.nvertskull.Value   = {7000, '', 0};
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
    HeadFile      = sProcess.options.headfile.Value{1};
    HeadFormat    = sProcess.options.headfile.Value{2};
    CortexFile1   = sProcess.options.cortexfile1.Value{1};
    CortexFormat1 = sProcess.options.cortexfile1.Value{2};
    CortexFile2   = sProcess.options.cortexfile2.Value{1};
    CortexFormat2 = sProcess.options.cortexfile2.Value{2};
    InnerFile     = sProcess.options.innerfile.Value{1};
    InnerFormat   = sProcess.options.innerfile.Value{2};
    OuterFile     = sProcess.options.outerfile.Value{1};
    OuterFormat   = sProcess.options.outerfile.Value{2};
    if isempty([HeadFile, CortexFile1, InnerFile, OuterFile])
        bst_report('Error', sProcess, [], 'Not enough files selected.');
        return
    end
    % Number of vertices
    nVertHead   = sProcess.options.nverthead.Value{1};
    nVertCortex = sProcess.options.nvertcortex.Value{1};
    nVertSkull  = sProcess.options.nvertskull.Value{1};
    if isempty(nVertCortex) || (nVertCortex < 50) || isempty(nVertHead) || (nVertHead < 50) || isempty(nVertSkull) || (nVertSkull < 50)
        bst_report('Error', sProcess, [], 'Invalid number of vertices.');
        return
    end
    % Divide by number of cortex files
    if ~isempty(CortexFile2)
        nVertCortex = nVertCortex / 2;
    end
    
    % ===== GET/CREATE SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create subject is it does not exist yet
%     if isempty(sSubject)
%         [sSubject, iSubject] = db_add_subject(SubjectName);
%     end
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        bst_report('Error', sProcess, [], ['No MRI available for subject "' SubjectName '".']);
        return
    end
    
    % ===== HEAD FILE =====
    if ~isempty(HeadFile)
        % Import file
        [iScalp, OldHeadFile] = import_surfaces(iSubject, HeadFile, HeadFormat, 0);
        OldHeadFile = OldHeadFile{1};
        % Set the file type
        OldHeadFile = db_surface_type(OldHeadFile, 'Scalp');
        % Downsample
        NewHeadFile = tess_downsize(OldHeadFile, nVertHead, 'reducepatch');
        % Delete intial file
        if ~file_compare(OldHeadFile, NewHeadFile)
            file_delete(file_fullpath(OldHeadFile), 1);
            NewHeadFile = file_fullpath(NewHeadFile);
        end
        % Update Comment field
        HeadMat.Comment = 'Head';
        bst_save(file_fullpath(NewHeadFile), HeadMat, 'v7', 1);
    end
    
    % ===== CORTEX FILE =====
    % First hemisphere
    if ~isempty(CortexFile1)
        % Import file
        [iCortex1, OldCortexFile1] = import_surfaces(iSubject, CortexFile1, CortexFormat1, 0);
        OldCortexFile1 = OldCortexFile1{1};
        % Downsample
        NewCortexFile1 = tess_downsize(OldCortexFile1, nVertCortex, 'reducepatch');
        % Delete intial file
        if ~file_compare(NewCortexFile1, OldCortexFile1)
            file_delete(file_fullpath(OldCortexFile1), 1);
            NewCortexFile1 = file_fullpath(NewCortexFile1);
        end
    end
    % Second hemisphere
    if ~isempty(CortexFile2)
        % Import file
        [iCortex2, OldCortexFile2] = import_surfaces(iSubject, CortexFile2, CortexFormat2, 0);
        OldCortexFile2 = OldCortexFile2{1};
        % Downsample
        NewCortexFile2 = tess_downsize(OldCortexFile2, nVertCortex, 'reducepatch');
        % Delete intial file
        if ~file_compare(NewCortexFile2, OldCortexFile2)
            file_delete(file_fullpath(OldCortexFile2), 1);
            NewCortexFile2 = file_fullpath(NewCortexFile2);
        end
    end
    % Merge hemispheres
    if ~isempty(CortexFile1) && ~isempty(CortexFile2)
        CortexFile = tess_concatenate({NewCortexFile1, NewCortexFile2}, 'cortex');
        % Delete separate hemispheres
        file_delete({file_fullpath(NewCortexFile1), file_fullpath(NewCortexFile2)}, 1);
    % Only one hemisphere
    elseif ~isempty(CortexFile1)
        CortexFile = NewCortexFile1;
        % Update Comment field for Head file
        CortexMat.Comment = 'Cortex';
        bst_save(CortexFile, CortexMat, 'v7', 1);
    end
    % Set file type 
    if ~isempty(CortexFile1) || ~isempty(CortexFile2)
        CortexFile = db_surface_type(CortexFile, 'Cortex');
    end
    
    % ===== INNER SKULL =====
    if ~isempty(InnerFile)
        % Import file
        [iInner, OldInnerFile] = import_surfaces(iSubject, InnerFile, InnerFormat, 0);
        OldInnerFile = OldInnerFile{1};
        % Set the file type
        OldInnerFile = db_surface_type(OldInnerFile, 'InnerSkull');
        % Downsample
        NewInnerFile = tess_downsize(OldInnerFile, nVertSkull, 'reducepatch');
        % Update Comment field
        InnerMat.Comment = 'Inner skull';
        bst_save(file_fullpath(NewInnerFile), InnerMat, 'v7', 1);
        % Delete intial file
        if ~file_compare(OldInnerFile, NewInnerFile)
            file_delete(file_fullpath(OldInnerFile), 1);
        end
    end
    
    % ===== OUTER SKULL =====
    if ~isempty(OuterFile)
        % Import file
        [iOuter, OldOuterFile] = import_surfaces(iSubject, OuterFile, OuterFormat, 0);
        OldOuterFile = OldOuterFile{1};
        % Set the file type
        OldOuterFile = db_surface_type(OldOuterFile, 'OuterSkull');
        % Downsample
        NewOuterFile = tess_downsize(OldOuterFile, nVertSkull, 'reducepatch');
        % Update Comment field
        OuterMat.Comment = 'Outer skull';
        bst_save(file_fullpath(NewOuterFile), OuterMat, 'v7', 1);
        % Delete intial file
        if ~file_compare(OldOuterFile, NewOuterFile)
            file_delete(file_fullpath(OldOuterFile), 1);
        end
    end

    % Reload subject folder (necessary, because we deleted manually some files, 
    % without removing their references in the database)
    db_reload_subjects(iSubject);

    OutputFiles = {'import'};
end



